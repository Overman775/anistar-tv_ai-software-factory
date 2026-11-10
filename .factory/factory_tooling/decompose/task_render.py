"""Mermaid rendering and decomposition violation artifacts."""

from __future__ import annotations

import html
import json
import os
from collections.abc import Iterable
from pathlib import Path

from factory_tooling.decompose.contracts import LoadedTask
from factory_tooling.decompose.output_safety import atomic_write_text
from factory_tooling.decompose.task_data import (
    VALID_PURPOSES,
    _graph_scope,
    _relation_ids,
)
from factory_tooling.decompose.task_relations import (
    build_relation_graph,
)


def _escape_mermaid_label(value: object) -> str:
    text = str(value).replace("\r", " ").replace("\n", " ")
    return html.escape(text, quote=True)


def _aliases(values: Iterable[str], prefix: str) -> dict[str, str]:
    return {
        value: f"{prefix}_{index:03d}"
        for index, value in enumerate(sorted(values, key=lambda item: str(item)))
    }


def generate_mermaid_graph(tasks: dict[str, LoadedTask]) -> str:
    lines = ["```mermaid", "flowchart TD", "  %% Task purpose styles"]
    lines.append("  classDef functionality fill:#bbf,stroke:#333,stroke-width:1px;")
    lines.append("  classDef technical_preparation fill:#6f9,stroke:#333,stroke-width:1px;")
    lines.append("  classDef research fill:#f9f,stroke:#333,stroke-width:1px;")
    lines.append("  classDef backend fill:#ff9,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5;")

    task_aliases = _aliases(tasks.keys(), "task")
    scopes = {_graph_scope(task) for task in tasks.values()}
    scope_aliases = _aliases(scopes, "scope")
    blocker_ids = {
        blocker_id
        for task in tasks.values()
        for blocker_id in _relation_ids(task.get("blocked_by"))
        if (blocker_id and blocker_id != "[TBD_BACKEND]" and blocker_id not in tasks)
    }
    blocker_aliases = _aliases(blocker_ids, "blocker")

    for scope in sorted(scopes, key=lambda item: str(item)):
        lines.append(
            f'\n  subgraph {scope_aliases[scope]} ["Scope: {_escape_mermaid_label(scope)}"]'
        )
        scope_tasks = sorted(
            (task for task in tasks.values() if _graph_scope(task) == scope),
            key=lambda task: str(task["id"]),
        )
        for task in scope_tasks:
            clean_name = str(task["name"])
            if len(clean_name) > 30:
                clean_name = clean_name[:27] + "..."
            label = (
                f"{_escape_mermaid_label(task['id'])}<br/>"
                f"{_escape_mermaid_label(clean_name)} "
                f"({_escape_mermaid_label(task['estimate'])})"
            )
            lines.append(f'    {task_aliases[task["id"]]}["{label}"]')
        lines.append("  end")

    lines.append("")
    for task_id in sorted(tasks, key=str):
        task = tasks[task_id]
        purpose = task.get("purpose")
        if isinstance(purpose, str) and purpose in VALID_PURPOSES:
            lines.append(f"  class {task_aliases[task_id]} {purpose};")

    lines.append("\n  %% Task dependencies")
    relations = build_relation_graph(tasks)
    for task_id in sorted(tasks, key=str):
        task_alias = task_aliases[task_id]
        for related_id, relation_type in relations[task_id]:
            related_alias = task_aliases[related_id]
            if relation_type == "depends_on":
                lines.append(f"  {related_alias} --> {task_alias}")
            elif relation_type == "parent_task":
                lines.append(f'  {related_alias} -. "branch stack" .-> {task_alias}')
            else:
                lines.append(f'  {related_alias} -. "blocks" .-> {task_alias}')

    for blocker_id in sorted(blocker_ids, key=str):
        blocker_alias = blocker_aliases[blocker_id]
        blocker_label = _escape_mermaid_label(blocker_id)
        lines.append(f'  {blocker_alias}["Blocker: {blocker_label}"]')
        lines.append(f"  class {blocker_alias} backend;")

    for task_id in sorted(tasks, key=str):
        task_alias = task_aliases[task_id]
        for blocker_id in sorted(_relation_ids(tasks[task_id].get("blocked_by")), key=str):
            if blocker_id in blocker_aliases:
                lines.append(f"  {blocker_aliases[blocker_id]} -.-> {task_alias}")

    lines.append("```")
    return "\n".join(lines)


def _ensure_directory(path: str | Path) -> None:
    if path:
        os.makedirs(path, exist_ok=True)


def _write_violations_json(
    output_dir: str | Path,
    messages: list[str],
    dependency_cycles: list[str] | None = None,
    parent_task_cycles: list[str] | None = None,
    deferred_cycles: list[str] | None = None,
    mixed_relation_cycles: list[str] | None = None,
) -> None:
    _ensure_directory(output_dir)
    violations_file = os.path.join(output_dir, "violations.json")
    atomic_write_text(
        violations_file,
        json.dumps(
            {
                "cycles": dependency_cycles or [],
                "parent_task_cycles": parent_task_cycles or [],
                "deferred_cycles": deferred_cycles or [],
                "mixed_relation_cycles": mixed_relation_cycles or [],
                "violations": messages,
            },
            indent=2,
            ensure_ascii=False,
        ),
    )
