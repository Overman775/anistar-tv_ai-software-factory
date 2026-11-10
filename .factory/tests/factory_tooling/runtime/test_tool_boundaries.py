"""Behavior at the new module boundaries: drift, process receipts and policy."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

from factory_tooling.runtime.check_process import Process, execute_check
from factory_tooling.runtime.contracts import EscalationPolicy
from factory_tooling.runtime.escalation import correction_decision
from factory_tooling.runtime.workflow_config import load_config
from factory_tooling.runtime.workflow_core import Invalid
from tests.factory_tooling.runtime import test_workflow

_TOOLS = Path(__file__).resolve().parents[3] / "tools"


class ToolBoundaryTests(unittest.TestCase):
    def test_extracted_runtime_and_plan_rules_are_frozen_before_dispatch(self) -> None:
        files = [
            "tools/workflow.py",
            "gates/skills/planning/validate_plan.py",
            "factory_tooling/runtime/assignment.py",
            "factory_tooling/runtime/command_contract.py",
            "factory_tooling/runtime/workflow_core.py",
            "factory_tooling/runtime/workflow_config.py",
            "factory_tooling/runtime/workflow_graph.py",
            "factory_tooling/runtime/workflow_sources.py",
            "factory_tooling/runtime/check_process.py",
            "factory_tooling/runtime/escalation_policy.py",
            "factory_tooling/planning/plan_document.py",
            "factory_tooling/planning/plan_rules.py",
            "factory_tooling/planning/plan_revision.py",
        ]
        for relative in files:
            with self.subTest(module=relative):
                fixture = test_workflow.WorkflowTests()
                fixture.setUp()
                try:
                    config_file = fixture.config_file(lambda c: None)
                    fixture.config = load_config(config_file)
                    fixture.init()
                    target = config_file.parent / relative
                    self.assertTrue(str(target.resolve()) in fixture.config["_files"], relative)
                    target.write_text(target.read_text() + "\n# changed policy\n")
                    with self.assertRaisesRegex(Invalid, "drift"):
                        fixture.ledger.claim("write-label")
                finally:
                    fixture.doCleanups()

    def test_process_runner_publishes_pid_before_wait_and_preserves_failure(self) -> None:
        events: list[tuple[str, object]] = []

        class Process:
            pid = 42

            def wait(self, timeout: float | None = None) -> int:
                events.append(("wait", timeout))
                return 7

            def kill(self) -> None:
                raise AssertionError("Unexpected kill on completed process")

        def popen(argv: list[str], **kwargs: Any) -> Process:
            events.append(("spawn", argv))
            kwargs["stdout"].write(b"failure evidence")
            return Process()

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "result.log"
            result = execute_check(
                {"argv": ["fake-check"], "cwd": ".", "timeout_seconds": 9},
                Path(directory),
                output,
                lambda pid: events.append(("started", pid)),
                popen=popen,
            )
            self.assertEqual((7, "FAIL", None), result)
            self.assertEqual([("spawn", ["fake-check"]), ("started", 42), ("wait", 9)], events)
            self.assertEqual(b"failure evidence", output.read_bytes())

    def test_corrupt_persisted_types_fail_before_a_transition_or_write(self) -> None:
        fixture = test_workflow.WorkflowTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        fixture.init()
        state = json.loads(fixture.ledger.path.read_text())
        state["counters"] = {"label:tests": "zero"}
        from factory_tooling.runtime.workflow_core import atomic_json

        atomic_json(fixture.ledger.path, state)
        before = fixture.ledger.path.read_bytes()
        with self.assertRaisesRegex(Invalid, "Invalid persisted state.*counters"):
            fixture.ledger.claim("write-label")
        self.assertEqual(before, fixture.ledger.path.read_bytes())

    def test_disabled_escalation_survives_state_roundtrip(self) -> None:
        fixture = test_workflow.WorkflowTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        config_file = fixture.config_file(
            lambda c: c["profiles"]["generalist"]["variants"]["generalist"].update(escalation=None)
        )
        fixture.config = load_config(config_file)
        fixture.init()
        self.assertIsNone(fixture.ledger.read()["config"]["profiles"]["generalist"]["escalation"])
        fixture.ledger.claim("write-label")

    def test_invalid_state_is_rejected_before_initial_write_or_save(self) -> None:
        fixture = test_workflow.WorkflowTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        # The semantic source validator accepts extra metadata; persisted fields still need types.
        fixture.g["sources"]["request"]["plan_revision"] = "one"
        with self.assertRaisesRegex(Invalid, "Invalid persisted state.*plan_revision"):
            fixture.init()
        self.assertFalse(fixture.ledger.path.exists())
        fixture.g["sources"]["request"].pop("plan_revision")
        state = fixture.init()
        before = fixture.ledger.path.read_bytes()
        invalid = json.loads(json.dumps(state))
        invalid["counters"] = {"label:tests": "zero"}
        with self.assertRaisesRegex(Invalid, "Invalid persisted state.*counters"):
            fixture.ledger.save(invalid, "invalid")
        self.assertEqual(before, fixture.ledger.path.read_bytes())

    def test_exhausted_budget_wins_over_escalation(self) -> None:
        policy: EscalationPolicy = {"to": "senior", "after_failed_attempts": 2}
        self.assertEqual(
            ("human", "human"), correction_decision("quality", "middle", policy, 2, 1, 1)
        )
        self.assertEqual(
            ("senior", "escalate"), correction_decision("quality", "middle", policy, 2, 0, 1)
        )
        self.assertEqual(
            ("middle", "retry"), correction_decision("quality", "middle", policy, 1, 0, 1)
        )
        self.assertEqual(
            ("middle", "blocked"), correction_decision("environment", "middle", policy, 3, 0, 1)
        )


if __name__ == "__main__":
    unittest.main()
