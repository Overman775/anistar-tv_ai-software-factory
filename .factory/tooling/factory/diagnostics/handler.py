"""Write bounded diagnostic records, buffering when SQLite is busy."""

import json
import logging
import time
import uuid
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from factory.diagnostics.diagnostic_journal import DiagnosticJournal, JournalBusy, LogRow
from factory.diagnostics.records import FIELDS, IDENTIFIER, MAX_RECORD_BYTES, valid_record


class Journal(logging.Handler):
    def __init__(
        self,
        workspace: str | Path,
        operation: str,
        *,
        store: DiagnosticJournal,
        can_export: Callable[[Path], bool],
    ) -> None:
        super().__init__()
        self.root = Path(workspace).resolve()
        if not self.root.is_dir():
            raise OSError("Diagnostic workspace unavailable")
        self.store = store
        self.can_export = can_export
        self.invocation_id = uuid.uuid4().hex
        self.operation = operation
        self.failed = False
        self.pending: list[LogRow] = []
        started = time.monotonic()
        self.store.prepare(self.root)
        self.wait_budget = max(0, 1 - (time.monotonic() - started))

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
            row = LogRow(
                data,
                fields.get("run_id"),
                fields.get("dispatch_id"),
                self.operation != "telemetry.export" and self.can_export(self.root),
            )
            if not self.pending:
                try:
                    self.store.append(self.root, self.invocation_id, [row], 0)
                    return
                except JournalBusy:
                    pass  # Buffer until the shared write budget is available.
            if len(self.pending) >= 64:
                raise ValueError("diagnostic buffer full")
            self.pending.append(row)
        except Exception:
            self.failed = True

    def flush_pending(self) -> None:
        if not self.pending:
            return
        try:
            self.store.append(self.root, self.invocation_id, self.pending, self.wait_budget)
            self.pending.clear()
        except Exception:
            self.failed = True
