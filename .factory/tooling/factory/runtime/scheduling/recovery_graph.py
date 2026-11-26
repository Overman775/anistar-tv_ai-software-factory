"""Graph-owned gates and transitions for repair and resumption of an existing attempt."""

from __future__ import annotations

import time
from dataclasses import dataclass
from functools import cache
from typing import TYPE_CHECKING, cast

from pydantic_graph import Graph, GraphBuilder, StepContext

from factory.dependency_graph import run_program
from factory.runtime import upstream
from factory.runtime.contracts import State, agent_key
from factory.runtime.reports import approval
from factory.runtime.scheduling import dispatch, escalation
from factory.runtime.scheduling.attempt_graph import invalidate
from factory.runtime.scheduling.escalation_policy import RetryBudget
from factory.runtime.scheduling.orchestrator_graph import Checkpoint, Hold, stop_identity
from factory.runtime.transport.evidence import pending_transports
from factory.runtime.workflow_config import check_config, freeze_project
from factory.runtime.workflow_core import acceptance_guard, require
from factory.runtime.workflow_graph import execution_graph, validate_graph

if TYPE_CHECKING:
    from factory.runtime.workflow import Ledger


class RecoveryCommand:
    """A user- or coordinator-authorized request to reopen work."""


@dataclass(frozen=True)
class Retry(RecoveryCommand):
    node_id: str
    stage: str
    reason: str
    evidence: str
    dry_run: bool
    dispatch_id: str | None
    evidence_dispatch: str | None


@dataclass(frozen=True)
class ResumeTask(RecoveryCommand):
    task_id: str
    evidence: str
    stop_id: str | None


@dataclass(frozen=True)
class SourceDecision:
    request: ResumeTask
    reason: str


@dataclass(frozen=True)
class ResumeApproval(RecoveryCommand):
    node_id: str
    request_id: str
    evidence: str


@dataclass(frozen=True)
class Repair:
    ledger: Ledger
    state: State


@dataclass(frozen=True)
class ValidatedRetry:
    request: Retry
    budget: RetryBudget
    affected: set[str]


async def retry_gate(ctx: StepContext) -> ValidatedRetry:
    repair, req = cast(Repair, ctx.state), cast(Retry, ctx.inputs)
    ledger, s = repair.ledger, repair.state
    node_id, stage, reason, terminal_evidence, expected_dispatch = (
        req.node_id,
        req.stage,
        req.reason,
        req.evidence,
        req.dispatch_id,
    )
    require(s["status"] == "active", "Terminal run is immutable; start a new authorized run")
    require(not s.get("pause_reason"), "Run is paused by user")
    nodes = {n["id"]: n for n in s["graph"]["nodes"]}
    n, v = nodes[node_id], s["nodes"][node_id]
    dispatch.check_identity(v, expected_dispatch)
    require(terminal_evidence and reason, "Reconcile old writer and explain retry")
    require(not ledger.active_commands(s), "Unresolved project commands")
    require(v["status"] != "unknown", "Resolve the previous assignment before retry")
    require(
        v["status"] in {"blocked", "done"},
        "Cannot retry a live writer",
    )
    profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
    acceptance_guard(escalation.guard, s, n["task"])
    require(
        stage == "recovery" or not profile.get("escalation"),
        "Use correct for an escalating profile's quality decision",
    )
    budget = RetryBudget.for_task(s, n["task"], stage)
    budget.require_available()
    affected = execution_graph(nodes).affected_by({node_id})
    blocked = [key for key in affected if s["nodes"][key]["status"] == "blocked"]
    decisions = Checkpoint(s, nodes, ledger).evaluate(blocked)
    holds = [decision for decision in decisions.values() if isinstance(decision, Hold)]
    for hold in holds:
        require(
            hold.required in (None, "retry"),
            f"Blocked attempt requires {hold.required} before retry",
        )
    if req.evidence_dispatch is not None or expected_dispatch is not None:
        routes = [route for hold in holds for route in hold.targets]
        if req.evidence_dispatch is not None or any(
            route["node_id"] != node_id or route["evidence"]["node_id"] != node_id
            for route in routes
        ):
            require(
                any(
                    route["action"] == "retry"
                    and route["node_id"] == node_id
                    and route["dispatch_id"] == v.get("dispatch_id")
                    and route["evidence"]["dispatch_id"] == req.evidence_dispatch
                    and route["stage"] == stage
                    for route in routes
                ),
                "Retry needs the active repair route and evidence dispatch",
            )
    for key in affected:
        if previous_dispatch := s["nodes"][key].get("dispatch_id"):
            pending_transports(ledger.root, s, dispatch_id=previous_dispatch)
    if profile.get("escalation") or (
        stage == "recovery" and s["graph"]["agents"][agent_key(n)]["role"] == "tester"
    ):
        require(
            not any(
                s["nodes"][k].get("report", {}).get("outcome") in {"FAIL", "BLOCKED"}
                for k in affected
            ),
            "Use correct for a reported failure or blocker; recovery is transport-only",
        )
    require(
        not any(
            s["nodes"][k]["status"] in {"reserved", "running", "unknown"}
            for k in affected - {node_id}
        ),
        "Reconcile dependent workers first",
    )

    return ValidatedRetry(req, budget, affected)


