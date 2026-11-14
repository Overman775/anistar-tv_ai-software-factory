from __future__ import annotations

import hashlib
import json
import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Any

from factory.decompose import generate_task_graph as graph
from factory.decompose.contracts import LoadedTask
from tests.fixture_bundle import ROOT as FIXTURE_ROOT


class TaskGraphFixture:
    def __init__(self, add_cleanup: Callable[[Callable[[], object]], object]) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        add_cleanup(self.temp_dir.cleanup)
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
