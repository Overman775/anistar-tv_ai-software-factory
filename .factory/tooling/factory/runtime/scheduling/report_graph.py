"""Route a validated worker handoff through approval, project and stage gates."""

from dataclasses import dataclass
from functools import cache
from pathlib import Path
from typing import Literal, cast

from pydantic_graph import Graph, GraphBuilder, StepContext

from factory.dependency_graph import run_program
from factory.runtime.contracts import Node, Report, State
from factory.runtime.reports import approval, review_findings, transition_gates
from factory.runtime.workflow_core import Invalid, acceptance_guard, require
from factory.runtime.workflow_graph import validate_graph
from factory.tasks.contracts import Task


@dataclass(frozen=True)
class Handoff:
    root: Path
    state: State
    node: Node
    task: Task
    report: Report


@dataclass(frozen=True)
class Verdict:
    handoff: Handoff
    action: Literal["pass", "fail"]
    route: str


@dataclass(frozen=True)
class Rejected:
    node: str
    reason: str


async def project_gates(ctx: StepContext) -> Verdict | Rejected:
    h = cast(Handoff, ctx.inputs)
    try:
        h.report["gate_results"] = acceptance_guard(
            transition_gates.evaluate,
            h.state["config"]["_project"]["data"],
            h.node,
            h.task,
            h.report,
        )
    except Invalid as exc:
        return Rejected(h.node["id"], str(exc))
    return Verdict(h, "pass", "passed")


async def external_approval(ctx: StepContext) -> Verdict:
    h = cast(Handoff, ctx.inputs)
    require("approval_request" in h.report, "Invalid approval request: field required")
    approval.bind_request(h.root, h.state, h.node, h.task, h.report)
    validate_graph(approval.expanded_graph(h.state, h.node, h.report), h.state["config"], h.root)
    return Verdict(h, "fail", "await_approval")


async def request_checks(ctx: StepContext) -> Verdict:
    return Verdict(cast(Handoff, ctx.inputs), "fail", "revise_checks")


async def return_work(ctx: StepContext) -> Verdict:
    return Verdict(cast(Handoff, ctx.inputs), "fail", "correction")


async def stage_gate(ctx: StepContext) -> Verdict:
    v = cast(Verdict, ctx.inputs)
    h = v.handoff
    acceptance_guard(review_findings.apply, h.state, h.node, h.report)
    gate = transition_gates.stage_result(h.state, h.node, h.report)
    h.report["gate_results"] = [gate, *h.report.get("gate_results", [])]
    return v


@cache
def report_graph() -> Graph:
    b = GraphBuilder(name="Report", input_type=Handoff, auto_instrument=False)
    passed, approval_step = b.step(project_gates), b.step(external_approval)
    checks, correction, stage = b.step(request_checks), b.step(return_work), b.step(stage_gate)
    route = (
        b.decision(node_id="worker_verdict")
        .branch(
            b.match(
                Handoff,
                matches=lambda h: (
                    h.report.get("stage_result") == "APPROVAL_REQUIRED"
                    or "approval_request" in h.report
                ),
            ).to(approval_step)
        )
        .branch(b.match(Handoff, matches=lambda h: h.report["outcome"] == "PASS").to(passed))
        .branch(
            b.match(
                Handoff,
                matches=lambda h: (
                    h.node["stage"] == "review"
                    and h.report["outcome"] == "BLOCKED"
                    and h.report["stage_result"] == "CHECKS_REQUESTED"
                ),
            ).to(checks)
        )
        .branch(b.match(Handoff).to(correction))
    )
    b.add_edge(b.start_node, route)
    project_result = (
        b.decision(node_id="project_gate_result")
        .branch(b.match(Rejected).to(b.end_node))
        .branch(b.match(Verdict).to(stage))
    )
    b.add_edge(passed, project_result)
    b.add(b.edge_from(approval_step, checks, correction).to(stage))
    b.add_edge(stage, b.end_node)
    return b.build()


def evaluate(handoff: Handoff) -> Verdict:
    result = cast(Verdict | Rejected, run_program(report_graph(), inputs=handoff))
    if isinstance(result, Rejected):
        raise Invalid(result.reason)
    return result
