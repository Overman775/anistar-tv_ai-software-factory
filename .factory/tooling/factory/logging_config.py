"""Explicit, best-effort local diagnostic journal for factory CLI invocations."""

from __future__ import annotations

import json
import logging
import os
import re
import sqlite3
import stat
import sys
import time
import uuid
from contextlib import closing
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated, Any, Literal, NotRequired, Protocol

from pydantic import ConfigDict, StringConstraints, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

MAX_RECORDS = 500
MAX_RECORD_BYTES = 1024
FIELDS = {
    "run_id",
    "task_id",
    "node_id",
    "dispatch_id",
    "execution_id",
    "outcome",
    "error_code",
    "transport_operation",
}
IDENTIFIER = re.compile(r"^[A-Za-z0-9_.:-]{1,96}$")
EVENTS = {
    "created",
    "packet_prepared",
    "reserved",
    "bound",
    "check_started",
    "check_process",
    "check_finished",
    "finished",
    "unknown",
    "reconciled",
    "session_replaced",
    "revised",
    "source_reintake",
    "retry",
    "task_resumed",
    "approval_resumed",
    "packet_chunk_served",
    "packet_confirmed",
    "accepted",
    "correction_decided",
    "archived",
    "prompt_prepared",
    "transport_requested",
    "transport_interrupted",
    "transport_returned",
    "operation_failed",
}
OPERATIONS = {
    "config",
    "validate",
    "init",
    "correct",
    "resume-task",
    "resume-approved",
    "show",
    "diagram",
    "revise",
    "reintake",
    "replace-session",
    "claim",
    "accept",
    "packet",
    "prepare-packet",
    "read-packet",
    "confirm-packet",
    "bind",
    "run-check",
    "prepare-report",
    "finish",
    "unknown",
    "resolve",
    "retry",
    "archive",
    "clean",
    "acp_doctor",
    "acp_setup",
    "acp_prepare",
    "acp_run",
}
OUTCOMES = {"PASS", "FAIL", "BLOCKED", "completed", "cancelled", "success", "failure", "stale"}
ERRORS = {
    "SOURCE_DRIFT",
    "RETRY_BUDGET_EXHAUSTED",
    "QUEUED_CAPACITY",
    "QUEUED_OWNERSHIP",
    "QUEUED_RESOURCE",
    "QUEUED_SNAPSHOT",
    "io_error",
    "missing_key",
    "invalid_operation",
    "runtime_error",
    "executable_unavailable",
}
TRANSPORT_OPERATIONS = {"create", "show", "status", "prompt", "cancel", "close"}
LOGGER = logging.getLogger("factory")


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


class Journal(logging.Handler):
    def __init__(self, workspace: str | Path, operation: str) -> None:
        super().__init__()
        self.path = database_path(workspace)
        self.invocation_id = uuid.uuid4().hex
        self.operation = operation
        self.failed = False
        self.pending: list[tuple[str, str | None, str | None]] = []
        started = time.monotonic()
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        try:
            fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            pass
        else:
            os.close(fd)
        with (
            closing(sqlite3.connect(self.path, timeout=1)) as conn,
            conn,
        ):
            conn.execute(
                "CREATE TABLE IF NOT EXISTS records "
                "(id INTEGER PRIMARY KEY, invocation_id TEXT, run_id TEXT, "
                "dispatch_id TEXT, payload TEXT NOT NULL)"
            )
        self.wait_budget = max(0, 1 - (time.monotonic() - started))

    def _write(self, rows: list[tuple[str, str | None, str | None]], timeout: float) -> None:
        database_path(self.path.parent.parent.parent)
        with closing(sqlite3.connect(self.path, timeout=timeout)) as conn, conn:
            conn.execute("PRAGMA max_page_count = 2048")
            conn.execute("BEGIN IMMEDIATE")
            conn.executemany(
                "INSERT INTO records (invocation_id, run_id, dispatch_id, payload) "
                "VALUES (?, ?, ?, ?)",
                [
                    (self.invocation_id, run_id, dispatch_id, data)
                    for data, run_id, dispatch_id in rows
                ],
            )
            conn.execute(
                "DELETE FROM records WHERE id NOT IN "
                "(SELECT id FROM records ORDER BY id DESC LIMIT ?)",
                (MAX_RECORDS,),
            )

    def emit(self, record: logging.LogRecord) -> None:
        if self.failed:
            return
        try:
            fields: dict[str, Any] = {
                "time": datetime.now(UTC).isoformat(),
                "event": record.msg,
                "operation": self.operation,
                "level": record.levelname,
                "invocation_id": self.invocation_id,
            }
            for key in FIELDS:
                value = getattr(record, key, None)
                if isinstance(value, str) and IDENTIFIER.fullmatch(value):
                    fields[key] = value
            if not valid_record(fields):
                raise ValueError("invalid diagnostic record")
            data = json.dumps(fields, ensure_ascii=True, separators=(",", ":"))
            if len(data.encode()) > MAX_RECORD_BYTES:
                raise ValueError("record too large")
            row = (data, fields.get("run_id"), fields.get("dispatch_id"))
            if not self.pending:
                try:
                    self._write([row], 0)
                    return
                except sqlite3.OperationalError as exc:
                    if exc.sqlite_errorcode & 255 not in (
                        sqlite3.SQLITE_BUSY,
                        sqlite3.SQLITE_LOCKED,
                    ):
                        raise
            if len(self.pending) >= 64:
                raise ValueError("diagnostic buffer full")
            self.pending.append(row)
        except (OSError, ValueError, sqlite3.Error):
            self.failed = True

    def flush_pending(self) -> None:
        if not self.pending:
            return
        try:
            self._write(self.pending, self.wait_budget)
            self.pending.clear()
        except (OSError, ValueError, sqlite3.Error):
            self.failed = True


