"""Application-facing operations for one database backend."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, Protocol

if TYPE_CHECKING:
    from factory.diagnostics.diagnostic_journal import DiagnosticJournal
    from factory.processes.records import ProcessRepository
    from factory.runtime.history.history_repository import HistoryRepository
    from factory.runtime.knowledge.case_index import CaseIndex
    from factory.runtime.knowledge.lesson_index import LessonIndex
    from factory.runtime.knowledge.lesson_trace_repository import LessonTraceRepository
    from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
    from factory.runtime.observability.export_feed import ExportFeed, ObservationReader
    from factory.runtime.packets.repository import PacketRepository
    from factory.runtime.run_repository import RunRepository


class DatabaseBackend(Protocol):
    """A backend supplies all sections together, including the pre-installation guard."""

    @property
    def processes(self) -> ProcessRepository: ...

    @property
    def runs(self) -> RunRepository: ...

    @property
    def history(self) -> HistoryRepository: ...

    @property
    def packets(self) -> PacketRepository: ...

    @property
    def teacher(self) -> TeacherJobRepository: ...

    @property
    def lessons(self) -> LessonIndex: ...

    @property
    def traces(self) -> LessonTraceRepository: ...

    @property
    def cases(self) -> CaseIndex: ...

    @property
    def observations(self) -> ObservationReader: ...

    @property
    def exports(self) -> ExportFeed: ...

    @property
    def diagnostics(self) -> DiagnosticJournal: ...

    def has_active_workflow(self, factory_root: Path) -> bool:
        """Check for an active run before changing the venv, without initializing a database."""
        ...
