"""Transitions local to a single workflow dispatch."""

from factory.runtime.contracts import Dispatch
from factory.runtime.scheduling.attempt_graph import Action, advance
from factory.runtime.workflow_core import Invalid, require


def check_identity(dispatch: Dispatch, expected: str | None) -> None:
    require(
        expected is None or dispatch.get("dispatch_id") == expected, "Assignment dispatch is stale"
    )


def mark_unknown(dispatch: Dispatch, reason: str) -> None:
    require(dispatch["status"] in {"reserved", "running"}, "Not an in-flight request")
    dispatch.update({"status": advance(dispatch, "lost"), "reason": reason})


def reconcile(dispatch: Dispatch, status: str, evidence: str) -> None:
    require(
        dispatch["status"] == "unknown" and isinstance(evidence, str) and evidence.strip(),
        "Reconcile unknown work with actual runtime/file evidence",
    )
    if status not in ("reserved", "running", "blocked"):
        raise Invalid("Invalid reconciliation state")
    if status == "running":
        require(dispatch.get("handle"), "Bind actual handle before claiming running")
    if status == "reserved":
        require(
            not dispatch.get("prompt_submitted") and not dispatch.get("handle"),
            "Cannot redispatch an already sent assignment",
        )
    recovery: dict[str, Action] = {
        "reserved": "recover_reserved",
        "running": "recover_running",
        "blocked": "recover_blocked",
    }
    dispatch["status"] = advance(dispatch, recovery[status])
