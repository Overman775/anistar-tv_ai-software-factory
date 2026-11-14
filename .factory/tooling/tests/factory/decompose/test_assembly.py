from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory.decompose import assemble
from factory.gates.gate_contract import digest, evidence
from factory.paths import FACTORY_ROOT
from factory.project.profile_io import load_profile
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
        )

    def approve(self) -> dict[str, Any]:
        request = assemble.prepare(self.args)
        report: dict[str, Any] = {
            k: request[k] for k in ("run_id", "assignment_id", "reviewer_id", "role")
        }
        report.update(
            request_hash=digest(request),
            verdict="APPROVE",
            findings=[],
            criteria=[
                evidence(
                    k,
                    "PASS",
                    "Checked plan against tasks",
                    ["tasks/generated/01-orders-list-core.md"],
                )
                for k in assemble.REVIEW_CRITERIA
            ],
        )
        Path(self.args.review).write_text(json.dumps(report))
        return report

    def test_assembly_creates_only_local_tasks_and_retains_staging(self) -> None:
        self.approve()
        result = assemble.assemble(self.args)
        self.assertEqual("PASS", result["status"])
        self.assertTrue((self.fixture.root / "docs/tasks/orders/01-orders-list-core.md").is_file())
        self.assertTrue(self.fixture.tasks_dir.exists())
        self.assertFalse((self.fixture.root / ".factory/memory/state").exists())

    def test_existing_bundle_keeps_user_files(self) -> None:
        self.approve()
        bundle = self.fixture.root / "docs/tasks/orders"
        bundle.mkdir(parents=True)
        sentinel = bundle / "USER-SENTINEL.md"
        sentinel.write_bytes(b"Existing user task.\n")
        with self.assertRaisesRegex(ValueError, "already exists"):
            assemble.assemble(self.args)
        self.assertEqual([sentinel], list(bundle.iterdir()))
        self.assertEqual(b"Existing user task.\n", sentinel.read_bytes())

    def test_missing_review_blocks_writes(self) -> None:
        with self.assertRaises(ValueError):
            assemble.assemble(self.args)
        self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())

    def test_changed_task_invalidates_approval(self) -> None:
        self.approve()
        path = self.fixture.tasks_dir / "generated/01-orders-list-core.md"
        path.write_text(path.read_text() + "\nChanged wording\n")
        with self.assertRaisesRegex(ValueError, "stale"):
            assemble.assemble(self.args)
        self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())

    def test_wrong_identity_and_blocking_finding(self) -> None:
        report = self.approve()
        report["reviewer_id"] = "author"
        Path(self.args.review).write_text(json.dumps(report))
        with self.assertRaisesRegex(ValueError, "identity"):
            assemble.assemble(self.args)
        report = self.approve()
        report["findings"] = [
            {
                "id": "F1",
                "blocking": True,
                "message": "Requirement missing",
                "evidence": ["plan.md"],
            }
        ]
        Path(self.args.review).write_text(json.dumps(report))
        with self.assertRaisesRegex(ValueError, "FAIL"):
            assemble.assemble(self.args)

    def test_no_self_review_and_no_replay_across_assignment(self) -> None:
        self.args.reviewer_id = "author"
        with self.assertRaisesRegex(ValueError, "independent"):
            assemble.prepare(self.args)
        self.args.reviewer_id = "reviewer"
        self.approve()
        self.args.assignment_id = "review-2"
        assemble.prepare(self.args)
        with self.assertRaisesRegex(ValueError, "mismatch"):
            assemble.assemble(self.args)

    def test_project_script_drift_blocks_reviewed_bundle(self) -> None:
        self.approve()
        script = self.fixture.root / ".factory/project/gates/skills/decompose/check.py"
        script.write_text(script.read_text() + "\n# changed\n")
        with self.assertRaises(ValueError):
            assemble.assemble(self.args)
        self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())

    def test_source_identity_must_match_intake(self) -> None:
        path = self.fixture.source_lock
        lock = json.loads(path.read_text())
        lock["plan_id"] = "different-plan"
        path.write_text(json.dumps(lock))
        with self.assertRaisesRegex(ValueError, "identity/revision"):
            assemble.prepare(self.args)

    def test_evidence_cannot_overwrite_inputs(self) -> None:
        self.args.evidence_dir = str(self.fixture.root)
        with self.assertRaisesRegex(ValueError, "protected inputs"):
            assemble.prepare(self.args)

    def test_request_and_evidence_never_overwrite_protected_inputs(self) -> None:
        policy = load_profile(Path(self.args.config).parent / "project/project.yaml")
        material = self.fixture.root / "docs/README.md"
        inputs = [
            Path(self.args.config),
            Path(self.args.source_lock),
            Path(policy["path"]),
            material,
            self.fixture.root / "plan.md",
        ]
        inputs.extend(Path(path) for path in policy["files"])
        before = {path: path.read_bytes() for path in inputs}
        for path in inputs:
            with self.subTest(request=str(path)):
                self.args.request = str(path)
                with self.assertRaisesRegex(ValueError, "protected inputs"):
                    assemble.prepare(self.args)
                self.assertFalse(Path(self.args.evidence_dir).exists())
        self.assertEqual(before, {path: path.read_bytes() for path in before})

    def test_cli_blocks_policy_overwrite_before_evidence_write(self) -> None:
        policy = self.fixture.root / ".factory/project/project.yaml"
        before = policy.read_bytes()
        command = [
            sys.executable,
            str(FIXTURE_ROOT / "gates/skills/decompose/assemble.py"),
            "review-request",
            "--config",
            self.args.config,
            "--staging-dir",
            self.args.staging_dir,
            "--source-lock",
            self.args.source_lock,
            "--request",
            str(policy),
            "--evidence-dir",
            self.args.evidence_dir,
            "--run-id",
            "r",
            "--assignment-id",
            "a",
            "--author-id",
            "author",
            "--reviewer-id",
            "reviewer",
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(2, result.returncode)
        self.assertIn("protected inputs", result.stderr)
        self.assertEqual(before, policy.read_bytes())
        self.assertFalse(Path(self.args.evidence_dir).exists())

    def test_graph_cli_cannot_overwrite_policy_or_follow_diagnostic_alias(self) -> None:
        policy = self.fixture.root / ".factory/project/project.yaml"
        before = policy.read_bytes()
        command = [
            sys.executable,
            str(FIXTURE_ROOT / "gates/skills/decompose/generate_task_graph.py"),
            "--config",
            self.args.config,
            "--staging-dir",
            self.args.staging_dir,
            "--source-lock",
            self.args.source_lock,
            "--core-only",
            "--output",
        ]
        result = subprocess.run(command + [str(policy)], capture_output=True, text=True)
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
            command + [str(evidence / "graph.md")], capture_output=True, text=True
        )
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertEqual(before, policy.read_bytes())
        self.assertFalse((evidence / "graph.md").exists())

    def test_evidence_aliases_cannot_mutate_policy_or_provenance(self) -> None:
        policy = self.fixture.root / ".factory/project/project.yaml"
        before = policy.read_bytes()
        evidence = Path(self.args.evidence_dir)
        evidence.mkdir()
        link = evidence / "graph.log"
        try:
            link.symlink_to(policy)
        except OSError as exc:
            self.skipTest(f"symlinks unavailable: {exc}")
        with self.assertRaisesRegex(ValueError, "symlink or hardlink"):
            assemble.prepare(self.args)
        self.assertEqual(before, policy.read_bytes())
        self.assertFalse(Path(self.args.request).exists())
        link.unlink()
        try:
            os.link(policy, evidence / "graph.md")
        except OSError as exc:
            self.skipTest(f"hardlinks unavailable: {exc}")
        with self.assertRaisesRegex(ValueError, "symlink or hardlink"):
            assemble.prepare(self.args)
        self.assertEqual(before, policy.read_bytes())
        self.assertFalse(Path(self.args.request).exists())

    def test_request_cannot_replace_factory_dependency_or_workspace_instructions(self) -> None:
        agents = self.fixture.root / "AGENTS.md"
        agents.write_text("Project instructions")
        for target in (agents, FACTORY_ROOT / "tooling/factory/decompose/assemble.py"):
            before = target.read_bytes()
            self.args.request = str(target)
            with self.assertRaisesRegex(ValueError, "protected inputs"):
                assemble.prepare(self.args)
            self.assertEqual(before, target.read_bytes())
            self.assertFalse(Path(self.args.evidence_dir).exists())

    def test_late_graph_log_symlink_does_not_touch_policy(self) -> None:
        policy = self.fixture.root / ".factory/project/project.yaml"
        before = policy.read_bytes()
        real_run = subprocess.run

        def run_and_insert_alias(command: Any, *args: Any, **kwargs: Any) -> Any:
            result = real_run(command, *args, **kwargs)
            if any("generate_task_graph.py" in str(part) for part in command):
                (Path(self.args.evidence_dir) / "graph.log").symlink_to(policy)
            return result

        with patch("factory.decompose.assemble.subprocess.run", side_effect=run_and_insert_alias):
            assemble.prepare(self.args)
        self.assertEqual(before, policy.read_bytes())
        self.assertFalse((Path(self.args.evidence_dir) / "graph.log").is_symlink())
        self.assertTrue(Path(self.args.request).is_file())

    def test_atomic_graph_output_replaces_late_alias(self) -> None:
        from factory.decompose.output_safety import atomic_write_text

        target = self.fixture.root / "user.txt"
        target.write_text("original")
        output = self.fixture.root / "graph.md"
        output.symlink_to(target)
        atomic_write_text(output, "graph")
        self.assertEqual("original", target.read_text())
        self.assertEqual("graph", output.read_text())
        self.assertFalse(output.is_symlink())

    def test_review_changed_during_copy_blocks_assembly(self) -> None:
        self.approve()
        copy = shutil.copyfile

        def changing_copy(source: Path, target: Path) -> Path:
            result = copy(source, target)
            Path(self.args.review).write_text("{}")
            return result

        with patch.object(shutil, "copyfile", side_effect=changing_copy):
            with self.assertRaisesRegex(ValueError, "Review inputs changed"):
                assemble.assemble(self.args)
        self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())
