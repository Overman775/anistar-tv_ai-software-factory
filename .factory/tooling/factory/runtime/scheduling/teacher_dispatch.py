"""Issue and reconcile a specific Teacher assignment across coordinator processes."""

from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Literal, Never, cast
from uuid import NAMESPACE_URL, uuid5

from pydantic_graph import Graph, StepContext

from factory.dependency_graph import run_program
from factory.graphs.program import Operations, compile_program
from factory.paths import MEMORY
from factory.runtime import teacher
from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
from factory.runtime.knowledge.teacher_models import (
    TeacherAssignment,
    TeacherAttempt,
    TeacherProfile,
)
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid, lock, relative, require


def ticket(key: str, number: int) -> str:
    return uuid5(NAMESPACE_URL, f"factory/teacher/{key}/{number}").hex


def current_ticket(key: str, event: TeacherAssignment) -> str:
    if event.attempts and event.attempts[-1].status != "stopped":
        return event.attempts[-1].dispatch_id
    return ticket(key, len(event.attempts) + 1)


@dataclass
class Request:
    action: Literal["claim", "bind", "release"]
    event: TeacherAssignment
    key: str
    dispatch: str
    value: str
    root: Path

    def attempt(self) -> TeacherAttempt | None:
        return next((a for a in self.event.attempts if a.dispatch_id == self.dispatch), None)


async def reserve(ctx: StepContext) -> dict[str, object]:
    req = cast(Request, ctx.inputs)
    require(not req.event.done and not req.event.waiting_for, "Teacher event is closed or waiting")
    require(req.action == "claim" and req.attempt() is None, "Teacher assignment already issued")
    require(req.dispatch == current_ticket(req.key, req.event), "Stale Teacher assignment ticket")
    profile: TeacherProfile = req.event.profile or teacher.launch_profile(
        load_config(req.root / ".factory/factory.yaml")
    )
    req.event.attempts.append(TeacherAttempt(dispatch_id=req.dispatch))
    return {
        **profile,
        "action": "spawn" if profile["profile"].get("runner") != "acpx" else "prepare_acp",
        "dispatch_id": req.dispatch,
        "event_id": req.key,
    }


async def inspect(ctx: StepContext) -> dict[str, object]:
    req = cast(Request, ctx.inputs)
    attempt = req.attempt()
    require(attempt is not None, "Teacher assignment not found")
    assert attempt is not None
    return {
        "action": "reconcile",
        "event_id": req.key,
        "dispatch_id": attempt.dispatch_id,
        "handle": attempt.handle,
        "status": "done" if req.event.done else attempt.status,
        "ticket": current_ticket(req.key, req.event),
    }


async def reconcile(ctx: StepContext) -> dict[str, object]:
    req = cast(Request, ctx.inputs)
    require(
        not req.event.done and req.value.strip(), "Need an open Teacher event and observed evidence"
    )
    attempt = req.attempt()
    require(attempt is not None and attempt is req.event.attempts[-1], "Stale Teacher assignment")
    assert attempt is not None
    require(req.action in {"bind", "release"}, "Missing Teacher observation")
    if req.action == "bind":
        require(
            attempt.status != "stopped" and attempt.handle in (None, req.value),
            "Teacher handle mismatch",
        )
        attempt.handle, attempt.status = req.value, "running"
    else:
        require(attempt.evidence in (None, req.value), "Teacher reconciliation evidence changed")
        attempt.evidence, attempt.status = req.value, "stopped"
    return {
        "event_id": req.key,
        **attempt.model_dump(),
        "ticket": current_ticket(req.key, req.event),
    }


async def event_status(ctx: StepContext) -> dict[str, object]:
    req = cast(Request, ctx.inputs)
    return {
        "event_id": req.key,
        "action": "done" if req.event.done else "wait",
        "question": req.event.waiting_for,
    }


def reject(_: Request, reason: str) -> Never:
    raise Invalid(reason)


@lru_cache(maxsize=16)
def delivery_graph(entry: str, documents: tuple[tuple[str, str], ...]) -> Graph:
    decisions = {
        "teacher_event": {
            "observation": lambda r: r.action != "claim",
            "prior_assignment": lambda r: r.attempt() is not None,
            "waiting": lambda r: r.event.waiting_for is not None,
            "completed": lambda r: r.event.done,
            "claim": lambda r: r.action == "claim",
        }
    }
    actions = {
        "reserve_teacher": reserve,
        "inspect_teacher": inspect,
        "reconcile_teacher": reconcile,
        "wait_for_owner": event_status,
        "completed_event": event_status,
    }
    return compile_program(
        entry,
        dict(documents),
        Operations(
            actions, decisions, reject, inputs=dict.fromkeys([*actions, *decisions], Request)
        ),
        batch=False,
    )


def deliver(
    root: Path,
    key: str,
    requested: str | None,
    bind: list[str] | None,
    stopped: list[str] | None,
    jobs: TeacherJobRepository,
) -> dict[str, object]:
    with lock(relative(root, f"{MEMORY}/teacher/write.lock"), wait=True):
        event = teacher.read_event(root, key, jobs=jobs)
        teacher.require_checkout(root, event)
        latest = event.attempts[-1].dispatch_id if event.attempts else ticket(key, 1)
        dispatch, value = bind or stopped or [requested or latest, ""]
        req = Request(
            "bind" if bind else "release" if stopped else "claim", event, key, dispatch, value, root
        )
        result = cast(
            dict[str, object],
            run_program(
                delivery_graph(event.graph_entry, tuple(sorted(event.definitions.items()))),
                inputs=req,
            ),
        )
        if result.get("action") not in {"reconcile", "wait", "done"}:
            teacher.update_event(root, key, event, jobs=jobs)
        return result
