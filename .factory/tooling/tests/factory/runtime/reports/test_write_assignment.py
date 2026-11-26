"""Compare a generic role assignment with a material-check subgraph on the same checkout shape."""

import json
import subprocess
import unittest
from pathlib import Path
from typing import Any

from factory.runtime import graph_inputs
from factory.runtime.state_io import parse_report_draft
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class WriteAssignmentTests(unittest.TestCase):
    def prepare(self, specialized: bool) -> tuple[WorkflowFixture, Path, str, str]:
        f = WorkflowFixture(self.addCleanup)
        f.require_fixture_review()
        f.fixture_policy += "public_contracts:\n  lib/example.dart: [contract.md]\n"
        config = f.config_file(lambda c: c["execution"].update(workspace="shared"))
        if specialized:
            graphs = config.parent / "graphs"
            parent = graphs / "implement.yaml"
            parent.write_text(
                parent.read_text().replace(
                    "implementer: role-assignment", "implementer: implementer-pilot"
                )
            )
            (graphs / "implementer-pilot.yaml").write_text(
                "id: implementer-pilot\nentry: code\nnodes:\n"
                "  code: {operation: check_code, after: tests}\n"
                "  tests: {operation: check_tests, after: docs}\n"
                "  docs: {operation: check_docs}\n"
            )
        f.g["tasks"]["label"]["scope"].extend(["contract.md", "test_label.py"])
        author = next(n for n in f.g["nodes"] if n["id"] == "write-label")
        author["owns"] = list(f.g["tasks"]["label"]["scope"])
        (f.root / "contract.md").write_text("label()")
        (f.root / "lib/example.dart").write_text("label()")
        (f.root / "test_label.py").write_text("def test_label(): pass")
        self.f, self.config = f, config
        run_id = self.cmd(
            "init", graph_inputs.propose(f.root, graph_inputs.PROPOSAL.validate_python(f.g))
        )["run_id"]
        self.cmd(
            "claim",
            "write-label",
            "--ticket",
            self.cmd("status")["assignment_tickets"]["write-label"],
        )
        packet = self.cmd("packet", "write-label")
        ticket = packet["dispatch_id"]
        self.cmd(
            "bind",
            "write-label",
            "fixture-author",
            packet["model"]["id"] or "fixture-default",
            "--dispatch",
            ticket,
        )
        return f, config, run_id, ticket

    def cmd(self, *args: str, ok: bool = True) -> Any:
        run = subprocess.run(
            [
                *CLI,
                "workflow",
                "--workspace",
                str(self.f.root),
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
        body = json.loads(run.stdout)
        return body["result"] if ok else body["error"]

    def report(self, result: dict[str, Any] | None = None) -> str:
        raw = self.f.report("write-label")
        del raw["files"], raw["write_result"]
        if result is not None:
            raw["write_result"] = result
        return graph_inputs.draft_report(self.f.root, parse_report_draft(raw))

    def test_complete_first_delivery_in_both_representations(self) -> None:
        for specialized in (False, True):
            with self.subTest(specialized=specialized):
                f, _, _, _ = self.prepare(specialized)
                (f.root / "test_label.py").write_text("def test_label(): assert True")
                (f.root / "lib/example.dart").write_text("label(value)")
                (f.root / "contract.md").write_text("label(value)")
                raw = self.report(
                    {
                        "code": ["lib/example.dart"],
                        "tests": ["test_label.py"],
                        "docs": ["contract.md"],
                    }
                )
                receipt = self.cmd("prepare-report", "write-label", raw)["report_id"]
                self.cmd("finish", "write-label", receipt)
                self.cmd("finish", "write-label", receipt)
                self.assertEqual(["verify-label"], self.cmd("status")["runnable"])

    def test_resume_supplement_and_replay_in_both_representations(self) -> None:
        for specialized in (False, True):
            with self.subTest(specialized=specialized):
                f, _, run, ticket = self.prepare(specialized)
                handoff = ["handoff", "write-label", "--dispatch", ticket]
                self.assertIn(
                    "documentation or applicability reason", self.cmd(*handoff)["missing"]
                )
                self.assertIn(
                    "Implementer handoff needs",
                    str(self.cmd("prepare-report", "write-label", self.report(), ok=False)),
                )
                args = [
                    "--request",
                    "local",
                    "--code",
                    "lib/example.dart",
                    "--test",
                    "behavior",
                    "--docs-current",
                    "Local label uses existing contract",
                ]
                first = self.cmd(*handoff, *args)
                self.assertEqual(first, self.cmd(*handoff, *args))
                self.assertEqual(specialized, "steps" in first)
                self.cmd(*handoff, "--request", "local", "--code", "lib/example.dart", ok=False)
                self.cmd("handoff", "write-label", "--dispatch", "wrong", *args, ok=False)
                self.cmd("pause", "Resume the existing ticket")
                (f.root / "lib/example.dart").write_text("label(value)")
                (f.root / "test_label.py").write_text("def test_label(): assert True")
                self.cmd("resume")
                missing = self.cmd(*handoff)["missing"]
                self.assertIn("updated documentation for the current public contract", missing)
                self.assertEqual([], self.cmd("status")["runnable"])
                self.cmd(
                    *handoff,
                    "--request",
                    "code",
                    "--code",
                    "lib/example.dart",
                    "--test",
                    "test_label.py",
                )
                self.assertIn(
                    "updated documentation",
                    str(self.cmd("prepare-report", "write-label", self.report(), ok=False)),
                )
                (f.root / "contract.md").write_text("label(value)")
                final = self.cmd(*handoff, "--request", "doc", "--docs", "contract.md")
                self.assertEqual([], self.cmd(*handoff)["missing"])
                receipt = self.cmd("prepare-report", "write-label", self.report())["report_id"]
                self.cmd("finish", "write-label", receipt)
                tester = self.cmd("status")["assignment_tickets"]["verify-label"]
                self.cmd("claim", "verify-label", "--ticket", tester)
                self.cmd("finish", "write-label", receipt)
                self.assertEqual(
                    final, self.cmd(*handoff, "--request", "doc", "--docs", "contract.md")
                )
                self.cmd(*handoff, "--request", "new", "--docs", "contract.md", ok=False)
                state = f.ledger.read()
                self.assertEqual(
                    (run, ticket, tester),
                    (
                        state["run_id"],
                        state["nodes"]["write-label"]["dispatch_id"],
                        state["nodes"]["verify-label"]["dispatch_id"],
                    ),
                )
                self.assertEqual(1, state["nodes"]["verify-label"]["attempt"])
                self.assertEqual("fixture-author", state["nodes"]["write-label"]["handle"])
