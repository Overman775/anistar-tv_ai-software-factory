"""Recover a separate approved plan and independent worker handoffs by process ID."""

import json
import shutil
import subprocess
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory.database.provider import current_database
from factory.decompose.assemble import REVIEW_CRITERIA
from factory.decompose.graph.task_data import normalized_plan_hash
from factory.decompose.staging.manifest import staged_manifest
from factory.gates.gate_contract import digest, evidence
from factory.processes import cli
from factory.project.profile_io import load_profile
from factory.runtime import graph_inputs
from tests import CLI
from tests.factory.decompose.fixture_task_graph import TaskGraphFixture
from tests.factory.planning.fixture_plan import PLAN
from tests.factory.runtime.workflow_fixture import WorkflowFixture
from tests.fixture_bundle import ROOT


class DecompositionProcessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = TaskGraphFixture(self.addCleanup)
        self.execution = WorkflowFixture(self.addCleanup)
        self.implement_config = self.execution.config_file(
            lambda c: c["execution"].update(workspace="shared")
        )
        self.root = self.execution.root
        self.f.root = self.root
        self.worker_root = self.f.tasks_dir
        self.config = self.root / ".factory/factory.yaml"
        shutil.copytree(
            ROOT, self.root / ".factory", ignore=shutil.ignore_patterns("__pycache__", ".venv")
        )
        profile = load_profile(self.config.parent / "project/project.yaml")
        for description in profile["data"].get("documents", {}).values():
            path = self.root / description["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("Fixture project reference")
        (self.root / "docs").mkdir(exist_ok=True)
        (self.root / "docs/README.md").write_text("Fixture project index")
        self.run_id = ""
        self.count = 0
        self.first = "orders-load-01"
        self.second = "orders-show-02"
        self.make_tasks([self.first])
        self.author = ""

    def make_tasks(self, parents: list[str], *, missing: bool = False, cycle: bool = False) -> None:
        self.f.write_tasks(
            [
                self.f.task(self.first, depends_on=[self.second] if cycle else []),
                self.f.task(
                    self.second,
                    depends_on=parents,
                    acceptance_ids=["AC-01" if missing else "AC-02"],
                ),
            ]
        )
        plan = (
            PLAN.replace("payment-webview-trusted-ca", "orders-plan")
            .replace("revision: 1", "revision: 2")
            .replace("status: draft", "status: approved")
            .replace("approved_revision: none", "approved_revision: 2")
            .replace(
                "| CAP-01 | platform_plugin_api",
                "| CAP-02 | local_contract | Show the selected order | `project_fact`: card selection |\n| CAP-01 | platform_plugin_api",
            )
            .replace("- Out of scope:", "  - CAP-02 — show the selected order.\n- Out of scope:")
            .replace(
                "### Developer acceptance",
                "| AC-02 | CAP-02 | Selected order is shown | Open the selected order |\n\n### Developer acceptance",
            )
        )
        (self.root / "plan.md").write_text(plan)
        envelope = self.worker_root / "generated/task_result.json"
        data = json.loads(envelope.read_bytes())
        data["source_plan"]["hash"] = normalized_plan_hash(plan)
        envelope.write_text(json.dumps(data))
        for card in data["tasks"]:
            path = envelope.parent / card["filename"]
            path.write_text(
                path.read_text()
                + "- **Depends on:** "
                + (", ".join(card["depends_on"]) or "—")
                + "\n"
            )

    def call(self, action: str, *args: str, ok: bool = True, request: str | None = None) -> Any:
        self.count += 1
        cmd = [
            *CLI,
            "decompose",
            "run",
            action,
            "--workspace",
            str(self.root),
            "--config",
            str(self.config),
            "--request",
            request or str(self.count),
            *args,
        ]
        if self.run_id:
            cmd += ["--run", self.run_id]
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        self.assertEqual(ok, result.returncode == 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def begin(self) -> None:
        self.run_id = self.call(
            "init",
            "--plan",
            "plan.md",
            "--destination",
            "docs/tasks/orders",
            "--authorization",
            "owner authorized decomposition of approved revision 2",
        )["run_id"]
        self.author = self.bind("author")

    def bind(self, handle: str) -> str:
        ticket = self.call("claim")["dispatch"]
        self.call("bind", "--dispatch", ticket, "--handle", handle)
        return str(ticket)

    def signal(self, ticket: str) -> Any:
        hashes, count = staged_manifest(self.worker_root)
        done = {
            "status": "DONE",
            "staging_root": str(self.worker_root),
            "task_count": count,
            "blockers": [],
            "files": [{"path": k, "sha256": v} for k, v in hashes.items()],
        }
        path = self.root / "done"
        path.write_text(json.dumps(done))
        return self.call("manifest", "--dispatch", ticket, "--file", str(path))

    def files(self, ticket: str, names: list[str] | None = None) -> None:
        for name in names if names is not None else staged_manifest(self.worker_root)[0]:
            self.call(
                "deliver",
                "--dispatch",
                ticket,
                "--path",
                name,
                "--file",
                str(self.worker_root / name),
            )

    def verdict(self, ticket: str, *, approve: bool) -> tuple[Path, str]:
        payload = self.call("packet", "--dispatch", ticket, "--handle", "reviewer")[
            "review_request"
        ]
        self.assertEqual(sorted([self.first, self.second]), payload["task_ids"])
        report = {k: payload[k] for k in ("run_id", "role", "assignment_id", "reviewer_id")}
        report.update(
            request_hash=digest(payload),
            verdict="APPROVE" if approve else "NEEDS_WORK",
            criteria=[
                evidence(k, "PASS", "Checked against the approved plan", ["plan.md"])
                for k in REVIEW_CRITERIA
            ],
            findings=[]
            if approve
            else [
                {
                    "id": "F1",
                    "blocking": True,
                    "message": "Second card requires the first",
                    "evidence": ["generated/02-orders-show.md"],
                }
            ],
        )
        file = self.root / ("verdict-" + ticket)
        file.write_text(json.dumps(report))
        result = self.call("report", "--dispatch", ticket, "--file", str(file))
        self.assertEqual("PASS" if approve else "FAIL", result["status"])
        return file, payload["artifact_hash"]

    def test_partial_coverage_cycle_review_and_owned_publication(self) -> None:
        self.make_tasks([], missing=True)
        self.begin()
        self.call(
            "note",
            "--dispatch",
            self.author,
            "--evidence",
            "Two drafted tasks in the worker checkout",
        )
        self.assertTrue(self.call("status")["needs_manifest"])
        partial = self.signal(self.author)
        self.assertEqual(3, len(partial["missing"]))
        self.files(self.author, [partial["missing"][0]])
        self.assertEqual(2, len(self.call("status")["missing"]))
        self.call("pause", "--evidence", "Worker connection interrupted")
        self.call("resume")
        self.files(self.author, partial["missing"][1:])
        gate = self.call("validate")
        self.assertIn("coverage", str(gate["diagnostics"]).lower())
        self.assertEqual(self.author, self.call("status")["dispatch"]["dispatch"])
        self.make_tasks([self.first], cycle=True)
        self.files(self.author)
        self.signal(self.author)
        self.assertTrue(self.call("validate")["diagnostics"]["cycles"])
        self.make_tasks([])
        self.files(self.author)
        self.signal(self.author)
        self.assertEqual("PASS", self.call("validate")["status"])
        review = self.bind("reviewer")
        card = "generated/02-orders-show.md"
        envelope = "generated/task_result.json"
        self.call(
            "deliver",
            "--dispatch",
            review,
            "--path",
            card,
            "--file",
            str(self.worker_root / card),
            ok=False,
        )
        old, before = self.verdict(review, approve=False)
        self.call(
            "authorize-repair",
            "--actor",
            "reviewer",
            "--allow",
            card,
            "--allow",
            envelope,
            "--reference",
            "F1",
        )
        repair = self.bind("reviewer")
        self.make_tasks([self.first])
        first = "generated/01-orders-load.md"
        self.call(
            "deliver",
            "--dispatch",
            repair,
            "--path",
            first,
            "--file",
            str(self.worker_root / first),
            ok=False,
        )
        self.files(repair, [card, envelope])
        self.signal(repair)
        self.assertEqual("PASS", self.call("validate")["status"])
        final = self.bind("reviewer")
        self.call("report", "--dispatch", final, "--file", str(old), ok=False)
        _, after = self.verdict(final, approve=True)
        self.assertNotEqual(before, after)
        op = self.call("prepare-publication")
        target = self.root / op["destination"]
        shutil.copytree(self.root / op["staged"], target)
        inode = target.stat().st_ino
        self.call("publish", ok=False)
        self.assertEqual(inode, target.stat().st_ino)
        target.rename(target.with_name("foreign"))
        args = cli.build_parser().parse_args(
            ["publish", "--workspace", str(self.root), "--run", self.run_id, "--request", "install"]
        )
        with (
            patch.object(
                current_database().processes, "save", side_effect=RuntimeError("lost commit")
            ),
            self.assertRaisesRegex(RuntimeError, "lost commit"),
        ):
            cli.operate(args, "decompose")
        self.assertTrue((target / "epic.md").is_file())
        receipt = self.call("publish", request="install")
        self.assertEqual(receipt, self.call("publish", request="install"))
        self.call("clean")
        h = self.call("history")
        self.assertEqual([before, after], [r["basis"] for r in h["facts"]["reviews"]])
        self.assertEqual([self.first], h["facts"]["gate"]["tasks"][self.second]["depends_on"])
        self.assertEqual("completed", h["status"]["terminal"])
        graph = deepcopy(self.execution.g)
        task = graph["tasks"]["label"]
        graph.update(
            agents={}, nodes=[], tasks={key: deepcopy(task) for key in (self.first, self.second)}
        )
        for key, t in graph["tasks"].items():
            t["write_scope"] = [f"lib/{key}.py"]
            t["scope"] = t["write_scope"]
            t["required_checks"][0]["criteria"] = h["facts"]["gate"]["tasks"][key]["acceptance_ids"]
        graph["tasks"]["integration"] = {
            **deepcopy(task),
            "kind": "integration",
            "independent_review": True,
            "outcome": "Validate both orders tasks",
            "depends_on": [self.first, self.second],
            "acceptance_ids": ["AC-01", "AC-02"],
        }
        graph["tasks"]["integration"]["scope"] = [
            f"lib/{key}.py" for key in (self.first, self.second)
        ]
        graph["tasks"]["integration"]["required_checks"][0]["criteria"] = ["AC-01", "AC-02"]
        proposal = graph_inputs.propose_plan(
            self.root, graph, "request", "plan.md", decomposition_run=self.run_id
        )
        cmd = [
            *CLI,
            "workflow",
            "--workspace",
            str(self.root),
            "--config",
            str(self.implement_config),
        ]
        result = subprocess.run([*cmd, "init", proposal, "--json"], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        status = json.loads(subprocess.check_output([*cmd, "status", "--json"]))["result"]
        self.assertEqual(["work-" + self.first], status["runnable"])
        state = self.execution.ledger.read()
        self.assertEqual([self.first], state["graph"]["tasks"][self.second]["depends_on"])
        self.assertEqual(self.run_id, state["graph"]["sources"]["request"]["decomposition_run"])

    def test_replacement_author_cannot_approve_inherited_material(self) -> None:
        self.make_tasks([], missing=True)
        self.begin()
        self.files(self.author)
        self.signal(self.author)
        self.assertEqual("FAIL", self.call("validate")["status"])
        self.call("stopped", "--dispatch", self.author, "--evidence", "Original worker stopped")
        replacement = self.bind("replacement")
        self.make_tasks([])
        self.files(replacement)
        self.signal(replacement)
        self.assertEqual("PASS", self.call("validate")["status"])
        ticket = self.call("claim")["dispatch"]
        for handle in ("author", "replacement"):
            self.call("bind", "--dispatch", ticket, "--handle", handle, ok=False)
        self.call("bind", "--dispatch", ticket, "--handle", "independent")
        packet = self.call("packet", "--dispatch", ticket, "--handle", "independent")
        self.assertEqual("replacement", packet["review_request"]["author_id"])

    def test_confirm_transferred_bytes_after_stop_before_done_signal(self) -> None:
        self.begin()
        hashes, count = staged_manifest(self.worker_root)
        path = self.root / "observed-hashes"
        path.write_text(json.dumps(hashes))
        params = [
            "--file",
            str(path),
            "--evidence",
            "Coordinator verified the transferred set against the worker receipt",
        ]
        self.call(
            "note", "--dispatch", self.author, "--evidence", "Files saved in the worker workspace"
        )
        self.call("confirm-files", *params, ok=False)
        self.assertIn("Restore exact", self.call("status")["recovery"])
        self.files(self.author)
        self.call(
            "stopped", "--dispatch", self.author, "--evidence", "Worker exited before sending DONE"
        )
        wrong = self.root / "wrong-hashes"
        wrong.write_text(json.dumps(dict.fromkeys(hashes, "0" * 64)))
        self.call("confirm-files", "--file", str(wrong), "--evidence", "Wrong capture", ok=False)
        self.assertEqual(count, self.call("confirm-files", *params)["task_count"])
        self.assertEqual("PASS", self.call("validate")["status"])
        self.verdict(self.bind("reviewer"), approve=True)
        self.assertEqual(1, len(self.call("history")["attempts"]["generate"]))

    def test_clean_candidate_skips_repair_and_semantic_gap_returns_to_planning(self) -> None:
        unrelated = self.execution.init()
        self.begin()
        self.files(self.author)
        self.signal(self.author)
        self.assertEqual("PASS", self.call("validate")["status"])
        self.verdict(self.bind("reviewer"), approve=True)
        self.call("prepare-publication")
        self.call("publish")
        history = self.call("history")
        self.assertNotIn("repair", history["attempts"])
        self.run_id = self.call(
            "init",
            "--plan",
            "plan.md",
            "--destination",
            "docs/tasks/new",
            "--authorization",
            "owner-2",
        )["run_id"]
        ticket = self.bind("another-author")
        gap = self.call(
            "report",
            "--dispatch",
            ticket,
            "--outcome",
            "SEMANTIC_GAP",
            "--evidence",
            "Which source owns selection?",
        )
        self.assertEqual("planning", gap["return_to"])
        self.assertEqual("planning", self.call("status")["action"])
        self.assertFalse((self.root / "docs/tasks/new").exists())
        self.assertEqual(unrelated, self.execution.ledger.read())
