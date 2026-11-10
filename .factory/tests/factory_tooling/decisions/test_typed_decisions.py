"""Typed decisions: thresholds, malformed estimates, consumers and pinned policy."""

from __future__ import annotations

import unittest
from copy import deepcopy
from typing import Any

from factory_tooling.decisions.decision_contract import (
    preserve_obligations,
    validate_answer,
    validate_answers,
    validate_definition,
)
from factory_tooling.project.profile_io import (
    check_frozen,
    load_profile,
    snapshot,
    validate_snapshot,
)
from factory_tooling.project.profile_rules import required_checks, validate
from tests.factory_tooling.project import test_decision_files
from tests.factory_tooling.project.test_gates import policy


def definition(kind: str, threshold: float = 0.4) -> dict[str, Any]:
    result = dict(
        id="d", type=kind, question="Evaluate the supplied evidence", min_confidence=threshold
    )
    if kind == "choice":
        result["choices"] = [dict(value=k, description="Case " + k) for k in ("a", "b", "c")]
    if kind == "score":
        result["levels"] = [
            dict(label=k, description="Level " + k) for k in ("low", "medium", "high")
        ]
    return result


def answer(**value: Any) -> dict[str, Any]:
    return dict(reason="Inspected fixture inputs", source="agent:fixture", **value)


