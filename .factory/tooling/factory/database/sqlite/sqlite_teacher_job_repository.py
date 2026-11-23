"""Workflow database adapter for the Teacher outbox."""

import json
import sqlite3
from collections.abc import Callable
from pathlib import Path

from factory.database.sqlite import workflow_db
from factory.runtime.contracts import ReportRef
from factory.runtime.knowledge.teacher_models import SearchEvidence, TeacherJob, decode_event
from factory.runtime.workflow_core import digest, require


def read(root: Path, key: str) -> str:
    with workflow_db.database(root) as db:
        row = db.execute("SELECT record FROM teacher_jobs WHERE id=?", (key,)).fetchone()
    if row is None:
        raise FileNotFoundError("Teacher event not found")
    return str(row[0])


def enqueue_once(root: Path, key: str, prepare: Callable[[], TeacherJob]) -> None:
    with workflow_db.database(root) as db:
        prior = db.execute("SELECT record FROM teacher_jobs WHERE id=?", (key,)).fetchone()
        if prior is not None:
            decode_event(key, prior[0])
        else:
            insert_event(db, prepare())


def insert_event(db: sqlite3.Connection, event: TeacherJob) -> None:
    event.user_sha256 = digest(event.user_instructions.encode())
    db.execute(
        "INSERT INTO teacher_jobs(id,record) VALUES (?,?) ON CONFLICT(id) DO NOTHING",
        (event.key(), event.model_dump_json()),
    )


def update(root: Path, key: str, event: TeacherJob) -> None:
    with workflow_db.database(root) as db:
        require(
            db.execute(
                "UPDATE teacher_jobs SET record=?,updated_at=strftime('%Y-%m-%dT%H:%M:%fZ','now') WHERE id=?",
                (event.model_dump_json(), key),
            ).rowcount
            == 1,
            "Unknown Teacher event",
        )


def pending(root: Path, waiting: bool, checkout: Callable[[], str | None]) -> list[str]:
    with workflow_db.database(root) as db:
        # Read one queue snapshot; unbound work is also available outside Git.
        db.execute("BEGIN")
        scoped = db.execute(
            """SELECT 1 FROM teacher_jobs WHERE done=0
               AND json_extract(record, '$.checkout') IS NOT NULL LIMIT 1"""
        ).fetchone()
        branch = checkout() if scoped else None
        rows = db.execute(
            """SELECT id, record FROM teacher_jobs WHERE done=0
               AND (json_extract(record, '$.checkout') IS NULL OR json_extract(record, '$.checkout') = ?)
               AND (json_extract(record, '$.waiting_for') IS NOT NULL) = ?
               ORDER BY id""",
            (branch, waiting),
        )
        keys = []
        for key, raw in rows:
            decode_event(key, raw)
            keys.append(key)
        return keys


def feedback(root: Path, refs: list[ReportRef], run: str, current: str) -> list[SearchEvidence]:
    with workflow_db.database(root) as db:
        rows = db.execute(
            """SELECT s.id,s.node_id,s.dispatch_id,s.status,e.query,e.catalog_sha256,s.matches
               FROM json_each(?) r JOIN lesson_searches s ON
               s.run_id=? AND s.node_id=(r.value ->> '$.node_id') AND s.dispatch_id=(r.value ->> '$.dispatch_id')
               LEFT JOIN lesson_search_evidence e ON e.search_id=s.id ORDER BY s.id""",
            (json.dumps(refs), run),
        )
        return [
            SearchEvidence(
                search_id=i,
                node_id=n,
                dispatch_id=d,
                status=status,
                query=q,
                same_catalog=stamp == current if stamp else None,
                matches=json.loads(hits),
            )
            for i, n, d, status, q, stamp, hits in rows
        ]
