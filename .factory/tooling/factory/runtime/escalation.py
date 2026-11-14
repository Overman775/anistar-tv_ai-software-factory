"""Coordinator policy validation and task-scoped correction transitions.

No model calls, backend cancellation, or worker-side routing. The caller verifies
terminal evidence, diagnosis and real capabilities before submitting a decision.
"""

from __future__ import annotations

import json
import time
from copy import copy, deepcopy
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, Protocol, cast

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.runtime import report_history
from factory.runtime import review_findings as review_findings
from factory.runtime.acceptance import ensure as ensure
from factory.runtime.contracts import (
    Agent,
    CorrectionRecord,
    CorrectionSummary,
    Dispatch,
    EscalationStop,
    Node,
    Nonblank,
    Report,
)
from factory.runtime.contracts import EscalationPolicy as EscalationPolicy
from factory.runtime.contracts import State as State
from factory.runtime.contracts import agent_key as agent_key
from factory.runtime.escalation_policy import CAUSES as CAUSES
from factory.runtime.escalation_policy import configure as configure
from factory.runtime.escalation_policy import correction_decision
from factory.runtime.escalation_policy import guard as guard
from factory.runtime.escalation_policy import limits as limits
from factory.runtime.escalation_policy import routing as routing
from factory.runtime.workflow_core import digest as digest
from factory.runtime.workflow_core import snapshot as snapshot
from factory.runtime.workflow_graph import ancestors as ancestors
from factory.runtime.workflow_graph import validate_assignment_lineage
from factory.runtime.workflow_graph import validate_graph as validate_graph
from factory.tasks.contracts import Task
from factory.validation import validation_message


class CorrectionLedger(Protocol):
    root: Path

    def check_sources(self, state: State, task: Task) -> None: ...
    def save(self, state: State, event: str, **details: object) -> None: ...


CORRECTION_RECORD = TypeAdapter[CorrectionRecord](CorrectionRecord)

ACTIVE = {"reserved", "running", "unknown"}


@with_config(ConfigDict(strict=True, extra="forbid"))
class CorrectionRequest(TypedDict):
    author_dispatch_id: Nonblank
    evidence_node: Nonblank
    evidence_dispatch_id: Nonblank
    cause: Literal["static", "tests", "docs", "review"]
    kind: Literal["quality", "environment", "requirements"]
    reason: Nonblank
    terminal_evidence: Nonblank
    handoff: Nonblank


CORRECTION_REQUEST = TypeAdapter[CorrectionRequest](CorrectionRequest)


@dataclass(frozen=True)
class CorrectionEvidence:
    nodes: dict[str, Node]
    node: Node
    task_id: str
    assignment: Agent
    profile_id: str
    policy: EscalationPolicy
    report: Report


@dataclass(frozen=True)
class CorrectionDecision:
    failures: int
    budget_cause: Literal["static", "tests", "docs", "review", "recovery"]
    used: int
    budget: int
    target: str
    decision: Literal["blocked", "human", "retry", "escalate"]


def correct(ledger: CorrectionLedger, state: State, node_id: str, raw: object) -> CorrectionRecord:
    # Called under the ledger lock. All changes are committed in one save.
    try:
        request = CORRECTION_REQUEST.validate_python(raw)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid correction request", exc, CORRECTION_REQUEST)
        ) from None
    identity = [
        node_id,
        request["author_dispatch_id"],
        request["evidence_node"],
        request["evidence_dispatch_id"],
    ]
    existing = next((r for r in state.get("corrections", []) if r["identity"] == identity), None)
    if existing:
        ensure(
            existing["request_hash"]
            == digest(json.dumps(request, sort_keys=True, ensure_ascii=False).encode()),
            "Conflicting decision for the same evidence",
        )
        return copy(existing)  # Replay never spends budget or replaces a session.
    evidence = validate_correction(ledger, state, node_id, request, identity)
    decision = choose_correction(state, request, evidence)
    return apply_correction(ledger, state, node_id, request, identity, evidence, decision)


