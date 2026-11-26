"""Two consecutive real runs choose different permitted assignments on identical receipts."""

import json
import subprocess
import unittest
from copy import deepcopy
from typing import Any

from factory.runtime import graph_inputs
from factory.runtime.state_io import parse_report_draft
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class PinnedVerificationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = f = WorkflowFixture(self.addCleanup)
        self.config = f.config_file(lambda c: c["execution"].update(workspace="shared"))
        nodes = {n["id"]: n for n in f.g["nodes"]}
        full = nodes["verify-label"]
        initial = {**deepcopy(full), "id": "first-check", "required_check_ids": ["behavior"]}
        focused = {
            **deepcopy(full),
            "id": "focused",
            "required_check_ids": ["behavior"],
            "depends_on": ["first-check"],
        }
        full["depends_on"] = ["first-check"]
        f.g["nodes"].extend([initial, focused])
        nodes["accept-label"]["depends_on"].append("focused")
        self.proposal = graph_inputs.propose(f.root, graph_inputs.PROPOSAL.validate_python(f.g))
        self.proofs: list[dict[str, str]] = []

    def cmd(self, group: str, *args: str) -> Any:
        run = subprocess.run(
            [
                *CLI,
                group,
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
        self.assertEqual(0, run.returncode, run.stdout + run.stderr)
        return json.loads(run.stdout)["result"]

    def start(self, node: str) -> dict[str, Any]:
        ticket = self.cmd("workflow", "status")["assignment_tickets"][node]
        self.cmd("workflow", "claim", node, "--ticket", ticket)
        packet = self.cmd("workflow", "packet", node)
        self.cmd(
            "workflow",
            "bind",
            node,
            "worker-" + packet["node"]["agent"],
            packet["model"]["id"] or "fixture",
            "--dispatch",
            ticket,
        )
        self.assertEqual(ticket, packet["dispatch_id"])
        return dict(packet)

    def finish(self, node: str, packet: dict[str, Any]) -> str:
        draft = {
            key: packet[key]
            for key in ("node_id", "task_id", "slice_id", "run_id", "dispatch_id", "source_hash")
        }
        draft.update(terminal=True, outcome="PASS", summary="Verified fixture", checks=[])
        receipts = []
        if packet["role"] == "implementer":
            draft.update(
                stage_result="WRITES_READY",
                write_result={
                    "code": ["lib/example.dart"],
                    "tests": ["behavior"],
                    "docs_current": "Internal label",
                },
            )
        else:
            execution = self.cmd(
                "checks",
                "run",
                node,
                "behavior",
                "--request",
                "sample",
                "--dispatch",
                packet["dispatch_id"],
            )
            receipts.append(execution["execution_id"])
            draft.update(
                stage_result="VERIFIED",
                not_applicable={"docs": "Internal label", "static": "No static gate"},
            )
        raw = graph_inputs.draft_report(self.f.root, parse_report_draft(draft))
        report = self.cmd("workflow", "prepare-report", node, raw, *receipts)
        self.cmd("workflow", "finish", node, report["report_id"])
        return receipts[0] if receipts else ""

    def test_changed_nested_definition_after_pause(self) -> None:
        child = self.config.parent / "graphs/tester.yaml"
        parent = self.config.parent / "graphs/implement.yaml"
        original_parent = parent.read_bytes()
        first_yaml = child.read_text()
        second_yaml = first_yaml.replace(
            "full_with_peer, priority: 20, target: wait_peer",
            "full_with_peer, priority: 20, target: release",
        ).replace(
            "focused_with_peer, priority: 20, target: release",
            "focused_with_peer, priority: 20, target: wait_peer",
        )
        for index, selected in enumerate(("focused", "verify-label")):
            run = self.cmd("workflow", "init", self.proposal)["run_id"]
            self.finish("write-label", self.start("write-label"))
            ticket = self.start("first-check")
            if index == 0:
                self.cmd("workflow", "pause", "Paused inside Tester before the receipt")
                child.write_text(second_yaml)
                self.cmd("workflow", "resume")
            receipt = self.finish("first-check", ticket)
            self.assertEqual([selected], self.cmd("workflow", "status")["runnable"])
            remaining = "verify-label" if index == 0 else "focused"
            next_packet = self.start(selected)
            self.finish(selected, next_packet)
            self.finish(remaining, self.start(remaining))
            self.cmd("workflow", "accept", "accept-label")
            self.cmd("workflow", "archive", "completed", "All three checks accepted")
            self.cmd("workflow", "clean")
            self.proofs.append(
                {
                    "run": run,
                    "receipt": receipt,
                    "checked": ticket["dispatch_id"],
                    "node": selected,
                    "dispatch": next_packet["dispatch_id"],
                }
            )

        self.assertEqual(original_parent, parent.read_bytes())
        self.assertEqual(2, len({row["run"] for row in self.proofs}))
        self.assertEqual(2, len({row["dispatch"] for row in self.proofs}))
        for proof, source in zip(self.proofs, (first_yaml, second_yaml), strict=True):
            state = self.f.ledger.history.archived_state(self.f.root, proof["run"])
            self.assertEqual(source, state["definitions"]["tester"])
            check = self.cmd(
                "workflow",
                "explain",
                "first-check",
                "--dispatch",
                proof["checked"],
                "--run",
                proof["run"],
            )
            self.assertEqual("PASS", check["checks"][proof["receipt"]]["result"]["result"])
            assignment = self.cmd(
                "workflow",
                "explain",
                proof["node"],
                "--dispatch",
                proof["dispatch"],
                "--run",
                proof["run"],
            )
            path = next(e["route"] for e in assignment["events"] if e["event"] == "reserved")
            self.assertIn("implement/verify/order -> release", path)
            self.assertEqual("tester", state["nodes"][proof["node"]]["role"])
