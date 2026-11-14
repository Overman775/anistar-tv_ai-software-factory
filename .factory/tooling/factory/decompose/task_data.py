"""Task document loading, source locks and normalized task vocabulary."""

from __future__ import annotations

import glob
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from typing import TypeGuard

from pydantic import TypeAdapter, ValidationError

from factory.decompose.contracts import (
    Envelope,
    Estimate,
    LoadedTask,
    LoadResult,
    RawTask,
    SourceLock,
    TaskEnvelope,
)
from factory.tasks.criteria import criteria_map as criteria_map
from factory.tasks.criteria import plan_criteria
from factory.validation import validation_message

TASK_ENVELOPE = TypeAdapter[TaskEnvelope](TaskEnvelope)
TASK_RECORD = TypeAdapter[RawTask](RawTask)
ESTIMATE = TypeAdapter[Estimate](Estimate)
SOURCE_LOCK = TypeAdapter[SourceLock](SourceLock)

PURPOSE_LABELS = {
    "functionality": "Functionality",
    "technical_preparation": "Technical preparation",
    "research": "Research",
}
VALID_PURPOSES = set(PURPOSE_LABELS)


VALID_CONTRACT_TYPES = {
    "backend_api",
    "platform_plugin_api",
    "storage",
    "local_contract",
    "external_contract",
    "none",
}


VALID_COVERAGE = {"complete", "external", "out_of_scope"}


CAPABILITY_ID_RE = re.compile(r"^CAP-\d{2,}$")


SCOPE_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")


TASK_ID_SEQUENCE_RE = re.compile(r"-(\d{2})$")


TASK_FILENAME_RE = re.compile(r"^(\d{2})-[a-z0-9][a-z0-9_-]*\.md$")


def capabilities_by_task(
    tasks: dict[str, LoadedTask], envelopes: list[Envelope]
) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {task_id: set() for task_id in tasks}
    for envelope in envelopes:
        coverage = envelope.get("capability_coverage")
        if not isinstance(coverage, list):
            continue
        for item in coverage:
            if not isinstance(item, dict) or item.get("coverage") != "complete":
                continue
            capability = item.get("capability_id")
            ids = item.get("task_ids")
            if not _is_nonempty_text(capability) or not isinstance(ids, list):
                continue
            for task_id in ids:
                if isinstance(task_id, str) and task_id in result:
                    result[task_id].add(capability)
    return result


def _as_list(value: object) -> list[object]:
    return value if isinstance(value, list) else []


def _relation_ids(value: object) -> list[str]:
    return [item for item in _as_list(value) if _is_nonempty_text(item)]


def _graph_scope(task: LoadedTask) -> str:
    scope = task.get("scope")
    return scope.strip() if _is_nonempty_text(scope) else "unspecified"


def _format_hours(value: float | None) -> str:
    if value is None:
        return "0"
    return str(int(value)) if float(value).is_integer() else str(value).rstrip("0").rstrip(".")


def normalize_estimate(task: dict[str, object]) -> tuple[str, float, float]:
    try:
        estimate = ESTIMATE.validate_python(task.get("estimate"))
        min_hours, max_hours = float(estimate["min_hours"]), float(estimate["max_hours"])
    except ValidationError:
        min_hours = max_hours = 0.0
    if min_hours == max_hours:
        label = f"{_format_hours(max_hours)} h"
    else:
        label = f"{_format_hours(min_hours)}–{_format_hours(max_hours)} h"
    return label, min_hours, max_hours


def find_markdown_file(task: dict[str, object] | LoadedTask, json_filepath: str) -> str | None:
    task_dir = os.path.dirname(json_filepath)
    filename = task.get("filename")
    if _is_nonempty_text(filename):
        candidate = os.path.join(task_dir, filename)
        if os.path.isfile(candidate):
            return candidate
    return None