async def preview_retry(ctx: StepContext) -> dict[str, object]:
    repair, checked = cast(Repair, ctx.state), cast(ValidatedRetry, ctx.inputs)
    s, req, budget, affected = repair.state, checked.request, checked.budget, checked.affected
    node_id, stage, reason, terminal_evidence = req.node_id, req.stage, req.reason, req.evidence
    return {
        "dry_run": True,
        "run_id": s["run_id"],
        "node_id": node_id,
        "stage": stage,
        "reason": reason,
        "terminal_evidence": terminal_evidence,
        "budget": {
            "key": budget.key,
            "used": budget.used,
            "limit": budget.limit,
            "planned_used": budget.used + 1,
        },
        "affected": {
            key: {
                "dispatch_id": s["nodes"][key].get("dispatch_id"),
                "current_status": s["nodes"][key]["status"],
                "planned_status": "pending",
            }
            for key in sorted(affected)
        },
    }


async def commit_retry(ctx: StepContext) -> None:
    repair, checked = cast(Repair, ctx.state), cast(ValidatedRetry, ctx.inputs)
    ledger, s, req, affected = repair.ledger, repair.state, checked.request, checked.affected
    node_id, stage, reason, terminal_evidence = req.node_id, req.stage, req.reason, req.evidence
    checked.budget.spend()
    for k in sorted(affected):
        old = s["nodes"][k]
        s["events"].append(
            {
                "at": time.time(),
                "event": "invalidated",
                "node": k,
                "previous": old,
            }
        )
        s["nodes"][k] = invalidate(old)
    ledger.save(
        s,
        "retry",
        node=node_id,
        stage=stage,
        reason=reason,
        terminal_evidence=terminal_evidence,
    )


async def classify_resume(ctx: StepContext) -> ResumeTask | SourceDecision:
    state, req = cast(Repair, ctx.state).state, cast(ResumeTask, ctx.inputs)
    require(req.task_id in state["graph"]["tasks"], "Unknown task")
    pending = upstream.pending_prerequisites(state, req.task_id)
    if req.stop_id in pending:
        assert req.stop_id is not None
        return SourceDecision(req, pending[req.stop_id])
    require(
        not pending or req.task_id in state.get("escalation_stops", {}),
        "Task stop decision is stale",
    )
    return req


async def resolve_source_prerequisite(ctx: StepContext) -> None:
    repair, decision = cast(Repair, ctx.state), cast(SourceDecision, ctx.inputs)
    state, req = repair.state, decision.request
    require(
        state["status"] == "active" and req.evidence.strip(),
        "Need active run and resolution evidence",
    )
    require(not state.get("pause_reason"), "Run is paused by user")
    check_config(state)
    repair.ledger.check_sources(state, state["graph"]["tasks"][req.task_id])
    repair.ledger.save(
        state,
        "source_prerequisite_resolved",
        task=req.task_id,
        request_id=req.stop_id,
        reason=decision.reason,
        evidence=req.evidence,
    )


async def resume_task(ctx: StepContext) -> None:
    repair, req = cast(Repair, ctx.state), cast(ResumeTask, ctx.inputs)
    ledger, state, task_id, evidence = repair.ledger, repair.state, req.task_id, req.evidence
    require(
        state["status"] == "active" and evidence.strip(),
        "Need active run and resolved blocker/human decision",
    )
    require(not state.get("pause_reason"), "Run is paused by user")
    require(not ledger.active_commands(state), "Unresolved project commands")
    check_config(state)
    require(
        task_id in state.get("escalation_stops", {}),
        "Task has no escalation stop",
    )
    require(
        not any(v["status"] in escalation.ACTIVE for v in state["nodes"].values()),
        "Quiesce runtime before resume",
    )
    stop = state["escalation_stops"][task_id]
    require(
        req.stop_id is None or req.stop_id == stop_identity(state, task_id),
        "Task stop decision is stale",
    )
    ledger.check_sources(state, state["graph"]["tasks"][task_id])
    stage = "recovery" if stop["kind"] == "environment" else stop["cause"]
    budget = RetryBudget.for_task(state, task_id, stage)
    budget.require_available("Budget exhausted; resume cannot reset limits")
    nodes = validate_graph(state["graph"], state["config"], ledger.root)
    node_id = stop["node_id"]
    roots = set(stop.get("node_ids", [node_id]))
    affected = execution_graph(nodes).affected_by(roots)
    for k in affected:
        old = state["nodes"][k]
        state["events"].append(dict(at=time.time(), event="invalidated", node=k, previous=old))
        state["nodes"][k] = invalidate(old)
    budget.spend()
    del state["escalation_stops"][task_id]
    ledger.save(
        state,
        "task_resumed",
        task=task_id,
        evidence=evidence,
        previous=stop,
        retry_cause=stage,
    )
    # Work is pending; dispatch still requires a separate claim and bind.


