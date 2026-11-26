"""Planning recovers from exact saved input and publishes only its reviewed revision."""

import json
import subprocess
import unittest
from typing import Any
from unittest.mock import patch

from factory.database.provider import current_database
from factory.processes import cli, engine, publication
from factory.runtime import graph_inputs
from factory.runtime.workflow_core import digest
from tests import CLI
from tests.factory.planning.fixture_plan import PLAN
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class PlanningProcessTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = WorkflowFixture(self.addCleanup)
        self.config = self.f.config_file(lambda c: c["execution"].update(workspace="shared"))
        self.root = self.f.root
        self.draft = self.root / "draft.md"
        self.draft.write_text(PLAN)
        self.approved = self.root / "approved.md"
        self.approved.write_text(
            PLAN.replace("status: draft", "status: approved", 1).replace(
                "approved_revision: none", "approved_revision: 1", 1
            )
        )
        self.run_id = ""
        self.count = 0

    def call(self, action: str, *items: str, ok: bool = True, request: str | None = None) -> Any:
        self.count += 1
        args = [
            "--workspace",
            str(self.root),
            "--config",
            str(self.config),
            "--request",
            request or f"r{self.count}",
        ]
        if self.run_id:
            args.extend(("--run", self.run_id))
        result = subprocess.run(
            [*CLI, "planning", "run", action, *args, *items], capture_output=True, text=True
        )
        self.assertEqual(ok, result.returncode == 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def test_material_gap_holds_before_work_and_explicit_no_plan_overrides_delegation(self) -> None:
        source = self.f.g["sources"]["request"]
        source["semantic_gap"] = "Which host may use the trust override?"
        cmd = [*CLI, "workflow", "--workspace", str(self.root), "--config", str(self.config)]
        for refs, code in [
            ({}, "NEEDS_PLANNING"),
            ({"delegated_planning_ref": "owner delegates policy choice"}, "PLANNING_REQUIRED"),
            ({"no_plan_ref": "owner later forbids planning"}, "NEEDS_PLANNING"),
        ]:
            source.update(refs)
            proposal = graph_inputs.propose(self.root, self.f.g)
            result = subprocess.run([*cmd, "init", proposal], capture_output=True, text=True)
            self.assertNotEqual(0, result.returncode)
            self.assertIn(code, result.stderr + result.stdout)
            self.assertEqual("before", (self.root / "lib/example.dart").read_text())
            self.assertFalse(self.f.ledger.runs.has_current(self.root))

    def start(self, *extra: str) -> str:
        self.run_id = self.call(
            "init",
            "--task",
            "Design a bounded playback change",
            "--destination",
            "plans/result.md",
            *extra,
        )["run_id"]
        ticket = self.call("claim", request="claim-architect")["dispatch"]
        self.assertEqual(ticket, self.call("claim", request="claim-architect")["dispatch"])
        self.assertEqual("reconcile", self.call("claim")["action"])
        self.call("bind", "--dispatch", ticket, "--handle", "architect-one")
        return str(ticket)

    def approved_candidate(self, ticket: str) -> None:
        destination = self.root / "plans/result.md"
        original = publication.identity(destination)
        sketch = self.root / "sketch.yaml"
        sketch.write_text("boundary: []\nverify: [boundary]\n")
        output = self.call(
            "report",
            "--dispatch",
            ticket,
            "--outcome",
            "PLAN_READY",
            "--evidence",
            "Closure of all material decisions",
            "--file",
            str(self.draft),
            "--sketch",
            str(sketch),
        )
        status = self.call("status")
        self.assertEqual("review", status["action"])
        self.assertEqual(["boundary"], status["candidate"]["sketch"]["verify"])
        args = (
            "--basis",
            output["candidate"],
            "--outcome",
            "APPROVED",
            "--file",
            str(self.approved),
            "--reference",
            "owner-message-12",
            "--evidence",
            "Scope and three plan gates checked",
        )
        self.call("review", *args, "--actor", "architect-one", ok=False)
        self.call("review", *args, "--actor", "independent-coordinator")
        self.assertEqual(original, publication.identity(destination))

    def test_approved_publication_handles_lost_commit_and_preserves_history(self) -> None:
        ticket = self.start(
            "--continuation",
            "implement",
            "--authorization",
            "owner requested implementation after approval",
        )
        self.approved_candidate(ticket)
        self.call("prepare-publication")
        # Simulate the process dying after rename and just before the SQLite write.
        args = cli.build_parser().parse_args(
            [
                "publish",
                "--workspace",
                str(self.root),
                "--config",
                str(self.config),
                "--run",
                self.run_id,
                "--request",
                "install",
            ]
        )
        with (
            patch.object(
                current_database().processes, "save", side_effect=RuntimeError("interrupted commit")
            ),
            self.assertRaisesRegex(RuntimeError, "interrupted commit"),
        ):
            cli.operate(args, "planning")
        self.assertEqual(self.approved.read_bytes(), (self.root / "plans/result.md").read_bytes())
        first = self.call("publish", request="install")
        self.assertEqual(first, self.call("publish", request="install"))
        self.assertEqual("implement", first["continuation"])
        proposal = graph_inputs.propose_plan(self.root, self.f.g, "request", first["destination"])
        cmd = [*CLI, "workflow", "--workspace", str(self.root), "--config", str(self.config)]
        result = subprocess.run([*cmd, "init", proposal, "--json"], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertIn(
            "write-label",
            json.loads(subprocess.check_output([*cmd, "status", "--json"]))["result"]["runnable"],
        )

        self.call("clean")
        history = self.call("history")
        self.assertEqual(1, len([e for e in history["events"] if e["event"] == "publish"]))
        self.assertEqual(
            digest(self.approved.read_bytes()), history["facts"]["approved"]["content_hash"]
        )
        self.assertEqual(ticket, history["attempts"]["architect"][0]["dispatch"])

    def test_published_plan_becomes_an_independent_decompose_source(self) -> None:
        ticket = self.start(
            "--continuation", "decompose", "--authorization", "owner asks for local tasks"
        )
        self.approved_candidate(ticket)
        self.call("prepare-publication")
        completed = self.call("publish")
        self.call("clean")
        args = [*CLI, "decompose", "run"]
        common = ["--workspace", str(self.root), "--config", str(self.config)]
        started = subprocess.run(
            [
                *args,
                "init",
                *common,
                "--request",
                "separate-bundle",
                "--authorization",
                "owner asks for local tasks",
                "--plan",
                completed["destination"],
                "--destination",
                "tasks/planned",
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        follow = json.loads(started.stdout)["run_id"]
        self.assertNotEqual(follow, self.run_id)
        history = subprocess.run(
            [*args, "history", *common, "--run", follow], capture_output=True, text=True, check=True
        )
        locked = json.loads(history.stdout)["subject"]["source_lock"]
        approved = self.call("history")["facts"]["approved"]
        self.assertEqual(
            (approved["plan_id"], approved["revision"]),
            (locked["plan_id"], locked["plan_revision"]),
        )
        self.assertEqual("sha256:" + approved["content_hash"], locked["plan_content_hash"])
        self.assertEqual(
            approved["content_hash"], digest((self.root / completed["destination"]).read_bytes())
        )

    def test_format_success_cannot_open_publication_on_a_redirected_edge(self) -> None:
        definition = self.config.parent / "graphs/planning.yaml"
        definition.write_text(
            definition.read_text()
            .replace("plan_ready, target: review", "plan_ready, target: publish")
            .replace("approved, target: publish", "approved, target: review")
        )
        ticket = self.start()
        self.call(
            "report",
            "--dispatch",
            ticket,
            "--outcome",
            "PLAN_READY",
            "--evidence",
            "Candidate conforms to the draft contract",
            "--file",
            str(self.draft),
        )
        status = self.call("status")
        self.assertEqual("hold", status["action"])
        self.assertIn("Independent approval", status["reason"])
        self.call("prepare-publication", ok=False)
        self.assertFalse((self.root / "plans/result.md").exists())
        self.assertIn("plan_ready", self.call("diagram")["mermaid"])
        self.call("cancel", "--evidence", "Owner cancelled invalid definition")
        self.assertEqual("cancelled", self.call("history")["status"]["terminal"])

    def test_questions_resume_the_same_architect_and_explorer(self) -> None:
        unrelated = self.f.init()
        ticket = self.start()
        for outcome in ("NEEDS_USER_DECISION", "BLOCKED_REQUIREMENTS"):
            self.call(
                "report",
                "--dispatch",
                ticket,
                "--outcome",
                outcome,
                "--evidence",
                "Need the owner scope or source",
            )
            self.assertEqual("answer", self.call("status")["action"])
            self.assertFalse((self.root / "plans/result.md").exists())
            self.call(
                "answer", "--reference", "owner-11", "--evidence", "Inspect the playback binding"
            )
            self.assertEqual(ticket, self.call("status")["dispatch"]["dispatch"])
        self.call("question", "--evidence", "Where does playback select and call the handler?")
        explorer = self.call("claim")["dispatch"]
        self.call("bind", "--dispatch", explorer, "--handle", "researcher-one")
        self.call(
            "note",
            "--dispatch",
            explorer,
            "--evidence",
            "Located entry",
            "--cite",
            "lib/example.dart:1",
        )
        self.call(
            "report",
            "--dispatch",
            explorer,
            "--outcome",
            "BLOCKED_EXTERNAL_SOURCE",
            "--source",
            "behavior.py",
            "--evidence",
            "Missing call site",
        )
        self.call("answer", "--reference", "owner-12", "--evidence", "Source made available")
        self.assertEqual(explorer, self.call("status")["dispatch"]["dispatch"])
        (self.root / "behavior.py").write_text("def choose():\n    return playback()\n")
        self.call(
            "report",
            "--dispatch",
            explorer,
            "--outcome",
            "ANALYSIS_READY",
            "--cite",
            "behavior.py:1",
            "--cite",
            "behavior.py:2",
            "--evidence",
            "choose invokes playback",
        )
        self.assertEqual(ticket, self.call("status")["dispatch"]["dispatch"])
        self.approved_candidate(ticket)
        self.call("prepare-publication")
        proof = self.call("publish")
        self.assertEqual("none", proof["continuation"])
        self.assertEqual(unrelated, self.f.ledger.read())

    def test_replacement_recovers_after_original_saved_and_before_installation(self) -> None:
        target = self.root / "result.md"
        target.write_text("approved previous version")
        op = publication.prepare(
            self.root,
            "result.md",
            {"content": "approved new version"},
            publication.identity(target),
            directory=False,
        )
        staged = self.root / op["staged"]
        publication.move_new(target, staged.with_name("previous"))
        self.assertFalse(target.exists())
        result = publication.install(self.root, op)
        self.assertEqual("approved new version", target.read_text())
        self.assertEqual(result, publication.install(self.root, op))
        publication.release(self.root, op)
        self.assertFalse(staged.parent.exists())

    def test_cancel_restores_half_published_plan_and_clean_releases_stage(self) -> None:
        target = self.root / "plans/result.md"
        target.parent.mkdir(exist_ok=True)
        target.write_bytes(self.approved.read_bytes())
        self.draft.write_text(
            PLAN.replace("revision: 1", "revision: 2", 1).replace(
                "payment opens with a valid chain",
                "payment opens with a valid chain and a valid payment host",
            )
        )
        self.approved.write_text(
            self.draft.read_text()
            .replace("status: draft", "status: approved", 1)
            .replace("approved_revision: none", "approved_revision: 2", 1)
        )
        original = publication.identity(target)
        assert original is not None
        ticket = self.start("--previous", original["digest"])
        self.call("pause", "--evidence", "Owner requested pause")
        held = self.call("packet", "--dispatch", ticket, "--handle", "architect-one")
        self.assertEqual("wait", held["action"])
        self.assertNotIn("context", held)
        self.call("resume")
        args = cli.build_parser().parse_args(
            [
                "packet",
                "--workspace",
                str(self.root),
                "--run",
                self.run_id,
                "--dispatch",
                ticket,
                "--handle",
                "architect-one",
            ]
        )
        with patch.object(engine, "handlers", return_value={}):
            self.assertIn("Restore", cli.operate(args, "planning")["reason"])
        self.approved_candidate(ticket)
        self.call("prepare-publication")
        op = self.call("history")["facts"]["publication"]
        stage = self.root / op["staged"]
        publication.move_new(target, stage.with_name("previous"))
        self.call("cancel", "--evidence", "Owner cancelled")
        self.assertEqual(original, publication.identity(target))
        self.call("clean")
        self.call("clean")
        self.assertFalse(stage.parent.exists())
        self.call("publish", ok=False)

    def test_equal_foreign_publication_and_changed_previous_plan_are_preserved(self) -> None:
        ticket = self.start()
        self.approved_candidate(ticket)
        self.call("prepare-publication")
        path = self.root / "plans/result.md"
        path.write_bytes(self.approved.read_bytes())
        original = path.stat().st_ino
        self.call("publish", ok=False)
        self.assertEqual(original, path.stat().st_ino)
        self.assertEqual("publish", self.call("status")["action"])
        prepared = publication.prepare(
            self.root,
            "plans/result.md",
            {"content": "new"},
            publication.identity(path),
            directory=False,
        )
        path.write_text("external")
        with self.assertRaisesRegex(ValueError, "edited"):
            publication.install(self.root, prepared)
        self.assertEqual("external", path.read_text())
