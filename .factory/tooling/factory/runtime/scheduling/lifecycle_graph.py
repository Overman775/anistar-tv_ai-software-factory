"""Orchestrator control commands, archive gates and atomic dispatch of its final Teacher job."""

from __future__ import annotations

import time
from dataclasses import dataclass
from functools import cache
from typing import TYPE_CHECKING, Literal, cast

from pydantic_graph import Graph, GraphBuilder, StepContext

from factory.dependency_graph import run_program
from factory.diagnostics.events import event
from factory.runtime import teacher
from factory.runtime.contracts import State
from factory.runtime.knowledge.teacher_models import TeacherJob
from factory.runtime.observability import acpx_usage as telemetry
from factory.runtime.run_repository import ArchiveReference
from factory.runtime.transport import evidence as transport_evidence
from factory.runtime.workflow_core import Invalid, require

if TYPE_CHECKING:
    from factory.runtime.workflow import Ledger


@dataclass(frozen=True)
class Control:
    action: Literal["pause", "resume", "complete", "cancel"]
    ledger: Ledger
    state: State
    reason: str
    probe: telemetry.SessionProbe | None = None


@dataclass(frozen=True)
class Finalizing:
    command: Control
    reference: ArchiveReference


@dataclass(frozen=True)
class Archive:
    prepared: Finalizing
    review: TeacherJob | None = None


async def pause(ctx: StepContext) -> None:
    c = cast(Control, ctx.inputs)
    require(c.state["status"] == "active", "Run is not active")
    require(c.reason.strip(), "User pause/stop reason required")
    c.state["pause_reason"] = c.reason
    c.ledger.save(c.state, "paused", reason=c.reason)


async def resume(ctx: StepContext) -> None:
    c = cast(Control, ctx.inputs)
    require(c.state["status"] == "active", "Run is not active")
    require(c.state.get("pause_reason"), "Run is not paused")
    del c.state["pause_reason"]
    c.ledger.save(c.state, "resumed")


async def terminal_gate(ctx: StepContext) -> Control:
    c = cast(Control, ctx.inputs)
    require(c.reason, "Final summary required")
    require(not c.ledger.active_commands(c.state), "Unresolved project commands")
    return c


async def archived_result(ctx: StepContext) -> str:
    c = cast(Control, ctx.inputs)
    expected = "completed" if c.action == "complete" else "cancelled"
    require(
        c.state["status"] == expected and c.state["summary"] == c.reason,
        "Terminal history is immutable",
    )
    c.ledger.runs.cleanup_paths(c.ledger.root, c.state)
    return c.ledger.runs.reference(
        c.ledger.root, c.state["run_id"], stored_source=c.state["archive_path"]
    ).location


async def quiescent_run(ctx: StepContext) -> Finalizing:
    c = cast(Control, ctx.inputs)
    require(
        all(
            v["status"] not in {"reserved", "running", "unknown"} for v in c.state["nodes"].values()
        ),
        "Outstanding runtime work",
    )
    c.state["summary"] = c.reason
    ref = c.ledger.runs.reference(c.ledger.root, c.state["run_id"])
    c.state["archive_path"] = ref.source
    return Finalizing(c, ref)


async def completion_gate(ctx: StepContext) -> Finalizing:
    prepared = cast(Finalizing, ctx.inputs)
    c = prepared.command
    c.ledger.check_completion(c.state)
    c.state["status"] = "completed"
    return prepared


async def schedule_teacher(ctx: StepContext) -> Archive:
    prepared = cast(Finalizing, ctx.inputs)
    c = prepared.command
    review = teacher.run_review_event(c.state)
    c.state["final_teacher_event"] = review.key()
    return Archive(prepared, review)


async def cancel(ctx: StepContext) -> Archive:
    prepared = cast(Finalizing, ctx.inputs)
    from factory.runtime.scheduling.orchestrator_graph import Checkpoint, Hold
    from factory.runtime.workflow_config import check_config

    command = prepared.command
    state = command.state
    try:
        check_config(state)
    except Invalid as exc:
        state["route_holds"] = {"run": str(exc)}
    else:
        nodes = {node["id"]: node for node in state["graph"]["nodes"]}
        outcomes = Checkpoint(state, nodes, command.ledger).evaluate(list(nodes))
        state["route_holds"] = {
            key: outcome.reason
            for key, outcome in outcomes.items()
            if isinstance(outcome, Hold) and outcome.required == "resolve_graph"
        }
    prepared.command.state["status"] = "cancelled"
    return Archive(prepared)


async def seal_archive(ctx: StepContext) -> str:
    archive = cast(Archive, ctx.inputs)
    c = archive.prepared.command
    state, ledger = c.state, c.ledger
    pending = transport_evidence.pending_transports(ledger.root, state)
    usage = telemetry.collect(state, probe=c.probe)
    state["events"].append({"event": "archived", "at": time.time()})
    ledger.runs.commit_archive(ledger.root, state, usage, pending, archive.review)
    event("archived", run_id=state["run_id"], outcome=state["status"])
    return archive.prepared.reference.location


@cache
def lifecycle_graph() -> Graph:
    b = GraphBuilder(name="RunLifecycle", input_type=Control, auto_instrument=False)
    pause_step, resume_step = b.step(pause), b.step(resume)
    terminal, archived, quiet = (
        b.step(terminal_gate),
        b.step(archived_result),
        b.step(quiescent_run),
    )
    complete, cancelled = b.step(completion_gate), b.step(cancel)
    teacher_step, seal = b.step(schedule_teacher), b.step(seal_archive)
    command = (
        b.decision(node_id="run_command")
        .branch(b.match(Control, matches=lambda c: c.action == "pause").to(pause_step))
        .branch(b.match(Control, matches=lambda c: c.action == "resume").to(resume_step))
        .branch(b.match(Control).to(terminal))
    )
    existing = (
        b.decision(node_id="archive_state")
        .branch(b.match(Control, matches=lambda c: c.state["status"] != "active").to(archived))
        .branch(b.match(Control).to(quiet))
    )
    outcome = (
        b.decision(node_id="terminal_outcome")
        .branch(b.match(Finalizing, matches=lambda p: p.command.action == "complete").to(complete))
        .branch(b.match(Finalizing).to(cancelled))
    )
    b.add_edge(b.start_node, command)
    b.add_edge(terminal, existing)
    b.add_edge(quiet, outcome)
    b.add_edge(complete, teacher_step)
    b.add(b.edge_from(teacher_step, cancelled).to(seal))
    b.add(b.edge_from(seal, archived, pause_step, resume_step).to(b.end_node))
    return b.build()


def set_paused(ledger: Ledger, reason: str | None) -> None:
    with ledger.locked():
        command = Control(
            "resume" if reason is None else "pause", ledger, ledger.read(), reason or ""
        )
        run_program(lifecycle_graph(), inputs=command)


def archive(
    ledger: Ledger, outcome: str, summary: str, probe: telemetry.SessionProbe | None
) -> str:
    if outcome not in ("completed", "cancelled"):
        raise Invalid("Only terminal runs can be archived")
    with ledger.locked():
        command = Control(
            "complete" if outcome == "completed" else "cancel",
            ledger,
            ledger.read(),
            summary,
            probe,
        )
        return cast(str, run_program(lifecycle_graph(), inputs=command))