def validate_correction(
    ledger: CorrectionLedger,
    state: State,
    node_id: str,
    request: CorrectionRequest,
    identity: list[str],
) -> CorrectionEvidence:
    nodes = validate_graph(state["graph"], state["config"], ledger.root)
    ensure(node_id in nodes and request["evidence_node"] in nodes, "Unknown correction node")
    node, evidence_node = nodes[node_id], nodes[request["evidence_node"]]
    task_id = node["task"]
    assignment = state["graph"]["agents"][agent_key(node)]
    profile_id = assignment["profile"]
    profile = state["config"]["profiles"][profile_id]
    policy = profile.get("escalation")
    if not policy:
        raise ValueError("Profile has no escalation policy")
    ensure(assignment["role"] in {"developer", "test-writer"}, "Unsupported correction specialty")
    guard(state, task_id, profile_id, node_id)
    ensure(
        not any(v["status"] in ACTIVE for v in state["nodes"].values()),
        "Quiesce runtime before correction decision",
    )
    current, evidence = state["nodes"][node_id], state["nodes"][request["evidence_node"]]
    ensure(
        current.get("dispatch_id") == request["author_dispatch_id"]
        and current.get("profile") == profile_id,
        "Stale author assignment",
    )
    historical = report_history.historical(
        ledger.root, state, request["evidence_node"], request["evidence_dispatch_id"]
    )
    report = historical["report"]
    original = historical["assignment"]
    if not isinstance(report, dict) or not isinstance(original, dict):
        raise ValueError("Invalid historical report or assignment")
    ensure(
        report.get("terminal") is True and report.get("outcome") in {"FAIL", "BLOCKED"},
        "Need terminal failed/blocked report",
    )
    integration_evidence = evidence_node["task"] != task_id
    if integration_evidence:
        ensure(
            evidence_node["stage"] in {"verify", "review"}
            and state["graph"]["agents"][agent_key(evidence_node)]["role"] == "judge"
            and task_id in review_findings.review_tasks(state, evidence_node["task"]),
            "Cross-task correction needs integration review evidence",
        )
    ensure(
        (evidence_node["task"] == task_id or integration_evidence)
        and (node_id == evidence_node["id"] or node_id in ancestors(nodes, evidence_node["id"])),
        "Evidence must belong to this task or integration and depend on the corrected work",
    )
    relevant_findings = [
        item
        for item in state.get("review_findings", {}).get(task_id, {}).values()
        if item.get("owner_node_id") == node_id
        and any(
            event.get("dispatch_id") == request["evidence_dispatch_id"] for event in item["history"]
        )
    ]
    if relevant_findings or integration_evidence:
        ensure(
            any(
                item.get("status") == "open"
                and item.get("reviewed", {}).get("dispatch_id") == request["evidence_dispatch_id"]
                for item in relevant_findings
            ),
            "Correction needs an unresolved current finding assigned to this author",
        )
    ensure(
        evidence.get("dispatch_id") == request["evidence_dispatch_id"]
        and evidence["status"] == "blocked",
        "Historical failure was superseded; need a current unresolved obligation",
    )
    evidence_task = state["graph"]["tasks"][evidence_node["task"]]
    original_scope = original["task"]["scope"]
    ensure(
        set(original_scope) == set(evidence_task["scope"]),
        "Historical scope requires current verification",
    )
    ensure(
        original["task"]["required_checks"] == evidence_task["required_checks"],
        "Historical requirements need current verification",
    )
    ensure(
        report.get("files") == snapshot(ledger.root, original_scope),
        "Correction evidence is stale for current files; historical report retained",
    )
    ensure(
        not any(
            r["kind"] == "quality" and r["node_id"] == node_id and r["identity"][2:] == identity[2:]
            for r in state.get("corrections", [])
        ),
        "Failure incident already counted",
    )
    ledger.check_sources(state, state["graph"]["tasks"][task_id])
    ledger.check_sources(state, evidence_task)
    ensure(
        not report.get("observed_source_drift")
        and report.get("source_hash") == state["graph"]["sources"][evidence_task["source"]]["hash"],
        "Source drift requires current evidence after re-intake",
    )
    if request["kind"] == "quality":
        ensure(
            report.get("stage_result")
            not in {
                "NEEDS_PLANNING",
                "SOURCE_DRIFT",
                "BLOCKED_TOOL_ERROR",
                "BLOCKED_UNTESTABLE",
                "GOLDEN_DIFF",
                "APPROVAL_REQUIRED",
                "BEHAVIOR_CHANGE",
            },
            "Diagnose the real blocker first",
        )
    if request["kind"] == "quality":
        static_failure = (
            report.get("stage_result") == "BLOCKED_STATIC_FAILURE" and request["cause"] == "static"
        )
        ensure(
            report.get("outcome") == "FAIL"
            or (static_failure and report.get("outcome") == "BLOCKED"),
            "Quality failure needs FAIL or a diagnosed static failure, not a transport or planning blocker",
        )
        ensure(
            report.get("stage_result")
            not in {
                "WRITES_READY",
                "NEEDS_PLANNING",
                "SOURCE_DRIFT",
                "BLOCKED_TOOL_ERROR",
                "BLOCKED_UNTESTABLE",
            },
            "Diagnose the real blocker first",
        )
        ensure(
            report.get("unsuccessful_attempt")
            or report.get("evidence")
            or any(
                c.get("execution_id") and c.get("result") == "FAIL"
                for c in report.get("checks", [])
            )
            or any(
                item.get("blocking") and item.get("evidence") for item in report.get("findings", [])
            ),
            "Quality correction needs evidence of actual unsuccessful work",
        )
        if report.get("stage_result") == "FAIL_CODE":
            ensure(
                assignment["role"] == "developer", "FAIL_CODE belongs to Developer, not TestWriter"
            )
        if report.get("stage_result") == "FAIL_TEST":
            ensure(assignment["role"] == "test-writer", "FAIL_TEST belongs to TestWriter")
    else:
        ensure(report.get("outcome") == "BLOCKED", "Non-quality diagnosis needs a BLOCKED report")
    return CorrectionEvidence(nodes, node, task_id, assignment, profile_id, policy, report)