class TypedDecisionTests(unittest.TestCase):
    def test_predicate_threshold_inclusive_and_symmetric(self) -> None:
        d = definition("predicate")
        for p, expected in [(0, False), (0.3, False), (0.7, True), (1, True)]:
            self.assertIs(validate_answer(d, answer(probability=p))["value"], expected)
        for p in (0.3001, 0.5, 0.6999):
            with self.subTest(p=p), self.assertRaisesRegex(ValueError, "UNKNOWN"):
                validate_answer(d, answer(probability=p))
        with self.assertRaisesRegex(ValueError, "UNKNOWN"):
            validate_answer(definition("predicate", 0), answer(probability=0.5))

    def test_typed_threshold_cannot_be_bypassed_by_legacy_boolean(self) -> None:
        for d in [definition("predicate"), dict(id="d", question="Q", min_confidence=0.4)]:
            with self.assertRaises(ValueError):
                validate_answer(d, dict(value=False, reason="skip"))
        with self.assertRaises(ValueError):
            validate_answer(dict(id="d", question="Q"), dict(value=False, reason="legacy"))
        with self.assertRaises(ValueError):
            validate_answers(["d"], {})

    def test_choice_accepts_only_unique_winner_and_threshold(self) -> None:
        d = definition("choice", 0.6)
        a = answer(choice="b", probabilities={"a": 0.1, "b": 0.8, "c": 0.1}, confidence=0.7)
        original = deepcopy(a)
        self.assertEqual("b", validate_answer(d, a)["value"])
        self.assertEqual(original, a)
        patches: list[dict[str, Any]] = [
            dict(choice="missing"),
            dict(choice="a"),
            dict(confidence=0.59),
            dict(probabilities={"a": 0.5, "b": 0.5, "c": 0}),
        ]
        for patch in patches:
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                validate_answer(d, a | patch)

    def test_score_uses_mean_and_separate_confidence(self) -> None:
        d = definition("score", 0.6)
        a = answer(score=1.1, probabilities={"0": 0, "1": 0.9, "2": 0.1}, confidence=0.85)
        self.assertEqual(1.1, validate_answer(d, a)["value"])
        patches: list[dict[str, Any]] = [
            dict(score=1),
            dict(score=3),
            dict(score=True),
            dict(confidence=0.5),
        ]
        for patch in patches:
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                validate_answer(d, a | patch)
        # The same mean may hide disagreement between extreme levels.
        with self.assertRaisesRegex(ValueError, "min_confidence"):
            validate_answer(
                d, answer(score=1, probabilities={"0": 0.5, "1": 0, "2": 0.5}, confidence=0)
            )

    def test_invalid_numbers_distributions_and_sources_fail_closed(self) -> None:
        for bad in [True, "0.9", None, float("nan"), float("inf"), -0.1, 1.1, 10**400]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                validate_answer(definition("predicate"), answer(probability=bad))
            with self.subTest(confidence=bad), self.assertRaises(ValueError):
                validate_answer(
                    definition("choice"),
                    answer(choice="a", probabilities={"a": 1, "b": 0, "c": 0}, confidence=bad),
                )
        for distribution in [
            {"a": 1},
            {"a": 1, "b": 0, "c": 0, "foreign": 0},
            {"a": 0.8, "b": 0.1, "c": 0},
            {"a": float("nan"), "b": 0, "c": 0},
            {"a": True, "b": 0, "c": 0},
            [],
        ]:
            with self.subTest(distribution=distribution), self.assertRaises(ValueError):
                validate_answer(
                    definition("choice"),
                    answer(choice="a", probabilities=distribution, confidence=1),
                )
        for a in [
            dict(probability=0.9),
            answer(probability=0.9) | {"source": ""},
            answer(probability=0.9) | {"reason": " "},
            answer(probability=0.9) | {"value": True},
            {"error": "timeout"},
            {"type": "refusal"},
        ]:
            with self.subTest(a=a), self.assertRaises(ValueError):
                validate_answer(definition("predicate"), a)

    def test_definitions_validate_types_options_levels_and_thresholds(self) -> None:
        for kind in ("predicate", "choice", "score"):
            validate_definition(definition(kind))
        bad = [
            definition("predicate") | {"type": "box"},
            definition("predicate") | {"min_confidence": True},
            definition("predicate") | {"min_confidence": float("nan")},
            definition("predicate") | {"criteria": {"true": "yes"}},
            definition("predicate") | {"choices": []},
            definition("choice") | {"choices": [{"value": "a", "description": "a"}] * 2},
            definition("score") | {"levels": []},
            definition("score")
            | {"levels": [{"label": str(i), "description": "L"} for i in range(11)]},
        ]
        for d in bad:
            with self.subTest(d=d), self.assertRaises(ValueError):
                validate_definition(d)

    def test_all_supplied_answers_checked_even_when_unused(self) -> None:
        p = policy()
        p["decisions"] = [definition("choice", 0.6)]
        task: dict[str, Any] = dict(
            scope=["src/a.py"],
            policy_decisions={
                "d": answer(
                    choice="a", probabilities={"a": 0.8, "b": 0.1, "c": 0.1}, confidence=0.7
                )
            },
        )
        self.assertTrue(required_checks(p, task))
        task["policy_decisions"]["d"]["confidence"] = 0.5
        with self.assertRaisesRegex(ValueError, "min_confidence"):
            required_checks(p, task)
        validate_answers(p["decisions"], {})

    def test_check_references_reject_choice_and_score(self) -> None:
        for kind in ("choice", "score"):
            p = policy()
            p["decisions"] = [definition(kind)]
            p["gates"][0]["checks"][0]["decision"] = "d"
            with self.assertRaisesRegex(ValueError, "must be predicate"):
                validate(p)

    def test_predicate_controls_checks_after_threshold_validation(self) -> None:
        p = policy()
        p["decisions"] = [definition("predicate")]
        p["gates"][0]["checks"][0]["decision"] = "d"
        validate(p)
        for probability, count in [(0.1, 0), (0.9, 1)]:
            self.assertEqual(
                count,
                len(
                    required_checks(
                        p,
                        dict(
                            scope=["src/a.py"],
                            policy_decisions={"d": answer(probability=probability)},
                        ),
                    )
                ),
            )
        with self.assertRaisesRegex(ValueError, "UNKNOWN"):
            required_checks(
                p, dict(scope=["src/a.py"], policy_decisions={"d": answer(probability=0.6)})
            )

    def test_revisions_preserve_predicates_and_typed_values(self) -> None:
        yes: dict[str, Any] = {"d": answer(probability=0.9)}
        no: dict[str, Any] = {"d": answer(probability=0.1)}
        preserve_obligations([definition("predicate")], no, yes)
        with self.assertRaisesRegex(ValueError, "weaken"):
            preserve_obligations([definition("predicate")], yes, no)
        for kind, value, changed in [
            (
                "choice",
                answer(choice="a", probabilities={"a": 0.8, "b": 0.1, "c": 0.1}, confidence=0.7),
                answer(choice="b", probabilities={"a": 0.1, "b": 0.8, "c": 0.1}, confidence=0.7),
            ),
            (
                "score",
                answer(score=1.1, probabilities={"0": 0, "1": 0.9, "2": 0.1}, confidence=0.85),
                answer(score=1.2, probabilities={"0": 0, "1": 0.8, "2": 0.2}, confidence=0.85),
            ),
        ]:
            before: dict[str, Any] = {"d": value}
            definitions = [definition(kind)]
            preserve_obligations(definitions, before, deepcopy(before))
            with self.assertRaisesRegex(ValueError, "re-intake"):
                preserve_obligations(definitions, before, {"d": changed})
            with self.assertRaisesRegex(ValueError, "remove"):
                preserve_obligations(definitions, before, {})

    def test_typed_definitions_roundtrip_and_threshold_drift(self) -> None:
        f = test_decision_files.DecisionFileTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.definitions = [
            definition("predicate") | {"id": "needs-static"},
            definition("choice"),
            definition("score") | {"id": "severity"},
        ]
        f.write()
        loaded = load_profile(f.file)
        pinned = snapshot(loaded, source="accepted fixture")
        self.assertEqual(loaded["data"], validate_snapshot(pinned))
        f.definitions[0]["min_confidence"] = 0.8
        f.write()
        with self.assertRaisesRegex(ValueError, "drift"):
            check_frozen(loaded["files"])
        self.assertEqual(0.4, validate_snapshot(pinned)["decisions"][0]["min_confidence"])
