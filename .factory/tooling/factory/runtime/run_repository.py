"""Storage operations needed by a workflow journal for one checkout."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING, Protocol

from factory.runtime.contracts import State
from factory.runtime.history.artifact_ref import Artifact

if TYPE_CHECKING:
    from factory.runtime.knowledge.teacher_models import TeacherJob


@dataclass(frozen=True)
class ArchiveReference:
    """Durable Teacher source and the corresponding public command result."""

    source: str
    location: str


class RunRepository(Protocol):
    """Persist one checkout's run. The coordinator holds the lock across archive preparation and commit."""

    def publish_input(self, root: Path, kind: str, value: object) -> str: ...
    def read_input(self, root: Path, kind: str, key: str) -> object: ...
    def has_current(self, root: Path) -> bool: ...
    def get_current(self, root: Path) -> State: ...
    def create_run(self, root: Path, state: State, evidence: tuple[Artifact, ...]) -> None: ...
    def save_progress(self, root: Path, state: State, evidence: tuple[Artifact, ...]) -> None: ...
    def store_artifact(self, root: Path, run: str, artifact: Artifact) -> None: ...
    def cleanup_paths(self, root: Path, state: State) -> list[Path]: ...
    def release_current(self, root: Path, run: str) -> None: ...

    def reference(
        self, root: Path, run_id: str, *, stored_source: str | None = None
    ) -> ArchiveReference:
        """Locate a new archive, or resolve its recorded source on an identical retry."""
        ...

    def commit_archive(
        self,
        root: Path,
        state: State,
        usage: dict[str, object],
        pending: dict[str, tuple[str, str, str]],
        review: TeacherJob | None,
    ) -> None:
        """Seal the current active run, evidence and optional Teacher event atomically."""
        ...
