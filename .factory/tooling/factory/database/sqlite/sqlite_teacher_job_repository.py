"""Workflow database adapter for the Teacher outbox."""

import sqlite3
from collections.abc import Callable
from pathlib import Path

from factory.database.sqlite import graph_records, workflow_db
from factory.database.sqlite.lesson_hits import read_hits
from factory.runtime.contracts import ReportRef
from factory.runtime.knowledge.teacher_models import SearchEvidence, TeacherJob, decode_event
from factory.runtime.workflow_core import digest, require

COLUMNS = (
    "kind",
    "incident",
    "source",
    "operation",
    "observation",
    "checkout",
    "user_instructions",
    "user_sha256",
    "delete_target",
    "edit_target",
    "cancelled_by",
    "waiting_for",
    "resolution",
    "done",
)


def load_job(db: sqlite3.Connection, key: str) -> TeacherJob:
    row = db.execute(f"SELECT {','.join(COLUMNS)} FROM teacher_jobs WHERE id=?", (key,)).fetchone()
    if row is None:
        raise FileNotFoundError("Teacher event not found")
    details = graph_records.inflate(
        db.execute(
            "SELECT ordinal,parent,name,kind,value FROM teacher_fields WHERE job_id=? ORDER BY ordinal",
            (key,),
        ).fetchall()
    )
    require(isinstance(details, dict), "Invalid Teacher evidence")
    assert isinstance(details, dict)
    raw = dict(zip(COLUMNS, row, strict=True))
    raw["done"] = bool(raw["done"])
    return decode_event(key, {**details, **raw})


def read(root: Path, key: str) -> TeacherJob:
    with workflow_db.database(root) as db:
        db.execute("BEGIN")
        return load_job(db, key)


def enqueue_once(root: Path, key: str, prepare: Callable[[], TeacherJob]) -> None:
    with workflow_db.database(root) as db:
        db.execute("BEGIN IMMEDIATE")
        if db.execute("SELECT 1 FROM teacher_jobs WHERE id=?", (key,)).fetchone():
            load_job(db, key)
        else:
            insert_event(db, prepare())


def _fields(db: sqlite3.Connection, key: str, event: TeacherJob) -> None:
    details = event.model_dump(exclude=set(COLUMNS), exclude_none=True)
    db.execute("DELETE FROM teacher_fields WHERE job_id=?", (key,))
    db.executemany(
        "INSERT INTO teacher_fields VALUES (?,?,?,?,?,?)",
        ((key, *row) for row in graph_records.flatten(details)),
    )


def insert_event(db: sqlite3.Connection, event: TeacherJob) -> None:
    key = event.key()
    event.user_sha256 = digest(event.user_instructions.encode())
    values = event.model_dump()
    inserted = db.execute(
        f"INSERT INTO teacher_jobs(id,{','.join(COLUMNS)}) VALUES (?,{','.join('?' for _ in COLUMNS)}) ON CONFLICT(id) DO NOTHING",
        (key, *(values[col] for col in COLUMNS)),
    )
    if inserted.rowcount:
        _fields(db, key, event)
    else:
        load_job(db, key)


def update(root: Path, key: str, event: TeacherJob) -> None:
    require(event.key() == key, "Teacher event identity mismatch")
    data = event.model_dump()
    with workflow_db.database(root) as db:
        changes = ",".join(col + "=?" for col in COLUMNS)
        require(
            db.execute(
                f"UPDATE teacher_jobs SET {changes},updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=?",
                (*(data[col] for col in COLUMNS), key),
            ).rowcount
            == 1,
            "Unknown Teacher event",
        )
        _fields(db, key, event)


def pending(root: Path, waiting: bool, checkout: Callable[[], str | None]) -> list[str]:
    with workflow_db.database(root) as db:
        db.execute("BEGIN")
        scoped = db.execute(
            "SELECT 1 FROM teacher_jobs WHERE done=0 AND checkout IS NOT NULL LIMIT 1"
        ).fetchone()
        branch = checkout() if scoped else None
        keys = [
            r[0]
            for r in db.execute(
                "SELECT id FROM teacher_jobs WHERE done=0 AND (checkout IS NULL OR checkout=?) AND (waiting_for IS NOT NULL)=? ORDER BY id",
                (branch, waiting),
            )
        ]
        for key in keys:
            load_job(db, key)
        return keys


def feedback(root: Path, refs: list[ReportRef], run: str, current: str) -> list[SearchEvidence]:
    with workflow_db.database(root) as db:
        db.execute("BEGIN")
        assignments = {(r["node_id"], r["dispatch_id"]) for r in refs if r["run_id"] == run}
        rows = db.execute(
            """SELECT s.id,s.node_id,s.dispatch_id,s.status,e.query,e.catalog_sha256
               FROM lesson_searches s LEFT JOIN lesson_search_evidence e ON e.search_id=s.id
               WHERE s.run_id=? ORDER BY s.id""",
            (run,),
        )
        return [
            SearchEvidence(
                search_id=i,
                node_id=n,
                dispatch_id=d,
                status=status,
                query=q,
                same_catalog=stamp == current if stamp else None,
                matches=read_hits(db, i),
            )
            for i, n, d, status, q, stamp in rows
            if (n, d) in assignments
        ]
