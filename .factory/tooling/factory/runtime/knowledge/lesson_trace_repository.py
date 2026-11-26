"""Local evidence of lesson retrieval, worker reports and Teacher decisions."""

from pathlib import Path
from typing import Literal, Protocol

from pydantic import BaseModel, ConfigDict, Field
from typing_extensions import TypedDict

from factory.runtime.contracts import CardChange, LessonId, LessonScope


class SearchHit(TypedDict):
    id: LessonId
    scope: LessonScope
    revision: str


class TraceRow(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", hide_input_in_errors=True)


class SearchRow(TraceRow):
    id: int
    at: str
    run_id: str | None
    node_id: str | None
    dispatch_id: str | None
    elapsed_ms: int
    status: Literal["hit", "miss", "error"]
    query_sha256: str
    matches: list[SearchHit]
    error_type: str | None


class ApplicationRow(TraceRow):
    report_id: int
    run_id: str
    node_id: str | None
    dispatch_id: str | None
    report_path: str
    report_outcome: str
    lesson_id: LessonId
    revision: str
    result: str
    search_id: int | None


class TeacherRow(TraceRow):
    id: str
    created_at: str
    updated_at: str
    status: Literal["cancelled", "completed", "waiting", "pending"]
    kind: Literal["accept", "retro", "user"]
    operation: Literal["capture", "edit", "audit", "delete"]
    run_id: str | None
    changes: list[CardChange]
    reason: str | None


class LessonTrace(TraceRow):
    run_id: str | None
    search_counts: dict[str, int] = Field(default_factory=lambda: {"hit": 0, "miss": 0, "error": 0})
    reported_applications: int = 0
    teacher_counts: dict[str, int] = Field(default_factory=dict)
    searches: list[SearchRow] = Field(default_factory=list)
    applications: list[ApplicationRow] = Field(default_factory=list)
    teacher: list[TeacherRow] = Field(default_factory=list)


class LessonTraceRepository(Protocol):
    def record_search(
        self,
        root: Path,
        run_id: str | None,
        dispatch_id: str | None,
        query: str,
        elapsed: int,
        matches: list[SearchHit],
        error: str | None,
        catalog_sha256: str | None,
    ) -> None: ...
    def read_trace(self, root: Path, run: str | None, limit: int) -> LessonTrace: ...
