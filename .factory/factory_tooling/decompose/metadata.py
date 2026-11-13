"""Project structured decomposition data into task drafts without changing prose."""

from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import re
import shutil
import tempfile
from pathlib import Path
from typing import Any, TypedDict

from factory_tooling.decompose.contracts import LoadedTask
from factory_tooling.decompose.output_safety import reject_symlink_ancestors
from factory_tooling.decompose.task_data import (
    PURPOSE_LABELS,
    TASK_ENVELOPE,
    _relation_ids,
    capabilities_by_task,
    load_source_lock,
    load_tasks,
)
from factory_tooling.decompose.task_validation import validate_dependencies


class Projection(TypedDict):
    documents: dict[str, str]
    envelopes: dict[str, dict[str, Any]]
    input_sha256: dict[str, str]


def render_metadata(
    text: str, task: LoadedTask, source: dict[str, Any], capabilities: list[str], plan_path: str
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
        for path in sorted(glob.glob(str(staging / "**" / "task_result.json"), recursive=True))
    ]


def project(staging: Path, source_lock: Path) -> Projection:
    """Return rendered documents and envelope totals; caller owns staging writes."""
    reject_symlink_ancestors(source_lock)
    paths = envelope_paths(staging)
    inputs = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths}
    inputs[str(source_lock)] = hashlib.sha256(source_lock.read_bytes()).hexdigest()
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
    inputs[str(plan)] = hashlib.sha256(plan.read_bytes()).hexdigest()
    if "sha256:" + inputs[str(plan)] != lock["plan_content_hash"]:
        raise ValueError("SOURCE_DRIFT: plan changed during projection")
    source = {
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
    rendered_envelopes: dict[str, dict[str, Any]] = {}
    for envelope in envelopes:
        if envelope["source_plan"] != source:
            raise ValueError("Envelope source differs from lock")
        coverage = envelope["capability_coverage"]
        if not isinstance(coverage, list):
            raise ValueError("Invalid capability coverage")
        owned = [task for task in tasks.values() if task["file"] == envelope["file"]]
        original = json.loads(Path(envelope["file"]).read_text(encoding="utf-8"))
        original["total_min_hours"] = sum(task["estimate_min_hours"] for task in owned)
        original["total_max_hours"] = sum(task["estimate_max_hours"] for task in owned)
        rendered_envelopes[envelope["file"]] = dict(TASK_ENVELOPE.validate_python(original))
        for task in owned:
            caps = sorted(task_capabilities[task["id"]])
            path = task.get("markdown_file")
            if path is None:
                raise ValueError(f"Missing Markdown for {task['id']}")
            raw = Path(path).read_bytes()
            inputs[path] = hashlib.sha256(raw).hexdigest()
            documents[path] = render_metadata(raw.decode("utf-8"), task, source, caps, plan_path)
    if (
        envelope_paths(staging) != paths
        or source_lock.is_symlink()
        or any(
            hashlib.sha256(Path(path).read_bytes()).hexdigest() != expected
            for path, expected in inputs.items()
        )
    ):
        raise ValueError("Projection inputs changed; rerun")
    return {"documents": documents, "envelopes": rendered_envelopes, "input_sha256": inputs}


def apply(staging: Path, source_lock: Path, checkpoint_id: str) -> dict[str, object]:
    """Apply one projection under the caller's single-writer discipline."""
    if not re.fullmatch(r"[a-z0-9][a-z0-9_-]*", checkpoint_id):
        raise ValueError("Safe checkpoint ID required")
    projection = project(staging, source_lock)
    root = staging.resolve()
    inputs = projection["input_sha256"]
    changes = {
        **{path: text.encode("utf-8") for path, text in projection["documents"].items()},
        **{
            path: (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
            for path, value in projection["envelopes"].items()
        },
    }
    for raw in changes:
        path = Path(raw)
        reject_symlink_ancestors(path)
        if not path.resolve().is_relative_to(root) or path.stat().st_nlink != 1:
            raise ValueError("Unsafe projection target")
        if raw not in inputs:
            raise ValueError("Unbound projection target")
    checkpoints = staging.parent / "checkpoints"
    reject_symlink_ancestors(checkpoints)
    checkpoints.mkdir(parents=True, exist_ok=True)
    checkpoint = checkpoints / checkpoint_id
    if checkpoint.exists() or checkpoint.is_symlink():
        raise ValueError("Checkpoint already exists")
    with tempfile.TemporaryDirectory(prefix=".checkpoint-", dir=checkpoints) as temp:
        backup = Path(temp) / "checkpoint"
        backup.mkdir()
        snapshot_dir = backup / "tasks"
        shutil.copytree(staging, snapshot_dir)
        manifest: dict[str, str] = {}
        for raw in sorted(changes):
            rel = Path(raw).resolve().relative_to(root)
            manifest[rel.as_posix()] = inputs[raw]
        (backup / "manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        if any(
            hashlib.sha256((snapshot_dir / rel).read_bytes()).hexdigest() != digest
            for rel, digest in manifest.items()
        ):
            raise ValueError("Checkpoint input changed; rerun")
        os.rename(backup, checkpoint)
    temp_paths: list[Path] = []
    try:
        for raw, content in changes.items():
            path = Path(raw)
            fd, name = tempfile.mkstemp(prefix=".metadata-", dir=path.parent)
            temporary = Path(name)
            temp_paths.append(temporary)
            with os.fdopen(fd, "wb") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
        if set(map(str, envelope_paths(staging))) != set(projection["envelopes"]):
            raise ValueError("Projection envelope set changed; rerun")
        for raw, digest in inputs.items():
            path = Path(raw)
            reject_symlink_ancestors(path)
            if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise ValueError("Projection inputs changed; rerun")
        for (raw, _), temporary in zip(changes.items(), temp_paths, strict=True):
            path = Path(raw)
            reject_symlink_ancestors(path)
            if (
                path.stat().st_nlink != 1
                or hashlib.sha256(path.read_bytes()).hexdigest() != inputs[raw]
            ):
                raise ValueError("Projection target changed; recover from checkpoint")
            os.replace(temporary, path)
        return {
            "checkpoint": str(checkpoint),
            "documents": len(projection["documents"]),
            "envelopes": len(projection["envelopes"]),
        }
    finally:
        for temporary in temp_paths:
            temporary.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staging", type=Path)
    parser.add_argument("source_lock", type=Path)
    parser.add_argument("--checkpoint", required=True, help="new safe checkpoint ID")
    args = parser.parse_args()
    try:
        print(
            json.dumps(
                apply(args.staging, args.source_lock, args.checkpoint), ensure_ascii=False, indent=2
            )
        )
    except (OSError, ValueError, KeyError, TypeError) as exc:
        parser.exit(1, f"BLOCKED: {exc}\n")


if __name__ == "__main__":
    main()
