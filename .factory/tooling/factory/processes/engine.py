"""Resolve and commit one transition of a pinned standalone process."""

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any, Never, cast
from uuid import uuid4

from pydantic_graph import Graph, StepContext
from pydantic_graph.step import StepFunction

from factory.database.provider import current_database
from factory.dependency_graph import run_program
from factory.graphs.definition import load
from factory.graphs.program import Operations, compile_program
from factory.paths import FACTORY_ROOT
from factory.processes.records import Attempt, Process, ProcessRun, ProcessState
from factory.runtime.workflow_core import Invalid, digest, graph_identity, lock, relative, require


@dataclass(frozen=True)
class Offer:
    action: str
    role: str | None = None
    reason: str | None = None


def offer(action: str, role: str | None = None) -> StepFunction:
    async def execute(ctx: StepContext) -> Offer:
        return Offer(action, role)

    return execute


def reject(_: ProcessRun, reason: str) -> Never:
    raise Invalid(reason)


def register(
    phases: tuple[str, ...], decision: str, actions: Mapping[str, StepFunction]
) -> Operations:
    def at(phase: str) -> Callable[[ProcessRun], bool]:
        return lambda run: run.state.phase == phase

    return Operations(
        actions,
        {decision: {phase: at(phase) for phase in phases}},
        reject,
        inputs=dict.fromkeys([decision, *actions], ProcessRun),
    )


@lru_cache(maxsize=32)
def program(entry: Process, definitions: tuple[tuple[str, str], ...]) -> Graph:
    from factory.processes import decompose, planning
    from factory.review import review_run

    if entry == "retune":
        from factory.runtime.scheduling.teacher_dispatch import delivery_graph

        return delivery_graph("teacher", definitions)
    registries = {
        "code-review": review_run.operations,
        "planning": planning.operations,
        "decompose": decompose.operations,
    }
    return compile_program(entry, dict(definitions), registries[entry](), batch=False)


def resolve(run: ProcessRun) -> Offer:
    if run.process == "retune":
        return Offer("teacher", "teacher")
    try:
        selected = cast(
            Offer,
            run_program(program(run.process, tuple(sorted(run.definitions.items()))), inputs=run),
        )
    except Invalid as exc:
        return Offer("hold", reason=str(exc))
    if selected.action == "prepare-publication" and run.state.phase != "approved":
        return Offer(
            "hold",
            reason="Independent approval of the current candidate is required before publication",
        )
    if selected.action == "publish" and run.state.phase != "install_ready":
        return Offer("hold", reason="An owned prepared publication is required before installation")
    return selected


def handlers() -> dict[str, str]:
    tooling = FACTORY_ROOT / "tooling/factory"
    return {
        path.relative_to(tooling).as_posix(): digest(path.read_bytes())
        for folder in ("graphs", "processes", "planning", "decompose", "review", "gates", "project")
        for path in (tooling / folder).rglob("*.py")
    } | {
        name: digest((tooling / name).read_bytes())
        for name in (
            "dependency_graph.py",
            "file_reader.py",
            "runtime/workflow_core.py",
            "runtime/knowledge/retune.py",
            "runtime/teacher.py",
            "runtime/scheduling/teacher_dispatch.py",
            "runtime/commands/process.py",
            "database/sqlite/sqlite_process_repository.py",
        )
    }


def identifier(process: Process, key: str) -> str:
    return process + "-" + graph_identity([process, key])[:28]


def start(
    root: Path,
    process: Process,
    key: str,
    subject: dict[str, Any],
    definition_dir: Path,
    *,
    definitions: dict[str, str] | None = None,
) -> ProcessRun:
    require(key.strip(), "Need a stable intake request")
    run_id = identifier(process, key)
    repo = current_database().processes
    docs = definitions if definitions is not None else load(definition_dir, process)
    program(process, tuple(sorted(docs.items())))
    run = ProcessRun(
        run_id=run_id,
        process=process,
        subject=subject,
        definitions=docs,
        handlers=handlers(),
        state=ProcessState(phase="intake"),
        revision=0,
    )
    return repo.create(root, run)


