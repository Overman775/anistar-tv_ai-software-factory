"""Read task records from the active ledger or a terminal archive."""

from pathlib import Path
from typing import Literal, NotRequired, TypedDict

from factory import file_reader
from factory.database.provider import current_database
from factory.paths import MEMORY as BASE
from factory.runtime.contracts import FindingView, Report
from factory.runtime.history.history_repository import HistoryRepository
from factory.runtime.reports.review_findings import view
from factory.runtime.workflow_core import Invalid, relative, require


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


def read_evidence(
    workspace: str | Path,
    path: str,
    *,
    run_id: str | None = None,
    history: HistoryRepository | None = None,
) -> bytes:
    """Read a loose reference or a member of the selected run archive."""
    history = current_database().history if history is None else history
    root = Path(workspace).resolve()
    name = _evidence_path(path)
    result = relative(root, name)
    if run_id is not None:
        require(
            name.startswith(f"{BASE}/history/{run_id}/")
            or (result.parent == root / BASE / "state" and result.name.startswith(run_id + "-")),
            "Wrong artifact owner",
        )
        allow_loose = not (
            name.startswith(f"{BASE}/history/{run_id}/reports/")
            or (result.parent == root / BASE / "state" and name.endswith(".packet.json"))
        )
        data = history.stored_evidence(root, run_id, name, allow_loose=allow_loose)
        if data is not None:
            return data
    if result.is_file():
        return file_reader.read_bytes(result)
    raise Invalid(f"Memory evidence not found: {path}")


def read_task(
    workspace: str | Path,
    task_id: str,
    *,
    run_id: str | None,
    history: HistoryRepository | None = None,
) -> TaskMemory:
    """Read the current ledger or the closed SQLite record for a specific run."""
    history = current_database().history if history is None else history
    root = Path(workspace).resolve()
    if run_id is not None:
        require(
            bool(run_id)
            and "\0" not in run_id
            and Path(run_id).name == run_id
            and run_id not in {".", ".."},
            "Expected a single run ID",
        )
    record_path = "current" if run_id is None else run_id
    try:
        if run_id is None:
            state = history.current(root)
        else:
            state = history.archived_state(root, run_id)
    except FileNotFoundError as exc:
        raise Invalid(f"Run not found: {record_path}") from exc
    except Invalid:
        raise
    except (OSError, ValueError) as exc:
        raise Invalid(f"Cannot read run: {record_path}: {exc}") from exc

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
