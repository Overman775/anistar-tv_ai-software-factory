"""Read-only projection of the next workflow actions; caller holds the ledger lock."""

from pathlib import Path
from typing import Any, Protocol

from factory.runtime import command_worker, escalation, report_history
from factory.runtime.contracts import ExecutionReceipt, Node, State
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import Invalid, require
from factory.runtime.workflow_graph import (
    validate_assignment_lineage,
    validate_graph,
)
from factory.tasks.contracts import Task


class QueryLedger(Protocol):
    root: Path

    def active_commands(self, state: State) -> dict[str, ExecutionReceipt]: ...
    def acceptance_task(self, state: State, nodes: dict[str, Node], node_id: str) -> Task: ...
    def claim_pool(self, state: State, nodes: dict[str, Node], node_id: str) -> str: ...
    def check_completion(self, state: State) -> None: ...


def next_actions(ledger: QueryLedger, state: State, after: str | None) -> dict[str, Any]:
    require(
        after is None or after.startswith(state["run_id"] + ":"),
        "Cursor belongs to a different run",
    )
    active = {
        key: {
            field: value
            for field, value in current.items()
            if field in {"status", "dispatch_id", "profile", "handle", "reason"}
        }
        for key, current in state["nodes"].items()
        if current["status"] in escalation.ACTIVE
    }
    commands = {
        rid: {
            "node_id": r["node_id"],
            "dispatch_id": r["dispatch_id"],
            "check_id": r["spec"]["id"],
            "owner_registered": command_worker.artifact(ledger.root, r, ".owner.json").exists(),
        }
        for rid, r in ledger.active_commands(state).items()
    }
    result: dict[str, Any] = {
        "run_status": state["status"],
        "pause_reason": state.get("pause_reason"),
        "automatic_continuation": False,
        "dispatches": active,
        "sessions": {
            key: session
            for key, session in state["sessions"].items()
            if any(n["id"] in active and n.get("agent") == key for n in state["graph"]["nodes"])
        },
        "commands": commands,
    }
    results = {}
    ready, accepts = [], []
    blockers: dict[str, str] = {}
    corrections: dict[str, list[str]] = {}
    if state["status"] == "active":
        nodes = validate_graph(state["graph"], state["config"], ledger.root)
        try:
            check_config(state)
            validate_assignment_lineage(
                state["graph"], state["config"], state.get("corrections", [])
            )
        except Invalid as exc:
            blockers["run"] = str(exc)
        for key, current in state["nodes"].items():
            report = current.get("report")
            if report and current.get("dispatch_id") not in state.get("processed_results", []):
                results[key] = {
                    "dispatch_id": current["dispatch_id"],
                    "outcome": report["outcome"],
                    "stage_result": report.get("stage_result"),
                    "report_ref": current.get("report_ref"),
                }
            if current["status"] == "unknown":
                blockers[key] = "Reconcile actual transport ownership before retry"
            if current["status"] == "blocked":
                blockers[key] = str(report.get("stage_result", "Blocked")) if report else "Blocked"
                if (
                    not active
                    and not commands
                    and not state.get("pause_reason")
                    and "run" not in blockers
                ):
                    corrections[key] = escalation.possible_actions(state, nodes[key], current)
            if current["status"] != "pending" or "run" in blockers:
                continue
            try:
                if nodes[key]["stage"] == "accept":
                    ledger.acceptance_task(state, nodes, key)
                    accepts.append(key)
                else:
                    ledger.claim_pool(state, nodes, key)
                    ready.append(key)
            except Invalid as exc:
                blockers[key] = str(exc)
    completion = False
    if state["status"] == "active" and not active:
        try:
            ledger.check_completion(state)
            completion = True
        except Invalid as exc:
            blockers["completion"] = str(exc)
    result = {
        **result,
        "results": results,
        "runnable": ready,
        "acceptance": accepts,
        "blockers": blockers,
        "corrections": corrections,
        "completion_eligible": completion,
    }

    cursor = f"{state['run_id']}:{len(state['events'])}:{report_history.identity(result)[:16]}"
    if after == cursor and not commands:
        return {"cursor": cursor, "unchanged": True, "run_status": state["status"]}
    return {**result, "cursor": cursor, "unchanged": False}
