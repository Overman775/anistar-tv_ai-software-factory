"""Transitions local to a single workflow dispatch."""

from typing import Literal, cast

from factory.runtime.contracts import Dispatch
from factory.runtime.workflow_core import Invalid, require


def mark_unknown(dispatch: Dispatch, reason: str) -> None:
    require(dispatch["status"] in {"reserved", "running"}, "Not an in-flight request")
    dispatch.update({"status": "unknown", "reason": reason})


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
    dispatch["status"] = cast(Literal["reserved", "running", "blocked"], status)
