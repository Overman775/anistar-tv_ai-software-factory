"""Project next workflow actions and deliver the Teacher outbox under the ledger lock."""

from pathlib import Path
from typing import Any, Protocol, cast

from factory.runtime import teacher
from factory.runtime.agent_commands import command_shell, factory_command
from factory.runtime.contracts import Dispatch, State
from factory.runtime.history import report_history
from factory.runtime.history.history_repository import HistoryRepository
from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
from factory.runtime.packets.content import pending_packet_confirmations
from factory.runtime.scheduling import escalation
from factory.runtime.scheduling.orchestrator_graph import (
    Accept,
    Assign,
    Checkpoint,
    GateEvidence,
    Hold,
    assignment_ticket,
    stop_identity,
)
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import Invalid, graph_identity, require
from factory.runtime.workflow_graph import (
    validate_assignment_lineage,
    validate_graph,
)


class EvidenceLedger(Protocol):
    root: Path
    history: HistoryRepository

    def read(self) -> State: ...


def lookup_state(ledger: EvidenceLedger, run_id: str | None) -> State:
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
    return state


def explain(
    ledger: EvidenceLedger, node_id: str, dispatch_id: str, run_id: str | None
) -> dict[str, Any]:
    """Read the specific attempt, including superseded attempts and sealed runs."""
    state = lookup_state(ledger, run_id)
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


class QueryLedger(GateEvidence, Protocol):
    def check_completion(
        self, state: State, *, config_error: str | None = None, config_checked: bool = False
    ) -> None: ...


