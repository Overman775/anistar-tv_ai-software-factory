"""Read task records from the active ledger or a terminal archive."""

from pathlib import Path
from typing import Any, TypedDict

from factory_tooling.runtime.contracts import Dispatch
from factory_tooling.runtime.review_findings import view
from factory_tooling.runtime.state_io import parse_state
from factory_tooling.runtime.workflow_core import Invalid, read_json, relative, require


class TaskMemory(TypedDict):
    run_id: str
    run_status: str
    task_id: str
    steps: dict[str, Dispatch]
    open_findings: dict[str, Any]


def resolve_evidence(workspace: str | Path, path: str) -> Path:
    """Resolve an archived memory reference without rewriting the archive or following links."""
    if path.startswith(".ai-pipeline/"):
        path = ".factory/memory/" + path[len(".ai-pipeline/") :]
    require(path.startswith(".factory/memory/"), "Expected a memory evidence path")
    result = relative(Path(workspace).resolve(), path)
    require(result.is_file(), f"Memory evidence not found: {path}")
    return result


def read_task(workspace: str | Path, task_id: str, *, run_id: str | None) -> TaskMemory:
    """Read one file. None selects the active ledger; a run ID selects its archive."""
    root = Path(workspace).resolve()
    if run_id is None:
        record_path = ".factory/memory/state/workflow.json"
    else:
        require(
            bool(run_id)
            and "\0" not in run_id
            and Path(run_id).name == run_id
            and run_id not in {".", ".."},
            "Expected a single run ID",
        )
        record_path = f".factory/memory/history/{run_id}/run.json"

    try:
        state = parse_state(read_json(relative(root, record_path)))
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

    steps: dict[str, Dispatch] = {}
    for node in state["graph"]["nodes"]:
        if node["task"] != task_id:
            continue
        record = state["nodes"].get(node["id"])
        if record is None or "status" not in record:
            raise Invalid(f"Missing step state: {node['id']}")
        step: Dispatch = {"status": record["status"]}
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
