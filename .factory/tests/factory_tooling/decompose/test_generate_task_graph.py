from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory_tooling.decompose import generate_task_graph as graph
from factory_tooling.decompose.contracts import LoadedTask
from factory_tooling.decompose.metadata import apply, project
from factory_tooling.paths import FACTORY_ROOT
from tests.fixture_bundle import ROOT as FIXTURE_ROOT

SCRIPT_PATH = FACTORY_ROOT / "gates/skills/decompose/generate_task_graph.py"


class GenerateTaskGraphTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.tasks_dir = self.root / "tasks"
        self.tasks_dir.mkdir()
        self.source_lock = self.root / "decomposition-source.json"
        self.source_lock.write_text(
            json.dumps(
                {
                    "plan_id": "orders-plan",
                    "plan_revision": 2,
                    "plan_hash": "sha256:test",
                    "plan_path": "docs/plans/orders-plan.md",
                    "capability_ids": [],
                    "acceptance_ids": ["AC-01"],
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def test_metadata_projection_derives_totals_without_writing_inputs(self) -> None:
        labels = (
            "ID",
            "Plan source",
            "Covers capabilities",
            "Acceptance criteria",
            "Contribution to plan criteria",
            "Purpose",
            "Scope",
            "Estimate",
            "Parent task",
            "Depends on",
            "Blocked by",
        )
        prose = "\n## 1. Context\n\nUnchanged author prose.\n"
        markdown = "# Author title\n" + "".join(f"- **{name}:** old\n" for name in labels) + prose
        task = self.task()
        self.write_tasks([task], markdown=markdown)
        envelope_path = self.tasks_dir / "generated/task_result.json"
        envelope = json.loads(envelope_path.read_text())
        envelope["total_min_hours"] = 999
        envelope_path.write_text(json.dumps(envelope))
        result = project(self.tasks_dir, self.source_lock)
        rendered = result["envelopes"]
        self.assertIsInstance(rendered, dict)
        self.assertEqual(
            task["estimate"]["min_hours"], rendered[str(envelope_path)]["total_min_hours"]
        )
        self.assertEqual(999, json.loads(envelope_path.read_text())["total_min_hours"])
        doc = self.tasks_dir / "generated" / task["filename"]
        self.assertEqual(markdown, doc.read_text())
        documents = result["documents"]
        self.assertIsInstance(documents, dict)
        self.assertTrue(documents[str(doc)].endswith(prose))

    def test_projection_covers_cross_envelope_tasks_and_final_plan_link(self) -> None:
        labels = (
            "ID",
            "Plan source",
            "Covers capabilities",
            "Acceptance criteria",
            "Contribution to plan criteria",
            "Purpose",
            "Scope",
            "Estimate",
            "Parent task",
            "Depends on",
            "Blocked by",
        )
        markdown = (
            "# Title\n"
            + "".join(f"- **{name}:** old\n" for name in labels)
            + "\n## Context\nProse\n"
        )
        first = self.task("orders-first-01")
        second = self.task("orders-second-02")
        self.write_tasks([first, second], markdown=markdown)
        one_path = self.tasks_dir / "generated/task_result.json"
        one = json.loads(one_path.read_text())
        two = dict(one)
        one["tasks"] = [first]
        one["capability_coverage"] = [
            {
                "capability_id": "CAP-01",
                "coverage": "complete",
                "task_ids": [first["id"], second["id"]],
            }
        ]
        two["tasks"] = [second]
        two["capability_coverage"] = []
        one_path.write_text(json.dumps(one))
        second_dir = self.tasks_dir / "second"
        second_dir.mkdir()
        second_path = second_dir / second["filename"]
        (self.tasks_dir / "generated" / second["filename"]).rename(second_path)
        (second_dir / "task_result.json").write_text(json.dumps(two))
        projected = project(self.tasks_dir, self.source_lock)
        output = projected["documents"][str(second_path)]
        self.assertIn("- **Covers capabilities:** CAP-01", output)
        plan = Path(json.loads(self.source_lock.read_text())["plan_path"]).resolve()
        link = output.split("[approved plan](<", 1)[1].split(">)", 1)[0]
        self.assertEqual(plan, (Path.cwd() / "docs/tasks/bundle" / link).resolve())
        self.assertIn(str(second_path), projected["input_sha256"])
        self.assertIn(str(self.source_lock), projected["input_sha256"])

    def test_projection_rejects_symlinked_staging_directory_before_loading(self) -> None:
        external = self.root / "external"
        external.mkdir()
        (external / "task_result.json").write_text("{}")
        link = self.tasks_dir / "linked"
        try:
            link.symlink_to(external, target_is_directory=True)
        except OSError as exc:
            self.skipTest(f"symlink unavailable: {exc}")
        with self.assertRaisesRegex(ValueError, "Symlink in staging"):
            project(self.tasks_dir, self.source_lock)

    def test_projection_rejects_symlink_in_staging_or_source_ancestors(self) -> None:
        external = self.root / "external-state"
        (external / "tasks").mkdir(parents=True)
        (external / "source.json").write_text("{}")
        parent = self.root / "factory"
        parent.mkdir()
        link = parent / "staging"
        try:
            link.symlink_to(external, target_is_directory=True)
        except OSError as exc:
            self.skipTest(f"symlink unavailable: {exc}")
        with self.assertRaisesRegex(ValueError, "Symlink in projection path"):
            project(link / "tasks", link / "source.json")
        with self.assertRaisesRegex(ValueError, "Symlink in projection path"):
            project(self.tasks_dir, link / "source.json")

    def test_metadata_apply_saves_checkpoint_and_updates_drafts(self) -> None:
        labels = (
            "ID",
            "Plan source",
            "Covers capabilities",
            "Acceptance criteria",
            "Contribution to plan criteria",
            "Purpose",
            "Scope",
            "Estimate",
            "Parent task",
            "Depends on",
            "Blocked by",
        )
        prose = "\n## Context\nAuthor prose remains.\n"
        draft = "# Title\n" + "".join(f"- **{name}:** old\n" for name in labels) + prose
        task = self.task()
        self.write_tasks([task], markdown=draft)
        envelope = self.tasks_dir / "generated/task_result.json"
        original = envelope.read_bytes()
        data = json.loads(original)
        data["total_min_hours"] = 999
        envelope.write_text(json.dumps(data))
        original = envelope.read_bytes()
        result = apply(self.tasks_dir, self.source_lock, "snapshot-1")
        checkpoint = Path(str(result["checkpoint"]))
        self.assertEqual(original, (checkpoint / "tasks/generated/task_result.json").read_bytes())
        self.assertEqual(
            task["estimate"]["min_hours"], json.loads(envelope.read_text())["total_min_hours"]
        )
        doc = self.tasks_dir / "generated" / task["filename"]
        self.assertTrue(doc.read_text().endswith(prose))
        self.assertIn(task["id"], doc.read_text())
        with self.assertRaisesRegex(ValueError, "Checkpoint already exists"):
            apply(self.tasks_dir, self.source_lock, "snapshot-1")

    def test_metadata_apply_interruption_preserves_complete_checkpoint(self) -> None:
        labels = (
            "ID",
            "Plan source",
            "Covers capabilities",
            "Acceptance criteria",
            "Contribution to plan criteria",
            "Purpose",
            "Scope",
            "Estimate",
            "Parent task",
            "Depends on",
            "Blocked by",
        )
        draft = (
            "# Title\n"
            + "".join(f"- **{name}:** old\n" for name in labels)
            + "\n## Context\nKeep.\n"
        )
        task = self.task()
        self.write_tasks([task], markdown=draft)
        extra = self.tasks_dir / "generated/author-notes.txt"
        extra.write_text("Keep all staging")
        with patch(
            "factory_tooling.decompose.metadata.os.replace", side_effect=OSError("interrupted")
        ):
            with self.assertRaisesRegex(OSError, "interrupted"):
                apply(self.tasks_dir, self.source_lock, "interrupted-1")
        checkpoint = self.tasks_dir.parent / "checkpoints/interrupted-1/tasks/generated"
        self.assertEqual(draft, (checkpoint / task["filename"]).read_text())
        self.assertEqual("Keep all staging", (checkpoint / "author-notes.txt").read_text())
        self.assertEqual(draft, (self.tasks_dir / "generated" / task["filename"]).read_text())

    def test_metadata_apply_rejects_plan_drift_before_staging_writes(self) -> None:
        labels = (
            "ID",
            "Plan source",
            "Covers capabilities",
            "Acceptance criteria",
            "Contribution to plan criteria",
            "Purpose",
            "Scope",
            "Estimate",
            "Parent task",
            "Depends on",
            "Blocked by",
        )
        draft = (
            "# Title\n"
            + "".join(f"- **{name}:** old\n" for name in labels)
            + "\n## Context\nKeep.\n"
        )
        task = self.task()
        self.write_tasks([task], markdown=draft)
        (self.root / "plan.md").write_text("changed after approval")
        with self.assertRaisesRegex(ValueError, "SOURCE_DRIFT"):
            apply(self.tasks_dir, self.source_lock, "drift")
        self.assertEqual(draft, (self.tasks_dir / "generated" / task["filename"]).read_text())
        self.assertFalse((self.tasks_dir.parent / "checkpoints/drift").exists())

    def test_metadata_apply_rechecks_plan_after_projection(self) -> None:
        labels = (
            "ID",
            "Plan source",
            "Covers capabilities",
            "Acceptance criteria",
            "Contribution to plan criteria",
            "Purpose",
            "Scope",
            "Estimate",
            "Parent task",
            "Depends on",
            "Blocked by",
        )
        draft = (
            "# Title\n"
            + "".join(f"- **{name}:** old\n" for name in labels)
            + "\n## Context\nKeep.\n"
        )
        task = self.task()
        self.write_tasks([task], markdown=draft)
        original_project = project

        def mutate_plan(staging: Path, source: Path) -> Any:
            result = original_project(staging, source)
            (self.root / "plan.md").write_text("changed after projection")
            return result

        with patch("factory_tooling.decompose.metadata.project", side_effect=mutate_plan):
            with self.assertRaisesRegex(ValueError, "inputs changed"):
                apply(self.tasks_dir, self.source_lock, "drift-after-projection")
        self.assertEqual(draft, (self.tasks_dir / "generated" / task["filename"]).read_text())

    def test_empty_capability_ids_source_lock_is_rejected(self) -> None:
        _, messages = graph.load_source_lock(str(self.source_lock))

        self.assertTrue(any("capability_ids" in message for message in messages))

    def test_source_lock_records_verifiable_git_provenance_without_guessing_dirty_head(
        self,
    ) -> None:
        plan = self.root / "plan.md"
        content = (
            "### Acceptance criteria\n| ID | Applicability | Criterion | Verification |\n"
            "| --- | --- | --- | --- |\n| AC-01 | global | Outcome | Verify |\n"
        )
        plan.write_text(content)
        lock = {
            "plan_id": "orders-plan",
            "plan_revision": 2,
            "plan_hash": "sha256:" + hashlib.sha256(content.rstrip().encode()).hexdigest(),
            "plan_content_hash": "sha256:" + hashlib.sha256(plan.read_bytes()).hexdigest(),
            "plan_path": str(plan),
            "capability_ids": ["CAP-01"],
            "acceptance_ids": ["AC-01"],
        }
        self.source_lock.write_text(json.dumps(lock))
        self.assertEqual(graph.load_source_lock(self.source_lock)[1], [])  # no repository
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        subprocess.run(["git", "-C", str(self.root), "add", "plan.md"], check=True)
        subprocess.run(
            [
                "git",
                "-C",
                str(self.root),
                "-c",
                "user.name=Test",
                "-c",
                "user.email=test@example.org",
                "-c",
                "core.hooksPath=/dev/null",
                "-c",
                "commit.gpgsign=false",
                "commit",
                "-qm",
                "plan",
            ],
            check=True,
        )
        commit = subprocess.check_output(
            ["git", "-C", str(self.root), "rev-parse", "HEAD"], text=True
        ).strip()
        self.assertEqual(graph.load_source_lock(self.source_lock)[1], [])
        lock["plan_commit"] = commit
        self.source_lock.write_text(json.dumps(lock))
        self.assertEqual(graph.load_source_lock(self.source_lock)[1], [])
        plan.write_bytes(content.replace("\n", "\r\n").encode())
        lock["plan_content_hash"] = "sha256:" + hashlib.sha256(plan.read_bytes()).hexdigest()
        self.source_lock.write_text(json.dumps(lock))
        self.assertEqual(graph.load_source_lock(self.source_lock)[1], [])
        del lock["plan_commit"]
        self.source_lock.write_text(json.dumps(lock))
        self.assertEqual(graph.load_source_lock(self.source_lock)[1], [])
        lock["plan_commit"] = commit
        tree = subprocess.check_output(
            ["git", "-C", str(self.root), "rev-parse", "HEAD^{tree}"], text=True
        ).strip()
        lock["plan_commit"] = tree
        self.source_lock.write_text(json.dumps(lock))
        self.assertTrue(
            any(
                "does not identify a Git commit" in m
                for m in graph.load_source_lock(self.source_lock)[1]
            )
        )
        lock["plan_commit"] = "0" * 40
        self.source_lock.write_text(json.dumps(lock))
        self.assertTrue(
            any(
                "plan_commit does not identify" in m
                for m in graph.load_source_lock(self.source_lock)[1]
            )
        )
        changed = content + "\nUncommitted change.\n"
        plan.write_text(changed)
        lock["plan_hash"] = "sha256:" + hashlib.sha256(changed.rstrip().encode()).hexdigest()
        lock["plan_content_hash"] = "sha256:" + hashlib.sha256(plan.read_bytes()).hexdigest()
        lock["plan_commit"] = commit
        self.source_lock.write_text(json.dumps(lock))
        self.assertTrue(
            any(
                "plan_commit does not identify" in m
                for m in graph.load_source_lock(self.source_lock)[1]
            )
        )
        del lock["plan_commit"]
        self.source_lock.write_text(json.dumps(lock))
        self.assertEqual(graph.load_source_lock(self.source_lock)[1], [])

    def write_tasks(
        self,
        tasks: list[dict[str, Any]],
        markdown: str | dict[str, str] | None = None,
    ) -> dict[str, LoadedTask]:
        scope_dir = self.tasks_dir / "generated"
        scope_dir.mkdir(exist_ok=True)
        coverage = []
        total_min = 0.0
        total_max = 0.0
        purpose_labels: dict[str, Any] = {
            "functionality": "Functionality",
            "technical_preparation": "Technical preparation",
            "research": "Research",
        }
        for index, task in enumerate(tasks, start=1):
            capability_id = f"CAP-{index:02d}"
            task.setdefault("acceptance_ids", [f"AC-{index:02d}"])
            task_id = task.get("id")
            coverage.append(
                {
                    "capability_id": capability_id,
                    "task_ids": [task_id] if isinstance(task_id, str) and task_id else [],
                    "coverage": "complete",
                }
            )
            estimate = task.get("estimate")
            if isinstance(estimate, dict):
                min_hours = estimate.get("min_hours")
                max_hours = estimate.get("max_hours")
                if isinstance(min_hours, (int, float)) and not isinstance(min_hours, bool):
                    total_min += min_hours
                if isinstance(max_hours, (int, float)) and not isinstance(max_hours, bool):
                    total_max += max_hours

            filename = task.get("filename")
            if not isinstance(filename, str) or Path(filename).name != filename or "\\" in filename:
                continue
            if markdown is None:
                estimate_label = graph.normalize_estimate(task)[0]
                local = task.get("local_acceptance_criteria", [])
                local_table = ""
                if local:
                    local_table = (
                        "\n### Local acceptance criteria\n| ID | Applicability | Criterion | Verification |\n| --- | --- | --- | --- |\n"
                        + "\n".join(
                            f"| {c['id']} | {c['applies_to']} | {c['requirement']} | {c['verification']} |"
                            for c in local
                        )
                    )
                content = (
                    f"# {task.get('title', 'Task')}\n\n"
                    f"- **ID:** {task_id or '—'}\n"
                    "- **Plan source:** orders-plan, revision 2\n"
                    f"- **Covers capabilities:** {capability_id}\n"
                    f"- **Acceptance criteria:** {', '.join(task['acceptance_ids']) or '—'}\n"
                    f"- **Contribution to plan criteria:** {', '.join(task.get('contributes_to_acceptance_ids', [])) or '—'}\n"
                    f"- **Purpose:** {purpose_labels.get(str(task.get('purpose')), task.get('purpose', '—'))}\n"
                    f"- **Scope:** {task.get('scope', '—')}\n"
                    f"- **Estimate:** {estimate_label}\n" + local_table
                )
            elif isinstance(markdown, dict):
                content = markdown.get(str(task_id), "")
            else:
                content = markdown
            (scope_dir / filename).write_text(content, encoding="utf-8")

        ac_ids = sorted({cid for t in tasks for cid in t["acceptance_ids"]})
        plan_text = (
            "### Acceptance criteria\n| ID | Applicability | Criterion | Verification |\n| --- | --- | --- | --- |\n"
            + "\n".join(
                f"| {cid} | global | Visible outcome {cid} | Verify the outcome |" for cid in ac_ids
            )
        )
        plan_path = self.root / "plan.md"
        plan_path.write_text(plan_text, encoding="utf-8")
        plan_hash = "sha256:" + hashlib.sha256(plan_text.encode()).hexdigest()
        payload: dict[str, Any] = {
            "source_plan": {
                "plan_id": "orders-plan",
                "revision": 2,
                "hash": plan_hash,
            },
            "capability_coverage": coverage,
            "summary": "Order list tasks",
            "total_min_hours": total_min,
            "total_max_hours": total_max,
            "tasks": tasks,
        }
        self.source_lock.write_text(
            json.dumps(
                {
                    "plan_id": "orders-plan",
                    "plan_revision": 2,
                    "plan_hash": plan_hash,
                    "plan_content_hash": "sha256:"
                    + hashlib.sha256(plan_path.read_bytes()).hexdigest(),
                    "project_policy_sha256": graph.load_profile(
                        graph.configured_profile(FIXTURE_ROOT / "factory.yaml")
                    )["hash"],
                    "plan_path": str(plan_path),
                    "capability_ids": [item["capability_id"] for item in coverage],
                    "acceptance_ids": sorted({cid for t in tasks for cid in t["acceptance_ids"]}),
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        self.write_payload(payload)
        return graph.load_tasks(str(self.tasks_dir))["tasks"]

    def write_payload(self, payload: dict[str, Any]) -> None:
        scope_dir = self.tasks_dir / "generated"
        scope_dir.mkdir(exist_ok=True)
        (scope_dir / "task_result.json").write_text(
            json.dumps(payload, ensure_ascii=False), encoding="utf-8"
        )

    def run_cli(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--config",
                str(FIXTURE_ROOT / "factory.yaml"),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(self.root / "graph.md"),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

    @staticmethod
    def task(task_id: str = "orders-list-core-01", **overrides: Any) -> dict[str, Any]:
        sequence = task_id.rsplit("-", 1)[-1]
        slug = task_id.rsplit("-", 1)[0]
        task: dict[str, Any] = {
            "id": task_id,
            "filename": f"{sequence}-{slug}.md",
            "title": "Show order list",
            "purpose": "functionality",
            "scope": "orders_list",
            "outcome": "User sees the order list",
            "affected_layers": ["domain", "data", "presentation"],
            "contract_type": "backend_api",
            "implemented": ["loading", "loaded"],
            "deferred": [],
            "parent_task": None,
            "depends_on": [],
            "blocked_by": [],
            "estimate": {"min_hours": 6, "max_hours": 8, "confidence": "medium"},
        }
        task.update(overrides)
        return task

    def contributor_pair(self) -> tuple[dict[str, Any], dict[str, Any]]:
        producer = self.task(
            "orders-producer-01",
            acceptance_ids=[],
            contributes_to_acceptance_ids=["AC-01"],
            local_acceptance_criteria=[
                {
                    "id": "AC-01",
                    "applies_to": "global",
                    "requirement": "Bounded producer output",
                    "verification": "Observe producer output",
                }
            ],
        )
        closer = self.task(
            "orders-full-flow-02", acceptance_ids=["AC-01"], depends_on=["orders-producer-01"]
        )
        return producer, closer

    def test_functional_contributor_accepts_locally_before_dependent_full_closer(self) -> None:
        self.write_tasks(list(self.contributor_pair()))
        result = self.run_cli()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_functional_contributor_requires_local_acceptance(self) -> None:
        producer, closer = self.contributor_pair()
        producer["local_acceptance_criteria"] = []
        self.write_tasks([producer, closer])
        result = self.run_cli()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("acceptance criteria", result.stderr)

    def test_full_closer_must_await_all_functional_contributors(self) -> None:
        producer, closer = self.contributor_pair()
        closer["depends_on"] = []
        self.write_tasks([producer, closer])
        result = self.run_cli()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("closer must depend on all contributors", result.stderr)

    def test_contribution_cannot_replace_full_acceptance_closer(self) -> None:
        self.write_tasks(list(self.contributor_pair()))
        task_file = self.tasks_dir / "generated/task_result.json"
        payload = json.loads(task_file.read_text())
        closer = payload["tasks"][1]
        closer["acceptance_ids"] = []
        closer["contributes_to_acceptance_ids"] = ["AC-01"]
        closer["local_acceptance_criteria"] = payload["tasks"][0]["local_acceptance_criteria"]
        task_file.write_text(json.dumps(payload))
        result = self.run_cli()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Acceptance closer coverage", result.stderr)

    def test_local_acceptance_markdown_must_preserve_envelope_meaning(self) -> None:
        producer, closer = self.contributor_pair()
        self.write_tasks([producer, closer])
        markdown = self.tasks_dir / "generated" / producer["filename"]
        markdown.write_text(
            markdown.read_text().replace("Bounded producer output", "Different local output")
        )
        result = self.run_cli()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("Local acceptance Markdown differs", result.stderr)

    def test_source_lock_pins_exact_bytes_in_addition_to_normalized_hash(self) -> None:
        self.write_tasks([self.task()])
        lock = json.loads(self.source_lock.read_text())
        plan = Path(lock["plan_path"])
        plan.write_bytes(plan.read_bytes() + b"  ")
        _, messages = graph.load_source_lock(str(self.source_lock))
        self.assertTrue(any("plan_content_hash differs" in message for message in messages))

    def test_acceptance_missing_from_all_tasks_blocks(self) -> None:
        self.write_tasks([self.task()])
        file = self.tasks_dir / "generated/task_result.json"
        data = json.loads(file.read_text())
        data["tasks"][0]["acceptance_ids"] = []
        file.write_text(json.dumps(data))
        result = self.run_cli()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("acceptance", result.stdout.lower() + result.stderr.lower())

    def test_acceptance_source_lock_cannot_omit_plan_criterion(self) -> None:
        self.write_tasks([self.task()])
        source = json.loads(self.source_lock.read_text())
        source["acceptance_ids"] = ["AC-99"]
        self.source_lock.write_text(json.dumps(source))
        _, messages = graph.load_source_lock(str(self.source_lock))
        self.assertTrue(any("differs from plan" in message for message in messages))

    def test_acceptance_visible_handoff_cannot_drop_id(self) -> None:
        self.write_tasks([self.task()])
        file = next((self.tasks_dir / "generated").glob("*.md"))
        file.write_text(
            file.read_text().replace(
                "**Acceptance criteria:** AC-01", "**Acceptance criteria:** AC-99"
            )
        )
        result = self.run_cli()
        self.assertNotEqual(0, result.returncode)
        self.assertIn("AC-*", result.stdout + result.stderr)

    def test_explicit_scope_and_outcome_id_are_used(self) -> None:
        tasks = self.write_tasks([self.task()])

        task = tasks["orders-list-core-01"]
        self.assertEqual("orders_list", task["scope"])
        self.assertEqual("Show order list", task["name"])
        self.assertEqual(["domain", "data", "presentation"], task["affected_layers"])

    def test_all_three_purposes_are_supported(self) -> None:
        source = [
            self.task(f"orders-{purpose}-01", purpose=purpose, scope=purpose)
            for purpose in ("functionality", "technical_preparation", "research")
        ]
        tasks = self.write_tasks(source)

        self.assertEqual(
            {"functionality", "technical_preparation", "research"},
            {task["purpose"] for task in tasks.values()},
        )

    def test_unknown_purpose_is_reported_in_english(self) -> None:
        tasks = self.write_tasks([self.task(purpose="integration")])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("purpose: Input should be" in message for message in messages))

    def test_missing_purpose_is_reported(self) -> None:
        task = self.task()
        del task["purpose"]

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("purpose" in message.lower() for message in messages))

    def test_without_scope_does_not_infer_it_from_outcome_id(self) -> None:
        task = self.task()
        task.pop("scope")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertIsNone(tasks[task["id"]]["scope"])
        self.assertTrue(any("scope: Field required" in message for message in messages))

    def test_incomplete_task_is_rejected_without_graph(self) -> None:
        task: dict[str, Any] = {"id": "cart-ui-01", "title": "UI"}
        self.write_tasks([task])
        result = self.run_cli()
        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(any("Field required" in message for message in violations["violations"]))

    def test_unknown_fields_are_rejected_without_graph_or_projection(self) -> None:
        from factory_tooling.decompose.metadata import project

        for location in ("envelope", "task"):
            with self.subTest(location=location):
                task = self.task()
                if location == "task":
                    task["unexpected"] = 2
                self.write_tasks([task])
                payload_path = self.tasks_dir / "generated/task_result.json"
                payload = json.loads(payload_path.read_text())
                if location == "envelope":
                    payload["unexpected"] = 2
                    payload_path.write_text(json.dumps(payload))
                result = self.run_cli()
                self.assertEqual(1, result.returncode)
                violations = json.loads((self.root / "violations.json").read_text())
                self.assertTrue(
                    any(
                        "Extra inputs are not permitted" in item
                        for item in violations["violations"]
                    )
                )
                self.assertFalse((self.root / "graph.md").exists())
                with self.assertRaisesRegex(ValueError, "Extra inputs are not permitted"):
                    project(self.tasks_dir, self.source_lock)

    def test_empty_envelope_is_rejected_without_graph(self) -> None:
        self.write_payload({"tasks": []})
        result = self.run_cli()
        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(any("must not be empty" in message for message in violations["violations"]))

    def test_rejects_non_object_task_entry_without_graph(self) -> None:
        self.write_payload({"tasks": ["not-an-object"]})

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(any("object" in message for message in violations["violations"]))

    def test_unrecognized_old_payload_is_hard_rejected_without_graph(self) -> None:
        self.write_payload(
            {
                "primary_scope": "cart",
                "layer": "ui",
                "requires": [],
                "estimate_hours": 4,
            }
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(any("field tasks" in message for message in violations["violations"]))

    def test_missing_required_field_is_reported_with_cycle(self) -> None:
        task = self.task("orders-loop-01", depends_on=["orders-loop-01"])
        task.pop("outcome")
        self.write_tasks([task])
        result = self.run_cli()
        self.assertEqual(1, result.returncode)
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(violations["cycles"])
        self.assertTrue(any("outcome" in message for message in violations["violations"]))

    def test_mermaid_defines_only_current_purpose_classes(self) -> None:
        tasks = self.write_tasks([self.task("orders-list-core-01", affected_layers=["domain"])])

        mermaid = graph.generate_mermaid_graph(tasks)

        class_names = {
            line.strip().split()[1]
            for line in mermaid.splitlines()
            if line.strip().startswith("classDef ")
        }
        self.assertEqual(
            {"functionality", "technical_preparation", "research", "backend"},
            class_names,
        )

    def test_reports_missing_required_fields(self) -> None:
        task = self.task()
        for field in (
            "filename",
            "title",
            "outcome",
            "affected_layers",
            "contract_type",
            "implemented",
            "deferred",
            "parent_task",
            "depends_on",
            "blocked_by",
            "estimate",
        ):
            task.pop(field)
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        for field in (
            "filename",
            "title",
            "outcome",
            "implemented",
            "deferred",
            "parent_task",
            "depends_on",
            "blocked_by",
            "estimate",
        ):
            self.assertTrue(
                any(field in message and "Field required" in message for message in messages),
                field,
            )

    def test_functionality_reports_malformed_base_types(self) -> None:
        task = self.task(
            filename=[],
            title=0,
            scope=[],
            outcome=0,
            affected_layers="data",
            implemented={},
            deferred={},
            parent_task=1,
            depends_on="orders-base-00",
            blocked_by="API-1",
            estimate=[],
        )
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)
        combined = "\n".join(messages)

        for fragment in (
            "filename",
            "title",
            "scope",
            "outcome",
            "affected_layers:",
            "implemented:",
            "deferred:",
            "parent_task",
            "depends_on:",
            "blocked_by:",
            "estimate:",
        ):
            self.assertIn(fragment, combined)

    def test_cli_hard_fails_malformed_scope_without_graph(self) -> None:
        self.write_tasks([self.task(scope=[])])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(any("scope" in message for message in violations["violations"]))

    def test_cli_hard_fails_truthy_non_string_filename_without_graph(self) -> None:
        self.write_tasks([self.task(filename=1)])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertNotIn("No tasks found", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(any("filename" in message for message in violations["violations"]))

    def test_cli_hard_fails_task_without_id(self) -> None:
        task = self.task()
        task.pop("id")
        self.write_tasks([task])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertNotIn("No tasks found", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        violations = json.loads((self.root / "violations.json").read_text(encoding="utf-8"))
        self.assertTrue(
            any(
                "id" in message and "Field required" in message
                for message in violations["violations"]
            )
        )

    def test_project_prose_may_use_other_languages(self) -> None:
        # Factory headings are English; task titles and content remain project-owned.
        self.write_tasks([self.task(title="Список заказов", outcome="Пользователь видит заказы")])
        result = self.run_cli()
        self.assertEqual(0, result.returncode, result.stderr)
        rendered = (self.root / "graph.md").read_text(encoding="utf-8")
        self.assertIn("Список заказов", rendered)

    def test_cli_valid_envelope_passes_and_writes_graph(self) -> None:
        self.write_tasks([self.task()])

        result = self.run_cli()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Graph gate: PASS", result.stderr)
        self.assertTrue((self.root / "graph.md").is_file())
        self.assertFalse((self.root / "violations.json").exists())

    def test_cli_empty_staging_is_hard_failure(self) -> None:
        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("task_result.json", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_missing_dependency_is_hard_failure(self) -> None:
        self.write_tasks([self.task(depends_on=["orders-missing-99"])])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("missing task", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_invalid_contract_type_and_layer_are_hard_failure(self) -> None:
        self.write_tasks(
            [
                self.task(
                    contract_type="graphql",
                    affected_layers=["domain", "widgets"],
                )
            ]
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("contract_type", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_anistar_project_gate_rejects_unknown_layer(self) -> None:
        self.write_tasks([self.task(affected_layers=["widgets"])])
        result = self.run_cli()
        self.assertEqual(1, result.returncode)
        self.assertIn("anistar-task-metadata", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_anistar_project_gate_rejects_oversized_task(self) -> None:
        task = self.task()
        task["estimate"]["max_hours"] = 17
        self.write_tasks([task])
        result = self.run_cli()
        self.assertEqual(1, result.returncode)
        self.assertIn("anistar-task-metadata", result.stderr)

    def test_common_validator_does_not_require_project_layers(self) -> None:
        task = self.task(affected_layers=["custom-layer"])
        tasks = self.write_tasks([task])
        self.assertEqual([], graph.validate_dependencies(tasks))

    def test_cli_duplicate_task_id_is_hard_failure(self) -> None:
        self.write_tasks([self.task(), self.task()])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("ID is duplicated", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_duplicate_filename_is_hard_failure(self) -> None:
        shared_filename = "01-orders-shared.md"
        self.write_tasks(
            [
                self.task("orders-first-01", filename=shared_filename),
                self.task("orders-second-02", filename=shared_filename),
            ]
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("the same filename", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_missing_markdown_is_hard_failure(self) -> None:
        task = self.task()
        self.write_tasks([task])
        (self.tasks_dir / "generated" / task["filename"]).unlink()

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("Markdown-file", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_visible_markdown_identity_mismatch_is_hard_failure(self) -> None:
        task = self.task()
        self.write_tasks([task])
        markdown_path = self.tasks_dir / "generated" / task["filename"]
        content = markdown_path.read_text(encoding="utf-8")
        markdown_path.write_text(
            content.replace(task["id"], "orders-wrong-99", 1),
            encoding="utf-8",
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("visible ID", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_source_tuple_mismatch_is_hard_failure(self) -> None:
        self.write_tasks([self.task()])
        source = json.loads(self.source_lock.read_text(encoding="utf-8"))
        source["plan_revision"] += 1
        self.source_lock.write_text(json.dumps(source, ensure_ascii=False), encoding="utf-8")

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("source_plan does not match", result.stderr)

    def test_cli_capability_coverage_mismatch_is_hard_failure(self) -> None:
        self.write_tasks([self.task()])
        source = json.loads(self.source_lock.read_text(encoding="utf-8"))
        source["capability_ids"].append("CAP-99")
        self.source_lock.write_text(json.dumps(source, ensure_ascii=False), encoding="utf-8")

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("Capability coverage", result.stderr)

    def test_uses_depends_on_and_ignores_requires(self) -> None:
        base = self.task("orders-base-01", affected_layers=["domain"])
        explicit = self.task(
            "orders-explicit-03", depends_on=[base["id"]], requires=["ignored-task-99"]
        )
        tasks = self.write_tasks([base, explicit])

        self.assertEqual([base["id"]], tasks[explicit["id"]]["depends_on"])

    def test_filename_uses_task_sequence_as_prefix(self) -> None:
        task = self.task("orders-list-core-01", filename="orders-list-core-01.md")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("01-slug.md" in message for message in messages))

    def test_rejects_legacy_id_without_two_digit_sequence(self) -> None:
        task = self.task("orders-list-core-1", filename="1-orders-list-core.md")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("-NN" in message for message in messages))

    def test_core_estimates_have_no_project_hour_ceiling(self) -> None:
        source = [
            self.task(
                f"orders-size-{hours:02d}",
                scope=f"size_{hours}",
                affected_layers=["domain"],
                estimate={"min_hours": hours, "max_hours": hours, "confidence": "high"},
            )
            for hours in (8, 12, 16, 17)
        ]
        tasks = self.write_tasks(source)

        messages = graph.validate_dependencies(tasks)

        self.assertFalse(any("orders-size-08" in message for message in messages))
        self.assertFalse(any("orders-size-12" in message for message in messages))
        self.assertFalse(any("orders-size-16" in message for message in messages))
        self.assertEqual([], messages)  # AniStar ceiling is covered by project-gate CLI tests.

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())

    def test_string_estimate_is_not_parsed(self) -> None:
        task = self.task(estimate="6–8 h")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertEqual(0, tasks[task["id"]]["estimate_max_hours"])
        self.assertTrue(any("estimate:" in message for message in messages))

    def test_estimate_validates_order_numbers_but_confidence_is_optional(self) -> None:
        reversed_range = self.task(
            "orders-estimate-reversed-01",
            estimate={"min_hours": 20, "max_hours": 8, "confidence": "medium"},
        )
        negative = self.task(
            "orders-estimate-negative-02",
            estimate={"min_hours": -1, "max_hours": 2, "confidence": "high"},
        )
        nonnumeric = self.task(
            "orders-estimate-text-03",
            estimate={"min_hours": "one", "max_hours": 2, "confidence": "low"},
        )
        missing_confidence = self.task(
            "orders-estimate-confidence-04",
            estimate={"min_hours": 1, "max_hours": 2},
        )
        tasks = self.write_tasks([reversed_range, negative, nonnumeric, missing_confidence])

        messages = graph.validate_dependencies(tasks)
        combined = "\n".join(messages)

        self.assertIn("orders-estimate-reversed-01", combined)
        self.assertIn("min_hours cannot exceed max_hours", combined)
        self.assertIn("orders-estimate-negative-02", combined)
        self.assertIn("estimate.min_hours", combined)
        self.assertIn("orders-estimate-text-03", combined)
        self.assertIn("valid number", combined)
        self.assertFalse(any("orders-estimate-confidence-04" in message for message in messages))

    def test_technical_preparation_requires_valid_existing_consumers(self) -> None:
        consumer = self.task("orders-consumer-01")
        empty = self.task(
            "orders-tech-empty-02",
            purpose="technical_preparation",
            consumers=[],
        )
        missing = self.task(
            "orders-tech-missing-03",
            purpose="technical_preparation",
            consumers=["orders-missing-99"],
        )
        valid = self.task(
            "orders-tech-valid-04",
            purpose="technical_preparation",
            consumers=[consumer["id"]],
        )
        tasks = self.write_tasks([consumer, empty, missing, valid])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(
            any(empty["id"] in message and "consumers" in message for message in messages)
        )
        self.assertTrue(
            any(missing["id"] in message and "orders-missing-99" in message for message in messages)
        )
        self.assertFalse(
            any(valid["id"] in message and "consumers" in message for message in messages)
        )

    def test_research_requires_question_positive_timebox_and_expected_result(self) -> None:
        invalid = self.task(
            "orders-research-invalid-01",
            purpose="research",
            research_question="",
            timebox_hours=0,
            expected_result=None,
        )
        valid = self.task(
            "orders-research-valid-02",
            purpose="research",
            research_question="How to update reliably offset?",
            timebox_hours=4,
            expected_result="Recorded decision and prototype",
        )
        tasks = self.write_tasks([invalid, valid])

        messages = graph.validate_dependencies(tasks)
        combined = "\n".join(messages)

        for field in ("research_question", "timebox_hours", "expected_result"):
            self.assertIn(invalid["id"], combined)
            self.assertIn(field, combined)
            self.assertFalse(
                any(valid["id"] in message and field in message for message in messages)
            )

    def test_functionality_does_not_require_conditional_fields(self) -> None:
        task = self.task("orders-functionality-valid-01")
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        for field in ("consumers", "research_question", "timebox_hours", "expected_result"):
            self.assertFalse(
                any(task["id"] in message and field in message for message in messages)
            )

    def test_data_layer_does_not_imply_backend_api_grounding(self) -> None:
        task = self.task(affected_layers=["data", "presentation"])
        tasks = self.write_tasks([task], markdown="No contract information")

        messages = graph.validate_dependencies(tasks)

        self.assertFalse(any("API" in message and task["id"] in message for message in messages))

    def test_deferred_completed_by_must_reference_existing_task(self) -> None:
        task = self.task(
            deferred=[
                {
                    "behavior": "error_and_retry",
                    "completed_by": "orders-missing-02",
                    "temporary_behavior": "generic_error",
                }
            ]
        )
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(
            any(
                "orders-missing-02" in message and "deferred" in message.lower()
                for message in messages
            )
        )

    def test_deferred_completed_by_accepts_existing_task(self) -> None:
        followup = self.task("orders-error-retry-02", affected_layers=["presentation"])
        task = self.task(
            deferred=[
                {
                    "behavior": "error_and_retry",
                    "completed_by": followup["id"],
                    "temporary_behavior": "generic_error",
                }
            ]
        )
        tasks = self.write_tasks([task, followup])

        messages = graph.validate_dependencies(tasks)

        self.assertFalse(any("deferred" in message.lower() for message in messages))

    def test_deferred_cannot_be_completed_by_same_task(self) -> None:
        task = self.task()
        task["deferred"] = [
            {
                "behavior": "error_and_retry",
                "completed_by": task["id"],
                "temporary_behavior": "generic_error",
            }
        ]
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("cannot be closed by the same task" in message for message in messages))

    def test_deferred_cycle_is_hard_blocked(self) -> None:
        first = self.task("orders-first-01")
        second = self.task("orders-second-02")
        first["deferred"] = [
            {
                "behavior": "second_behavior",
                "completed_by": second["id"],
                "temporary_behavior": "generic_error",
            }
        ]
        second["deferred"] = [
            {
                "behavior": "first_behavior",
                "completed_by": first["id"],
                "temporary_behavior": "generic_error",
            }
        ]
        self.write_tasks([first, second])
        tasks = graph.load_tasks(str(self.tasks_dir))["tasks"]

        self.assertTrue(graph.check_deferred_cycles(tasks))

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("deferred behavior cycle", result.stderr.lower())

    def test_falsy_invalid_deferred_values_are_not_masked(self) -> None:
        source = [
            self.task("orders-deferred-dict-01", deferred={}),
            self.task("orders-deferred-string-02", deferred=""),
            self.task("orders-deferred-zero-03", deferred=0),
        ]
        tasks = self.write_tasks(source)

        messages = graph.validate_dependencies(tasks)

        for task in source:
            self.assertTrue(
                any(task["id"] in message and "deferred:" in message for message in messages)
            )

    def test_missing_and_null_deferred_are_invalid(self) -> None:
        missing = self.task("orders-deferred-missing-01")
        missing.pop("deferred")
        explicit_none = self.task("orders-deferred-none-02", deferred=None)
        tasks = self.write_tasks([missing, explicit_none])

        errors = "\n".join(graph.validate_dependencies(tasks))
        self.assertIn(f"{missing['id']}': deferred: Field required", errors)
        self.assertIn(f"{explicit_none['id']}': deferred: Input should be a valid list", errors)

    def test_dependency_cycle_is_detected(self) -> None:
        first = self.task("orders-first-01", depends_on=["orders-second-02"])
        second = self.task("orders-second-02", depends_on=["orders-first-01"])
        tasks = self.write_tasks([first, second])

        self.assertTrue(graph.check_circular_dependencies(tasks))

    def test_parent_task_must_reference_existing_task(self) -> None:
        task = self.task(parent_task="orders-missing-parent-00")
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(
            any(
                "parent task" in message.lower() and "orders-missing-parent-00" in message
                for message in messages
            )
        )

    def test_parent_task_cycle_is_detected_separately(self) -> None:
        first = self.task("orders-first-01", parent_task="orders-second-02")
        second = self.task("orders-second-02", parent_task="orders-first-01")
        tasks = self.write_tasks([first, second])

        self.assertEqual([], graph.check_circular_dependencies(tasks))
        self.assertTrue(graph.check_parent_task_cycles(tasks))

    def test_mixed_dependency_and_parent_cycle_is_hard_blocked(self) -> None:
        first = self.task("orders-first-01", depends_on=["orders-second-02"])
        second = self.task("orders-second-02", parent_task="orders-first-01")
        tasks = self.write_tasks([first, second])

        self.assertEqual([], graph.check_circular_dependencies(tasks))
        self.assertEqual([], graph.check_parent_task_cycles(tasks))
        self.assertTrue(graph.check_mixed_relation_cycles(tasks))

    def test_same_relation_pair_prefers_hard_dependency_once(self) -> None:
        parent = self.task("orders-parent-01")
        child = self.task(
            "orders-child-02",
            depends_on=[parent["id"]],
            parent_task=parent["id"],
        )
        tasks = self.write_tasks([parent, child])

        relations = graph.build_relation_graph(tasks)

        self.assertEqual([(parent["id"], "depends_on")], relations[child["id"]])

    def test_local_blocker_is_relation_and_uses_task_alias_in_mermaid(self) -> None:
        blocker = self.task("orders-blocker-01")
        target = self.task("orders-target-02", blocked_by=[blocker["id"]])
        tasks = self.write_tasks([blocker, target])

        relations = graph.build_relation_graph(tasks)
        mermaid = graph.generate_mermaid_graph(tasks)

        self.assertEqual([(blocker["id"], "blocked_by")], relations[target["id"]])
        self.assertIn('task_000 -. "blocks" .-> task_001', mermaid)
        self.assertNotIn("blocker_000", mermaid)

    def test_local_blocker_duplicate_pair_prefers_hard_dependency(self) -> None:
        blocker = self.task("orders-blocker-01")
        target = self.task(
            "orders-target-02",
            depends_on=[blocker["id"]],
            blocked_by=[blocker["id"]],
        )
        tasks = self.write_tasks([blocker, target])

        relations = graph.build_relation_graph(tasks)
        mermaid = graph.generate_mermaid_graph(tasks)

        self.assertEqual([(blocker["id"], "depends_on")], relations[target["id"]])
        self.assertEqual(1, mermaid.count("task_000 --> task_001"))
        self.assertNotIn("blocks", mermaid)

    def test_local_blocker_mixed_cycle_is_hard_blocked_with_russian_diagnostic(self) -> None:
        first = self.task(
            "orders-first-01",
            blocked_by=["orders-second-02"],
        )
        second = self.task(
            "orders-second-02",
            depends_on=[first["id"]],
        )
        self.write_tasks([first, second])
        tasks = graph.load_tasks(str(self.tasks_dir))["tasks"]

        self.assertTrue(graph.check_mixed_relation_cycles(tasks))

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--config",
                str(FIXTURE_ROOT / "factory.yaml"),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(self.root / "graph.md"),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(1, result.returncode)
        self.assertIn("mixed cycle", result.stderr.lower())

    def test_mixed_cycle_cli_diagnostic_is_russian(self) -> None:
        first = self.task("orders-first-01", depends_on=["orders-second-02"])
        second = self.task("orders-second-02", parent_task="orders-first-01")
        self.write_tasks([first, second])
        output = self.root / "graph.md"

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--config",
                str(FIXTURE_ROOT / "factory.yaml"),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(output),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("mixed cycle", result.stderr.lower())

    def test_parent_task_cycle_cli_diagnostic_is_russian(self) -> None:
        first = self.task("orders-first-01", parent_task="orders-second-02")
        second = self.task("orders-second-02", parent_task="orders-first-01")
        self.write_tasks([first, second])
        output = self.root / "graph.md"

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--config",
                str(FIXTURE_ROOT / "factory.yaml"),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(output),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("branch stack cycle", result.stderr.lower())

    def test_cycle_cli_diagnostic_is_russian(self) -> None:
        first = self.task("orders-first-01", depends_on=["orders-second-02"])
        second = self.task("orders-second-02", depends_on=["orders-first-01"])
        self.write_tasks([first, second])
        output = self.root / "graph.md"

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--config",
                str(FIXTURE_ROOT / "factory.yaml"),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(output),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("dependency cycle", result.stderr.lower())

    def test_mermaid_uses_ascii_purpose_classes(self) -> None:
        source = [
            self.task(f"orders-{purpose}-01", purpose=purpose, scope=purpose)
            for purpose in ("functionality", "technical_preparation", "research")
        ]
        tasks = self.write_tasks(source)

        mermaid = graph.generate_mermaid_graph(tasks)

        for class_name in ("functionality", "technical_preparation", "research"):
            self.assertIn(f"classDef {class_name}", mermaid)
            self.assertIn(f" {class_name};", mermaid)

    def test_mermaid_uses_deterministic_safe_aliases(self) -> None:
        unsafe_id = 'orders/list "core"-01'
        unsafe_scope = 'orders/list "scope"'
        blocker = 'API/BLOCK "1"-x'
        task = self.task(
            unsafe_id,
            scope=unsafe_scope,
            affected_layers=["domain"],
            blocked_by=[blocker],
        )
        tasks = self.write_tasks([task])

        mermaid = graph.generate_mermaid_graph(tasks)
        reversed_mermaid = graph.generate_mermaid_graph(dict(reversed(list(tasks.items()))))

        self.assertEqual(mermaid, reversed_mermaid)
        self.assertIn("subgraph scope_000", mermaid)
        self.assertIn("task_000[", mermaid)
        self.assertIn("blocker_000[", mermaid)
        self.assertNotIn(f"subgraph {unsafe_scope}", mermaid)
        self.assertNotIn(f"class {unsafe_id}", mermaid)
        self.assertNotIn(f"{blocker}[", mermaid)
        self.assertIn("orders/list &quot;core&quot;-01", mermaid)
        self.assertIn("Scope: orders/list &quot;scope&quot;", mermaid)
        self.assertIn("Blocker: API/BLOCK &quot;1&quot;-x", mermaid)

    def test_mermaid_renders_parent_edge_without_hard_dependency_duplicate(self) -> None:
        parent = self.task("orders-base-01", affected_layers=["domain"])
        stacked = self.task(
            "orders-stacked-02",
            affected_layers=["presentation"],
            parent_task=parent["id"],
        )
        tasks = self.write_tasks([parent, stacked])
        mermaid = graph.generate_mermaid_graph(tasks)
        self.assertIn('task_000 -. "branch stack" .-> task_001', mermaid)

        stacked["depends_on"] = [parent["id"]]
        tasks = self.write_tasks([parent, stacked])
        mermaid = graph.generate_mermaid_graph(tasks)
        self.assertIn("task_000 --> task_001", mermaid)
        self.assertNotIn("branch stack", mermaid)


if __name__ == "__main__":
    unittest.main()