def verification_progress(state: State) -> dict[str, object]:
    """Project assigned obligations and the latest attempt for this exact candidate."""
    progress: dict[str, object] = {}
    executions = state.get("executions", {})
    for node, dispatch in state["nodes"].items():
        assignment = dispatch.get("assignment")
        if dispatch.get("role") != "tester" or assignment is None:
            continue
        ticket = dispatch["dispatch_id"]
        commands = {
            rec["spec"]["id"]: (key, rec)
            for key, rec in executions.items()
            if rec["dispatch_id"] == ticket and rec["node_id"] == node
        }
        report = dispatch.get("report")
        observations = {
            entry["id"]: entry
            for entry in (report.get("checks", []) if report else [])
            if entry.get("kind") == "observation"
        }
        rows: dict[str, dict[str, object]] = {}
        for spec in assignment["requirements"]["required_checks"]:
            key = spec["id"]
            row: dict[str, object] = {"kind": spec["kind"], "status": "PENDING"}
            if spec["kind"] == "observation":
                observed = observations.get(key)
                row["status"] = (
                    observed.get("result", "BLOCKED") if observed else "AWAITING_OBSERVATION"
                )
                row["method"] = spec["method"]
                if observed:
                    row["evidence"] = observed.get("evidence")
            elif key in commands:
                execution, record = commands[key]
                row.update(
                    status=record["status"], request_id=record["request_id"], execution_id=execution
                )
                if "result" in record:
                    row["receipt"] = execution
            rows[key] = row
        progress[node] = {
            "dispatch_id": ticket,
            "source_hash": assignment["source"]["hash"],
            "checks": rows,
        }
    return progress


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
            if field in {"status", "dispatch_id", "profile", "handle", "reason", "submission"}
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
            "owner_registered": "owner" in r,
            "reconcile_command": factory_command(
                ledger.root, config, "checks", "reconcile", rid, shell=shell
            ),
        }
        for rid, r in ledger.active_commands(state).items()
    }
    result: dict[str, Any] = {
        "run_status": state["status"],
        "task_routes": {
            key: {
                "kind": task["kind"],
                "risk": task["risk"],
                "reason": task["reason"],
                "owner_review_ref": task.get("owner_review_ref"),
                "independent_review": task["independent_review"],
                "roles": list(
                    dict.fromkeys(
                        state["graph"]["agents"][n["agent"]]["role"]
                        for n in state["graph"]["nodes"]
                        if n["task"] == key and n["agent"]
                    )
                ),
            }
            for key, task in state["graph"]["tasks"].items()
        },
        "pause_reason": state.get("pause_reason"),
        "automatic_continuation": False,
        "dispatches": active,
        "sessions": {
            key: session
            for key, session in state["sessions"].items()
            if any(n["id"] in active and n.get("agent") == key for n in state["graph"]["nodes"])
        },
        "commands": commands,
        "verification": verification_progress(state),
        "after_archive": teacher.finalizer(ledger.root, state, jobs=jobs),
        "pending_teacher_events": teacher.pending(ledger.root, jobs=jobs),
        "pending_packet_confirmations": pending_packet_confirmations(state),
    }
    results = {}
    ready, accepts = [], []
    blockers: dict[str, str] = {}
    corrections: dict[str, list[str]] = {}
    handoffs: dict[str, list[dict[str, object]]] = {}
    repair_routes = {}
    source_stops: dict[str, dict[str, str]] = {}
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
        checkpoint = Checkpoint(state, nodes, ledger, blockers.get("run"))
        source_stops = checkpoint.source_stops
        outcomes = checkpoint.evaluate(list(state["nodes"]))
        for key, current in state["nodes"].items():
            report = current.get("report")
            if report and current.get("dispatch_id") not in state.get("processed_results", []):
                results[key] = {
                    "dispatch_id": current["dispatch_id"],
                    "outcome": report["outcome"],
                    "stage_result": report.get("stage_result"),
                    "report_ref": current.get("report_ref"),
                }
            outcome = outcomes[key]
            if isinstance(outcome, Hold):
                if outcome.reason != blockers.get("run"):
                    blockers[key] = outcome.reason
                if outcome.corrections:
                    corrections[key] = list(outcome.corrections)
                if outcome.corrections and outcome.next_role:
                    handoffs[key] = [
                        {
                            "command": "workflow " + action,
                            "role": outcome.next_role,
                            "reason": outcome.reason,
                            "source": current.get("report_ref"),
                            **(
                                {"criteria": report["criterion_assessments"]}
                                if report and "criterion_assessments" in report
                                else {}
                            ),
                            **(
                                {"approval_request": report["approval_request"]}
                                if action == "resume-approved"
                                and report
                                and "approval_request" in report
                                else {}
                            ),
                            "node_id": key,
                        }
                        for action in outcome.corrections
                    ]
                if outcome.targets:
                    repair_routes[key] = list(outcome.targets)
                    handoffs[key] = [
                        {
                            "command": "workflow " + target["action"],
                            "role": state["nodes"][target["node_id"]]["role"],
                            "node_id": target["node_id"],
                            "dispatch_id": target["dispatch_id"],
                            "stage": target["stage"],
                            "source": target["evidence"],
                            "reason": outcome.reason,
                        }
                        for target in outcome.targets
                    ]
            elif isinstance(outcome, Accept):
                accepts.append(key)
            elif isinstance(outcome, Assign):
                ready.append(key)
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
    tickets = {
        key: assignment_ticket(run_id, state["revision"], key, state["nodes"][key]["attempt"] + 1)
        for key in ready
    }
    result = {
        **result,
        "run_id": run_id,
        "command_shell": shell,
        "read_commands": read_commands,
        "results": results,
        "runnable": ready,
        "assignment_tickets": tickets,
        "acceptance": accepts,
        "blockers": blockers,
        "corrections": corrections,
        "repair_routes": repair_routes,
        "handoffs": handoffs,
        "source_stops": source_stops,
        "task_stops": {
            task: {"stop_id": stop_identity(state, task), "reason": stop["reason"]}
            for task, stop in state.get("escalation_stops", {}).items()
        },
        "completion_eligible": completion,
    }

    cursor = f"{state['run_id']}:{len(state['events'])}:{graph_identity(result)[:16]}"
    if after == cursor and not commands:
        return {
            "cursor": cursor,
            "unchanged": True,
            "run_id": run_id,
            "run_status": state["status"],
        }
    return {**result, "cursor": cursor, "unchanged": False}
