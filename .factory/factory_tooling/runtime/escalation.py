"""Coordinator policy validation and task-scoped correction transitions.

No model calls, backend cancellation, or worker-side routing. The caller verifies
terminal evidence, diagnosis and real capabilities before submitting a decision.
"""

from __future__ import annotations

import json
import time
from copy import deepcopy
from pathlib import Path
from typing import Any, Protocol

from factory_tooling.runtime import report_history
from factory_tooling.runtime import review_findings as review_findings
from factory_tooling.runtime.acceptance import ensure as ensure
from factory_tooling.runtime.contracts import Dispatch, Node, Task
from factory_tooling.runtime.contracts import EscalationPolicy as EscalationPolicy
from factory_tooling.runtime.contracts import State as State
from factory_tooling.runtime.contracts import agent_key as agent_key
from factory_tooling.runtime.escalation_policy import CAUSES as CAUSES
from factory_tooling.runtime.escalation_policy import configure as configure
from factory_tooling.runtime.escalation_policy import guard as guard
from factory_tooling.runtime.escalation_policy import limits as limits
from factory_tooling.runtime.workflow_core import digest as digest
from factory_tooling.runtime.workflow_core import snapshot as snapshot
from factory_tooling.runtime.workflow_graph import ancestors as ancestors
from factory_tooling.runtime.workflow_graph import validate_assignment_lineage
from factory_tooling.runtime.workflow_graph import validate_graph as validate_graph


class CorrectionLedger(Protocol):
    root: Path

    def check_sources(self, state: State, task: Task) -> None: ...
    def save(self, state: State, event: str, **details: object) -> None: ...


ACTIVE = {"reserved", "running", "unknown"}


def correction_decision(
    kind: str, profile_id: str, policy: EscalationPolicy, failures: int, used: int, budget: int
) -> tuple[str, str]:
    """Pure retry/escalation choice; no counters or sessions are changed here."""
    target = profile_id
    if kind in {"environment", "requirements"}:
        decision = "blocked"
    elif used >= budget:
        target, decision = "human", "human"
    else:
        if failures >= policy["after_failed_attempts"]:
            target = policy["to"]
        decision = (
            "human" if target == "human" else ("escalate" if target != profile_id else "retry")
        )
    return target, decision


def correct(ledger: CorrectionLedger, state: State, node_id: str, request: Any) -> dict[str, Any]:
    # Called under the ledger lock. All changes are committed in one save.
    if not (isinstance(request, dict)):
        raise ValueError("Correction requires a JSON decision")
    required = {
        "author_dispatch_id",
        "evidence_node",
        "evidence_dispatch_id",
        "cause",
        "kind",
        "reason",
        "terminal_evidence",
        "handoff",
    }
    if not (
        set(request) == required
        and all(isinstance(request[k], str) and request[k].strip() for k in required)
    ):
        raise ValueError(
            "Correction requires exact identities, cause, kind, reason, terminal_evidence and handoff"
        )
    ensure(
        request["kind"] in {"quality", "environment", "requirements"},
        "Unknown diagnosis",
    )
    ensure(request["cause"] in CAUSES, "Unknown correction cause")
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
        return existing  # Replay never spends budget, replaces a session or submits work twice.
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
    record = dict(
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
    )
    if decision in {"blocked", "human"}:
        state.setdefault("escalation_stops", {})[task_id] = dict(
            reason=request["reason"],
            decision=decision,
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
    state.setdefault("corrections", []).append(record)
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


def worker_context(state: State, task_id: str) -> dict[str, Any]:
    """Facts for this task only, without the coordinator's target/threshold policy."""
    history = []
    for record in state.get("corrections", []):
        if record["task_id"] == task_id:
            history.append(
                {
                    k: deepcopy(record[k])
                    for k in (
                        "identity",
                        "source_hash",
                        "from_profile",
                        "kind",
                        "cause",
                        "reason",
                        "handoff",
                        "evidence",
                    )
                }
            )
    remaining = {
        k: v - state["counters"].get(task_id + ":" + k, 0)
        for k, v in limits(state, task_id).items()
    }
    handoffs = [
        dict(agent=e["agent"], handoff=e["task_handoffs"][task_id])
        for e in state["events"]
        if e["event"] == "session_replaced" and task_id in e.get("task_handoffs", {})
    ]
    resolutions = [
        dict(evidence=e["evidence"], previous=e["previous"])
        for e in state["events"]
        if e["event"] == "task_resumed" and e["task"] == task_id
    ]
    return dict(
        history=history,
        session_handoffs=handoffs,
        blocker_resolutions=resolutions,
        remaining_retries=remaining,
        instruction="Past reports are historical. Verify current files and source; do not retry or choose another worker yourself.",
    )
