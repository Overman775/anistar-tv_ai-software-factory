"""Project ledger state into a worker assignment; context only assembles materials."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any, NotRequired

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.context import context
from factory.dependency_graph import compile_dependencies
from factory.runtime import upstream
from factory.runtime.agent_commands import check_commands, factory_command
from factory.runtime.contracts import (
    FindingView,
    LockedSource,
    Node,
    ReportRef,
    ReportSummary,
    State,
    agent_key,
)
from factory.runtime.history import report_history
from factory.runtime.reports import finish_requirements, review_findings
from factory.runtime.reports.summary import (
    REPORT_SUMMARY,
    compact_tester_report,
    initial_review_facts,
    unchanged_readiness,
)
from factory.runtime.scheduling import escalation
from factory.runtime.workflow_core import graph_identity
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
    source_resolutions: NotRequired[dict[str, str]]
    report_command: str
    check_commands: NotRequired[list[dict[str, str]]]


IMPLEMENT_PACKET = TypeAdapter[ImplementPacket](ImplementPacket)


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
    visible = {
        key: [dep for dep in item["depends_on"] if nodes[dep]["task"] in allowed]
        for key, item in nodes.items()
        if item["task"] in allowed
    }
    selected = compile_dependencies(visible).ancestors(node["id"])

    writers = [
        key for key in selected if nodes[key]["task"] == node["task"] and nodes[key].get("owns")
    ]
    initial_review = (
        node["stage"] == "review"
        and state["nodes"][node["id"]].get("attempt", 0) <= 1
        and not state.get("review_findings", {}).get(node["task"])
        and bool(writers)
        and all(unchanged_readiness(state["nodes"][key]) for key in writers)
    )
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
            if (
                initial_review
                and predecessor["task"] == node["task"]
                and role in {"implementer", "tester"}
                and item["report"]["outcome"] == "PASS"
            ):
                item["report"] = initial_review_facts(item["report"])
            if "report_ref" in saved:
                item["report_ref"] = saved["report_ref"]
        results[key] = item
    return results


def correction_context(state: State, task_id: str) -> escalation.WorkerCorrection:
    correction = escalation.worker_context(state, task_id)
    nodes = {node["id"]: node for node in state["graph"]["nodes"]}
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
            # A pre-execution blocker can have only the worker’s observation.
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


def projected_source(source: LockedSource, task: Task, node: Node) -> LockedSource:
    if "upstream_tasks" not in source or (
        task["kind"] == "integration" and node["stage"] in {"verify", "review"}
    ):
        return source
    result = source.copy()
    result["upstream_tasks"] = {
        key: original for key, original in source["upstream_tasks"].items() if key == node["task"]
    }
    return result


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
        source=projected_source(source, task, node),
        finish_requirements=obligations,
        report_command=factory_command(
            Path(state["workspace"]),
            state["config"]["_path"],
            "workflow",
            "prepare-report",
            node_id,
            "-",
        ),
        assignment_sha256=graph_identity(report_history.assignment(state, node, obligations)),
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
    if resolutions := upstream.resolution_evidence(state, node["task"]):
        packet["source_resolutions"] = resolutions
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