def choose_correction(
    state: State,
    request: CorrectionRequest,
    evidence: CorrectionEvidence,
) -> CorrectionDecision:
    task_id, profile_id, policy = evidence.task_id, evidence.profile_id, evidence.policy
    failures = sum(
        r["task_id"] == task_id
        and r["cause"] == request["cause"]
        and r["from_profile"] == profile_id
        and r["kind"] == "quality"
        for r in state.get("corrections", [])
    )
    failures += request["kind"] == "quality"
    budget_cause = "recovery" if request["kind"] == "environment" else request["cause"]
    used = state["counters"].get(task_id + ":" + budget_cause, 0)
    budget = limits(state, task_id)[budget_cause]
    target, decision = correction_decision(
        request["kind"], profile_id, policy, failures, used, budget
    )
    return CorrectionDecision(failures, budget_cause, used, budget, target, decision)


def apply_correction(
    ledger: CorrectionLedger,
    state: State,
    node_id: str,
    request: CorrectionRequest,
    identity: list[str],
    evidence: CorrectionEvidence,
    choice: CorrectionDecision,
) -> CorrectionRecord:
    nodes, node, task_id = evidence.nodes, evidence.node, evidence.task_id
    assignment, profile_id, report = evidence.assignment, evidence.profile_id, evidence.report
    failures, budget_cause, used, budget = (
        choice.failures,
        choice.budget_cause,
        choice.used,
        choice.budget,
    )
    target, decision = choice.target, choice.decision
    record: CorrectionRecord = dict(
        identity=identity,
        request_hash=digest(json.dumps(request, sort_keys=True, ensure_ascii=False).encode()),
        task_id=task_id,
        node_id=node_id,
        source_hash=state["graph"]["sources"][state["graph"]["tasks"][task_id]["source"]]["hash"],
        from_profile=profile_id,
        to_profile=target,
        kind=request["kind"],
        cause=request["cause"],
        reason=request["reason"],
        terminal_evidence=request["terminal_evidence"],
        handoff=request["handoff"],
        failure_count=failures,
        decision=decision,
        evidence=deepcopy(report),
        at=time.time(),
        budget_cause=budget_cause,
        budget_remaining=budget,
    )
    if decision in {"blocked", "human"}:
        state.setdefault("escalation_stops", {})[task_id] = dict(
            reason=request["reason"],
            decision="human" if decision == "human" else "blocked",
            node_id=node_id,
            kind=request["kind"],
            cause=request["cause"],
            budget_exhausted=used >= budget,
        )
    else:
        affected = {node_id} | {k for k in nodes if node_id in ancestors(nodes, k)}
        if target != profile_id:
            # Only the diagnosed author's affected assignments move. Independent
            # siblings keep their dispatch identity until diagnosed themselves.
            old_agent = agent_key(node)
            next_graph = deepcopy(state["graph"])
            new_agent = old_agent + "-e" + str(len(state.get("corrections", [])) + 1)
            ensure(new_agent not in next_graph["agents"], "Correction agent identity collision")
            replacements = {old_agent: new_agent}
            next_graph["agents"][new_agent] = dict(role=assignment["role"], profile=target)
            record["reassigned_nodes"] = []
            for n in next_graph["nodes"]:
                if n["task"] == task_id and n["id"] in affected and n.get("agent") == old_agent:
                    n["agent"] = new_agent
                    record["reassigned_nodes"].append(n["id"])
                    state.setdefault("retired_node_profiles", {}).setdefault(n["id"], []).append(
                        profile_id
                    )
            record["agents"] = replacements
            validate_graph(next_graph, state["config"], ledger.root)
            validate_assignment_lineage(
                next_graph,
                state["config"],
                [*state.get("corrections", []), record],
            )
            state["events"].append(
                dict(at=time.time(), event="correction_graph", previous_graph=state["graph"])
            )
            state["graph"] = next_graph
            state["revision"] += 1
            # The old handle keeps its owner; bind cannot reuse it for the new agent.
            # Physical termination is verified by the coordinator, not inferred here.
        for key in affected:
            old = state["nodes"][key]
            state["events"].append(
                dict(at=time.time(), event="invalidated", node=key, previous=old)
            )
            state["nodes"][key] = dict(status="pending", attempt=old["attempt"])
        if request["kind"] == "quality":
            state["counters"][task_id + ":" + request["cause"]] = used + 1
    record["budget_cause"] = budget_cause
    record["budget_remaining"] = budget - state["counters"].get(task_id + ":" + budget_cause, 0)
    validated = CORRECTION_RECORD.validate_python(record)
    state.setdefault("corrections", []).append(validated)
    ledger.save(state, "correction_decided", node=node_id, decision=decision, target=target)
    return record


