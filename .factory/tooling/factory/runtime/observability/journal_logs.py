"""Encode a local diagnostic snapshot as newline-delimited OTLP JSON log requests."""

import json
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

from factory.diagnostics.diagnostic_journal import DiagnosticJournal
from factory.diagnostics.records import decode_record
from factory.runtime.observability.observations import ident, nanos

ATTRIBUTE_KEYS = {
    "operation": "factory.operation",
    "invocation_id": "factory.invocation.id",
    "run_id": "factory.run.id",
    "dispatch_id": "factory.dispatch.id",
    "node_id": "factory.node.id",
    "task_id": "factory.task.id",
    "execution_id": "factory.execution.id",
    "outcome": "factory.outcome",
    "component": "factory.component",
    "error_code": "factory.error.code",
    "transport_operation": "factory.transport.operation",
}


@dataclass(frozen=True)
class JournalLog:
    name: str
    timestamp: int
    level: str
    severity: int
    attributes: dict[str, str]
    trace: str | None
    span: str | None


def project_log(payload: str) -> JournalLog | None:
    row = decode_record(payload)
    if row is None:
        return None
    at = nanos(row["time"])
    if not 0 < at < 2**64:
        return None
    run, dispatch = row.get("run_id"), row.get("dispatch_id")
    trace = ident(run, size=16) if run else None
    span = ident(run, dispatch) if run and dispatch else ident(run) if run else None
    return JournalLog(
        row["event"],
        at,
        row["level"],
        17 if row["level"] == "ERROR" else 9,
        {
            name: value
            for key, name in ATTRIBUTE_KEYS.items()
            if isinstance(value := row.get(key), str)
        },
        trace,
        span,
    )


def journal_lines(root: Path, store: DiagnosticJournal) -> Iterator[str]:
    resource = {"attributes": [{"key": "service.name", "value": {"stringValue": "overfactory"}}]}
    for payload in store.snapshot(root):
        record = project_log(payload)
        if record is None:
            continue
        log: dict[str, object] = {
            "timeUnixNano": str(record.timestamp),
            "eventName": record.name,
            "body": {"stringValue": record.name},
            "severityNumber": record.severity,
            "severityText": record.level,
            "attributes": [
                {"key": name, "value": {"stringValue": value}}
                for name, value in record.attributes.items()
            ],
        }
        if record.trace:
            log["traceId"], log["spanId"] = record.trace, record.span
        scope = {"scope": {"name": "overfactory.diagnostics"}, "logRecords": [log]}
        yield json.dumps(
            {"resourceLogs": [{"resource": resource, "scopeLogs": [scope]}]}, separators=(",", ":")
        )
