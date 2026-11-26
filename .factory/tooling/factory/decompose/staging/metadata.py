"""Project structured decomposition data into task drafts without changing prose."""

from __future__ import annotations

import glob
import hashlib
import json
import os
import re
from collections.abc import Mapping
from pathlib import Path
from typing import TypedDict

from factory import file_reader
from factory.decompose.contracts import LoadedTask, SourcePlan, TaskEnvelope
from factory.decompose.graph.task_data import (
    PURPOSE_LABELS,
    TASK_ENVELOPE,
    _relation_ids,
    capabilities_by_task,
    load_source_lock,
    load_tasks,
)
from factory.decompose.graph.validation import validate_dependencies
from factory.decompose.staging.output_safety import reject_symlink_ancestors


class Projection(TypedDict):
    documents: dict[str, str]
    envelopes: dict[str, TaskEnvelope]
    input_sha256: dict[str, str]


def render_metadata(
    text: str,
    task: LoadedTask,
    source: Mapping[str, object],
    capabilities: list[str],
    plan_path: str,
) -> str:
    """Replace canonical header values; retain title, prose and other metadata."""
    if any(ch in plan_path for ch in "<>\r\n"):
        raise ValueError("Invalid plan path")
    values = {
        "ID": task["id"],
        "Plan source": f"`{source['plan_id']}`, revision {source['revision']}, [approved plan](<{plan_path}>)",
        "Covers capabilities": ", ".join(capabilities) or "—",
        "Acceptance criteria": ", ".join(_relation_ids(task.get("acceptance_ids"))) or "—",
        "Contribution to plan criteria": ", ".join(
            _relation_ids(task.get("contributes_to_acceptance_ids"))
        )
        or "—",
        "Purpose": PURPOSE_LABELS[str(task["purpose"])],
        "Scope": str(task["scope"]),
        "Estimate": task["estimate"],
        "Parent task": str(task.get("parent_task") or "—"),
        "Depends on": ", ".join(_relation_ids(task.get("depends_on"))) or "—",
        "Blocked by": ", ".join(_relation_ids(task.get("blocked_by"))) or "—",
    }
    heading = re.search(r"(?m)^## ", text)
    end = heading.start() if heading else len(text)
    header, prose = text[:end], text[end:]
    for label, value in values.items():
        pattern = rf"(?m)^(-\s+\*\*{re.escape(label)}:\*\*)[^\S\n]*.*$"

        def replace(match: re.Match[str], replacement: str = value) -> str:
            return f"{match.group(1)} {replacement}"

        header, count = re.subn(pattern, replace, header)
        if count != 1:
            raise ValueError(f"Expected one header field: {label}")
    return header + prose


def markdown_path(relative: str, separator: str) -> str:
    """Use Markdown-compatible separators on the current host."""
    return relative.replace(separator, "/")


def envelope_paths(staging: Path) -> list[Path]:
    """Reject staging symlinks and match the loader's recursive enumeration."""
    reject_symlink_ancestors(staging)

    def fail(error: OSError) -> None:
        raise error

    for root, directories, files in os.walk(staging, onerror=fail):
        for name in (*directories, *files):
            if (Path(root) / name).is_symlink():
                raise ValueError("Symlink in staging")
    return [
        Path(path)
        for path in sorted(
            glob.glob(
                os.path.join(glob.escape(str(staging)), "**", "task_result.json"), recursive=True
            )
        )
    ]


def project(staging: Path, source_lock: Path) -> Projection:
    """Return rendered documents and envelope totals; caller owns staging writes."""
    reject_symlink_ancestors(source_lock)
    paths = envelope_paths(staging)
    inputs = {str(path): hashlib.sha256(file_reader.read_bytes(path)).hexdigest() for path in paths}
    inputs[str(source_lock)] = hashlib.sha256(file_reader.read_bytes(source_lock)).hexdigest()
    loaded = load_tasks(staging)
    tasks, envelopes = loaded["tasks"], loaded["envelopes"]
    if {Path(envelope["file"]) for envelope in envelopes} != set(paths):
        raise ValueError("Projection envelope set changed; rerun")
    errors = loaded["errors"] + validate_dependencies(tasks)
    if errors:
        raise ValueError("; ".join(errors))
    lock, lock_errors = load_source_lock(source_lock)
    if lock is None or lock_errors:
        raise ValueError("; ".join(lock_errors))
    plan = Path(lock["plan_path"])
    reject_symlink_ancestors(plan)
    inputs[str(plan)] = hashlib.sha256(file_reader.read_bytes(plan)).hexdigest()
    if "sha256:" + inputs[str(plan)] != lock["plan_content_hash"]:
        raise ValueError("SOURCE_DRIFT: plan changed during projection")
    source: SourcePlan = {
        "plan_id": lock["plan_id"],
        "revision": lock["plan_revision"],
        "hash": lock["plan_hash"],
    }
    task_capabilities = capabilities_by_task(tasks, envelopes)
    plan_path = markdown_path(
        os.path.relpath(Path(lock["plan_path"]).resolve(), Path.cwd() / "docs/tasks/bundle"),
        os.sep,
    )
    documents: dict[str, str] = {}
    rendered_envelopes: dict[str, TaskEnvelope] = {}
    for envelope in envelopes:
        if envelope["source_plan"] != source:
            raise ValueError("Envelope source differs from lock")
        coverage = envelope["capability_coverage"]
        if not isinstance(coverage, list):
            raise ValueError("Invalid capability coverage")
        owned = [task for task in tasks.values() if task["file"] == envelope["file"]]
        original = json.loads(file_reader.read_text(Path(envelope["file"]), encoding="utf-8"))
        original["total_min_hours"] = sum(task["estimate_min_hours"] for task in owned)
        original["total_max_hours"] = sum(task["estimate_max_hours"] for task in owned)
        rendered_envelopes[envelope["file"]] = TASK_ENVELOPE.validate_python(original)
        for task in owned:
            caps = sorted(task_capabilities[task["id"]])
            path = task.get("markdown_file")
            if path is None:
                raise ValueError(f"Missing Markdown for {task['id']}")
            raw = file_reader.read_bytes(Path(path))
            inputs[path] = hashlib.sha256(raw).hexdigest()
            documents[path] = render_metadata(raw.decode("utf-8"), task, source, caps, plan_path)
    if (
        envelope_paths(staging) != paths
        or source_lock.is_symlink()
        or any(
            hashlib.sha256(file_reader.read_bytes(Path(path))).hexdigest() != expected
            for path, expected in inputs.items()
        )
    ):
        raise ValueError("Projection inputs changed; rerun")
    return {"documents": documents, "envelopes": rendered_envelopes, "input_sha256": inputs}
