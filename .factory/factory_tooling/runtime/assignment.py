"""Project ledger state into a worker assignment; context only assembles materials."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
from typing import Any, cast

from factory_tooling.context import context
from factory_tooling.runtime import escalation, review_findings
from factory_tooling.runtime.contracts import (
    Node,
    State,
    agent_key,
)


def dependency_results(state: State, node: Node) -> dict[str, Any]:
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

    results: dict[str, Any] = {}
    for key in sorted(selected):
        saved = state["nodes"][key]
        item: dict[str, Any] = {
            "status": saved["status"],
            "task_id": nodes[key]["task"],
        }
        if "report" in saved:
            report = deepcopy(saved["report"])
            # Verification needs original evidence; workers can inspect bulky hash maps on demand.
            if node["stage"] not in {"verify", "review"}:
                report.pop("files", None)
            item["report"] = report
            item["report_ref"] = {
                "path": ".factory/memory/state/workflow.json",
                "keys": ["nodes", key, "report"],
                "run_id": state["run_id"],
                "dispatch_id": saved["report"]["dispatch_id"],
            }
        results[key] = item
    return results


def worker_node(node: Node) -> Node:
    return cast(Node, {k: deepcopy(v) for k, v in node.items() if k != "profile_selection"})


def implement_packet(state: State, node_id: str) -> dict[str, Any]:
    node = next(n for n in state["graph"]["nodes"] if n["id"] == node_id)
    current = state["nodes"][node_id]
    task = state["graph"]["tasks"][node["task"]]
    agent = state["graph"]["agents"][agent_key(node)]
    envelope = dict(
        run_id=state["run_id"],
        node_id=node_id,
        dispatch_id=current["dispatch_id"],
        task_id=node["task"],
        slice_id=task["slice"],
        task=task,
        node=worker_node(node),
        source=state["graph"]["sources"][task["source"]],
        source_hash=state["graph"]["sources"][task["source"]]["hash"],
        dependency_results=dependency_results(state, node),
        acceptance_sources=state["graph"]["sources"] if task["kind"] == "integration" else {},
        integration_tasks=state["graph"]["tasks"] if task["kind"] == "integration" else {},
        integration_owners={
            n["id"]: {
                "task_id": n["task"],
                "role": state["graph"]["agents"][agent_key(n)]["role"],
                "owns": n["owns"],
            }
            for n in state["graph"]["nodes"]
            if n.get("owns")
        }
        if task["kind"] == "integration"
        else {},
        review_findings=review_findings.view(state, node["task"]),
        correction=escalation.worker_context(state, node["task"]),
    )
    if state["config"]["profiles"][agent["profile"]]["runner"] == "acpx":
        envelope["report_path"] = str(
            Path(state["workspace"])
            / ".factory/memory"
            / "state"
            / f"{state['run_id']}-{node_id}-{current['dispatch_id']}.report.json"
        )
    return context.build(
        state["config"],
        state["workspace"],
        agent["profile"],
        agent["role"],
        "implement",
        envelope,
    )
