"""Project ledger state into a worker assignment; context only assembles materials."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any, NotRequired

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.context import context
from factory.runtime.agent_commands import check_commands
from factory.runtime.contracts import (
    CheckEvidence,
    CheckResult,
    FindingView,
    LockedSource,
    Node,
    ReportRef,
    ReportSummary,
    State,
    agent_key,
)
from factory.runtime.history import report_history
from factory.runtime.history.artifact_ref import transport_report
from factory.runtime.reports import finish_requirements, review_findings
from factory.runtime.scheduling import escalation
from factory.tasks.contracts import Task
from factory.validation import validation_message


@with_config(ConfigDict(strict=True, extra="forbid"))
class DependencyResult(TypedDict):
    status: str
    task_id: str
    report: NotRequired[ReportSummary]
    report_ref: NotRequired[ReportRef]


@with_config(ConfigDict(strict=True, extra="forbid"))
class IntegrationOwner(TypedDict):
    task_id: str
    role: str
    owns: list[str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ImplementPacket(context.ContextPacket):
    run_id: str
    node_id: str
    dispatch_id: str
    task_id: str
    slice_id: str
    task: Task
    node: Node
    source: LockedSource
    finish_requirements: finish_requirements.FinishRequirements
    assignment_sha256: str
    source_hash: str
    dependency_results: dict[str, DependencyResult]
    acceptance_sources: dict[str, LockedSource]
    integration_tasks: dict[str, Task]
    integration_owners: dict[str, IntegrationOwner]
    review_findings: dict[str, FindingView]
    correction: escalation.WorkerCorrection
    report_path: NotRequired[str]
    check_commands: NotRequired[list[dict[str, str]]]


IMPLEMENT_PACKET = TypeAdapter[ImplementPacket](ImplementPacket)
REPORT_SUMMARY = TypeAdapter[ReportSummary](ReportSummary)


def validate_packet(value: object) -> ImplementPacket:
    try:
        packet = IMPLEMENT_PACKET.validate_python(value)
        if packet["process"] != "implement":
            raise ValueError("Invalid Implement packet process")
        return packet
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid Implement packet", exc, IMPLEMENT_PACKET)
        ) from None


def dependency_results(state: State, node: Node) -> dict[str, DependencyResult]:
    """Carry relevant predecessors across acceptance without importing the whole run."""
    nodes = {item["id"]: item for item in state["graph"]["nodes"]}
    task = state["graph"]["tasks"][node["task"]]
    allowed = {node["task"], *task.get("depends_on", [])}
    allowed.update(nodes[key]["task"] for key in node["depends_on"])
    pending = list(node["depends_on"])
    selected: set[str] = set()
    while pending:
        key = pending.pop()
        if key in selected or nodes[key]["task"] not in allowed:
            continue
        selected.add(key)
        pending.extend(nodes[key]["depends_on"])

    results: dict[str, DependencyResult] = {}
    for key in sorted(selected):
        saved = state["nodes"][key]
        item: DependencyResult = {
            "status": saved["status"],
            "task_id": nodes[key]["task"],
        }
        if "report" in saved:
            # Prose and finding details stay inline. The immutable original carries hash maps.
            item["report"] = REPORT_SUMMARY.validate_python(
                {key: deepcopy(value) for key, value in saved["report"].items() if key != "files"}
            )
            predecessor = nodes[key]
            predecessor_agent = state["graph"]["agents"].get(agent_key(predecessor))
            role = predecessor_agent["role"] if predecessor_agent is not None else None
            if role == "tester" and predecessor["stage"] == "verify":
                item["report"] = compact_tester_report(state, key, item["report"])
            if "report_ref" in saved:
                item["report_ref"] = saved["report_ref"]
        results[key] = item
    return results


def compact_tester_report(state: State, node_id: str, report: ReportSummary) -> ReportSummary:
    """Delivery projection only; original reports and immutable references stay intact."""
    result = deepcopy(report)
    result["summary"] = "Verification " + report["outcome"]
    result.pop("evidence", None)
    # Canonical findings and gate prose remain available through report_ref; their
    # duplicated free text can contain successful test names and full-suite output.
    result.pop("gate_results", None)
    result.pop("findings", None)
    checks: list[CheckResult] = []
    observations = []
    for check in report["checks"]:
        execution_id = check.get("execution_id")
        receipt = state.get("executions", {}).get(execution_id or "")
        linked = (
            receipt is not None
            and receipt["node_id"] == node_id
            and receipt["dispatch_id"] == report["dispatch_id"]
            and receipt["run_id"] == report["run_id"]
            and receipt["spec"]["id"] == check["id"]
        )
        status = (
            receipt["status"] if linked and receipt is not None else check.get("result", "BLOCKED")
        )
        if linked and receipt is not None:
            for observation in receipt.get("verification", []):
                observed = deepcopy(observation)
                if observed["scope"] == "unknown":
                    observed["scope"] = receipt.get("selection", {}).get(
                        "mode", receipt.get("mode", "unknown")
                    )
                for failure in observed["failures"]:
                    failure["check_id"] = check["id"]
                observations.append(observed)
            skipped_stages = [
                stage["spec"]["id"]
                for stage in receipt.get("composite_stages", [])
                if stage["execution_id"] not in state.get("executions", {})
            ]
            if skipped_stages:
                observations.append(
                    {
                        "suite": "combined-gate",
                        "scope": receipt.get("mode", "unknown"),
                        "phase": "not-executed",
                        "result": "BLOCKED",
                        "counts": {},
                        "failures": [],
                        "diagnostics": ["Not executed checks: " + ", ".join(skipped_stages)],
                    }
                )
        if status == "PASS":
            continue
        compact: CheckEvidence = {
            "id": check["id"],
            "result": status,
            "reason": "Structured diagnostics unavailable; inspect immutable report/check evidence",
        }
        if linked and receipt is not None:
            compact["evidence"] = receipt["output"]
            compact["execution_id"] = execution_id or ""
            if receipt.get("error"):
                compact["reason"] = receipt["error"] or ""
        checks.append(compact)
    counts: dict[str, int] = {}
    for observation in observations:
        for key, value in observation["counts"].items():
            counts[key] = counts.get(key, 0) + value
    scopes = {item["scope"] for item in observations}
    result["verification"] = [
        {
            "suite": "overall",
            "scope": next(iter(scopes)) if len(scopes) == 1 else "unknown",
            "phase": "verify",
            "result": result["outcome"],
            "counts": counts,
            "failures": [failure for item in observations for failure in item["failures"]],
            "diagnostics": [
                text
                for item in observations
                if item["result"] != "PASS"
                for text in item["diagnostics"]
            ]
            or (
                [
                    "Structured diagnostics unavailable; inspect immutable report/check evidence",
                    *(
                        [
                            "Unstructured reporter observation: "
                            + (report.get("evidence") or report["summary"])[:500]
                        ]
                        if report["outcome"] != "PASS"
                        else []
                    ),
                ]
                if not observations
                else []
            ),
        }
    ]
    result["checks"] = checks
    return result


def correction_context(state: State, task_id: str) -> escalation.WorkerCorrection:
    correction = escalation.worker_context(state, task_id)
    nodes = {node["id"]: node for node in state["graph"]["nodes"]}
    for entry in correction.get("history", []):
        report = entry["evidence"]
        node = nodes.get(report["node_id"])
        if node is None or node["stage"] != "verify":
            continue
        agent = state["graph"]["agents"].get(agent_key(node))
        if agent is None or agent["role"] != "tester":
            continue
        summary = REPORT_SUMMARY.validate_python(
            {key: value for key, value in report.items() if key != "files"}
        )
        entry["evidence"] = compact_tester_report(state, node["id"], summary)
        for event in reversed(state["events"]):
            previous = event.get("previous")
            if (
                isinstance(previous, dict)
                and previous.get("dispatch_id") == report["dispatch_id"]
                and "report_ref" in previous
            ):
                entry["report_ref"] = report_history.reference(dict(previous).get("report_ref"))
                break
    failures: list[escalation.VerificationFailureHandoff] = []
    seen = {entry["evidence"]["node_id"] for entry in correction.get("history", [])}
    for event in reversed(state["events"]):
        node_id = event.get("node")
        if node_id is None or node_id in seen or node_id not in nodes:
            continue
        node = nodes[node_id]
        previous = event.get("previous")
        if node["task"] != task_id or node["stage"] != "verify" or not isinstance(previous, dict):
            continue
        values = dict(previous)
        raw_report = values.get("report")
        if not isinstance(raw_report, dict):
            continue
        seen.add(node_id)
        current_report = state["nodes"][node_id].get("report")
        if raw_report.get("outcome") == "PASS" or (
            current_report is not None and current_report["outcome"] == "PASS"
        ):
            continue
        agent = state["graph"]["agents"].get(agent_key(node))
        if agent is None or agent["role"] != "tester":
            continue
        summary = REPORT_SUMMARY.validate_python(
            {key: value for key, value in raw_report.items() if key != "files"}
        )
        failure: escalation.VerificationFailureHandoff = {
            "historical": True,
            "report": compact_tester_report(state, node_id, summary),
        }
        if "report_ref" in values:
            failure["report_ref"] = report_history.reference(values["report_ref"])
        failures.append(failure)
    if failures:
        correction["verification_failures"] = failures
    return correction


def delivered_findings(
    state: State, task_id: str, *, include_dependencies: bool
) -> dict[str, FindingView]:
    """Project Tester prose from structured failures without altering finding history."""
    result = review_findings.view(state, task_id, include_dependencies=include_dependencies)
    nodes = {node["id"]: node for node in state["graph"]["nodes"]}
    for finding in result.values():
        tid, fid = finding.get("task_id", task_id), finding.get("id")
        if not isinstance(tid, str) or not isinstance(fid, str):
            continue
        record = state.get("review_findings", {}).get(tid, {}).get(fid)
        if record is None or not record["history"]:
            # Leave unresolvable projections intact for the canonical packet validator.
            continue
        origin = record["history"][0]
        node = nodes.get(origin["node_id"])
        if node is None or state["graph"]["agents"][agent_key(node)]["role"] != "tester":
            continue
        details = []
        for receipt in state.get("executions", {}).values():
            if (
                receipt["node_id"] != origin["node_id"]
                or receipt["dispatch_id"] != origin["dispatch_id"]
            ):
                continue
            for observation in receipt.get("verification", []):
                for failure in observation["failures"]:
                    detail = failure["name"] + ": " + failure["diagnostic"]
                    if failure.get("location"):
                        detail += " (" + failure["location"] + ")"
                    details.append(detail)
        if not details:
            # Legacy reports may contain the only actionable failure observation.
            continue
        evidence = "Originating Tester dispatch failure diagnostics:\n" + "\n".join(
            dict.fromkeys(details)
        )
        finding["summary"] = "Verification finding " + finding["id"]
        latest = record["history"][-1]
        latest_node = nodes.get(latest["node_id"])
        if (
            latest_node is not None
            and state["graph"]["agents"][agent_key(latest_node)]["role"] == "tester"
        ):
            finding["evidence"] = evidence
        reviewed = finding.get("reviewed")
        if reviewed is not None:
            reviewer = nodes.get(reviewed["node_id"])
            if (
                reviewer is not None
                and state["graph"]["agents"][agent_key(reviewer)]["role"] == "tester"
            ):
                reviewed["evidence"] = evidence
    return result


def worker_node(node: Node) -> Node:
    return deepcopy(node)


def projected_task(
    task: Task, node: Node, obligations: finish_requirements.FinishRequirements
) -> Task:
    if task["kind"] != "integration" or not node.get("owns"):
        return deepcopy(task)
    result = deepcopy(task)
    result.pop("depends_on", None)
    result["scope"] = node.get("owns", [])
    result["required_checks"] = obligations["allowed_checks"]
    result["acceptance_ids"] = [
        cid
        for cid in task["acceptance_ids"]
        if ":" not in cid
        or any(cid in check["criteria"] for check in obligations["allowed_checks"])
    ]
    return result


def implement_packet(state: State, node_id: str) -> dict[str, Any]:
    node = next(n for n in state["graph"]["nodes"] if n["id"] == node_id)
    current = state["nodes"][node_id]
    task = state["graph"]["tasks"][node["task"]]
    agent = state["graph"]["agents"][agent_key(node)]
    role = agent["role"]
    obligations = finish_requirements.requirements(
        state["config"]["_project"]["data"], node, task, role
    )
    integration_verifier = task["kind"] == "integration" and node["stage"] in {"verify", "review"}
    source = state["graph"]["sources"][task["source"]]
    envelope = dict(
        run_id=state["run_id"],
        node_id=node_id,
        dispatch_id=current["dispatch_id"],
        task_id=node["task"],
        slice_id=task["slice"],
        task=task,
        node=worker_node(node),
        source=source,
        finish_requirements=obligations,
        assignment_sha256=report_history.identity(
            report_history.assignment(state, node, obligations)
        ),
        source_hash=state["graph"]["sources"][task["source"]]["hash"],
        dependency_results=dependency_results(state, node),
        acceptance_sources={
            key: value for key, value in state["graph"]["sources"].items() if key != task["source"]
        }
        if integration_verifier
        else {},
        integration_tasks={
            key: value for key, value in state["graph"]["tasks"].items() if key != node["task"]
        }
        if integration_verifier
        else {},
        integration_owners={
            n["id"]: {
                "task_id": n["task"],
                "role": state["graph"]["agents"][agent_key(n)]["role"],
                "owns": n["owns"],
            }
            for n in state["graph"]["nodes"]
            if n.get("owns")
        }
        if integration_verifier
        else {},
        review_findings=delivered_findings(
            state, node["task"], include_dependencies=integration_verifier
        ),
        correction=correction_context(state, node["task"]),
    )
    if state["config"]["profiles"][agent["profile"]]["runner"] == "acpx":
        envelope["report_path"] = str(
            Path(state["workspace"])
            / transport_report(state["run_id"], node_id, current["dispatch_id"])
        )
    packet = dict(
        context.build(
            state["config"],
            state["workspace"],
            agent["profile"],
            agent["role"],
            "implement",
            envelope,
        )
    )
    packet["task"] = projected_task(task, node, obligations)
    if "project-checks" in node.get("resources", []):
        packet["check_commands"] = [
            check_commands(
                Path(state["workspace"]),
                state["config"]["_path"],
                state["run_id"],
                node_id,
                current["dispatch_id"],
                check["id"],
            )
            for check in obligations["allowed_checks"]
            if check["kind"] != "observation"
        ]
    return dict(validate_packet(packet))