def load_tasks(staging_dir: str | Path) -> LoadResult:
    """Return tasks, envelopes and load errors in one fixed result shape."""
    all_tasks: dict[str, LoadedTask] = {}
    envelopes: list[Envelope] = []
    load_violations = []
    task_files = sorted(
        glob.glob(os.path.join(staging_dir, "**", "task_result.json"), recursive=True)
    )
    if not task_files:
        load_violations.append("🚨 No strict envelope '**/task_result.json' found.")

    for filepath in task_files:
        relative_file = os.path.relpath(filepath, staging_dir)
        try:
            with open(filepath, encoding="utf-8") as file:
                data = json.load(file)
            if not isinstance(data, dict):
                load_violations.append(f"🚨 File '{relative_file}': envelope must be an object.")
                continue
            try:
                TASK_ENVELOPE.validate_python(data)
            except ValidationError as error:
                load_violations.append(
                    validation_message(f"File '{relative_file}'", error, TASK_ENVELOPE)
                )
            # Keep partial identities and links to diagnose graph errors in the same run.
            tasks_list = data.get("tasks")
            if not isinstance(tasks_list, list):
                load_violations.append(f"🚨 File '{relative_file}': field tasks must be a list.")
                continue
            if not tasks_list:
                load_violations.append(f"🚨 File '{relative_file}': field tasks must not be empty.")
            envelopes.append(
                {
                    "file": filepath,
                    "relative_file": relative_file,
                    "source_plan": data.get("source_plan"),
                    "capability_coverage": data.get("capability_coverage"),
                    "summary": data.get("summary"),
                    "total_min_hours": data.get("total_min_hours"),
                    "total_max_hours": data.get("total_max_hours"),
                }
            )

            for task_index, task in enumerate(tasks_list):
                if not isinstance(task, dict):
                    load_violations.append(
                        f"🚨 File '{relative_file}': item tasks #{task_index + 1} "
                        "must be an object."
                    )
                    continue
                source_task_id = task.get("id")
                if _is_nonempty_text(source_task_id):
                    task_id = source_task_id
                    if task_id in all_tasks:
                        first_file = os.path.relpath(all_tasks[task_id]["file"], staging_dir)
                        load_violations.append(
                            f"🚨 Task '{task_id}': ID is duplicated in "
                            f"'{first_file}' and '{relative_file}'."
                        )
                        continue
                else:
                    task_id = f"<invalid-id:{relative_file.replace(os.sep, ':')}#{task_index + 1}>"

                purpose = task.get("purpose")
                affected_layers = task.get("affected_layers")
                dependency_value = task.get("depends_on")
                blocked_by = task.get("blocked_by")
                estimate_label, estimate_min, estimate_max = normalize_estimate(task)
                deferred = task.get("deferred")
                if "deferred" not in task or deferred is None:
                    deferred = []
                scope = task.get("scope")
                parent_task = task.get("parent_task")

                structural_errors = []
                try:
                    TASK_RECORD.validate_python(task)
                except ValidationError as error:
                    structural_errors.append(
                        validation_message(f"Task '{task_id}'", error, TASK_RECORD)
                    )
                estimate_value = task.get("estimate")
                all_tasks[task_id] = {
                    "id": task_id,
                    "source_id": source_task_id,
                    "acceptance_ids": task.get("acceptance_ids"),
                    "contributes_to_acceptance_ids": task.get("contributes_to_acceptance_ids", []),
                    "local_acceptance_criteria": task.get("local_acceptance_criteria", []),
                    "filename": task.get("filename"),
                    "title": task.get("title"),
                    "name": task.get("title") or task.get("outcome") or "Untitled",
                    "outcome": task.get("outcome"),
                    "scope": scope,
                    "affected_layers": affected_layers,
                    "contract_type": task.get("contract_type"),
                    "purpose": purpose,
                    "implemented": task.get("implemented"),
                    "consumers": task.get("consumers"),
                    "research_question": task.get("research_question"),
                    "timebox_hours": task.get("timebox_hours"),
                    "expected_result": task.get("expected_result"),
                    "estimate_raw": estimate_value,
                    "structural_errors": structural_errors,
                    "estimate": estimate_label,
                    "estimate_min_hours": estimate_min,
                    "estimate_max_hours": estimate_max,
                    "depends_on": dependency_value,
                    "blocked_by": blocked_by,
                    "parent_task": parent_task,
                    "deferred": deferred,
                    "file": filepath,
                    "markdown_file": find_markdown_file(task, filepath),
                }
                if all_tasks[task_id]["markdown_file"] is None:
                    load_violations.append(
                        f"🚨 Task '{task_id}': Markdown-file from the filename field "
                        f"not found next to '{relative_file}'."
                    )
        except Exception as error:
            load_violations.append(f"🚨 File '{relative_file}': failed to read task JSON: {error}")

    return {"tasks": all_tasks, "envelopes": envelopes, "errors": load_violations}


