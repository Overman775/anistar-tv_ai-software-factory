"""SQLite implementation of the database port. Load only the section in use."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from factory.diagnostics.diagnostic_journal import DiagnosticJournal
    from factory.runtime.history.history_repository import HistoryRepository
    from factory.runtime.knowledge.case_index import CaseIndex
    from factory.runtime.knowledge.lesson_index import LessonIndex
    from factory.runtime.knowledge.lesson_trace_repository import LessonTraceRepository
    from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
    from factory.runtime.observability.export_feed import ExportFeed, ObservationReader
    from factory.runtime.packets.repository import PacketRepository
    from factory.runtime.run_repository import RunRepository


class SQLiteDatabaseBackend:
    """Route each operation to the SQLite database that owns its data."""

    @property
    def runs(self) -> RunRepository:
        from factory.database.sqlite import sqlite_run_repository

        return sqlite_run_repository

    @property
    def history(self) -> HistoryRepository:
        from factory.database.sqlite import sqlite_history_repository

        return sqlite_history_repository

    @property
    def packets(self) -> PacketRepository:
        from factory.database.sqlite import sqlite_packet_repository

        return sqlite_packet_repository

    @property
    def teacher(self) -> TeacherJobRepository:
        from factory.database.sqlite import sqlite_teacher_job_repository

        return sqlite_teacher_job_repository

    @property
    def lessons(self) -> LessonIndex:
        from factory.database.sqlite import sqlite_lesson_index

        return sqlite_lesson_index

    @property
    def traces(self) -> LessonTraceRepository:
        from factory.database.sqlite import sqlite_lesson_trace_repository

        return sqlite_lesson_trace_repository

    @property
    def cases(self) -> CaseIndex:
        from factory.database.sqlite import sqlite_case_index

        return sqlite_case_index

    @property
    def observations(self) -> ObservationReader:
        from factory.database.sqlite import sqlite_export_feed

        return sqlite_export_feed

    @property
    def exports(self) -> ExportFeed:
        from factory.database.sqlite import sqlite_export_feed

        return sqlite_export_feed

    @property
    def diagnostics(self) -> DiagnosticJournal:
        from factory.database.sqlite import sqlite_diagnostic_journal

        return sqlite_diagnostic_journal

    def has_active_workflow(self, factory_root: Path) -> bool:
        """Read-only preflight runs before the factory environment or package exists."""
        import sqlite3
        from contextlib import closing

        state = factory_root / "memory/workflow.sqlite3"
        if not state.exists():
            return False
        with closing(sqlite3.connect(state.resolve().as_uri() + "?mode=ro", uri=True)) as db:
            return (
                db.execute("SELECT 1 FROM runs WHERE current=1 AND status='active'").fetchone()
                is not None
            )
