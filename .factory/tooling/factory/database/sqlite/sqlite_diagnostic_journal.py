"""Bounded SQLite journal, isolated from workflow state."""

import os
import sqlite3
import stat
from collections.abc import Iterable, Iterator
from contextlib import closing, contextmanager
from pathlib import Path

from factory.database.sqlite.layout import check_layout, preflight_recovery
from factory.diagnostics.diagnostic_journal import JournalBusy, LogRow
from factory.diagnostics.records import MAX_RECORD_BYTES

MAX_RECORDS = 5_000
SCHEMA = """
CREATE TABLE records (id INTEGER PRIMARY KEY, invocation_id TEXT, run_id TEXT,
    dispatch_id TEXT, payload TEXT NOT NULL, export_seq INTEGER);
CREATE UNIQUE INDEX eligible_records ON records(export_seq) WHERE export_seq IS NOT NULL;
CREATE TABLE log_sequence (seq INTEGER NOT NULL);
INSERT INTO log_sequence VALUES (0);
CREATE TABLE log_offsets (receiver TEXT PRIMARY KEY, seq INTEGER NOT NULL);
"""


def database_path(workspace: str | Path) -> Path:
    root = Path(workspace).resolve()
    current = root
    for part in (".factory", "diagnostics"):
        current = current / part
        if current.is_symlink():
            raise OSError("Unsafe diagnostic path")
    path = current / "journal.sqlite3"
    for candidate in (path, *(Path(str(path) + suffix) for suffix in ("-journal", "-wal", "-shm"))):
        try:
            info = candidate.lstat()
        except FileNotFoundError:
            continue
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise OSError("Unsafe diagnostic file")
    return path


def prepare(root: Path) -> None:
    path = database_path(root)
    try:
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            pass
        else:
            os.close(fd)
        preflight_recovery(path, SCHEMA, "diagnostic journal", 1)
        with (
            closing(sqlite3.connect(path, timeout=1)) as conn,
            conn,
        ):
            check_layout(conn, SCHEMA, "diagnostic journal", initialize=True)
    except sqlite3.Error as exc:
        raise OSError("Diagnostic journal unavailable") from exc


def append(root: Path, invocation_id: str, rows: list[LogRow], timeout: float) -> None:
    path = database_path(root)
    try:
        preflight_recovery(path, SCHEMA, "diagnostic journal", timeout)
        with (
            closing(sqlite3.connect(path.as_uri() + "?mode=rw", uri=True, timeout=timeout)) as conn,
            conn,
        ):
            conn.execute("BEGIN IMMEDIATE")
            check_layout(conn, SCHEMA, "diagnostic journal")
            conn.execute("PRAGMA max_page_count = 2048")
            eligible = sum(row.exportable for row in rows)
            first = 0
            if eligible:
                last = conn.execute(
                    "UPDATE log_sequence SET seq=seq+? RETURNING seq", (eligible,)
                ).fetchone()[0]
                first = last - eligible + 1
            sequences = iter(range(first, first + eligible))
            conn.executemany(
                "INSERT INTO records (invocation_id,run_id,dispatch_id,payload,export_seq) VALUES (?,?,?,?,?)",
                [
                    (
                        invocation_id,
                        row.run,
                        row.dispatch,
                        row.payload,
                        next(sequences) if row.exportable else None,
                    )
                    for row in rows
                ],
            )
            conn.execute(
                "DELETE FROM records WHERE id <= "
                "(SELECT id FROM records ORDER BY id DESC LIMIT 1 OFFSET ?)",
                (MAX_RECORDS,),
            )
    except sqlite3.Error as exc:
        if getattr(exc, "sqlite_errorcode", 0) & 255 in (
            sqlite3.SQLITE_BUSY,
            sqlite3.SQLITE_LOCKED,
        ):
            raise JournalBusy("Diagnostic journal busy") from exc
        raise OSError("Diagnostic write unavailable") from exc


@contextmanager
def records(root: Path, key: str, value: str, cursor: int) -> Iterator[Iterable[tuple[int, str]]]:
    if key == "operation":
        column = "json_extract(CASE WHEN json_valid(payload) THEN payload END, '$.operation')"
    elif key in {"invocation_id", "run_id", "dispatch_id"}:
        column = key
    else:
        raise ValueError("Invalid diagnostic selector")
    with _reader(root) as conn:
        if conn is None:
            yield ()
            return
        yield conn.execute(
            f"SELECT id, payload FROM records WHERE {column} = ? AND id < ? ORDER BY id DESC",
            (value, cursor or 2**63 - 1),
        )


@contextmanager
def _reader(root: Path) -> Iterator[sqlite3.Connection | None]:
    path = database_path(root)
    if not path.exists():
        yield None
        return
    try:
        with closing(sqlite3.connect(path.as_uri() + "?mode=ro", uri=True, timeout=1)) as conn:
            conn.execute("BEGIN")
            check_layout(conn, SCHEMA, "diagnostic journal")
            yield conn
    except sqlite3.Error as exc:
        raise ValueError("Diagnostics unavailable") from exc


def snapshot(root: Path) -> list[str]:
    """Copy one bounded snapshot before a caller writes to a potentially slow pipe."""
    with _reader(root) as conn:
        if conn is None:
            return []
        rows = conn.execute(
            """SELECT payload FROM (SELECT id,payload FROM records ORDER BY id DESC LIMIT ?)
               WHERE typeof(payload)='text' AND length(CAST(payload AS BLOB))<=? ORDER BY id""",
            (MAX_RECORDS, MAX_RECORD_BYTES),
        )
        return [payload for (payload,) in rows]


def delivery_window(root: Path, receiver: str) -> tuple[int, int]:
    with _reader(root) as conn:
        if conn is None:
            return 0, 0
        after, until = conn.execute(
            "SELECT coalesce((SELECT seq FROM log_offsets WHERE receiver=?),0), seq FROM log_sequence",
            (receiver,),
        ).fetchone()
        return after, until


def delivery_batch(root: Path, after: int, until: int, limit: int) -> list[tuple[int, str]]:
    with _reader(root) as conn:
        if conn is None:
            raise OSError("Diagnostic journal unavailable")
        return conn.execute(
            """SELECT export_seq, CASE WHEN typeof(payload)='text' AND length(CAST(payload AS BLOB))<=?
                   THEN payload ELSE '' END FROM records
               WHERE export_seq>? AND export_seq<=? ORDER BY export_seq LIMIT ?""",
            (MAX_RECORD_BYTES, after, until, limit),
        ).fetchall()


def acknowledge(root: Path, receiver: str, sequence: int) -> None:
    path = database_path(root)
    try:
        preflight_recovery(path, SCHEMA, "diagnostic journal", 1)
        with (
            closing(sqlite3.connect(path.as_uri() + "?mode=rw", uri=True, timeout=1)) as conn,
            conn,
        ):
            conn.execute("BEGIN IMMEDIATE")
            check_layout(conn, SCHEMA, "diagnostic journal")
            conn.execute(
                "INSERT INTO log_offsets VALUES (?,?) ON CONFLICT(receiver) DO UPDATE SET seq=max(seq,excluded.seq)",
                (receiver, sequence),
            )
    except sqlite3.Error as exc:
        raise OSError("Diagnostic checkpoint unavailable") from exc
