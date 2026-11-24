"""Journal access and integrity checks shared by workflow operations."""

from __future__ import annotations

import time
from contextlib import AbstractContextManager
from pathlib import Path
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory.database.provider import current_database
from factory.diagnostics.events import event as log_event
from factory.runtime.contracts import LedgerEvent, State
from factory.runtime.history.artifact_ref import Artifact
from factory.runtime.history.history_repository import HistoryRepository
from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
from factory.runtime.packets.repository import PacketRepository
from factory.runtime.run_repository import RunRepository
from factory.runtime.state_io import parse_state
from factory.runtime.workflow_core import Invalid, digest, lock, relative, require
from factory.tasks.contracts import Task
from factory.validation import validation_message

LEDGER_EVENT = TypeAdapter[LedgerEvent](LedgerEvent)


class RunJournal:
    """One checkout, its write lock, validated state and atomic event/evidence commits."""

    def __init__(
        self,
        workspace: str | Path,
        *,
        runs: RunRepository | None = None,
        packets: PacketRepository | None = None,
        jobs: TeacherJobRepository | None = None,
        history: HistoryRepository | None = None,
    ) -> None:
        self.history = current_database().history if history is None else history
        self.jobs = current_database().teacher if jobs is None else jobs
        self.packets = current_database().packets if packets is None else packets
        self.runs = current_database().runs if runs is None else runs
        self.root = Path(workspace).resolve()
        self.dir = self.root / ".factory/memory/state"
        self.diagnostic_state: dict[str, Any] | None = None
        self.diagnostic_attempt: tuple[str, str] | None = None

    def failure_context(
        self, node_id: object, *, expected_run: str | None = None
    ) -> dict[str, object]:
        state = self.diagnostic_state
        if state is None or (expected_run is not None and expected_run != state["run_id"]):
            return {}
        fields: dict[str, object] = {"run_id": state["run_id"]}
        if isinstance(node_id, str) and node_id in state["nodes"]:
            fields.update(node_id=node_id, task_id=state["nodes"][node_id])
            if self.diagnostic_attempt is not None and self.diagnostic_attempt[0] == node_id:
                fields["dispatch_id"] = self.diagnostic_attempt[1]
        return fields

    def locked(self, *, wait: bool = False) -> AbstractContextManager[None]:
        return lock(relative(self.root, ".factory/memory/state/workflow.lock"), wait=wait)

    def read(self) -> State:
        self.diagnostic_state = None
        self.diagnostic_attempt = None
        state = self.runs.get_current(self.root)
        self.diagnostic_state = {
            "run_id": state["run_id"],
            "nodes": {n["id"]: n["task"] for n in state["graph"]["nodes"]},
        }
        return state

    def save(self, state: State, event: str, **details: object) -> None:
        self.save_artifacts(state, event, (), **details)

    def save_artifacts(
        self,
        state: State,
        event: str,
        artifact_writes: tuple[Artifact, ...],
        /,
        **details: object,
    ) -> None:
        require(
            state["status"] == "active",
            "Terminal run is immutable; start a new authorized run",
        )
        try:
            state["events"].append(
                LEDGER_EVENT.validate_python({"at": time.time(), "event": event, **details})
            )
        except ValidationError as exc:
            raise Invalid(validation_message("Invalid workflow event", exc, LEDGER_EVENT)) from None
        parse_state(state)
        if event == "created":
            self.runs.create_run(self.root, state, artifact_writes)
        else:
            self.runs.save_progress(self.root, state, artifact_writes)
        _log_transition(state, event, details)

    def check_sources(self, state: State, task: Task) -> None:
        src = state["graph"]["sources"][task["source"]]
        require(digest(src["snapshot"].encode("utf-8")) == src["content_hash"], "SOURCE_DRIFT")

    def source_drifted(self, state: State, task: Task, outcome: str) -> bool:
        """Permit a terminal failure to record source drift; never hide other errors."""
        try:
            self.check_sources(state, task)
        except Invalid as exc:
            if str(exc) != "SOURCE_DRIFT" or outcome not in {"FAIL", "BLOCKED"}:
                raise
            return True
        return False


def _log_transition(state: State, event: str, details: dict[str, object]) -> None:
    node_id = details.get("node")
    node = next((n for n in state["graph"]["nodes"] if n["id"] == node_id), None)
    attempt = state["nodes"].get(node_id) if isinstance(node_id, str) else None
    event_fields: dict[str, object] = {"run_id": state["run_id"]}
    if node is not None:
        event_fields.update(node_id=node["id"], task_id=node["task"])
    elif isinstance(details.get("task"), str) and details["task"] in state["graph"]["tasks"]:
        event_fields["task_id"] = details["task"]
    if isinstance(details.get("dispatch_id"), str):
        event_fields["dispatch_id"] = details["dispatch_id"]
    elif attempt and attempt.get("dispatch_id"):
        event_fields["dispatch_id"] = attempt["dispatch_id"]
    elif event in {"retry", "correction_decided"}:
        for prior in reversed(state["events"][:-1]):
            if prior.get("event") != "invalidated":
                break
            if prior.get("node") == node_id:
                previous = prior.get("previous")
                if previous is not None and (dispatch_id := previous.get("dispatch_id")):
                    event_fields["dispatch_id"] = dispatch_id
                break
    if isinstance(details.get("result"), str) and details["result"] in {
        "PASS",
        "FAIL",
        "BLOCKED",
    }:
        event_fields["outcome"] = details["result"]
    if isinstance(details.get("outcome"), str) and details["outcome"] in {
        "PASS",
        "FAIL",
        "BLOCKED",
    }:
        event_fields["outcome"] = details["outcome"]
    if isinstance(details.get("execution_id"), str):
        event_fields["execution_id"] = details["execution_id"]
    if event.startswith("transport_") and details.get("operation") in (
        "create",
        "show",
        "status",
        "prompt",
        "cancel",
        "close",
    ):
        event_fields["transport_operation"] = details["operation"]
    if event == "transport_returned" and isinstance(details.get("exit_code"), int):
        event_fields["outcome"] = (
            "stale"
            if details.get("status") == "stale"
            else "success"
            if details["exit_code"] == 0
            else "failure"
        )
    log_event(event, **event_fields)
