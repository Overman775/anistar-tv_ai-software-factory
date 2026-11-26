"""Queue operations consumed by the Teacher workflow."""

from collections.abc import Callable
from pathlib import Path
from typing import Protocol

from factory.runtime.contracts import ReportRef
from factory.runtime.knowledge.teacher_models import SearchEvidence, TeacherJob


class TeacherJobRepository(Protocol):
    def read(self, root: Path, key: str) -> TeacherJob: ...
    def enqueue_once(self, root: Path, key: str, prepare: Callable[[], TeacherJob]) -> None: ...
    def update(self, root: Path, key: str, event: TeacherJob) -> None: ...
    def pending(
        self, root: Path, waiting: bool, checkout: Callable[[], str | None]
    ) -> list[str]: ...
    def feedback(
        self, root: Path, refs: list[ReportRef], run: str, current: str
    ) -> list[SearchEvidence]: ...
