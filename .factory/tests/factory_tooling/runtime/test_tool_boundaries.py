"""Behavior at the new module boundaries: drift, process receipts and policy."""

from __future__ import annotations

import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory_tooling.runtime.assignment import implement_packet, validate_packet
from factory_tooling.runtime.check_process import Process, execute_check
from factory_tooling.runtime.contracts import EscalationPolicy
from factory_tooling.runtime.escalation import correction_decision
from factory_tooling.runtime.workflow_config import load_config
from factory_tooling.runtime.workflow_core import Invalid, atomic_json
from factory_tooling.runtime.workflow_graph import validate_graph
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
        # Reject malformed source metadata before the first ledger write.
        fixture.g["sources"]["request"]["plan_revision"] = "one"
        with self.assertRaisesRegex(Invalid, "Invalid workflow graph.*plan_revision"):
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

    def test_ledger_rejects_unknown_nested_fields_and_bool_counter(self) -> None:
        fixture = test_workflow.WorkflowTests()
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        state = fixture.init()
        for path, value, location in (
            ("unexpected", "secret input must stay out of errors", "extra field"),
            ("attempt", True, "attempt"),
        ):
            with self.subTest(path=path):
                raw = json.loads(json.dumps(state))
                raw["nodes"]["write-label"][path] = value
                fixture.ledger.path.write_text(json.dumps(raw))
                with self.assertRaisesRegex(Invalid, rf"nodes\.\*.*{location}") as caught:
                    fixture.ledger.read()
                self.assertNotIn("secret input", str(caught.exception))

    def test_graph_intake_rejects_missing_and_null_full_records(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        for field in (
            "kind",
            "risk",
            "independent_review",
            "source",
            "scope",
            "required_checks",
            "acceptance_ids",
        ):
            for missing in (True, False):
                graph = deepcopy(f.g)
                if missing:
                    del graph["tasks"]["label"][field]
                else:
                    graph["tasks"]["label"][field] = None
                with self.subTest(field=field, missing=missing):
                    with self.assertRaisesRegex(Invalid, rf"tasks\.\*\.{field}"):
                        validate_graph(graph, f.config, f.root)
                    with self.assertRaisesRegex(Invalid, rf"tasks\.\*\.{field}"):
                        f.ledger.init(graph, f.config)
                    self.assertFalse(f.ledger.path.exists())

        for field in ("id", "task", "stage", "agent", "depends_on"):
            graph = deepcopy(f.g)
            del graph["nodes"][0][field]
            with self.subTest(node_field=field):
                with self.assertRaisesRegex(Invalid, rf"nodes\.0\.{field}"):
                    f.ledger.init(graph, f.config)
                self.assertFalse(f.ledger.path.exists())

    def test_persisted_assignment_enforces_full_nested_contract(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.init()
        f.start("write-label")
        current = f.ledger.read()
        original = f.ledger.path.read_bytes()
        for key, payload, reason in (
            (
                "task",
                {**current["nodes"]["write-label"]["assignment"]["task"], "scope": 123},
                "assignment.task.scope",
            ),
            (
                "source",
                {
                    key: value
                    for key, value in current["nodes"]["write-label"]["assignment"][
                        "source"
                    ].items()
                    if key != "snapshot"
                },
                "assignment.source.snapshot",
            ),
            ("requirements", {}, "assignment.requirements"),
            ("unknown", 42, "assignment.*extra field"),
        ):
            with self.subTest(key=key):
                invalid = json.loads(json.dumps(current))
                invalid["nodes"]["write-label"]["assignment"][key] = payload
                with self.assertRaisesRegex(Invalid, reason):
                    f.ledger.save(invalid, "invalid")
                self.assertEqual(original, f.ledger.path.read_bytes())
                atomic_json(f.ledger.path, invalid)
                with self.assertRaisesRegex(Invalid, reason):
                    f.ledger.read()
                f.ledger.path.write_bytes(original)

    def test_ledger_requires_source_locks_added_during_intake(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        self.assertNotIn("hash", f.g["sources"]["request"])
        validate_graph(f.g, f.config, f.root)
        f.init()
        original = f.ledger.path.read_bytes()
        for field in ("hash", "content_hash", "snapshot", "kind", "execution_mode"):
            with self.subTest(field=field):
                invalid = json.loads(original)
                del invalid["graph"]["sources"]["request"][field]
                with self.assertRaisesRegex(Invalid, rf"graph\.sources\.\*\.{field}"):
                    f.ledger.save(invalid, "invalid")
                self.assertEqual(original, f.ledger.path.read_bytes())
                atomic_json(f.ledger.path, invalid)
                with self.assertRaisesRegex(Invalid, rf"graph\.sources\.\*\.{field}"):
                    f.ledger.read()
                f.ledger.path.write_bytes(original)

    def test_packet_rejects_invalid_owned_projections_before_publishing(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.init()
        f.ledger.claim("write-label")
        state = f.ledger.read()
        for producer, payload, reason in (
            (
                "escalation.worker_context",
                {"remaining_retries": {"tests": "unbounded"}},
                "correction.remaining_retries.tests",
            ),
            (
                "escalation.worker_context",
                {
                    "history": [],
                    "blocker_resolutions": [],
                    "session_handoffs": [{"agent": "author", "handoff": "ready", "extra": True}],
                    "remaining_retries": {
                        "static": 0,
                        "tests": 0,
                        "docs": 0,
                        "recovery": 0,
                        "review": 0,
                    },
                    "instruction": "continue",
                },
                "correction.session_handoffs.0.*extra field",
            ),
            (
                "review_findings.view",
                {"REV-1": {"status": 123, "blocking": "yes"}},
                r"review_findings\.\*\.blocking",
            ),
        ):
            with self.subTest(producer=producer, reason=reason):
                with patch("factory_tooling.runtime.assignment." + producer, return_value=payload):
                    with self.assertRaisesRegex(Invalid, reason):
                        f.ledger.prepare_packet("write-label")
                self.assertEqual(state, f.ledger.read())
                self.assertEqual([], list(f.ledger.dir.glob("*.packet.json")))
        self.assertIn("sha256", f.ledger.prepare_packet("write-label"))

    def test_check_specs_reject_missing_and_null_fields_at_ledger_boundaries(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        f.ledger.run_check("verify-label", "behavior")
        state = f.ledger.read()
        original = f.ledger.path.read_bytes()
        [rid] = state["executions"]
        for location in ("graph", "assignment task", "assignment allowed", "execution"):
            for field in ("id", "kind", "category", "criteria", "method", "execution"):
                for missing in (True, False):
                    raw = json.loads(original)
                    assignment = raw["nodes"]["verify-label"]["assignment"]
                    if location == "graph":
                        spec = raw["graph"]["tasks"]["label"]["required_checks"][0]
                    elif location == "assignment task":
                        spec = assignment["task"]["required_checks"][0]
                    elif location == "assignment allowed":
                        spec = assignment["requirements"]["allowed_checks"][0]
                    else:
                        spec = raw["executions"][rid]["spec"]
                    if missing:
                        del spec[field]
                    else:
                        spec[field] = None
                    reason = (
                        "discriminator" if field == "kind" and location != "execution" else field
                    )
                    with self.subTest(location=location, field=field, missing=missing):
                        with self.assertRaisesRegex(Invalid, reason):
                            f.ledger.save(raw, "invalid check spec")
                        self.assertEqual(original, f.ledger.path.read_bytes())
                        atomic_json(f.ledger.path, raw)
                        with self.assertRaisesRegex(Invalid, reason):
                            f.ledger.read()
                        with self.assertRaisesRegex(Invalid, reason):
                            f.ledger.prepare_packet("verify-label")
                        f.ledger.path.write_bytes(original)
        self.assertEqual([], list(f.ledger.dir.glob("*.packet.json")))
        self.assertIn("sha256", f.ledger.prepare_packet("verify-label"))

    def test_worker_packet_rejects_incomplete_check_specs_before_publication(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        state = f.ledger.read()
        original = f.ledger.path.read_bytes()
        packet = implement_packet(state, "verify-label")
        self.assertEqual(packet, validate_packet(packet))
        for invalid in ({}, None, {**packet["task"]["required_checks"][0], "execution": None}):
            malformed = deepcopy(packet)
            malformed["task"]["required_checks"][0] = invalid
            with self.subTest(spec=invalid), self.assertRaisesRegex(ValueError, "required_checks"):
                validate_packet(malformed)
        projected = deepcopy(packet["task"])
        projected["required_checks"][0].pop("id")
        with (
            patch("factory_tooling.runtime.assignment.projected_task", return_value=projected),
            self.assertRaisesRegex(Invalid, r"required_checks\.0\..*\.id"),
        ):
            f.ledger.prepare_packet("verify-label")
        self.assertEqual(original, f.ledger.path.read_bytes())
        self.assertEqual([], list(f.ledger.dir.glob("*.packet.json")))

    def test_graph_distinguishes_observation_and_command_specs(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        command = f.g["tasks"]["label"]["required_checks"][0]
        invalid_command = deepcopy(command)
        invalid_command["execution"]["argv"] = []
        f.g["tasks"]["label"]["required_checks"][0] = invalid_command
        with self.assertRaisesRegex(Invalid, r"required_checks\.0\.tests\.execution.*argv"):
            f.init()
        self.assertFalse(f.ledger.path.exists())
        observation = {**command, "kind": "observation"}
        f.g["tasks"]["label"]["required_checks"][0] = observation
        with self.assertRaisesRegex(Invalid, r"required_checks\.0\.observation\..*extra field"):
            f.init()
        self.assertFalse(f.ledger.path.exists())
        del observation["execution"]
        f.init()
        f.start("write-label")
        packet = implement_packet(f.ledger.read(), "write-label")
        self.assertEqual([observation], packet["task"]["required_checks"])

    def test_report_validation_redacts_discriminator_and_dynamic_key(self) -> None:
        import traceback

        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.init()
        f.start("write-label")
        report = f.report("write-label")
        sentinel = "SENTINEL_TOKEN_DO_NOT_PRINT"
        for updates, field in (
            (
                {"review_checks": [{"id": "C", "result": sentinel}]},
                r"review_checks\.0: Unrecognized discriminator value",
            ),
            ({"files": {sentinel: False}}, r"files\.\*: Input should be a valid string"),
        ):
            with self.subTest(field=field):
                with self.assertRaisesRegex(Invalid, field) as caught:
                    f.ledger.finish("write-label", {**report, **updates})
                self.assertNotIn(sentinel, "".join(traceback.format_exception(caught.exception)))
        self.assertEqual("running", f.ledger.read()["nodes"]["write-label"]["status"])

    def test_terminal_report_rejects_number_and_false(self) -> None:
        from factory_tooling.runtime.state_io import parse_report

        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.init()
        f.start("write-label")
        report = f.report("write-label")
        self.assertIs(parse_report(report)["terminal"], True)
        for raw in (False, 1, "true"):
            with self.subTest(raw=raw), self.assertRaisesRegex(Invalid, "terminal"):
                parse_report({**report, "terminal": raw})

    def test_execution_rejects_explicit_null_and_numeric_coercion(self) -> None:
        from factory_tooling.runtime.command_contract import validate_execution

        command = {"argv": ["tool"], "cwd": ".", "timeout_seconds": 10}
        self.assertEqual(command, validate_execution(command))
        for field, value in (
            ("timeout_seconds", True),
            ("timeout_seconds", "10"),
            ("inputs", None),
            ("stages", []),
        ):
            with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, field):
                validate_execution({**command, field: value})

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