def status(run: ProcessRun, *, verify: bool = True) -> dict[str, Any]:
    changed = verify and handlers() != run.handlers
    permitted = resolve(run) if not changed else Offer("restore_handlers")
    active = run.state.attempts.get(permitted.action, [])
    actual = active[-1] if active else None
    action = permitted.action
    if run.state.terminal:
        action = run.state.terminal
    elif run.state.paused:
        action = "resume"
    elif actual and actual.status in {"reserved", "unknown"}:
        action = "reconcile"
    elif actual and actual.status == "running":
        action = "continue"
    step = (
        "packet"
        if action == "continue"
        else "status"
        if action in {"reconcile", "restore_handlers", "hold"}
        else "history"
        if run.state.terminal
        else "claim"
        if permitted.role and action == permitted.action
        else action
    )
    if permitted.action == "planning" and action == "planning":
        step = "status"
    command = [run.process, "run", step, "--run", run.run_id]
    if step == "packet" and actual is not None:
        command.extend(["--dispatch", actual.dispatch, "--handle", actual.handle or "HANDLE"])
    elif step not in {"history", "status"}:
        command.extend(["--request", "REQUEST_ID"])
    if step == "answer":
        command.extend(["--reference", "OWNER_REFERENCE", "--evidence", "ANSWER"])
    elif step == "review":
        command.extend(
            [
                "--actor",
                "COORDINATOR",
                "--basis",
                run.state.facts["candidate"]["sha256"],
                "--outcome",
                "approved",
                "--evidence",
                "ASSESSMENT",
                "--reference",
                "OWNER_APPROVAL",
                "--file",
                "APPROVED_PLAN",
            ]
        )
    elif step == "authorize-repair":
        command.extend(
            [
                "--actor",
                run.state.facts["reviewer"],
                "--allow",
                "PATH",
                "--reference",
                "REPAIR_AUTHORITY",
            ]
        )
    return {
        "run_id": run.run_id,
        "process": run.process,
        "revision": run.revision,
        "command": command,
        "alternatives": [
            [
                run.process,
                "run",
                "review",
                "--run",
                run.run_id,
                "--request",
                "REQUEST_ID",
                "--actor",
                "COORDINATOR",
                "--basis",
                run.state.facts["candidate"]["sha256"],
                "--outcome",
                "needs_work",
                "--evidence",
                "FINDINGS",
            ]
        ]
        if step == "review"
        else [],
        "phase": run.state.phase,
        "action": action,
        "node": permitted.action,
        "role": permitted.role,
        "paused": run.state.paused,
        "dispatch": actual.model_dump() if actual else None,
        "reason": "Registered process handlers changed"
        if changed
        else permitted.reason or run.state.paused or run.state.facts.get("reason"),
        "terminal": run.state.terminal,
    }


def active(run: ProcessRun, node: str, dispatch: str | None) -> Attempt:
    attempts = run.state.attempts.get(node, [])
    require(
        attempts and dispatch and attempts[-1].dispatch == dispatch,
        "Wrong process assignment ticket",
    )
    return attempts[-1]


def ticket(run: ProcessRun, dispatch: str | None) -> Attempt:
    for attempts in run.state.attempts.values():
        if attempts and attempts[-1].dispatch == dispatch:
            return attempts[-1]
    raise Invalid("Wrong process assignment ticket")


def claim(run: ProcessRun, selected: Offer) -> dict[str, Any]:
    role = selected.role
    require(role is not None, "Step belongs to the coordinator or owner")
    assert role is not None
    attempts = run.state.attempts.setdefault(selected.action, [])
    if attempts and attempts[-1].status != "failed" and attempts[-1].status != "done":
        prior = attempts[-1]
        return {"action": "reconcile", **prior.model_dump()}
    require(len(attempts) < 3, "Assignment attempt budget exhausted")
    new = Attempt(node=selected.action, role=role, dispatch=uuid4().hex, number=len(attempts) + 1)
    attempts.append(new)
    return {"action": "spawn", **new.model_dump()}


type Effect = Callable[[ProcessRun, Offer], dict[str, Any]]


def change(
    root: Path, process: Process, run_id: str, key: str, event: str, inputs: object, apply: Effect
) -> dict[str, Any]:
    require(key.strip(), "Need a stable request ID")
    repo = current_database().processes
    fingerprint = graph_identity([event, inputs])
    with lock(
        relative(root, ".factory/memory/process-locks/" + graph_identity(run_id) + ".lock"),
        wait=True,
    ):
        run = repo.get(root, run_id)
        require(run.process == process, "Run belongs to another process")
        if (previous := repo.receipt(root, run_id, key, fingerprint)) is not None:
            return previous
        require(not run.state.terminal, "Process run is closed")
        if event not in {"cancel", "stopped"}:
            require(handlers() == run.handlers, "Registered process handlers changed")
        if event not in {"resume", "cancel", "stopped"}:
            require(not run.state.paused, "Process is paused")
        result = apply(run, resolve(run))
        repo.save(root, run, key, fingerprint, event, result)
        return result