def _is_nonempty_text(value: object) -> TypeGuard[str]:
    return isinstance(value, str) and bool(value.strip())


def _is_number(value: object) -> TypeGuard[int | float]:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _plan_commit_error(plan: Path, content: bytes, commit: object) -> str | None:
    if commit is None:
        return None
    if (
        not isinstance(commit, str)
        or re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", commit) is None
    ):
        return "plan_commit must be a full lowercase Git commit ID"
    try:
        root = subprocess.run(
            ["git", "-C", str(plan.resolve().parent), "rev-parse", "--show-toplevel"],
            capture_output=True,
            check=False,
            timeout=5,
        )
        if root.returncode:
            return None
        repo = Path(os.fsdecode(root.stdout).strip()).resolve()
        relative = plan.resolve().relative_to(repo).as_posix()

        kind = subprocess.run(
            ["git", "-C", str(repo), "cat-file", "-t", commit],
            capture_output=True,
            check=False,
            timeout=5,
        )
        if kind.returncode or kind.stdout.strip() != b"commit":
            return "plan_commit does not identify a Git commit"
        saved = subprocess.run(
            ["git", "-C", str(repo), "show", f"{commit}:{relative}"],
            capture_output=True,
            check=False,
            timeout=5,
        )
        if saved.returncode or saved.stdout.replace(b"\r\n", b"\n") != content.replace(
            b"\r\n", b"\n"
        ):
            return "plan_commit does not identify the plan content"
    except (OSError, subprocess.TimeoutExpired, ValueError):
        # Git or repository identity unavailable: do not invent provenance.
        return None
    return None


def load_source_lock(path: str | Path) -> tuple[SourceLock | None, list[str]]:
    messages = []
    if not os.path.isfile(path):
        return None, [f"🚨 Source lock '{path}' not found."]
    try:
        with open(path, encoding="utf-8") as file:
            raw_source_lock = json.load(file)
    except (OSError, ValueError) as error:
        return None, [f"🚨 Source lock '{path}' cannot be read: {error}"]

    try:
        source_lock = SOURCE_LOCK.validate_python(raw_source_lock)
    except ValidationError as exc:
        return None, [validation_message(f"Invalid source lock '{path}'", exc, SOURCE_LOCK)]

    for field in ("capability_ids", "acceptance_ids"):
        values = source_lock[field]
        if len(values) != len(set(values)):
            messages.append(f"🚨 Source lock '{path}': {field} contains duplicates.")
    try:
        plan_path = Path(source_lock["plan_path"])
        plan_bytes = plan_path.read_bytes()
        plan_text = plan_bytes.decode("utf-8")
        content_hash = "sha256:" + hashlib.sha256(plan_bytes).hexdigest()
        if content_hash != source_lock.get("plan_content_hash"):
            raise ValueError("SOURCE_DRIFT: plan_content_hash differs from exact plan bytes")
        normalized = "\n".join(
            line.rstrip()
            for line in plan_text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        ).rstrip()
        actual_hash = "sha256:" + hashlib.sha256(normalized.encode()).hexdigest()
        if actual_hash != source_lock.get("plan_hash"):
            raise ValueError("SOURCE_DRIFT: plan_hash differs from plan")
        declared = {c["id"] for c in plan_criteria(plan_text)}
        if declared != set(source_lock.get("acceptance_ids") or []):
            raise ValueError("Acceptance source lock differs from plan")
        commit_error = _plan_commit_error(plan_path, plan_bytes, source_lock.get("plan_commit"))
        if commit_error:
            raise ValueError(commit_error)
    except (OSError, ValueError, KeyError, TypeError) as error:
        messages.append(f"🚨 {error}")
    return source_lock, messages
