"""One checkout's workflow state, Teacher outbox and packet receipts."""

import sqlite3
from collections.abc import Iterator
from contextlib import closing, contextmanager
from contextvars import ContextVar
from pathlib import Path

from factory.database.sqlite import graph_state
from factory.database.sqlite.artifacts import Artifact, put
from factory.database.sqlite.layout import check_layout, preflight_recovery
from factory.database.sqlite.workflow_schema import SCHEMA
from factory.diagnostics.events import event
from factory.diagnostics.records import error_code
from factory.runtime.contracts import State
from factory.runtime.observability import export_policy
from factory.runtime.state_io import parse_state
from factory.runtime.workflow_core import Invalid, relative, require

DATABASE = ".factory/memory/workflow.sqlite3"


def _configure_collection(db: sqlite3.Connection, enabled: bool) -> None:
    """Store committed source references in delivery order, never duplicate source payloads."""
    for table, key, changed in (("runs", "run_id", "status"), ("teacher_jobs", "id", "done")):
        # Eligibility follows the whole lifecycle. A dev-created or mixed run stays local.
        if enabled:
            db.execute(f"""CREATE TEMP TRIGGER otlp_begin_{table} AFTER INSERT ON main.{table}
                BEGIN UPDATE {table} SET otlp_eligible=1 WHERE {key}=NEW.{key}; END""")
        else:
            db.execute(f"""CREATE TEMP TRIGGER otlp_exclude_{table} AFTER UPDATE OF {changed} ON main.{table}
                WHEN OLD.otlp_eligible=1
                BEGIN UPDATE {table} SET otlp_eligible=0 WHERE {key}=NEW.{key}; END""")
    if not enabled:
        return
    now = "strftime('%Y-%m-%dT%H:%M:%fZ','now')"
    for kind, table, transition, condition, ref, at in (
        (
            "run",
            "runs",
            "UPDATE OF sha256",
            "NEW.otlp_eligible=1 AND NEW.sha256 IS NOT NULL AND OLD.sha256 IS NULL",
            "NEW.run_id",
            now,
        ),
        (
            "search",
            "lesson_searches",
            "INSERT",
            "NEW.run_id IS NULL OR EXISTS (SELECT 1 FROM runs WHERE run_id=NEW.run_id AND otlp_eligible=1)",
            "NEW.id",
            "NEW.at",
        ),
        (
            "teacher",
            "teacher_jobs",
            "UPDATE OF done",
            "NEW.otlp_eligible=1 AND NEW.done=1 AND OLD.done=0",
            "NEW.id",
            "NEW.updated_at",
        ),
    ):
        uid = "lower(hex(randomblob(16)))"
        if kind == "teacher":
            # A pending run finalizer already has a local observation ID.
            uid = f"CASE WHEN NEW.kind='accept' THEN 'teacher:' || NEW.id ELSE {uid} END"
        db.execute(f"""CREATE TEMP TRIGGER telemetry_{kind} AFTER {transition} ON main.{table}
            WHEN {condition} BEGIN INSERT INTO telemetry_feed(kind,ref,at,eligible,event_id)
            VALUES ('{kind}',{ref},{at},1,{uid}); END""")


_READ_ONLY = ContextVar("workflow_read_only", default=False)


@contextmanager
def read_only() -> Iterator[None]:
    """Prevent workflow reads from creating a database during preview."""
    token = _READ_ONLY.set(True)
    try:
        yield
    finally:
        _READ_ONLY.reset(token)


@contextmanager
def database(root: Path, *, timeout: float = 5) -> Iterator[sqlite3.Connection]:
    path = relative(root, DATABASE)
    read_only = _READ_ONLY.get()
    if not read_only:
        path.parent.mkdir(parents=True, exist_ok=True)
    for suffix in ("-wal", "-shm", "-journal"):
        relative(root, DATABASE + suffix)
    try:
        if not read_only:
            preflight_recovery(path, SCHEMA, "workflow database", timeout)
        source = path.as_uri() + "?mode=ro" if read_only else path
        with closing(sqlite3.connect(source, timeout=timeout, uri=read_only)) as db, db:
            db.execute("PRAGMA foreign_keys=ON")
            check_layout(db, SCHEMA, "workflow database", initialize=not read_only)
            if db.in_transaction:
                db.commit()
            if not read_only:
                _configure_collection(db, export_policy.enabled(root))
            yield db
    except sqlite3.Error as exc:
        event("database_failed", component="workflow_store", error_code=error_code(exc))
        raise Invalid(f"Workflow database: {exc}") from exc


def current_row(root: Path) -> tuple[str, str | None] | None:
    if not relative(root, DATABASE).is_file():
        return None
    with database(root) as db:
        row = db.execute("SELECT run_id,sha256 FROM runs WHERE current=1").fetchone()
        return (row[0], row[1]) if row else None


def save(
    root: Path, state: State, *, create: bool = False, evidence: tuple[Artifact, ...] = ()
) -> None:
    state = parse_state(state)
    with database(root) as db:
        values = (
            state["status"],
            state["revision"],
            state["workspace"],
            state.get("summary"),
            state["config"]["_project"]["data"]["id"],
            state["run_id"],
        )
        if create:
            db.execute(
                "INSERT INTO runs(status,revision,workspace,summary,project_id,run_id,current) VALUES (?,?,?,?,?,?,1)",
                values,
            )
        else:
            require(
                db.execute(
                    "UPDATE runs SET status=?,revision=?,workspace=?,summary=?,project_id=? WHERE run_id=? AND current=1 AND sha256 IS NULL",
                    values,
                ).rowcount
                == 1,
                "Run is not current",
            )
        graph_state.write(db, state)
        for item in evidence:
            put(db, state["run_id"], item)


def clean(root: Path, run: str) -> None:
    with database(root) as db:
        require(
            db.execute(
                "UPDATE runs SET current=0 WHERE run_id=? AND current=1 AND sha256 IS NOT NULL AND status IN ('completed','cancelled')",
                (run,),
            ).rowcount
            == 1,
            "Run is not terminal and current",
        )
