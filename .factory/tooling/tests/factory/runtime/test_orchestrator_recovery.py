"""Run the two-branch orchestration and recovery contract through separate CLI processes."""

import json
import subprocess
import sys
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import ExitStack
from typing import Any

from factory.runtime import graph_inputs
from factory.runtime.state_io import parse_report_draft
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class OrchestratorRecoveryTests(unittest.TestCase):
    def setUp(self) -> None:
        f = self.f = WorkflowFixture(self.addCleanup)
        f.batch()
        f.require_fixture_review()
        f.g["agents"]["second-author"] = {"role": "implementer", "profile": "implementer"}
        f.g["tasks"]["second"].update(
            depends_on=[], scope=["lib/second.dart"], independent_review=True
        )
        f.g["tasks"]["integrated"]["scope"].append("lib/second.dart")
        (f.root / "lib/second.dart").write_text("before")
        for key, task in f.g["tasks"].items():
            if key == "integrated":
                check = (
                    "from pathlib import Path; "
                    "assert Path('lib/example.dart').read_text() == 'Approved label'; "
                    "assert Path('lib/second.dart').read_text() == 'Corrected label'"
                )
            else:
                (path,) = task["scope"]
                check = f"from pathlib import Path; assert 'label' in Path({path!r}).read_text()"
            task["required_checks"][0]["execution"]["argv"] = [sys.executable, "-c", check]
        nodes = {n["id"]: n for n in f.g["nodes"]}
        nodes["write-second"].update(agent="second-author", depends_on=[], owns=["lib/second.dart"])
        nodes["accept-second"]["depends_on"] = ["review-second"]
        f.g["nodes"].append(
            {
                **nodes["review-label"],
                "id": "review-second",
                "task": "second",
                "depends_on": ["verify-second"],
            }
        )
        self.config_path = f.config_file(lambda c: c["execution"].update(workspace="shared"))
        self.packets: dict[str, Any] = {}
        self.dispatches: dict[str, str] = {}
        proposal_id = graph_inputs.propose(f.root, graph_inputs.PROPOSAL.validate_python(f.g))
        self.run_id = self.call("workflow", "init", proposal_id)["run_id"]

    def invoke(self, family: str, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                *CLI,
                family,
                "--workspace",
                str(self.f.root),
                "--config",
                str(self.config_path),
                *args,
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def call(self, family: str, *args: str) -> Any:
        run = self.invoke(family, *args)
        self.assertEqual(0, run.returncode, f"{args}: {run.stderr}")
        return json.loads(run.stdout)["result"]

    def start(self, node: str, ticket: str | None = None) -> dict[str, Any]:
        ticket = ticket or self.call("workflow", "status")["assignment_tickets"][node]
        self.call("workflow", "claim", node, "--ticket", ticket)
        packet = self.call("workflow", "packet", node)
        self.call(
            "workflow",
            "bind",
            node,
            "handle-" + packet["node"]["agent"],
            packet["model"]["id"] or "fixture-default",
            "--dispatch",
            packet["dispatch_id"],
        )
        self.packets[node] = packet
        self.dispatches[node] = packet["dispatch_id"]
        assert isinstance(packet, dict)
        return packet

    def draft(self, node: str, **fields: Any) -> str:
        packet = self.packets[node]
        raw = {
            key: packet[key]
            for key in ("run_id", "dispatch_id", "source_hash", "node_id", "task_id", "slice_id")
        }
        raw.update(
            terminal=True,
            outcome="PASS",
            summary=f"Finished {node}",
            checks=[],
            stage_result="WRITES_READY" if node.startswith("write-") else "VERIFIED",
        )
        if node.startswith("write-"):
            raw["write_result"] = {
                "code": packet["node"]["owns"],
                "tests": ["behavior"],
                "docs_current": "Internal fixture label only.",
            }
        if node.startswith("verify-"):
            raw["not_applicable"] = {
                "docs": "No documentation change",
                "static": "No static gate in this fixture",
            }
        raw.update(fields)
        return graph_inputs.draft_report(self.f.root, parse_report_draft(raw))

    def finish(self, node: str, *receipts: str, **fields: Any) -> str:
        draft_id = self.draft(node, **fields)
        prepared = self.call("workflow", "prepare-report", node, draft_id, *receipts)
        self.assertEqual(self.dispatches[node], prepared["dispatch_id"])
        self.call("workflow", "finish", node, prepared["report_id"])
        report_id = prepared["report_id"]
        assert isinstance(report_id, str)
        return report_id

    def verify(self, node: str) -> str:
        self.start(node)
        receipt = self.call(
            "checks",
            "run",
            node,
            "behavior",
            "--request",
            "behavior",
            "--dispatch",
            self.dispatches[node],
        )["execution_id"]
        self.finish(node, receipt)
        assert isinstance(receipt, str)
        return receipt

    def test_lost_native_launch_and_cancellation(self) -> None:
        node = "write-label"
        ticket = self.call("workflow", "status")["assignment_tickets"][node]
        first = self.call("workflow", "claim", node, "--ticket", ticket)
        self.assertEqual(
            {"action": "spawn", "runner": "native", "handle": None, "dispatch_id": ticket},
            first["delivery"],
        )
        self.call(
            "workflow", "unknown", node, "Native host lost launch response", "--dispatch", ticket
        )
        replay = self.call("workflow", "claim", node, "--ticket", ticket)
        self.assertNotIn("delivery", replay)
        self.assertEqual("reconcile", replay["action"])
        self.assertEqual("unknown", self.call("workflow", "status")["dispatches"][node]["status"])
        self.assertNotEqual(
            0, self.invoke("workflow", "archive", "cancelled", "Owner stopped").returncode
        )
        self.call(
            "workflow",
            "resolve",
            node,
            "blocked",
            "Host confirmed worker stopped",
            "--dispatch",
            ticket,
        )
        self.call("workflow", "archive", "cancelled", "Owner stopped")
        status = self.call("workflow", "status")
        self.assertEqual("cancelled", status["run_status"])
        self.assertEqual("skipped", status["after_archive"]["status"])
        self.assertFalse(status["assignment_tickets"])

    def test_configured_preparatory_roles_receive_scoped_assignments(self) -> None:
        graph = self.f.g
        prep = ("code-explorer", "bug-hunter", "doc-writer")
        nodes = graph["nodes"]
        for role in prep:
            graph["agents"][role] = {"role": role, "profile": role}
            nodes.append(
                {
                    "id": role,
                    "task": "label",
                    "stage": "explore",
                    "agent": role,
                    "depends_on": [],
                    "owns": [],
                    "resources": [],
                }
            )
        next(n for n in nodes if n["id"] == "write-label")["depends_on"] = list(prep)
        for role in ("architect", "task-decomposer", "task-reviewer", "reviewer"):
            graph["agents"]["code-explorer"] = {"role": role, "profile": role}
            rejected = graph_inputs.propose(
                self.f.root, graph_inputs.PROPOSAL.validate_python(graph)
            )
            result = self.invoke("workflow", "revise", rejected, "Check role boundaries")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(f"Role outside Implement workflow: {role}", result.stderr)
        graph["agents"]["code-explorer"] = {"role": "code-explorer", "profile": "code-explorer"}
        proposal = graph_inputs.propose(self.f.root, graph_inputs.PROPOSAL.validate_python(graph))
        self.call("workflow", "revise", proposal, "Authorize scoped preparatory readings")
        for role in prep:
            with self.subTest(role=role):
                packet = self.start(role)
                self.assertEqual(role, packet["node"]["agent"])
                self.assertEqual([], packet["node"]["owns"])
                if role == "bug-hunter":
                    self.finish(
                        role,
                        stage_result="ROOT_CAUSE_FOUND",
                        role_material=[
                            {
                                "kind": "reproduction",
                                "observation": "Fixture label differs",
                                "paths": ["lib/example.dart"],
                            },
                            {
                                "kind": "cause",
                                "observation": "Inspected label literal",
                                "paths": ["lib/example.dart"],
                            },
                        ],
                    )
                else:
                    self.finish(
                        role, stage_result="EXPLORED", evidence=f"{role} inspected its task scope"
                    )
        self.assertIn("write-label", self.call("workflow", "status")["runnable"])

    def test_parallel_review_repair_and_resume(self) -> None:
        tickets = self.call("workflow", "status")["assignment_tickets"]
        with ThreadPoolExecutor(max_workers=2) as pool:
            claims = [
                pool.submit(self.call, "workflow", "claim", node, "--ticket", tickets[node])
                for node in ("write-label", "write-second")
            ]
            for claim in claims:
                claim.result()
        active = self.call("workflow", "status")["dispatches"]
        self.assertEqual(set(active), {"write-label", "write-second"})
        # Each native worker owns its file and stays alive until both bindings are visible.
        labels = {"write-label": "Approved label", "write-second": "Draft label"}
        with ExitStack() as stack:
            workers = {}
            for node in labels:
                packet = self.start(node, tickets[node])
                (path,) = packet["node"]["owns"]
                workers[node] = stack.enter_context(
                    subprocess.Popen(
                        [
                            sys.executable,
                            "-c",
                            "from pathlib import Path; import sys; Path(sys.argv[1]).write_text(input())",
                            path,
                        ],
                        cwd=self.f.root,
                        stdin=subprocess.PIPE,
                        text=True,
                    )
                )
                stack.callback(workers[node].kill)
            active = self.call("workflow", "status")["dispatches"]
            self.assertTrue(all(active[node]["status"] == "running" for node in workers))
            self.assertTrue(all(worker.poll() is None for worker in workers.values()))
            with ThreadPoolExecutor(max_workers=2) as pool:
                completions = [
                    pool.submit(worker.communicate, labels[node], timeout=20)
                    for node, worker in workers.items()
                ]
                for completion in completions:
                    completion.result()
            self.assertTrue(all(worker.returncode == 0 for worker in workers.values()))
        later = self.finish("write-second")
        crossed = self.invoke("workflow", "finish", "write-label", later)
        self.assertNotEqual(0, crossed.returncode)
        self.finish("write-label")
        before = self.call("workflow", "status")["assignment_tickets"]
        self.call("workflow", "finish", "write-second", later)
        self.assertEqual(before, self.call("workflow", "status")["assignment_tickets"])
        self.verify("verify-label")
        self.start("review-label")
        self.finish("review-label", verdict="APPROVE", findings=[])
        self.call("workflow", "accept", "accept-label")
        old_receipt = self.verify("verify-second")
        self.start("review-second")
        observed = (self.f.root / "lib/second.dart").read_text()
        self.assertEqual(observed, "Draft label")
        finding = dict(
            id="REV-1",
            status="open",
            blocking=True,
            owner_role="implementer",
            summary="Incorrect second label",
            evidence=f"Observed {observed}",
        )
        self.finish(
            "review-second",
            outcome="FAIL",
            verdict="NEEDS_WORK",
            findings=[finding],
            evidence="Label mismatch",
        )
        [route] = self.call("workflow", "status")["repair_routes"]["review-second"]
        self.assertEqual(
            ("retry", "write-second", self.dispatches["review-second"]),
            (route["action"], route["node_id"], route["evidence"]["dispatch_id"]),
        )
        self.call(
            "workflow",
            route["action"],
            route["node_id"],
            route["stage"],
            "Resolve REV-1",
            "Writer and Judge returned",
            "--dispatch",
            route["dispatch_id"],
            "--evidence-dispatch",
            route["evidence"]["dispatch_id"],
        )
        repair = self.start("write-second")
        (self.f.root / "lib/second.dart").write_text("Corrected label")
        draft_id = self.draft(
            "write-second",
            finding_updates=[dict(id="REV-1", status="ready", evidence="Corrected second label")],
        )
        self.call("workflow", "prepare-report", "write-second", draft_id)

        # The coordinator that ran prepare-report has exited. Recover the saved report without its response.
        resumed = self.call("workflow", "status")
        submitted = resumed["dispatches"]["write-second"]["submission"]
        self.assertEqual(
            submitted["report_id"],
            self.call("workflow", "prepare-report", "write-second", draft_id)["report_id"],
        )
        self.call("workflow", "finish", "write-second", submitted["report_id"])
        replay = self.call("workflow", "claim", "write-second", "--ticket", repair["dispatch_id"])
        self.assertTrue(replay["replayed"])
        self.assertEqual(self.dispatches["write-second"], replay["dispatch_id"])
        preserved = self.call(
            "workflow", "explain", "review-label", "--dispatch", self.dispatches["review-label"]
        )
        self.assertTrue(preserved["current"])
        self.assertEqual(1, preserved["attempt"])
        self.assertEqual("APPROVE", preserved["report"]["report"]["verdict"])
        self.start("verify-second")
        old = self.invoke(
            "workflow", "prepare-report", "verify-second", self.draft("verify-second"), old_receipt
        )
        self.assertNotEqual(old.returncode, 0)
        self.assertIn("receipt", old.stderr.lower())
        receipt = self.call(
            "checks",
            "run",
            "verify-second",
            "behavior",
            "--request",
            "behavior",
            "--dispatch",
            self.dispatches["verify-second"],
        )["execution_id"]
        self.assertNotEqual(old_receipt, receipt)
        self.finish("verify-second", receipt)
        judge = self.start("review-second")
        self.assertEqual(
            self.dispatches["verify-second"],
            judge["dependency_results"]["verify-second"]["report_ref"]["dispatch_id"],
        )
        self.finish(
            "review-second",
            verdict="APPROVE",
            findings=[dict(id="REV-1", status="fixed", evidence="Verified corrected label")],
        )
        self.call("workflow", "accept", "accept-second")
        self.verify("verify-all")
        self.start("review-all")
        self.finish(
            "review-all",
            verdict="APPROVE",
            findings=[
                dict(
                    task_id="second",
                    id="REV-1",
                    status="fixed",
                    evidence="Integrated check verified the repaired branch",
                )
            ],
        )
        self.call("workflow", "accept", "accept-all")
        self.assertTrue(self.call("workflow", "status")["completion_eligible"])
        self.call("workflow", "archive", "completed", "Both labels accepted")
        final = self.call("workflow", "status")["after_archive"]
        self.assertEqual("ready", final["status"])
        event = final["event_id"]

        def lessons(*args: str) -> Any:
            proc = subprocess.run(
                [*CLI, "lessons", "--workspace", str(self.f.root), *args],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            return json.loads(proc.stdout)

        with ThreadPoolExecutor(max_workers=2) as pool:
            grants = list(pool.map(lambda _: lessons("teacher-launch", event), range(2)))
        self.assertEqual({"spawn", "reconcile"}, {grant["action"] for grant in grants})
        token = grants[0]["dispatch_id"]
        self.assertEqual(token, grants[1]["dispatch_id"])
        stopped = lessons(
            "teacher-launch", event, "--stopped", token, "Host confirmed first launch never started"
        )
        replay = lessons("teacher-launch", event)
        self.assertEqual(
            ("reconcile", "stopped", stopped["ticket"]),
            (replay["action"], replay["status"], replay["ticket"]),
        )
        replacement = lessons("teacher-launch", event, "--ticket", replay["ticket"])
        self.assertEqual("spawn", replacement["action"])
        self.assertNotEqual(token, replacement["dispatch_id"])
        token = replacement["dispatch_id"]
        lessons("teacher-launch", event, "--bind", token, "fixture-teacher")
        current = lessons("teacher-launch", event)
        self.assertEqual(
            ("reconcile", token, "fixture-teacher"),
            (current["action"], current["dispatch_id"], current["handle"]),
        )
        job = lessons("packet", event)["event"]
        reviewed = {
            node: ref["dispatch_id"]
            for incident in job["incidents"].values()
            for node, ref in incident["accepted_reports"].items()
        }
        judge_history = [
            r["dispatch_id"]
            for incident in job["incidents"].values()
            for r in incident["reports"]
            if r["node_id"] == "review-second"
        ]
        self.assertEqual(2, len(set(judge_history)))
        self.assertIn(reviewed["review-second"], judge_history)
        self.assertEqual(self.dispatches, reviewed)
        lessons(
            "complete", event, "--dispatch", token, "--reason", "Inspected both accepted versions"
        )
        self.assertEqual("done", self.call("workflow", "status")["after_archive"]["status"])
