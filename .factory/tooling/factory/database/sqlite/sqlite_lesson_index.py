"""Incremental FTS5 index for Git-owned lesson cards."""

import sqlite3
from contextlib import closing
from pathlib import Path

from factory.diagnostics.events import event
from factory.diagnostics.records import error_code
from factory.runtime.knowledge.lesson_index import IndexDocument, LessonIndexError
from factory.runtime.workflow_core import digest, relative, require


def _sync_index(
    db: sqlite3.Connection, files: dict[str, bytes], describe: IndexDocument
) -> dict[str, str]:
    version = db.execute("PRAGMA user_version").fetchone()[0]
    if version == 0:
        # Rebuild the old checkout-local cache from its authoritative Markdown.
        db.execute("DROP TABLE IF EXISTS version")
        db.execute("DROP TABLE IF EXISTS lessons")
        db.execute(
            "CREATE TABLE lesson_files(file_id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, revision TEXT NOT NULL)"
        )
        db.execute(
            "CREATE VIRTUAL TABLE lessons USING fts5(id, content, tokenize='porter unicode61')"
        )
        db.execute("PRAGMA user_version=1")
    else:
        require(version == 1, "Unsupported lesson index")

    saved = {
        path: (rowid, revision)
        for rowid, path, revision in db.execute("SELECT file_id,path,revision FROM lesson_files")
    }
    for path in saved.keys() - files.keys():
        db.execute("DELETE FROM lessons WHERE rowid=?", (saved[path][0],))
        db.execute("DELETE FROM lesson_files WHERE file_id=?", (saved[path][0],))
    revisions: dict[str, str] = {}
    seen: set[str] = set()
    for path, raw in files.items():
        lesson_id = Path(path).stem
        require(lesson_id not in seen, f"Duplicate lesson ID: {lesson_id}")
        seen.add(lesson_id)
        revision = digest(raw)
        revisions[path] = revision
        previous = saved.get(path)
        if previous and previous[1] == revision:
            continue
        entry = describe(path, raw)
        if previous:
            rowid = previous[0]
            db.execute("UPDATE lesson_files SET revision=? WHERE file_id=?", (revision, rowid))
            db.execute("DELETE FROM lessons WHERE rowid=?", (rowid,))
        else:
            rowid = db.execute(
                "INSERT INTO lesson_files (path,revision) VALUES (?,?)", (path, revision)
            ).lastrowid
        if entry is not None:
            lesson_id, content = entry
            db.execute(
                "INSERT INTO lessons(rowid,id,content) VALUES (?,?,?)", (rowid, lesson_id, content)
            )

    return revisions


def search(
    root: Path, files: dict[str, bytes], terms: tuple[str, ...], describe: IndexDocument
) -> tuple[list[str], dict[str, str]]:
    cache = relative(root, ".factory/memory/cache/lessons.sqlite3")
    for suffix in ("-journal", "-wal", "-shm"):
        relative(root, f".factory/memory/cache/lessons.sqlite3{suffix}")
    try:
        with closing(sqlite3.connect(cache)) as db, db:
            db.execute("BEGIN")
            revisions = _sync_index(db, files, describe)
            rows = db.execute(
                """SELECT f.path FROM lessons JOIN lesson_files f ON f.file_id=lessons.rowid
                   WHERE lessons MATCH ? ORDER BY rank,lessons.id LIMIT 3""",
                (fts_query(terms),),
            ).fetchall()
    except sqlite3.Error as exc:
        event("database_failed", component="lesson_index", error_code=error_code(exc))
        raise LessonIndexError(str(exc), type(exc).__name__) from exc
    return [name for (name,) in rows], revisions


def fts_query(terms: tuple[str, ...]) -> str:
    return " OR ".join(f'"{word}"' for word in terms)