def initialize(workspace: str | Path, operation: str) -> Journal | None:
    """Configure only the factory logger. Safe to call repeatedly in one process."""
    for handler in list(LOGGER.handlers):
        if isinstance(handler, Journal):
            LOGGER.removeHandler(handler)
            handler.close()
    LOGGER.propagate = False
    LOGGER.setLevel(logging.INFO)
    try:
        handler = Journal(workspace, operation)
    except (OSError, sqlite3.Error):
        return None
    LOGGER.addHandler(handler)
    return handler


def event(name: str, **fields: object) -> None:
    try:
        if any(isinstance(handler, Journal) for handler in LOGGER.handlers):
            LOGGER.log(
                logging.ERROR if name == "operation_failed" else logging.INFO, name, extra=fields
            )
    except Exception:
        for handler in LOGGER.handlers:
            if isinstance(handler, Journal):
                handler.failed = True


class ReadableLedger(Protocol):
    diagnostic_state: dict[str, Any] | None
    diagnostic_attempt: tuple[str, str] | None


def failure_context(ledger: ReadableLedger, node_id: object) -> dict[str, object]:
    state = ledger.diagnostic_state
    if state is None:
        return {}
    fields: dict[str, object] = {"run_id": state["run_id"]}
    if isinstance(node_id, str) and node_id in state["nodes"]:
        fields.update(node_id=node_id, task_id=state["nodes"][node_id])
        if ledger.diagnostic_attempt is not None and ledger.diagnostic_attempt[0] == node_id:
            fields["dispatch_id"] = ledger.diagnostic_attempt[1]
    return fields


def error_code(exc: BaseException) -> str:
    message = str(exc) if isinstance(exc, ValueError) else ""
    if message in {
        "SOURCE_DRIFT",
        "RETRY_BUDGET_EXHAUSTED",
        "QUEUED_CAPACITY",
        "QUEUED_OWNERSHIP",
        "QUEUED_RESOURCE",
        "QUEUED_SNAPSHOT",
    }:
        return message
    if isinstance(exc, OSError):
        return "io_error"
    if isinstance(exc, KeyError):
        return "missing_key"
    if isinstance(exc, ValueError):
        return "invalid_operation"
    return "runtime_error"


def finish(handler: Journal | None, *, failed: bool = False) -> None:
    if handler is not None:
        handler.flush_pending()
    try:
        if handler is None or handler.failed:
            print("Factory diagnostics unavailable", file=sys.stderr)
        elif failed:
            print(f"Factory diagnostic invocation: {handler.invocation_id}", file=sys.stderr)
    except OSError:
        pass
    if handler is not None:
        LOGGER.removeHandler(handler)
        handler.close()


JournalId = Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9_.:-]{1,96}$")]
InvocationId = Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{32}$")]
RunId = Annotated[str, StringConstraints(pattern=r"^run-[0-9a-f]{12}$")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class JournalRecord(TypedDict):
    time: str
    event: JournalId
    operation: JournalId
    level: Literal["INFO", "ERROR"]
    invocation_id: InvocationId
    run_id: NotRequired[RunId]
    task_id: NotRequired[JournalId]
    node_id: NotRequired[JournalId]
    dispatch_id: NotRequired[InvocationId]
    execution_id: NotRequired[InvocationId]
    outcome: NotRequired[JournalId]
    error_code: NotRequired[JournalId]
    transport_operation: NotRequired[JournalId]


JOURNAL_RECORD = TypeAdapter[JournalRecord](JournalRecord)


def valid_record(raw: object) -> bool:
    try:
        record = JOURNAL_RECORD.validate_python(raw)
    except ValidationError:
        return False
    if record["event"] not in EVENTS or record["operation"] not in OPERATIONS:
        return False
    for value, choices in (
        (record.get("outcome"), OUTCOMES),
        (record.get("error_code"), ERRORS),
        (record.get("transport_operation"), TRANSPORT_OPERATIONS),
    ):
        if value is not None and value not in choices:
            return False
    try:
        datetime.fromisoformat(record["time"])
    except ValueError:
        return False
    return True


def read_journal(
    workspace: str | Path, key: str, value: str, cursor: int, limit: int
) -> dict[str, Any]:
    """Read a bounded page; selectors must be explicit and output is capped at 8 KiB."""
    if key not in {"invocation_id", "run_id", "dispatch_id"} or not IDENTIFIER.fullmatch(value):
        raise ValueError("Invalid diagnostic selector")
    if not 0 <= cursor <= 2**63 - 1 or not 1 <= limit <= 30:
        raise ValueError("Invalid diagnostic page")
    path = database_path(workspace)
    if not path.exists():
        return {"records": [], "next_cursor": None}
    matches: list[dict[str, Any]] = []
    last_id = cursor
    more = False
    try:
        with closing(sqlite3.connect(path, timeout=1)) as conn:
            rows = conn.execute(
                f"SELECT id, payload FROM records WHERE {key} = ? AND id < ? ORDER BY id DESC",
                (value, cursor or 2**63 - 1),
            )
            for record_id, payload in rows:
                if not isinstance(payload, str) or len(payload.encode()) > MAX_RECORD_BYTES:
                    continue
                try:
                    record = json.loads(payload)
                except ValueError:
                    continue
                if not valid_record(record) or record.get(key) != value:
                    continue
                candidate = matches + [record]
                if (
                    len(candidate) > limit
                    or len(json.dumps(candidate, ensure_ascii=True).encode()) > 7900
                ):
                    more = True
                    break
                matches = candidate
                last_id = record_id
    except sqlite3.Error as exc:
        raise ValueError("Diagnostics unavailable") from exc
    return {"records": matches, "next_cursor": last_id if more else None}