def possible_actions(state: State, node: Node, dispatch: Dispatch) -> list[str]:
    """Show coordinator operations whose diagnosis still needs evidence."""
    report = dispatch.get("report", {})
    if report.get("stage_result") == "APPROVAL_REQUIRED":
        return ["resume-approved"]
    if node["task"] in state.get("escalation_stops", {}):
        return ["resume-task"]
    if report.get("observed_source_drift"):
        return ["reintake"]
    if report.get("terminal") and dispatch.get("role") in {"developer", "test-writer", "judge"}:
        return ["correct"]
    return ["retry"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class SessionHandoff(TypedDict):
    agent: Nonblank
    handoff: Nonblank


@with_config(ConfigDict(strict=True, extra="forbid"))
class BlockerResolution(TypedDict):
    evidence: Nonblank
    previous: EscalationStop


@with_config(ConfigDict(strict=True, extra="forbid"))
class RemainingRetries(TypedDict):
    static: int
    tests: int
    docs: int
    recovery: int
    review: int


@with_config(ConfigDict(strict=True, extra="forbid"))
class WorkerCorrection(TypedDict):
    history: list[CorrectionSummary]
    session_handoffs: list[SessionHandoff]
    blocker_resolutions: list[BlockerResolution]
    remaining_retries: RemainingRetries
    instruction: Nonblank


def worker_context(state: State, task_id: str) -> WorkerCorrection:
    """Facts for this task only, without the coordinator's target/threshold policy."""
    history: list[CorrectionSummary] = [
        {
            "identity": list(record["identity"]),
            "source_hash": record["source_hash"],
            "from_profile": record["from_profile"],
            "kind": record["kind"],
            "cause": record["cause"],
            "reason": record["reason"],
            "handoff": record["handoff"],
            "evidence": deepcopy(record["evidence"]),
        }
        for record in state.get("corrections", [])
        if record["task_id"] == task_id
    ]
    remaining = {
        k: v - state["counters"].get(task_id + ":" + k, 0)
        for k, v in limits(state, task_id).items()
    }
    handoffs: list[SessionHandoff] = [
        {"agent": e["agent"], "handoff": e["task_handoffs"][task_id]}
        for e in state["events"]
        if e["event"] == "session_replaced" and task_id in e.get("task_handoffs", {})
    ]
    resolutions: list[BlockerResolution] = [
        {"evidence": e["evidence"], "previous": cast(EscalationStop, e["previous"])}
        for e in state["events"]
        if e["event"] == "task_resumed" and e["task"] == task_id
    ]
    return {
        "history": history,
        "session_handoffs": handoffs,
        "blocker_resolutions": resolutions,
        "remaining_retries": {
            "static": remaining["static"],
            "tests": remaining["tests"],
            "docs": remaining["docs"],
            "recovery": remaining["recovery"],
            "review": remaining["review"],
        },
        "instruction": "Past reports are historical. Verify current files and source; do not retry or choose another worker yourself.",
    }
