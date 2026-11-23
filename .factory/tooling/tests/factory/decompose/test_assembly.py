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

import yaml

from factory.decompose import assemble
from factory.decompose.graph.task_data import load_source_lock, load_tasks
from factory.gates.gate_contract import digest, evidence
from factory.paths import FACTORY_ROOT
from factory.project.contracts import Selection
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

        self.done_signal(Path(self.args.author_done))

    def done_signal(self, path: Path) -> None:
        staging = self.fixture.tasks_dir
        files = [item for item in sorted(staging.rglob("*")) if item.is_file()]
        value = {
            "status": "DONE",
            "staging_root": str(staging),
            "task_count": sum(
                len(json.loads(item.read_bytes())["tasks"])
                for item in files
                if item.name == "task_result.json"
            ),
            "blockers": [],
            "files": [
                {
                    "path": item.relative_to(staging).as_posix(),
                    "sha256": hashlib.sha256(item.read_bytes()).hexdigest(),
                }
                for item in files
            ],
        }
        path.write_text(json.dumps(value), encoding="utf-8")

    def test_done_signal_mismatch_blocks_before_graph(self) -> None:
        path = Path(self.args.author_done)
        valid = json.loads(path.read_bytes())
        for invalid in (
            {**valid, "task_count": valid["task_count"] + 1},
            {**valid, "files": valid["files"][:-1]},
            {**valid, "files": valid["files"] + [valid["files"][0]]},
            {**valid, "blockers": ["unfinished"]},
        ):
            with self.subTest(invalid=invalid):
                path.write_text(json.dumps(invalid), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Done Signal"):
                    assemble.prepare(self.args)
                self.assertFalse(Path(self.args.evidence_dir).exists())
        path.write_text(json.dumps(valid), encoding="utf-8")
        item = next(self.fixture.tasks_dir.rglob("*.md"))
        item.write_bytes(item.read_bytes() + b"\nChanged after Done Signal\n")
        with self.assertRaisesRegex(ValueError, "Done Signal"):
            assemble.prepare(self.args)
        self.assertFalse(Path(self.args.evidence_dir).exists())

    def test_unbound_legacy_request_is_rejected(self) -> None:
        self.approve()
        path = Path(self.args.request)
        old = json.loads(path.read_bytes())
        del old["author_manifest"]
        path.write_text(json.dumps(old), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "author_manifest"):
            assemble.assemble(self.args)

    def approve(self, request: dict[str, Any] | None = None) -> dict[str, Any]:
        if request is None:
            request = dict(assemble.prepare(self.args))
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
        Path(self.args.review).write_text(json.dumps(report), encoding="utf-8")
        return report

    def test_review_binding_ignores_unrelated_tool_but_tracks_validator(self) -> None:
        report = self.approve()
        request = json.loads(Path(self.args.request).read_text(encoding="utf-8"))
        copy = (self.fixture.root / "factory-copy").resolve()
        shutil.copytree(FACTORY_ROOT, copy, ignore=shutil.ignore_patterns(".venv", "__pycache__"))
        with (
            patch("factory.decompose.assemble.FACTORY_ROOT", copy),
            patch("factory.decompose.staging.output_safety.FACTORY_ROOT", copy),
        ):

            def status() -> str:
                _, artifacts, policy_hash = assemble.binding(
                    self.args.config, self.args.staging_dir, self.args.source_lock
                )
                tasks = load_tasks(self.args.staging_dir)["tasks"]
                return assemble.review_record(
                    request, report, artifacts, policy_hash, tasks, "review"
                )["status"]

            self.assertEqual("PASS", status())
            unrelated = copy / "tooling/factory/github/fetch_recent_notes.py"
            unrelated.write_bytes(unrelated.read_bytes() + b"\n# unrelated\n")
            self.assertEqual("PASS", status())
            self.assertEqual("PASS", assemble.assemble(self.args)["status"])
            for path in (
                "decompose/graph/validation.py",
                "runtime/commands/process.py",
                "file_reader.py",
            ):
                with self.subTest(path=path):
                    validator = copy / "tooling/factory" / path
                    baseline = validator.read_bytes()
                    validator.write_bytes(baseline + b"\n# changed validator\n")
                    self.assertEqual("BLOCKED", status())
                    validator.write_bytes(baseline)

    def test_cli_binds_selected_decompose_materials_only(self) -> None:
        from factory.context.context import build
        from factory.runtime.workflow_config import load_config

        config_path = Path(self.args.config)
        copy = config_path.parent.resolve()
        shutil.copytree(
            FIXTURE_ROOT,
            copy,
            dirs_exist_ok=True,
            ignore=shutil.ignore_patterns(".venv", "__pycache__"),
        )
        custom = copy / "custom/worker.md"
        custom.parent.mkdir()
        custom.write_text("Custom worker instructions", encoding="utf-8")
        settings = yaml.safe_load(config_path.read_text(encoding="utf-8"))
        reviewer_variants = settings["profiles"]["task-reviewer"]["variants"]
        reviewer_variants["fixture-task-reviewer"] = {
            **next(iter(reviewer_variants.values())),
            "adapter": "custom",
        }
        settings["profiles"]["task-reviewer"]["default"] = "task-reviewer"
        settings["adapters"]["custom"] = {
            **settings["adapters"]["codex"],
            "worker_instructions": "custom/worker.md",
        }
        config_path.write_text(yaml.safe_dump(settings), encoding="utf-8")
        assignment = {"source": {"kind": "approved-plan"}}

        def instructions(mode: str = "review") -> set[str]:
            packet = build(
                load_config(config_path),
                self.fixture.root,
                "fixture-task-reviewer",
                "task-reviewer",
                "decompose",
                {**assignment, "decompose_mode": mode},
            )
            return {
                Path(item["path"]).relative_to(copy).as_posix()
                for item in packet["instructions"]
                if Path(item["path"]).is_relative_to(copy)
            }

        normal = instructions()
        self.assertIn("custom/worker.md", normal)
        self.assertEqual(
            {"skills/factory-decompose/references/staging-contract.md"},
            instructions("repair") - normal,
        )
        script = copy / "gates/skills/decompose/assemble.py"
        common = [
            "--config",
            self.args.config,
            "--staging-dir",
            self.args.staging_dir,
            "--source-lock",
            self.args.source_lock,
            "--request",
            self.args.request,
            "--evidence-dir",
            self.args.evidence_dir,
        ]
        env = {**os.environ, "PYTHONPATH": str(copy / "tooling")}

        def cli(action: str, extra: list[str]) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                [sys.executable, str(script), action, *common, *extra],
                capture_output=True,
                text=True,
                env=env,
                check=False,
            )

        result = cli(
            "review-request",
            [
                "--author-done",
                self.args.author_done,
                "--run-id",
                "run-1",
                "--assignment-id",
                "review-1",
                "--author-id",
                "author",
                "--reviewer-id",
                "reviewer",
                "--reviewer-profile",
                "fixture-task-reviewer",
            ],
        )
        self.assertEqual(0, result.returncode, result.stderr)
        request = json.loads(Path(self.args.request).read_text(encoding="utf-8"))
        report = {k: request[k] for k in ("run_id", "assignment_id", "reviewer_id", "role")}
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
        Path(self.args.review).write_text(json.dumps(report), encoding="utf-8")
        arguments = ["--review", self.args.review, "--bundle-id", "orders"]
        self.assertEqual({"task-reviewer": "fixture-task-reviewer"}, request["profiles"])
        reviewer_variants["fixture-task-reviewer"]["adapter"] = "claude"
        config_path.write_text(yaml.safe_dump(settings), encoding="utf-8")
        self.assertIn("adapters/worker/claude.md", instructions())
        result = cli("assemble", arguments)
        self.assertEqual(2, result.returncode, result.stderr)
        self.assertIn("stale", result.stderr)
        reviewer_variants["fixture-task-reviewer"]["adapter"] = "custom"
        config_path.write_text(yaml.safe_dump(settings), encoding="utf-8")
        for path in (
            copy / "contracts/common/code-discovery.md",
            copy / "adapters/worker/codex.md",
            custom,
        ):
            with self.subTest(path=path):
                original = path.read_bytes()
                path.write_bytes(original + b"\nRequire two failure-path checks.\n")
                result = cli("assemble", arguments)
                self.assertEqual(2, result.returncode, result.stderr)
                self.assertIn("stale", result.stderr)
                self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())
                path.write_bytes(original)
        for unrelated in (
            copy / "tooling/factory/github/fetch_recent_notes.py",
            copy / "contracts/common/implement-write-result.md",
            copy / "adapters/worker/claude.md",
        ):
            self.assertNotIn(unrelated.relative_to(copy).as_posix(), instructions())
            unrelated.write_bytes(unrelated.read_bytes() + b"\n# Unrelated change.\n")
        result = cli("assemble", arguments)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertTrue((self.fixture.root / "docs/tasks/orders").is_dir())

    def test_changed_verification_rule_invalidates_approval(self) -> None:
        self.approve()
        copy = (self.fixture.root / "factory-copy").resolve()
        shutil.copytree(FACTORY_ROOT, copy, ignore=shutil.ignore_patterns(".venv", "__pycache__"))
        with (
            patch("factory.decompose.assemble.FACTORY_ROOT", copy),
            patch("factory.decompose.staging.output_safety.FACTORY_ROOT", copy),
        ):
            rule = copy / "gates/common/verification-rules.md"
            rule.write_bytes(rule.read_bytes() + b"\nRequire two failure-path checks.\n")
            with self.assertRaisesRegex(ValueError, "stale"):
                assemble.assemble(self.args)
            self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())

    def test_required_instruction_changes_invalidate_approval(self) -> None:
        self.approve()
        copy = (self.fixture.root / "factory-copy").resolve()
        shutil.copytree(FACTORY_ROOT, copy, ignore=shutil.ignore_patterns(".venv", "__pycache__"))
        with (
            patch("factory.decompose.assemble.FACTORY_ROOT", copy),
            patch("factory.decompose.staging.output_safety.FACTORY_ROOT", copy),
        ):
            for rule in (
                copy / "contracts/common/worker-rules.md",
                copy / "contracts/common/project-policy.md",
                copy / "contracts/common/communication.md",
                copy / "contracts/common/agent-checkpoint.md",
                copy / "adapters/worker/common.md",
                self.fixture.root / "AGENTS.md",
            ):
                with self.subTest(rule=rule):
                    original = rule.read_bytes()
                    rule.write_bytes(original + b"\nRequire two distinct failure-path checks.\n")
                    try:
                        with self.assertRaisesRegex(ValueError, "stale"):
                            assemble.assemble(self.args)
                        self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())
                    finally:
                        rule.write_bytes(original)
                        shutil.rmtree(self.fixture.root / "docs/tasks/orders", ignore_errors=True)

    def test_legacy_review_binding_requires_new_review(self) -> None:
        from factory.decompose.staging.output_safety import factory_inputs
        from factory.project.profile_io import freeze_materials, sha

        report = self.approve()
        request = json.loads(Path(self.args.request).read_text(encoding="utf-8"))
        policy = load_profile(Path(self.args.config).parent / "project/project.yaml")
        selections: list[Selection] = [
            dict(process="decompose", audience="coordinator", scope=None)
        ]
        selections += [
            dict(process="decompose", audience="worker", role=role, scope=None)
            for role in ("task-decomposer", "task-reviewer")
        ]
        core = {
            p.relative_to(FACTORY_ROOT).as_posix(): sha(p.read_bytes()) for p in factory_inputs()
        }
        request["policy_hash"] = digest(
            {
                "project": policy["hash"],
                "core": core,
                "documents": freeze_materials(policy, policy["workspace"], selections),
            }
        )
        report["request_hash"] = digest(request)
        Path(self.args.request).write_text(json.dumps(request), encoding="utf-8")
        Path(self.args.review).write_text(json.dumps(report), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "stale"):
            assemble.assemble(self.args)
        self.approve()
        self.assertEqual("PASS", assemble.assemble(self.args)["status"])

    def test_previous_scoped_binding_requires_new_review(self) -> None:
        from factory.decompose.staging.output_safety import review_inputs
        from factory.project.profile_io import freeze_materials, sha

        report = self.approve()
        request = json.loads(Path(self.args.request).read_text(encoding="utf-8"))
        policy = load_profile(Path(self.args.config).parent / "project/project.yaml")
        selections: list[Selection] = [
            dict(process="decompose", audience="coordinator", scope=None)
        ]
        selections += [
            dict(process="decompose", audience="worker", role=role, scope=None)
            for role in ("task-decomposer", "task-reviewer")
        ]
        added = {"contracts/common/worker-rules.md", "contracts/common/project-policy.md"}
        core = {
            p.relative_to(FACTORY_ROOT).as_posix(): sha(p.read_bytes())
            for p in review_inputs()
            if p.relative_to(FACTORY_ROOT).as_posix() not in added
        }
        request["policy_hash"] = digest(
            {
                "version": 2,
                "project": policy["hash"],
                "core": core,
                "documents": freeze_materials(policy, policy["workspace"], selections),
            }
        )
        report["request_hash"] = digest(request)
        Path(self.args.request).write_text(json.dumps(request), encoding="utf-8")
        Path(self.args.review).write_text(json.dumps(report), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "stale"):
            assemble.assemble(self.args)
        self.approve()
        self.assertEqual("PASS", assemble.assemble(self.args)["status"])

    def test_prepare_source_lock_cli_and_drift(self) -> None:
        plan = self.fixture.root / "plan.md"
        old_lock = json.loads(self.fixture.source_lock.read_text(encoding="utf-8"))
        old_lock["plan_hash"] = "sha256:" + digest(plan.read_text(encoding="utf-8"))
        self.fixture.source_lock.write_text(json.dumps(old_lock), encoding="utf-8")
        self.assertIn("SOURCE_DRIFT: plan_hash", str(load_source_lock(self.fixture.source_lock)[1]))
        script = FACTORY_ROOT / "gates/skills/decompose/prepare_source_lock.py"
        result = subprocess.run(
            [sys.executable, str(script), "--plan", str(plan), "--config", self.args.config],
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
            [sys.executable, str(script), "--plan", str(plan), "--config", self.args.config],
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
        self.done_signal(Path(self.args.author_done))
        self.approve()
        self.assertEqual("PASS", assemble.assemble(self.args)["status"])

    def test_repaired_tasks_require_new_review_evidence(self) -> None:
        self.approve()
        path = next((self.fixture.tasks_dir / "generated").glob("*.md"))
        path.write_bytes(path.read_bytes() + b"\nClarify existing accepted behavior.\n")
        self.args.previous_request = self.args.request
        self.args.request = str(self.fixture.root / "repaired-request.json")
        self.args.assignment_id = "review-repair"
        self.args.author_done = None
        self.args.repair_done = str(self.fixture.root / "repair-done.json")
        self.done_signal(Path(self.args.repair_done))
        request = assemble.prepare(self.args)
        self.assertTrue(request["repaired"])
        with self.assertRaisesRegex(ValueError, "request mismatch"):
            assemble.assemble(self.args)
        self.approve(dict(request))
        self.assertEqual("PASS", assemble.assemble(self.args)["status"])

    def test_source_lock_detects_invalid_utf8_byte_drift(self) -> None:
        plan = self.fixture.root / "plan.md"
        plan.write_bytes(plan.read_bytes() + b"\xff")
        self.assertIn(
            "SOURCE_DRIFT: plan_content_hash", str(load_source_lock(self.fixture.source_lock)[1])
        )

    def test_prepare_source_lock_rejects_draft(self) -> None:
        plan = self.fixture.root / "plan.md"
        plan.write_text(planning.PLAN, encoding="utf-8")
        script = FACTORY_ROOT / "gates/skills/decompose/prepare_source_lock.py"
        result = subprocess.run(
            [sys.executable, str(script), "--plan", str(plan), "--config", self.args.config],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertNotEqual(0, result.returncode)
        self.assertEqual("", result.stdout)

    def test_graph_validator_failure_blocks_project_checks(self) -> None:
        for code, status in ((1, "FAIL"), (2, "BLOCKED")):
            with self.subTest(code=code):
                completed = subprocess.CompletedProcess(
                    ["validator"], code, "graph stdout\n", "graph stderr\n"
                )
                with (
                    patch("factory.decompose.assemble.subprocess.run", return_value=completed),
                    patch("factory.decompose.assemble.check_decomposition_gates") as project_checks,
                ):
                    *_, records = assemble.inspect(
                        self.args.config,
                        self.args.staging_dir,
                        self.args.source_lock,
                        self.args.evidence_dir,
                    )
                by_id = {record["id"]: record for record in records}
                self.assertEqual(status, by_id["graph"]["status"])
                self.assertEqual("BLOCKED", by_id["project-checks"]["status"])
                project_checks.assert_not_called()
                self.assertEqual(
                    "graph stdout\ngraph stderr\n",
                    (Path(self.args.evidence_dir) / "graph.log").read_text(),
                )

    def test_cli_status_and_diagnostics_for_graph_and_review_request(self) -> None:
        script = self.fixture.root / ".factory/project/gates/skills/decompose/check.py"
        script.write_text(
            "import json, sys\n"
            "status = sys.argv[1]\n"
            'print(json.dumps({"status": status, "message": "diagnostic " + status, '
            '"evidence": ["fixture"]}))\n'
            'sys.exit({"PASS": 0, "FAIL": 1, "BLOCKED": 2}[status])\n'
        )
        gate = script.with_name("gate.yaml")
        original_gate = gate.read_text()
        payload_path = self.fixture.tasks_dir / "generated/task_result.json"
        original_payload = payload_path.read_text()
        for statuses, invalid, expected in [
            (("BLOCKED",), False, 2),
            (("PASS",), True, 1),
            (("BLOCKED",), True, 1),
            (("BLOCKED", "FAIL"), False, 1),
            (("PASS",), False, 0),
        ]:
            with self.subTest(statuses=statuses, invalid=invalid):
                text = original_gate.replace(
                    "argv: ['{python}', .factory/project/gates/skills/decompose/check.py]",
                    f"argv: ['{{python}}', .factory/project/gates/skills/decompose/check.py, {statuses[0]}]",
                )
                if len(statuses) == 2:
                    check = text[text.index("      - id:") :]
                    check = check.replace("anistar-task-metadata", "second-check")
                    check = check.replace(statuses[0] + "]", statuses[1] + "]")
                    text += check
                gate.write_text(text)
                lock = json.loads(self.fixture.source_lock.read_text())
                lock["project_policy_sha256"] = load_profile(
                    Path(self.args.config).parent / "project/project.yaml"
                )["hash"]
                self.fixture.source_lock.write_text(json.dumps(lock))
                payload = json.loads(original_payload)
                if invalid:
                    payload["tasks"][0]["id"] = "invalid"
                payload_path.write_text(json.dumps(payload))
                self.done_signal(Path(self.args.author_done))
                common = [
                    "--config",
                    self.args.config,
                    "--staging-dir",
                    self.args.staging_dir,
                    "--source-lock",
                    self.args.source_lock,
                ]
                graph_command = [
                    sys.executable,
                    str(FIXTURE_ROOT / "gates/skills/decompose/generate_task_graph.py"),
                    *common,
                    "--output",
                    str(self.fixture.root / "graph-output/graph.md"),
                ]
                review_command = [
                    sys.executable,
                    str(FIXTURE_ROOT / "gates/skills/decompose/assemble.py"),
                    "review-request",
                    *common,
                    "--author-done",
                    self.args.author_done,
                    "--request",
                    self.args.request,
                    "--evidence-dir",
                    self.args.evidence_dir,
                    "--run-id",
                    "run-1",
                    "--assignment-id",
                    "review-1",
                    "--author-id",
                    "author",
                    "--reviewer-id",
                    "reviewer",
                ]
                for command in (graph_command, review_command):
                    result = subprocess.run(command, capture_output=True, text=True, check=False)
                    self.assertEqual(expected, result.returncode, result.stderr)
                    if invalid:
                        self.assertIn("ID must end", result.stderr)
                        self.assertIn(
                            "Core validation must pass before project commands", result.stderr
                        )
                        self.assertNotIn("diagnostic BLOCKED", result.stderr)
                    else:
                        self.assertNotIn(
                            "Core validation must pass before project commands", result.stderr
                        )
                        for status in statuses:
                            if status != "PASS":
                                self.assertIn("diagnostic " + status, result.stderr)
                if not invalid and expected != 0:
                    for name in ("violations.json", "dependency_violations.md"):
                        self.assertNotIn(
                            "Core validation must pass before project commands",
                            (self.fixture.root / "graph-output" / name).read_text(),
                        )

    def test_normal_route_runs_project_check_twice(self) -> None:
        script = self.fixture.root / ".factory/project/gates/skills/decompose/check.py"
        script.write_text(
            "from pathlib import Path\n"
            "import json\n"
            "with Path('check-count').open('a') as f: f.write('x')\n"
            "print(json.dumps({'status': 'PASS', 'message': 'ok', 'evidence': ['fixture']}))\n"
        )
        lock = json.loads(self.fixture.source_lock.read_text())
        lock["project_policy_sha256"] = load_profile(
            self.fixture.root / ".factory/project/project.yaml"
        )["hash"]
        self.fixture.source_lock.write_text(json.dumps(lock))
        command = [
            sys.executable,
            str(FIXTURE_ROOT / "gates/skills/decompose/assemble.py"),
        ]
        common = [
            "--config",
            self.args.config,
            "--staging-dir",
            self.args.staging_dir,
            "--source-lock",
            self.args.source_lock,
            "--request",
            self.args.request,
            "--evidence-dir",
            self.args.evidence_dir,
        ]
        result = subprocess.run(
            [
                *command,
                "review-request",
                *common,
                "--author-done",
                self.args.author_done,
                "--run-id",
                "run-1",
                "--assignment-id",
                "review-1",
                "--author-id",
                "author",
                "--reviewer-id",
                "reviewer",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        response = json.loads(result.stdout)
        self.assertEqual(response["request_hash"], digest(response["request"]))
        self.approve(response["request"])
        result = subprocess.run(
            [*command, "assemble", *common, "--review", self.args.review, "--bundle-id", "orders"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("xx", (self.fixture.root / "check-count").read_text())

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
        Path(self.args.review).write_text(json.dumps(report), encoding="utf-8")
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
        Path(self.args.review).write_text(json.dumps(report), encoding="utf-8")
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

    def test_changed_selected_reference_invalidates_approval(self) -> None:
        f = self.fixture
        profile = Path(self.args.config).parent / "project/project.yaml"
        with profile.open("a", encoding="utf-8") as stream:
            stream.write(
                "\n    - id: decompose-background\n"
                "      for:\n"
                "        processes: [decompose]\n"
                "      project_file: docs/README.md\n"
                "      usage: reference\n"
            )
        lock = json.loads(f.source_lock.read_text())
        lock["project_policy_sha256"] = load_profile(profile)["hash"]
        f.source_lock.write_text(json.dumps(lock))
        self.approve()
        (f.root / "docs/README.md").write_text("Changed selected background")
        with self.assertRaisesRegex(ValueError, "stale"):
            assemble.assemble(self.args)
        self.assertFalse((f.root / "docs/tasks/orders").exists())

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
            FACTORY_ROOT / "tooling/factory/github/fetch_recent_notes.py",
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
        from factory.decompose.staging.output_safety import atomic_write_text

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
            Path(self.args.review).write_text("{}", encoding="utf-8")
            return result

        with patch.object(shutil, "copyfile", side_effect=changing_copy):
            with self.assertRaisesRegex(ValueError, "Review inputs changed"):
                assemble.assemble(self.args)
        self.assertFalse((self.fixture.root / "docs/tasks/orders").exists())
