"""Project next workflow actions and deliver the Teacher outbox under the ledger lock."""

from pathlib import Path
from typing import Any, Protocol, cast

from factory.runtime import command_worker, teacher
from factory.runtime.agent_commands import command_shell, factory_command
from factory.runtime.contracts import Dispatch, ExecutionReceipt, Node, State
from factory.runtime.history import report_history
from factory.runtime.history.history_repository import HistoryRepository
from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
from factory.runtime.packets.content import pending_packet_confirmations
from factory.runtime.scheduling import escalation
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import Invalid, require
from factory.runtime.workflow_graph import (
    validate_assignment_lineage,
    validate_graph,
)
from factory.tasks.contracts import Task


class EvidenceLedger(Protocol):
    root: Path
    history: HistoryRepository

    def read(self) -> State: ...


def explain(
    ledger: EvidenceLedger, node_id: str, dispatch_id: str, run_id: str | None
) -> dict[str, Any]:
    """Read the specific attempt, including superseded attempts and sealed runs."""
    if run_id is None:
        state = ledger.read()
    else:
        try:
            current = ledger.read()
        except FileNotFoundError:
            current = None
        state = (
            current
            if current is not None and current["run_id"] == run_id
            else ledger.history.archived_state(ledger.root, run_id)
        )
    run_id = state["run_id"]
    selected = state["nodes"].get(node_id)
    is_current = selected is not None and selected.get("dispatch_id") == dispatch_id
    attempt = selected if is_current else None
    events = []
    for event in state["events"]:
        prior = event.get("previous_nodes", {}).get(node_id)
        if event["event"] == "invalidated" and event.get("node") == node_id:
            prior = cast(Dispatch | None, event.get("previous"))
        previous_matches = prior is not None and prior.get("dispatch_id") == dispatch_id
        if previous_matches and not is_current:
            attempt = prior
        if previous_matches or event.get("dispatch_id") == dispatch_id:
            events.append(
                {
                    key: value
                    for key, value in event.items()
                    if key
                    not in {"previous", "previous_nodes", "previous_graph", "previous_config"}
                }
            )
    require(attempt is not None, "Unknown dispatch for node in selected run")
    assert attempt is not None
    report_ref = state.get("report_index", {}).get(dispatch_id) or attempt.get("report_ref")
    report = None
    if report_ref is not None:
        require(
            (report_ref["run_id"], report_ref["node_id"], report_ref["dispatch_id"])
            == (run_id, node_id, dispatch_id),
            "Report reference belongs to another attempt",
        )
        report = report_history.read(ledger.root, report_ref, history=ledger.history)
    assignment = attempt.get("assignment")
    return {
        "run_id": run_id,
        "run_status": state["status"],
        "node_id": node_id,
        "dispatch_id": dispatch_id,
        "current": is_current,
        "attempt": attempt["attempt"],
        "task_id": assignment["node"]["task"] if assignment is not None else None,
        "status": attempt["status"],
        "profile": attempt.get("profile"),
        "handle": attempt.get("handle"),
        "reason": attempt.get("reason"),
        "report_ref": report_ref,
        "report": report,
        "events": events,
        "checks": {
            execution: {
                "status": record["status"],
                "check_id": record["spec"]["id"],
                "request_id": record["request_id"],
                "result": record.get("result"),
            }
            for execution, record in state.get("executions", {}).items()
            if record["node_id"] == node_id and record["dispatch_id"] == dispatch_id
        },
        "artifacts": [
            item
            for item in ledger.history.listing(ledger.root, run_id)
            if item["dispatch_id"] == dispatch_id and item["node_id"] == node_id
        ],
    }


class QueryLedger(Protocol):
    root: Path

    def active_commands(self, state: State) -> dict[str, ExecutionReceipt]: ...
    def acceptance_task(self, state: State, nodes: dict[str, Node], node_id: str) -> Task: ...
    def claim_pool(self, state: State, nodes: dict[str, Node], node_id: str) -> str: ...
    def check_completion(
        self, state: State, *, config_error: str | None = None, config_checked: bool = False
    ) -> None: ...


def next_actions(
    ledger: QueryLedger, state: State, after: str | None, *, jobs: TeacherJobRepository
) -> dict[str, Any]:
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
    run_id = state["run_id"]
    shell = command_shell()
    config = state["config"]["_path"]
    commands = {
        rid: {
            "node_id": r["node_id"],
            "dispatch_id": r["dispatch_id"],
            "check_id": r["spec"]["id"],
            "owner_registered": command_worker.artifact(ledger.root, r, ".owner.json").exists(),
            "reconcile_command": factory_command(
                ledger.root, config, "checks", "reconcile", rid, shell=shell
            ),
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
        "after_archive": teacher.finalizer(ledger.root, state, jobs=jobs),
        "pending_teacher_events": teacher.pending(ledger.root, jobs=jobs),
        "pending_packet_confirmations": pending_packet_confirmations(state),
    }
    results = {}
    ready, accepts = [], []
    blockers: dict[str, str] = {}
    corrections: dict[str, list[str]] = {}
    config_error = None
    if state["status"] == "active":
        nodes = validate_graph(state["graph"], state["config"], ledger.root)
        try:
            check_config(state)
        except Invalid as exc:
            config_error = str(exc)
            blockers["run"] = config_error
        if config_error is None:
            try:
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
            ledger.check_completion(state, config_error=config_error, config_checked=True)
            completion = True
        except Invalid as exc:
            blockers["completion"] = str(exc)
    read_commands = {}
    for node in sorted(active.keys() | results.keys() | (blockers.keys() & state["nodes"].keys())):
        dispatch = state["nodes"][node].get("dispatch_id")
        if dispatch:
            read_commands[node] = factory_command(
                ledger.root,
                config,
                "workflow",
                "explain",
                node,
                "--dispatch",
                dispatch,
                "--run",
                run_id,
                shell=shell,
            )
    result = {
        **result,
        "run_id": run_id,
        "command_shell": shell,
        "read_commands": read_commands,
        "results": results,
        "runnable": ready,
        "acceptance": accepts,
        "blockers": blockers,
        "corrections": corrections,
        "completion_eligible": completion,
    }

    cursor = f"{state['run_id']}:{len(state['events'])}:{report_history.identity(result)[:16]}"
    if after == cursor and not commands:
        return {
            "cursor": cursor,
            "unchanged": True,
            "run_id": run_id,
            "run_status": state["status"],
        }
    return {**result, "cursor": cursor, "unchanged": False}
