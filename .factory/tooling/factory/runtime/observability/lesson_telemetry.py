"""Lesson trace collection and public read projection."""

import time
from pathlib import Path
from typing import Any

from factory.database.provider import current_database
from factory.runtime.knowledge.lesson_trace_repository import (
    ApplicationRow as ApplicationRow,
)
from factory.runtime.knowledge.lesson_trace_repository import (
    LessonTrace as LessonTrace,
)
from factory.runtime.knowledge.lesson_trace_repository import (
    LessonTraceRepository,
)
from factory.runtime.knowledge.lesson_trace_repository import (
    SearchHit as SearchHit,
)
from factory.runtime.knowledge.lesson_trace_repository import (
    SearchRow as SearchRow,
)
from factory.runtime.knowledge.lesson_trace_repository import (
    TeacherRow as TeacherRow,
)


def record_search(
    root: Path,
    run_id: str | None,
    dispatch_id: str | None,
    query: str,
    start: float,
    matches: list[SearchHit],
    error: str | None,
    catalog_sha256: str | None = None,
    *,
    store: LessonTraceRepository | None = None,
) -> None:
    store = current_database().traces if store is None else store
    elapsed = int((time.monotonic() - start) * 1000)
    store.record_search(root, run_id, dispatch_id, query, elapsed, matches, error, catalog_sha256)


def read_trace(
    root: Path, run: str | None, limit: int, *, store: LessonTraceRepository | None = None
) -> LessonTrace:
    store = current_database().traces if store is None else store
    return store.read_trace(root, run, limit)


def report(
    root: Path, run: str | None, limit: int, *, store: LessonTraceRepository | None = None
) -> dict[str, Any]:
    """Return the public JSON-compatible projection for programmatic callers."""
    return read_trace(root, run, limit, store=store).model_dump()
