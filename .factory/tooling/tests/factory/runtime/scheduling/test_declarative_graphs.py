"""Execute modified definitions through the production ledger and CLI on isolated checkouts."""

import json
import subprocess
import unittest
from copy import deepcopy
from typing import Any

import yaml

from factory.runtime.workflow_config import load_config
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class DeclarativeGraphTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = WorkflowFixture(self.addCleanup)
        self.config = self.fixture.config_file(lambda c: c["execution"].update(workspace="shared"))
        self.directory = self.config.parent / "graphs"
        self.parent = self.directory / "implement.yaml"
        self.child = self.directory / "implement-recovery.yaml"

    def initialize(self) -> str:
        f = self.fixture
        return f.ledger.init(deepcopy(f.g), load_config(self.config))["run_id"]

    def cli(self, *args: str, ok: bool = True) -> Any:
        run = subprocess.run(
            [
                *CLI,
                "workflow",
                "--workspace",
                str(self.fixture.root),
                "--config",
                str(self.config),
                *args,
                "--json",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(ok, run.returncode == 0, run.stdout + run.stderr)
        value = json.loads(run.stdout)
        return value["result"] if ok else value["error"]

    def test_invalid_definitions_rejected_before_intake(self) -> None:
        original = self.child.read_text()
        for old, new, issue in [
            ("operation: retry", "operation: absent", "unknown operation"),
            ("target: wait_owner", "target: absent", "unknown target"),
            ("outcome: terminal_worker", "outcome: blocked", "missing outcomes"),
            ("  retry:", "  repair:", "duplicate"),
            ("operation: retry", "call: implement", "Recursive workflow calls"),
            ("operation: retry", "call: absent", "Cannot load workflow definition"),
            (
                "operation: retry",
                "operation: retry, after: blocked_attempt",
                "cycle without a finite limit",
            ),
            ("operation: retry", "operation: retry, after: retry, limit: 2", "without exit"),
        ]:
            with self.subTest(issue=issue):
                self.child.write_text(original.replace(old, new))
                with self.assertRaisesRegex(ValueError, issue):
                    self.initialize()
                self.assertFalse(self.fixture.ledger.runs.has_current(self.fixture.root))

    def test_nested_definition_pin_changes_future_cli_route_only(self) -> None:
        # A confirmed failed attempt permits author correction or a scoped read-only diagnosis.
        original = self.child.read_text()
        first = self.initialize()
        self.fixture.start("write-label")
        self.fixture.ledger.finish(
            "write-label",
            self.fixture.report(
                "write-label",
                "FAIL",
                stage_result="FAIL_CODE",
                evidence="Reproduced regression",
            ),
        )
        self.child.write_text(
            original.replace(
                "terminal_worker, priority: 20, target: repair",
                "terminal_worker, priority: 20, target: diagnose",
            )
            .replace("target: retry}", "target: repair}")
            .replace("  retry: {operation: retry}\n", "")
        )
        # The first run is still attached to its original YAML.
        self.assertIn("retry", self.cli("status")["corrections"]["write-label"])
        self.cli("archive", "cancelled", "Owner cancelled first fixture")
        self.cli("clean")
        second = self.initialize()
        self.assertNotEqual(first, second)
        self.fixture.start("write-label")
        self.fixture.ledger.finish(
            "write-label",
            self.fixture.report(
                "write-label",
                "FAIL",
                stage_result="FAIL_CODE",
                evidence="Reproduced regression",
            ),
        )
        self.assertEqual(["revise"], self.cli("status")["corrections"]["write-label"])
        old = self.cli("diagram", "--view", "orchestrator", "--run", first)["mermaid"]
        new = self.cli("diagram", "--view", "orchestrator", "--run", second)["mermaid"]
        self.assertNotEqual(old, new)
        self.assertIn("terminal_worker (20)", old)
        self.assertIn("terminal_worker (20)", new)
        self.assertEqual(
            original,
            self.fixture.ledger.history.archived_state(self.fixture.root, first)["definitions"][
                "implement-recovery"
            ],
        )
        self.assertEqual(
            self.child.read_text(), self.fixture.ledger.read()["definitions"]["implement-recovery"]
        )

    def test_two_calls_and_closed_operation(self) -> None:
        parent = yaml.safe_load(self.parent.read_bytes())
        parent["nodes"]["other_recovery"] = {"call": "implement-recovery"}
        parent["nodes"]["attempt"]["routes"][0]["target"] = "other_recovery"
        del parent["nodes"]["reconcile"]
        self.parent.write_text(yaml.safe_dump(parent))
        self.initialize()
        diagram = self.cli("diagram", "--view", "orchestrator")["mermaid"]
        self.assertIn("implement/other_recovery/blocked_attempt", diagram)
        self.assertIn("implement/choose_recovery/blocked_attempt", diagram)
        self.assertIn(
            "Dependencies not complete",
            str(self.cli("claim", "verify-label", "--dry-run", ok=False)),
        )

    def test_equal_priority_holds_branch_with_rule_evidence(self) -> None:
        parent = yaml.safe_load(self.parent.read_bytes())
        route = parent["nodes"]["attempt"]["routes"]
        route.append(
            {
                "outcome": "pending",
                "priority": 20,
                "requires": ["acceptance"],
                "target": "authorize",
            }
        )
        self.parent.write_text(yaml.safe_dump(parent))
        self.initialize()
        result = self.cli("status")
        self.assertIn("matched targets", result["blockers"]["accept-label"])
        self.assertIn("write-label", result["assignment_tickets"])
        self.assertEqual({}, self.fixture.ledger.read()["counters"])

    def test_no_match_and_conflict_cancel_without_adopting_new_yaml(self) -> None:
        original = self.parent.read_bytes()
        for conflict in (False, True):
            with self.subTest(conflict=conflict):
                graph = yaml.safe_load(original)
                routes = graph["nodes"]["attempt"]["routes"]
                if conflict:
                    routes.append(
                        {
                            "outcome": "pending",
                            "requires": ["acceptance"],
                            "priority": 20,
                            "target": "authorize",
                        }
                    )
                else:
                    # Only the acceptance candidate enters the incomplete decision.
                    next(r for r in routes if r["outcome"] == "acceptance")["target"] = (
                        "accept_state"
                    )
                    graph["nodes"]["accept_state"] = {
                        "decision": "tester_state",
                        "routes": [
                            {"outcome": "pending", "requires": ["started"], "target": "accept"},
                            {"outcome": "started", "target": "accept"},
                            {"outcome": "prerequisite", "target": "accept"},
                        ],
                    }
                self.parent.write_text(yaml.safe_dump(graph))
                run = self.initialize()
                result = self.cli("status")
                reason = result["blockers"]["accept-label"]
                self.assertIn("implement/attempt" if conflict else "implement/accept_state", reason)
                self.assertIn("matched targets", reason)
                self.assertEqual({}, self.fixture.ledger.read()["counters"])
                self.parent.write_bytes(original)
                self.assertEqual(reason, self.cli("status")["blockers"]["accept-label"])
                self.assertIn("write-label", result["runnable"])
                if conflict:
                    self.cli(
                        "claim",
                        "write-label",
                        "--ticket",
                        result["assignment_tickets"]["write-label"],
                    )
                    self.cli("archive", "cancelled", "Owner cancelled", ok=False)
                    self.cli(
                        "unknown",
                        "write-label",
                        "Lost transport",
                        "--dispatch",
                        result["assignment_tickets"]["write-label"],
                    )
                    self.cli(
                        "resolve",
                        "write-label",
                        "blocked",
                        "Worker confirmed stopped",
                        "--dispatch",
                        result["assignment_tickets"]["write-label"],
                    )
                self.cli("archive", "cancelled", "Owner cancelled")
                self.assertEqual("skipped", self.cli("status")["after_archive"]["status"])
                self.cli("clean")
                self.assertEqual(
                    reason, self.cli("diagram", "--run", run)["route_holds"]["accept-label"]
                )
                second = self.initialize()
                self.assertNotEqual(run, second)
                self.assertEqual(
                    "Required work not done", self.cli("status")["blockers"]["accept-label"]
                )
                self.cli("archive", "cancelled", "End fixture")
                self.cli("clean")

    def test_failed_reservation_and_executable_change_preserve_ticket(self) -> None:
        self.initialize()
        ticket = self.cli("status")["assignment_tickets"]["write-label"]
        handler = self.config.parent / "tooling/factory/runtime/scheduling/orchestrator_graph.py"
        before = handler.read_bytes()
        handler.write_bytes(before + b"\n")
        status = self.cli("status")
        self.assertIn("Executable configuration/tooling drift", status["blockers"]["run"])
        self.assertNotIn("write-label", status["assignment_tickets"])
        handler.write_bytes(before)
        # Raise inside the actual commit after topology rows were rewritten. Check bytes through a new CLI.
        from unittest.mock import patch

        from factory.database.sqlite import graph_records

        original = graph_records.write

        def interrupted(*args: Any) -> None:
            original(*args)
            raise RuntimeError("lost commit")

        with (
            patch.object(graph_records, "write", interrupted),
            self.assertRaisesRegex(RuntimeError, "lost commit"),
        ):
            self.fixture.ledger.claim("write-label", ticket=ticket)
        status = self.cli("status")
        self.assertEqual(ticket, status["assignment_tickets"]["write-label"])
        self.assertEqual(0, self.fixture.ledger.read()["nodes"]["write-label"]["attempt"])
        claimed = self.cli("claim", "write-label", "--ticket", ticket)
        self.assertEqual(ticket, claimed["delivery"]["dispatch_id"])
        self.assertEqual(
            "reconcile", self.cli("claim", "write-label", "--ticket", ticket)["action"]
        )
