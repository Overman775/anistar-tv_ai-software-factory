from __future__ import annotations

import argparse

#!/usr/bin/env python3
import os
import sys
from pathlib import Path

from factory.decompose.output_safety import (
    atomic_write_text,
    guard_output,
    protected_inputs,
)
from factory.decompose.task_data import CAPABILITY_ID_RE as CAPABILITY_ID_RE
from factory.decompose.task_data import SCOPE_RE as SCOPE_RE
from factory.decompose.task_data import TASK_FILENAME_RE as TASK_FILENAME_RE
from factory.decompose.task_data import TASK_ID_SEQUENCE_RE as TASK_ID_SEQUENCE_RE
from factory.decompose.task_data import VALID_CONTRACT_TYPES as VALID_CONTRACT_TYPES
from factory.decompose.task_data import VALID_COVERAGE as VALID_COVERAGE
from factory.decompose.task_data import VALID_PURPOSES as VALID_PURPOSES
from factory.decompose.task_data import _as_list as _as_list
from factory.decompose.task_data import _format_hours as _format_hours

# Compatibility exports: existing imports and command entry points stay valid.
from factory.decompose.task_data import _graph_scope as _graph_scope
from factory.decompose.task_data import _is_nonempty_text as _is_nonempty_text
from factory.decompose.task_data import _is_number as _is_number
from factory.decompose.task_data import _relation_ids as _relation_ids
from factory.decompose.task_data import find_markdown_file as find_markdown_file
from factory.decompose.task_data import load_source_lock as load_source_lock
from factory.decompose.task_data import load_tasks as load_tasks
from factory.decompose.task_data import normalize_estimate as normalize_estimate
from factory.decompose.task_relations import build_relation_graph as build_relation_graph
from factory.decompose.task_relations import (
    check_circular_dependencies as check_circular_dependencies,
)
from factory.decompose.task_relations import check_deferred_cycles as check_deferred_cycles
from factory.decompose.task_relations import (
    check_mixed_relation_cycles as check_mixed_relation_cycles,
)
from factory.decompose.task_relations import (
    check_parent_task_cycles as check_parent_task_cycles,
)
from factory.decompose.task_render import _aliases as _aliases
from factory.decompose.task_render import _ensure_directory as _ensure_directory
from factory.decompose.task_render import _escape_mermaid_label as _escape_mermaid_label
from factory.decompose.task_render import _write_violations_json as _write_violations_json
from factory.decompose.task_render import generate_mermaid_graph as generate_mermaid_graph
from factory.decompose.task_validation import _markdown_field as _markdown_field
from factory.decompose.task_validation import _plain_markdown_value as _plain_markdown_value
from factory.decompose.task_validation import _validate_task as _validate_task
from factory.decompose.task_validation import validate_dependencies as validate_dependencies
from factory.decompose.task_validation import validate_envelopes as validate_envelopes
from factory.decompose.task_validation import (
    validate_markdown_files as validate_markdown_files,
)
from factory.paths import FACTORY_ROOT as FACTORY_ROOT
from factory.project.profile_io import load_profile as load_profile
from factory.project.project import configured_profile as configured_profile
from factory.project.skill_gates import run_decomposition_gates as run_decomposition_gates
from factory.tasks.criteria import criteria_map as criteria_map
from factory.tasks.criteria import plan_criteria as plan_criteria


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate task JSON and build a Mermaid-dependency graph."
    )
    parser.add_argument("--config", default=str(FACTORY_ROOT / "factory.yaml"))
    parser.add_argument(
        "--staging-dir",
        default=".factory/memory/staging/tasks",
        help="Directory containing prepared tasks.",
    )
    parser.add_argument(
        "--output",
        default=".factory/memory/staging/mermaid_graph.txt",
        help="File for the Mermaid-block.",
    )
    parser.add_argument(
        "--source-lock",
        default=".factory/memory/staging/decomposition-source.json",
        help="Locked decomposition source.",
    )
    parser.add_argument(
        "--core-only",
        action="store_true",
        help="Core preflight only; never authorizes final assembly",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    policy = load_profile(configured_profile(args.config))
    output_dir = os.path.dirname(args.output)
    protected = protected_inputs(args.config, args.staging_dir, args.source_lock, policy)
    output_path = Path(args.output)
    outputs = [
        output_path,
        Path(output_dir or ".") / "violations.json",
        Path(output_dir or ".") / "dependency_violations.md",
        Path(output_dir or ".") / "decomposition-gates.json",
    ]
    if len({p.resolve() for p in outputs}) != len(outputs):
        raise ValueError("Graph and diagnostics must use distinct paths")
    for candidate in outputs:
        guard_output(candidate, protected)
        if candidate.is_symlink() or (candidate.is_file() and candidate.stat().st_nlink != 1):
            raise ValueError("Graph output must not use a symlink or hardlink")
    loaded = load_tasks(args.staging_dir)
    tasks, envelopes, load_violations = loaded["tasks"], loaded["envelopes"], loaded["errors"]
    source_lock, source_lock_violations = load_source_lock(args.source_lock)

    if source_lock is not None and source_lock.get("project_policy_sha256") != policy["hash"]:
        source_lock_violations.append("Project policy drift/missing baseline: re-intake required")

    scope_count = len({_graph_scope(task) for task in tasks.values()})
    print(f"Tasks loaded: {len(tasks)}; scopes: {scope_count}.", file=sys.stderr)

    messages = (
        load_violations
        + source_lock_violations
        + validate_dependencies(tasks)
        + validate_envelopes(envelopes, tasks, source_lock)
        + validate_markdown_files(tasks, envelopes)
    )
    dependency_cycles = check_circular_dependencies(tasks)
    parent_task_cycles = check_parent_task_cycles(tasks)
    deferred_cycles = check_deferred_cycles(tasks)
    mixed_relation_cycles = check_mixed_relation_cycles(tasks)
    has_cycles = bool(
        dependency_cycles or parent_task_cycles or deferred_cycles or mixed_relation_cycles
    )
    if not messages and not has_cycles and not args.core_only:
        messages.extend(
            run_decomposition_gates(
                policy, tasks, envelopes, args.staging_dir, args.source_lock, output_dir or "."
            )
        )
    if messages or has_cycles:
        if dependency_cycles:
            print("🚨 Task dependency cycle detected.", file=sys.stderr)
        for cycle in dependency_cycles:
            print(f"  Cycle: {cycle}", file=sys.stderr)
        if parent_task_cycles:
            print("🚨 Branch stack cycle detected parent_task.", file=sys.stderr)
        for cycle in parent_task_cycles:
            print(f"  Stack cycle: {cycle}", file=sys.stderr)
        if deferred_cycles:
            print("🚨 Deferred behavior cycle detected.", file=sys.stderr)
        for cycle in deferred_cycles:
            print(f"  Cycle deferred: {cycle}", file=sys.stderr)
        if mixed_relation_cycles:
            print(
                "🚨 Mixed dependency and branch stack cycle detected.",
                file=sys.stderr,
            )
        for cycle in mixed_relation_cycles:
            print(f"  Mixed cycle: {cycle}", file=sys.stderr)
        for message in messages:
            print(f"  - {message}", file=sys.stderr)
        _write_violations_json(
            output_dir,
            messages,
            dependency_cycles,
            parent_task_cycles,
            deferred_cycles,
            mixed_relation_cycles,
        )
        violations_md_file = os.path.join(output_dir, "dependency_violations.md")
        _ensure_directory(output_dir)
        lines = ["# Decomposition violations\n\n"]
        lines.extend(f"- {message}\n" for message in messages)
        lines.extend(f"- 🚨 Cycle depends_on: {cycle}\n" for cycle in dependency_cycles)
        lines.extend(f"- 🚨 Cycle parent_task: {cycle}\n" for cycle in parent_task_cycles)
        lines.extend(f"- 🚨 Cycle deferred: {cycle}\n" for cycle in deferred_cycles)
        lines.extend(f"- 🚨 Mixed cycle: {cycle}\n" for cycle in mixed_relation_cycles)
        atomic_write_text(violations_md_file, "".join(lines))
        if os.path.exists(args.output):
            os.remove(args.output)
        print(
            "🚨 Graph gate: FAIL. Graph and final assembly blocked.",
            file=sys.stderr,
        )
        sys.exit(1)

    violations_file = os.path.join(output_dir, "violations.json")
    violations_md_file = os.path.join(output_dir, "dependency_violations.md")
    for stale_file in (violations_file, violations_md_file):
        if os.path.exists(stale_file):
            os.remove(stale_file)

    mermaid_block = generate_mermaid_graph(tasks)
    _ensure_directory(output_dir)
    atomic_write_text(args.output, mermaid_block)
    print(f"Graph gate: PASS. Graph written to {args.output}.", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as exc:
        print(f"BLOCKED: {exc}", file=sys.stderr)
        sys.exit(2)