async def resume_approval(ctx: StepContext) -> None:
    repair, req = cast(Repair, ctx.state), cast(ResumeApproval, ctx.inputs)
    ledger, state, node_id, request_id, evidence = (
        repair.ledger,
        repair.state,
        req.node_id,
        req.request_id,
        req.evidence,
    )
    require(not state.get("pause_reason"), "Run is paused by user")
    require(not ledger.active_commands(state), "Unresolved project commands")
    require(state["status"] == "active", "Run is not active")
    check_config(state)
    require(
        not any(v["status"] in escalation.ACTIVE for v in state["nodes"].values()),
        "Quiesce runtime before resuming approval",
    )
    nodes = validate_graph(state["graph"], state["config"], ledger.root)
    node = nodes[node_id]
    task = state["graph"]["tasks"][node["task"]]
    ledger.check_sources(state, task)
    acceptance_guard(escalation.guard, state, node["task"])
    approval.validate_resume(ledger.root, state, node, task, request_id, evidence)
    graph = approval.expanded_graph(state, node, state["nodes"][node_id]["report"])
    added = sorted(set(graph["tasks"][node["task"]]["scope"]) - set(task["scope"]))
    if added:
        validate_graph(graph, state["config"], ledger.root)
        state["config"] = freeze_project(state["config"], graph, ledger.root)
        state["graph"] = graph
        state["revision"] += 1
    roots = {node_id} | {
        key
        for key, candidate in nodes.items()
        if candidate["task"] == node["task"]
        and candidate["stage"] in {"verify", "review"}
        and state["nodes"][key]["status"] == "done"
    }
    affected = execution_graph(nodes).affected_by(roots)
    for key in sorted(affected):
        old = state["nodes"][key]
        if key != node_id and old["status"] == "blocked":
            continue  # This approval resolves only its own blocker.
        state["events"].append(dict(at=time.time(), event="invalidated", node=key, previous=old))
        state["nodes"][key] = invalidate(old)
    ledger.save(
        state,
        "approval_resumed",
        node=node_id,
        request_id=request_id,
        evidence=evidence,
        added_scope=added,
    )


@cache
def recovery_graph() -> Graph:
    b = GraphBuilder(
        name="AttemptRecovery",
        state_type=Repair,
        input_type=RecoveryCommand,
        auto_instrument=False,
    )
    check = b.step(retry_gate)
    apply = b.step(commit_retry)
    preview = b.step(preview_retry)
    task, approved = b.step(resume_task), b.step(resume_approval)
    classify, resolved = b.step(classify_resume), b.step(resolve_source_prerequisite)
    route = (
        b.decision(node_id="recovery_command")
        .branch(b.match(Retry).to(check))
        .branch(b.match(ResumeTask).to(classify))
        .branch(b.match(ResumeApproval).to(approved))
    )
    confirmation = (
        b.decision(node_id="retry_mode")
        .branch(b.match(ValidatedRetry, matches=lambda r: r.request.dry_run).to(preview))
        .branch(b.match(ValidatedRetry).to(apply))
    )
    b.add_edge(b.start_node, route)
    b.add_edge(
        classify,
        b.decision(node_id="task_resolution")
        .branch(b.match(SourceDecision).to(resolved))
        .branch(b.match(ResumeTask).to(task)),
    )
    b.add_edge(check, confirmation)
    b.add(b.edge_from(resolved, task, approved, preview, apply).to(b.end_node))
    return b.build()


def execute(
    ledger: Ledger, state: State, command: Retry | ResumeTask | ResumeApproval
) -> dict[str, object] | None:
    return cast(
        dict[str, object] | None,
        run_program(recovery_graph(), state=Repair(ledger, state), inputs=command),
    )
