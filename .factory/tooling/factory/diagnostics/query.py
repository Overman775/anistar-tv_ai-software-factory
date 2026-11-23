"""Read validated local diagnostic records by correlation ID."""

import json
from pathlib import Path
from typing import Any

from factory.database.provider import current_database
from factory.diagnostics.diagnostic_journal import DiagnosticJournal
from factory.diagnostics.records import IDENTIFIER, OPERATIONS, JournalRecord, decode_record


def read_journal(
    workspace: str | Path,
    key: str,
    value: str,
    cursor: int,
    limit: int,
    *,
    store: DiagnosticJournal | None = None,
) -> dict[str, Any]:
    """Read a bounded page; selectors must be explicit and output is capped at 8 KiB."""
    if key == "operation":
        if value not in OPERATIONS:
            raise ValueError("Invalid diagnostic operation")
    elif key not in {"invocation_id", "run_id", "dispatch_id"} or not IDENTIFIER.fullmatch(value):
        raise ValueError("Invalid diagnostic selector")
    if not 0 <= cursor <= 2**63 - 1 or not 1 <= limit <= 30:
        raise ValueError("Invalid diagnostic page")
    matches: list[JournalRecord] = []
    last_id = cursor
    more = False
    store = current_database().diagnostics if store is None else store
    with store.records(Path(workspace).resolve(), key, value, cursor) as rows:
        for record_id, payload in rows:
            record = decode_record(payload)
            if record is None or record.get(key) != value:
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
    return {"records": matches, "next_cursor": last_id if more else None}
