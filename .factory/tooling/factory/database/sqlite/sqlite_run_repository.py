"""SQLite implementation of the workflow run repository."""

from pathlib import Path

from factory.database.sqlite import (
    artifacts,
    sqlite_history_repository,
    sqlite_teacher_job_repository,
    workflow_db,
)
from factory.database.sqlite.sqlite_history_repository import cleanup_paths as cleanup_paths
from factory.runtime.contracts import State
from factory.runtime.knowledge.teacher_models import TeacherJob
from factory.runtime.run_repository import ArchiveReference
from factory.runtime.workflow_core import digest, relative, require


def has_current(root: Path) -> bool:
    return workflow_db.current_row(root) is not None


def create_run(root: Path, state: State, evidence: tuple[artifacts.Artifact, ...]) -> None:
    workflow_db.save(root, state, create=True, evidence=evidence)


def save_progress(root: Path, state: State, evidence: tuple[artifacts.Artifact, ...]) -> None:
    workflow_db.save(root, state, evidence=evidence)


def store_artifact(root: Path, run: str, artifact: artifacts.Artifact) -> None:
    with workflow_db.database(root) as db:
        artifacts.put(db, run, artifact)


def get_current(root: Path) -> State:
    return sqlite_history_repository.current(root)


def release_current(root: Path, run: str) -> None:
    workflow_db.clean(root, run)


def reference(root: Path, run_id: str, *, stored_source: str | None = None) -> ArchiveReference:
    source = workflow_db.DATABASE if stored_source is None else stored_source
    return ArchiveReference(source, str(relative(root, source)))


def commit_archive(
    root: Path,
    state: State,
    usage: dict[str, object],
    pending: dict[str, tuple[str, str, str]],
    review: TeacherJob | None,
) -> None:
    with workflow_db.database(root) as db:
        raw = sqlite_history_repository.journal_record(db, root, state, usage, pending)
        require(
            db.execute(
                "UPDATE runs SET record=?, sha256=? WHERE run_id=? AND current=1 AND status='active'",
                (raw.decode(), digest(raw), state["run_id"]),
            ).rowcount
            == 1,
            "Run already closed",
        )
        if review is not None:
            sqlite_teacher_job_repository.insert_event(db, review)
