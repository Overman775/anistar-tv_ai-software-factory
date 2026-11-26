from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import unittest
from pathlib import Path

from factory.decompose.graph.task_data import load_source_lock
from factory.gates.gate_contract import digest
from factory.project.profile_io import load_profile
from tests import CLI
from tests.factory.decompose import fixture_task_graph as fixtures
from tests.factory.planning import fixture_plan as planning
from tests.fixture_bundle import ROOT as FIXTURE_ROOT


class AssemblyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = fixtures.TaskGraphFixture(self.addCleanup)
        f = self.fixture
        f.write_tasks([f.task()])
        plan = (
            planning.PLAN.replace("payment-webview-trusted-ca", "orders-plan")
            .replace("revision: 1", "revision: 2")
            .replace("status: draft", "status: approved")
            .replace("approved_revision: none", "approved_revision: 2")
        )
        (f.root / "plan.md").write_text(plan)
        exact = "sha256:" + hashlib.sha256(plan.encode()).hexdigest()
        normalized = (
            "sha256:"
            + hashlib.sha256(
                "\n".join(line.rstrip() for line in plan.split("\n")).rstrip().encode()
            ).hexdigest()
        )
        project = f.root / ".factory/project"
        shutil.copytree(
            FIXTURE_ROOT / "project", project, ignore=shutil.ignore_patterns("__pycache__")
        )
        config = f.root / ".factory/factory.yaml"
        config.write_text("project: project/project.yaml\n")
        lock = json.loads(f.source_lock.read_text())
        lock.update(plan_content_hash=exact, plan_hash=normalized)
        policy = load_profile(project / "project.yaml")
        lock["project_policy_sha256"] = policy["hash"]
        for document in policy["data"].get("documents", {}).values():
            path = f.root / document["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("Fixture project policy")
        (f.root / "docs/README.md").write_text("Fixture index")
        (f.root / "AGENTS.md").write_text("Fixture workspace rules")
        f.source_lock.write_text(json.dumps(lock))
        payload_path = f.tasks_dir / "generated/task_result.json"
        payload = json.loads(payload_path.read_text())
        payload["source_plan"]["hash"] = normalized
        payload_path.write_text(json.dumps(payload))
        self.args = argparse.Namespace(
            config=str(config),
            staging_dir=str(f.tasks_dir),
            source_lock=str(f.source_lock),
            request=str(f.root / "review-request.json"),
            review=str(f.root / "review.json"),
            evidence_dir=str(f.root / "evidence"),
            run_id="run-1",
            assignment_id="review-1",
            author_id="author",
            reviewer_id="reviewer",
            bundle_id="orders",
            author_done=str(f.root / "author-done.json"),
        )

    def test_prepare_source_lock_cli_and_drift(self) -> None:
        plan = self.fixture.root / "plan.md"
        old_lock = json.loads(self.fixture.source_lock.read_text(encoding="utf-8"))
        old_lock["plan_hash"] = "sha256:" + digest(plan.read_text(encoding="utf-8"))
        self.fixture.source_lock.write_text(json.dumps(old_lock), encoding="utf-8")
        self.assertIn("SOURCE_DRIFT: plan_hash", str(load_source_lock(self.fixture.source_lock)[1]))
        result = subprocess.run(
            [*CLI, "decompose", "source-lock", "--plan", str(plan), "--config", self.args.config],
            capture_output=True,
            text=True,
            check=True,
        )
        lock = json.loads(result.stdout)
        self.assertNotIn("plan_commit", lock)
        self.assertEqual("orders-plan", lock["plan_id"])
        self.assertEqual(2, lock["plan_revision"])
        self.assertEqual(["CAP-01"], lock["capability_ids"])
        self.assertEqual(["AC-01"], lock["acceptance_ids"])
        self.fixture.source_lock.write_text(result.stdout, encoding="utf-8")
        self.assertEqual([], load_source_lock(self.fixture.source_lock)[1])
        plan.write_bytes(plan.read_bytes().replace(b"\n", b"\r\n"))
        self.assertIn("plan_content_hash", str(load_source_lock(self.fixture.source_lock)[1]))
        updated = subprocess.run(
            [*CLI, "decompose", "source-lock", "--plan", str(plan), "--config", self.args.config],
            capture_output=True,
            text=True,
            check=True,
        )
        self.assertEqual(lock["plan_hash"], json.loads(updated.stdout)["plan_hash"])

    def test_source_lock_uses_planning_numeric_revision(self) -> None:
        from factory.decompose.source_lock import prepare

        root = self.fixture.root
        plan = root / "plan.md"
        plan.write_text(
            plan.read_text(encoding="utf-8").replace("revision: 2\n", "revision: 02\n", 1),
            encoding="utf-8",
        )
        lock = prepare(plan, Path(self.args.config))
        self.assertEqual(2, lock["plan_revision"])
        self.fixture.source_lock.write_text(json.dumps(lock), encoding="utf-8")
        task = self.fixture.tasks_dir / "generated/task_result.json"
        payload = json.loads(task.read_text(encoding="utf-8"))
        payload["source_plan"]["hash"] = lock["plan_hash"]
        task.write_text(json.dumps(payload), encoding="utf-8")

        self.assertEqual([], load_source_lock(self.fixture.source_lock)[1])

    def test_source_lock_detects_invalid_utf8_byte_drift(self) -> None:
        plan = self.fixture.root / "plan.md"
        plan.write_bytes(plan.read_bytes() + b"\xff")
        self.assertIn(
            "SOURCE_DRIFT: plan_content_hash", str(load_source_lock(self.fixture.source_lock)[1])
        )

    def test_prepare_source_lock_rejects_draft(self) -> None:
        plan = self.fixture.root / "plan.md"
        plan.write_text(planning.PLAN, encoding="utf-8")
        result = subprocess.run(
            [*CLI, "decompose", "source-lock", "--plan", str(plan), "--config", self.args.config],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("", result.stdout)

    def test_graph_cli_cannot_overwrite_policy_or_follow_diagnostic_alias(self) -> None:
        policy = self.fixture.root / ".factory/project/project.yaml"
        before = policy.read_bytes()
        command = [
            *CLI,
            "decompose",
            "graph",
            "--config",
            self.args.config,
            "--staging-dir",
            self.args.staging_dir,
            "--source-lock",
            self.args.source_lock,
            "--core-only",
            "--output",
        ]
        result = subprocess.run(
            command + [str(policy)], capture_output=True, text=True, check=False
        )
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertIn("protected inputs", result.stderr)
        self.assertEqual(before, policy.read_bytes())
        evidence = Path(self.args.evidence_dir)
        evidence.mkdir()
        try:
            (evidence / "violations.json").symlink_to(policy)
        except OSError as exc:
            self.skipTest(f"symlinks unavailable: {exc}")
        result = subprocess.run(
            command + [str(evidence / "graph.md")], capture_output=True, text=True, check=False
        )
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertEqual(before, policy.read_bytes())
        self.assertFalse((evidence / "graph.md").exists())

    def test_atomic_graph_output_replaces_late_alias(self) -> None:
        from factory.decompose.staging.output_safety import atomic_write_text

        target = self.fixture.root / "user.txt"
        target.write_text("original")
        output = self.fixture.root / "graph.md"
        output.symlink_to(target)
        atomic_write_text(output, "graph")
        self.assertEqual("original", target.read_text())
        self.assertEqual("graph", output.read_text())
        self.assertFalse(output.is_symlink())
