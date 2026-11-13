"""Project ledger state into a worker assignment; context only assembles materials."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any, NotRequired

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory_tooling.context import context
from factory_tooling.runtime import (
    escalation,
    finish_requirements,
    report_history,
    review_findings,
)
from factory_tooling.runtime.contracts import (
    FindingView,
    LockedSource,
    Node,
    ReportRef,
    ReportSummary,
    State,
    Task,
    agent_key,
)
from factory_tooling.validation import validation_message


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
            if "report_ref" in saved:
                item["report_ref"] = saved["report_ref"]
        results[key] = item
    return results


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
        review_findings=review_findings.view(
            state, node["task"], include_dependencies=integration_verifier
        ),
        correction=escalation.worker_context(state, node["task"]),
    )
    if state["config"]["profiles"][agent["profile"]]["runner"] == "acpx":
        envelope["report_path"] = str(
            Path(state["workspace"])
            / ".factory/memory"
            / "state"
            / f"{state['run_id']}-{node_id}-{current['dispatch_id']}.report.json"
        )
    packet = context.build(
        state["config"],
        state["workspace"],
        agent["profile"],
        agent["role"],
        "implement",
        envelope,
    )
    packet["task"] = projected_task(task, node, obligations)
    return dict(validate_packet(packet))
