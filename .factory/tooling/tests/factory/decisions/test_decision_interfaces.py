"""One validated decision result feeds consumers and ledger revisions."""

from __future__ import annotations

import unittest
from copy import deepcopy
from typing import Any

import yaml

from factory.decisions.decision_contract import (
    DEFINITION,
    preserve_obligations,
    validate_answer,
    validate_answers,
)
from factory.project.profile_io import load_profile
from factory.project.profile_rules import required_checks
from factory.runtime.workflow_core import Invalid
from tests.factory.decisions.fixture_decisions import answer, definition
from tests.factory.project.fixture_policy import policy
from tests.factory.runtime import workflow_fixture
from tests.fixture_bundle import ROOT as FIXTURE_ROOT


def estimates() -> dict[str, Any]:
    return {
        "predicate": answer(probability=0.1),
        "choice": answer(choice="a", probabilities={"a": 0.8, "b": 0.1, "c": 0.1}, confidence=0.7),
        "score": answer(score=1.1, probabilities={"0": 0, "1": 0.9, "2": 0.1}, confidence=0.85),
    }


def definitions() -> list[dict[str, Any]]:
    return [definition(kind) | {"id": kind} for kind in estimates()]


class DecisionInterfaceTests(unittest.TestCase):
    def test_shipped_example_loads_and_uses_all_three_decision_types(self) -> None:
        profile = load_profile(FIXTURE_ROOT / "project/project.example.yaml")["data"]
        raw: dict[str, Any] = {
            "needs-e2e": answer(probability=0.1),
            "change-category": answer(
                choice="fix",
                probabilities={"fix": 0.8, "feature": 0.1, "other": 0.1},
                confidence=0.7,
            ),
            "issue-severity": estimates()["score"],
        }
        results = validate_answers(profile["decisions"], raw)
        self.assertEqual(
            {"needs-e2e": False, "change-category": "fix", "issue-severity": 1.1},
            {key: value["value"] for key, value in results.items()},
        )
        self.assertEqual("docs/business/billing.md", profile["documents"]["business-rules"]["path"])
        self.assertTrue(
            {"decomposition-coordinator", "decomposition-workers"}
            <= {rule["id"] for entries in profile["rules"].values() for rule in entries}
        )

    def test_all_types_return_values_confidence_and_provenance_without_mutation(self) -> None:
        raw = estimates()
        original = deepcopy(raw)
        result = validate_answers(definitions(), raw)
        expected: dict[str, Any] = {
            "predicate": (False, 0.8),
            "choice": ("a", 0.7),
            "score": (1.1, 0.85),
        }
        for d in definitions():
            key = d["id"]
            with self.subTest(kind=key):
                self.assertEqual(validate_answer(d, raw[key]), result[key])
                self.assertEqual(
                    {"id", "type", "value", "confidence", "source", "reason"}, set(result[key])
                )
                self.assertEqual((key, key), (result[key]["id"], result[key]["type"]))
                self.assertEqual(expected[key][0], result[key]["value"])
                self.assertAlmostEqual(expected[key][1], result[key]["confidence"])
                self.assertEqual(raw[key]["source"], result[key]["source"])
                self.assertEqual(raw[key]["reason"], result[key]["reason"])
        result["predicate"]["value"] = True
        self.assertEqual(original, raw)

    def test_missing_results_remain_absent_and_invalid_unused_answers_are_rejected(self) -> None:
        raw = estimates()
        self.assertEqual({}, validate_answers(definitions(), {}))
        self.assertEqual(
            {"predicate"}, set(validate_answers(definitions(), {"predicate": raw["predicate"]}))
        )
        for invalid in (
            raw | {"foreign": raw["predicate"]},
            raw | {"score": {"error": "unavailable"}},
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                validate_answers(definitions(), invalid)

    def test_revision_cannot_bypass_validation_of_either_side_or_added_answers(self) -> None:
        raw = estimates()
        invalid = [
            raw | {"predicate": answer(probability=0.6)},
            raw | {"choice": answer(choice="a")},
            raw | {"score": answer(probability=0.9)},
            raw | {"choice": raw["choice"] | {"source": ""}},
            raw | {"foreign": raw["predicate"]},
        ]
        for bad in invalid:
            for before, after in ((raw, bad), (bad, raw), ({}, bad)):
                with self.subTest(before=before, after=after), self.assertRaises(ValueError):
                    preserve_obligations(definitions(), before, after)

    def test_same_value_reassessment_can_update_confidence_and_evidence(self) -> None:
        before = estimates()
        after = {
            key: value | {"source": "agent:recheck", "reason": "Rechecked current inputs"}
            for key, value in before.items()
        }
        after["predicate"]["probability"] = 0.2
        after["choice"]["confidence"] = 0.6
        after["score"]["confidence"] = 0.9
        preserve_obligations(definitions(), before, after)

    def test_check_consumer_requires_predicate_without_truthiness_coercion(self) -> None:
        for kind in ("choice", "score"):
            p = policy()
            p["decisions"] = [DEFINITION.validate_python(definition(kind) | {"id": kind})]
            p["gates"][0]["checks"][0]["decision"] = kind
            task = dict(scope=["src/a.py"], policy_decisions={kind: estimates()[kind]})
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, "must be predicate"):
                required_checks(p, task)

    def workflow(self) -> workflow_fixture.WorkflowFixture:
        fixture = workflow_fixture.WorkflowFixture(self.addCleanup)
        fixture.fixture_profile.write_text(
            yaml.safe_dump({"id": "decision-fixture", "decisions": definitions()})
        )
        fixture.config["_project"] = load_profile(fixture.fixture_profile)
        fixture.config["_files"].update(fixture.config["_project"]["files"])
        fixture.g["tasks"]["label"]["policy_decisions"] = estimates()
        fixture.init()
        return fixture

    def test_reintake_keeps_history_budgets_and_guards_obligations(self) -> None:
        fixture = self.workflow()
        fixture.start("write-label")
        fixture.ledger.finish("write-label", fixture.report("write-label", "FAIL"))
        fixture.ledger.retry("write-label", "tests", "Correct failed work", "writer stopped")
        fixture.complete()
        initial = fixture.ledger.read()
        self.assertTrue(initial["counters"])
        self.assertEqual("done", initial["nodes"]["verify-label"]["status"])
        changed = deepcopy(fixture.g)
        changed["tasks"]["label"]["policy_decisions"]["choice"] = answer(
            choice="b", probabilities={"a": 0.1, "b": 0.8, "c": 0.1}, confidence=0.7
        )
        changed["tasks"]["label"]["policy_decisions"]["score"] = answer(
            score=1.2, probabilities={"0": 0, "1": 0.8, "2": 0.2}, confidence=0.85
        )
        fixture.ledger.reintake(changed, "Changed inputs", "user instruction")
        state = fixture.ledger.read()
        self.assertEqual(initial["run_id"], state["run_id"])
        self.assertEqual(initial["counters"], state["counters"])
        self.assertEqual(initial["revision"] + 1, state["revision"])
        self.assertTrue(all(node["status"] == "pending" for node in state["nodes"].values()))
        self.assertEqual("source_reintake", state["events"][-1]["event"])
        self.assertEqual(initial["graph"], state["events"][-1]["previous_graph"])
        self.assertEqual(initial["nodes"], state["events"][-1]["previous_nodes"])
        with self.assertRaises(Invalid):
            fixture.ledger.accept("accept-label")
        strengthened = deepcopy(changed)
        strengthened["tasks"]["label"]["policy_decisions"]["predicate"] = answer(probability=0.9)
        fixture.ledger.reintake(strengthened, "Changed inputs", "user instruction")
        weakened = deepcopy(strengthened)
        weakened["tasks"]["label"]["policy_decisions"]["predicate"] = answer(probability=0.1)
        with self.assertRaisesRegex(Invalid, "weaken"):
            fixture.ledger.reintake(weakened, "Changed inputs", "user instruction")
        removed = deepcopy(strengthened)
        removed["tasks"]["label"]["required_checks"] = []
        with self.assertRaises(Invalid):
            fixture.ledger.reintake(removed, "Changed inputs", "user instruction")

    def test_reintake_refreshes_only_decision_policy(self) -> None:
        fixture = self.workflow()
        revised_policy = definitions()
        revised_policy[1]["min_confidence"] = 0.6
        fixture.fixture_profile.write_text(
            yaml.safe_dump({"id": "decision-fixture", "decisions": revised_policy})
        )
        revised = deepcopy(fixture.g)
        revised["tasks"]["label"]["policy_decisions"]["choice"] = answer(
            choice="b", probabilities={"a": 0.1, "b": 0.8, "c": 0.1}, confidence=0.7
        )
        fixture.ledger.reintake(revised, "Policy threshold changed", "user authorized")
        state = fixture.ledger.read()
        self.assertEqual(revised_policy, state["config"]["_project"]["data"]["decisions"])
        self.assertNotEqual(
            state["events"][-1]["previous_config"]["_project"]["hash"],
            state["config"]["_project"]["hash"],
        )
        fixture.fixture_profile.write_text(
            yaml.safe_dump({"id": "different", "decisions": revised_policy})
        )
        with self.assertRaisesRegex(Invalid, "Only decision policy"):
            fixture.ledger.reintake(revised, "Unrelated policy change", "user authorized")

    def test_ledger_revision_uses_pinned_definitions_and_retains_raw_estimates(self) -> None:
        fixture = self.workflow()
        revised = deepcopy(fixture.g)
        revised["tasks"]["label"]["policy_decisions"]["predicate"] = answer(probability=0.9)
        initial_revision = fixture.ledger.read()["revision"]
        fixture.ledger.revise(revised, "Evidence now requires the condition")
        state = fixture.ledger.read()
        self.assertEqual(
            revised["tasks"]["label"]["policy_decisions"],
            state["graph"]["tasks"]["label"]["policy_decisions"],
        )
        self.assertEqual(initial_revision + 1, state["revision"])

        for kind, changed, message in (
            ("predicate", answer(probability=0.1), "weaken"),
            ("predicate", answer(probability=0.6), "min_confidence"),
            (
                "choice",
                answer(choice="b", probabilities={"a": 0.1, "b": 0.8, "c": 0.1}, confidence=0.7),
                "re-intake",
            ),
            (
                "score",
                answer(score=1.2, probabilities={"0": 0, "1": 0.8, "2": 0.2}, confidence=0.85),
                "re-intake",
            ),
        ):
            candidate = deepcopy(revised)
            candidate["tasks"]["label"]["policy_decisions"][kind] = changed
            with self.subTest(kind=kind, message=message), self.assertRaisesRegex(Invalid, message):
                fixture.ledger.revise(candidate, "Invalid reassessment")
            self.assertEqual(state, fixture.ledger.read())
