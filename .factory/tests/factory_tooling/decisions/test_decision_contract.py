"""Core decision boundary: no services, uncertain answers cannot waive checks."""

from __future__ import annotations

import unittest
from typing import Any

from factory_tooling.decisions.decision_contract import (
    preserve_obligations,
    validate_answer,
    validate_answers,
)
from factory_tooling.project.contracts import ProjectCheck, ProjectData
from factory_tooling.project.profile_rules import required_checks
from factory_tooling.runtime.workflow_config import load_config
from factory_tooling.runtime.workflow_core import Invalid
from tests.factory_tooling.runtime import test_workflow


def answer(value: Any) -> dict[str, Any]:
    return {
        "probability": 0.9 if value else 0.1,
        "source": "agent:fixture",
        "reason": "Inspected changed files and dependency inputs",
    }


class DecisionContractTests(unittest.TestCase):
    def test_no_decisions_keeps_unconditional_checks(self) -> None:
        check: ProjectCheck = {
            "id": "test",
            "kind": "observation",
            "level": "slice",
            "method": "Verify behavior",
        }
        profile: ProjectData = {
            "id": "fixture",
            "decisions": [],
            "gates": [{"id": "work", "at": ["implement.work"], "checks": [check]}],
        }
        self.assertEqual(
            ["test"], [x["id"] for x in required_checks(profile, {"scope": ["app.py"]})]
        )
        self.assertEqual({}, validate_answers([], {}))

    def test_agent_answers_work_without_provider_and_preserve_input(self) -> None:
        for value in (True, False):
            answers: dict[str, Any] = {"needed": answer(value)}
            results = validate_answers(
                [{"id": "needed", "question": "Required?", "type": "predicate"}], answers
            )
            self.assertIs(value, results["needed"]["value"])
            self.assertEqual({"needed": answer(value)}, answers)

    def test_unresolved_failed_probabilistic_or_unjustified_answer_never_becomes_false(
        self,
    ) -> None:
        for value in [
            None,
            {"error": "timeout"},
            {"probability": 0.01},
            {"value": False, "reason": "legacy"},
            answer(False) | {"probability": None},
            answer(False) | {"source": ""},
            answer(False) | {"reason": " "},
        ]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_answer({"id": "needed", "question": "Required?"}, value)

    def test_pending_definition_is_allowed_but_supplied_bad_answer_is_rejected(self) -> None:
        validate_answers([{"id": "later", "question": "Required?", "type": "predicate"}], {})
        with self.assertRaisesRegex(ValueError, "UNKNOWN"):
            validate_answers(
                [{"id": "later", "question": "Required?", "type": "predicate"}], {"later": {}}
            )
        with self.assertRaisesRegex(ValueError, "unknown policy"):
            validate_answers([], {"foreign": answer(True)})

    def test_active_obligations_cannot_be_removed_or_weakened(self) -> None:
        definitions = [{"id": "needed", "question": "Required?", "type": "predicate"}]
        for before, after in [
            ({"needed": answer(True)}, {}),
            ({"needed": answer(False)}, {}),
            ({"needed": answer(True)}, {"needed": answer(False)}),
        ]:
            with self.subTest(before=before, after=after), self.assertRaises(ValueError):
                preserve_obligations(definitions, before, after)
        preserve_obligations(definitions, {"needed": answer(False)}, {"needed": answer(True)})
        preserve_obligations(definitions, {"needed": answer(True)}, {"needed": answer(True)})

    def test_core_contract_and_validator_are_frozen_with_run(self) -> None:
        for rel in [
            "contracts/common/decisions.md",
            "factory_tooling/decisions/decision_contract.py",
        ]:
            with self.subTest(rel=rel):
                f = test_workflow.WorkflowTests()
                f.setUp()
                self.addCleanup(f.doCleanups)
                file = f.config_file(lambda c: None)
                f.config = load_config(file)
                f.init()
                f.ledger.claim("write-label")
                (file.parent / rel).write_text("changed")
                with self.assertRaisesRegex(Invalid, "drift"):
                    f.ledger.packet("write-label")
