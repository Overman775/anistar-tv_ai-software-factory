"""Committed observations and durable per-receiver delivery checkpoints."""

from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple, Protocol

from factory.runtime.knowledge.lesson_trace_repository import SearchRow
from factory.runtime.knowledge.teacher_models import TeacherJob
from factory.runtime.observability.acp_tools import ToolSummary
from factory.runtime.observability.acpx_usage import Session
from factory.runtime.observability.observations import ReportReference


class RunEvent(NamedTuple):
    kind: str
    at: float
    node: str | None
    dispatch: str | None
    outcome: str | None
    status: str | None
    role: str | None
    harness: str | None


class LessonApplication(NamedTuple):
    dispatch: str
    lesson: str
    revision: str
    outcome: str
    search: int | None
    search_uid: str | None


@dataclass
class TransportCall:
    ordinal: int
    dispatch: str
    node: str
    operation: str
    start: float
    end: float | None = None
    outcome: str = "unconfirmed"
    exit_code: int | None = None
    stale: bool = False
    tools: ToolSummary | None = None


class CheckObservation(NamedTuple):
    execution: str
    dispatch: str
    node: str
    check: str
    start: float
    end: float | None
    status: str
    exit_code: int | None


@dataclass(frozen=True)
class RunObservation:
    run: str
    project: str | None
    status: str
    at: str | None
    events: list[RunEvent]
    applications: list[LessonApplication]
    sessions: list[Session]
    transports: list[TransportCall]
    checks: list[CheckObservation]
    reports: dict[str, ReportReference]


@dataclass(frozen=True)
class SearchObservation:
    uid: str
    at: str
    project: str | None
    search: SearchRow


@dataclass(frozen=True)
class TeacherObservation:
    uid: str
    at: str
    project: str | None
    key: str
    created: str
    job: TeacherJob


type ObservationSource = RunObservation | SearchObservation | TeacherObservation


class ObservationReader(Protocol):
    def read_run(self, root: Path, run: str) -> list[ObservationSource]: ...


class ExportFeed(Protocol):
    def exists(self, root: Path) -> bool: ...
    def checkpoint(self, root: Path, key: str) -> tuple[int, int, int]: ...
    def next_observation(
        self, root: Path, after: int, until: int
    ) -> tuple[int, ObservationSource] | None: ...
    def acknowledge(self, root: Path, key: str, sequence: int, offset: int) -> None: ...
