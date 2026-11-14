"""Read task records from the active ledger or a terminal archive."""

import json
from pathlib import Path
from typing import Literal, NotRequired, TypedDict

from factory.runtime import run_archive
from factory.runtime.contracts import FindingView, Report
from factory.runtime.review_findings import view
from factory.runtime.state_io import parse_state
from factory.runtime.workflow_core import Invalid, read_json, relative, require


class MemoryStep(TypedDict):
    status: str
    attempt: NotRequired[int]
    dispatch_id: NotRequired[str]
    report: NotRequired[Report]


class TaskMemory(TypedDict):
    run_id: str
    run_status: Literal["active", "completed", "cancelled"]
    task_id: str
    steps: dict[str, MemoryStep]
    open_findings: dict[str, FindingView]


def _evidence_path(path: str) -> str:
    require(path.startswith(".factory/memory/"), "Expected a memory evidence path")
    return path


def resolve_evidence(workspace: str | Path, path: str) -> Path:
    """Resolve an existing loose memory reference without following links."""
    result = relative(Path(workspace).resolve(), _evidence_path(path))
    require(result.is_file(), f"Memory evidence not found: {path}")
    return result


def read_evidence(workspace: str | Path, path: str, *, run_id: str | None = None) -> bytes:
    """Read a loose reference or a member of the selected run archive."""
    root = Path(workspace).resolve()
    name = _evidence_path(path)
    result = relative(root, name)
    if run_id is not None:
        archive = run_archive.find_archive(root, run_id)
        if archive is not None:
            return run_archive.read_member(archive, name)
    if result.is_file():
        return result.read_bytes()
    raise Invalid(f"Memory evidence not found: {path}")


def read_task(workspace: str | Path, task_id: str, *, run_id: str | None) -> TaskMemory:
    """Read one file. None selects the active ledger; a run ID selects its archive."""
    root = Path(workspace).resolve()
    if run_id is not None:
        require(
            bool(run_id)
            and "\0" not in run_id
            and Path(run_id).name == run_id
            and run_id not in {".", ".."},
            "Expected a single run ID",
        )
    record_path = ".factory/memory/state/workflow.json" if run_id is None else run_id
    try:
        if run_id is None:
            record = read_json(relative(root, record_path))
        else:
            archive = run_archive.find_archive(root, run_id)
            if archive is None:
                raise FileNotFoundError(run_id)
            record = json.loads(run_archive.read_member(archive, "run.json"))
        state = parse_state(record)
    except FileNotFoundError as exc:
        raise Invalid(f"Run not found: {record_path}") from exc
    except Invalid:
        raise
    except (OSError, ValueError) as exc:
        raise Invalid(f"Cannot read run: {record_path}: {exc}") from exc

    if run_id is not None:
        require(state["run_id"] == run_id, "Archive run ID mismatch")
        require(state["status"] in {"completed", "cancelled"}, "Archive is not terminal")
    require(task_id in state["graph"]["tasks"], f"Unknown task: {task_id}")

    steps: dict[str, MemoryStep] = {}
    for node in state["graph"]["nodes"]:
        if node["task"] != task_id:
            continue
        record = state["nodes"].get(node["id"])
        if record is None or "status" not in record:
            raise Invalid(f"Missing step state: {node['id']}")
        step: MemoryStep = {"status": record["status"]}
        if "attempt" in record:
            step["attempt"] = record["attempt"]
        if "dispatch_id" in record:
            step["dispatch_id"] = record["dispatch_id"]
        if "report" in record:
            step["report"] = record["report"]
        steps[node["id"]] = step

    return {
        "run_id": state["run_id"],
        "run_status": state["status"],
        "task_id": task_id,
        "steps": steps,
        "open_findings": {
            key: finding
            for key, finding in view(state, task_id).items()
            if finding.get("status") == "open" and finding.get("task_id", task_id) == task_id
        },
    }
