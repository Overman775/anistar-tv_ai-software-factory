"""Allowlisted schema shared by diagnostic writers and readers."""

import json
import re
import sqlite3
from datetime import datetime
from typing import Annotated, Literal, NotRequired, TypeGuard

from pydantic import ConfigDict, StringConstraints, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

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
    "component",
}
IDENTIFIER = re.compile(r"^[A-Za-z0-9_.:-]{1,96}$")
EVENTS = {
    "result_acknowledged",
    "retro_recorded",
    "operation_completed",
    "database_failed",
    "lesson_search_recorded",
    "lesson_trace_unavailable",
    "export_retry",
    "history_skipped",
    "created",
    "packet_prepared",
    "reserved",
    "bound",
    "check_started",
    "check_process",
    "check_returned",
    "check_finished",
    "finished",
    "report_submitted",
    "unknown",
    "reconciled",
    "session_replaced",
    "revised",
    "source_reintake",
    "retry",
    "task_resumed",
    "source_prerequisite_resolved",
    "approval_resumed",
    "paused",
    "resumed",
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
    "read-instructions",
    "read-project",
    "next",
    "status",
    "ack-result",
    "expand-scope",
    "reconcile-check",
    "check-results",
    "_check-worker",
    "reset-history-index",
    "export-artifact",
    "verify-history",
    "rebind-history",
    "list-artifacts",
    "read-report",
    "record-retro",
    "prepare-workspace",
    "context",
    "project.context",
    "project.checks",
    "project.review-policy",
    "telemetry.export",
    "lessons.search_lessons",
    "lessons.telemetry",
    "lessons.capture-case",
    "lessons.feedback",
    "lessons.pending",
    "lessons.waiting",
    "lessons.route",
    "lessons.wait-owner",
    "lessons.reply",
    "lessons.teacher-launch",
    "lessons.retro",
    "lessons.retune",
    "lessons.user",
    "lessons.delete",
    "lessons.packet",
    "lessons.complete",
    "lessons.publish",
    "config",
    "validate",
    "init",
    "correct",
    "resume-task",
    "resume-approved",
    "pause",
    "resume",
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
    "handoff",
    "note",
    "authorize-check",
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
OUTCOMES = {
    "hit",
    "miss",
    "error",
    "PASS",
    "FAIL",
    "BLOCKED",
    "completed",
    "cancelled",
    "success",
    "failure",
    "stale",
}
# Only fixed reason codes cross the diagnostic boundary. Validation details stay on stderr.
REJECTION_CODES = {
    "Execution request dispatch is stale": "stale_dispatch",
    "Execution request ID already refers to different commands": "check_request_conflict",
    "Check needs project-checks reservation": "check_resource_missing",
    "Unknown assigned command": "unassigned_check",
    "Check needs a bound running node": "dispatch_not_running",
    "Report needs a bound running node": "dispatch_not_running",
    "Wait for outstanding native packet delivery before running checks": "packet_pending",
    "Invalid workflow report draft": "invalid_report_draft",
    "Existing evidence cannot be refreshed": "report_evidence_exists",
    "Stale report identity": "stale_report",
    "Duplicate receipt": "duplicate_receipt",
    "Unknown or incomplete receipt": "receipt_unavailable",
    "Stale or mismatched runner receipt": "stale_receipt",
    "Invalid packet chunk": "packet_chunk_invalid",
    "Acknowledge the preceding chunk ordinal and digest": "packet_ack_mismatch",
    "Chunk was not served in order; restart at chunk 1 if delivery receipt was lost": "packet_out_of_order",
    "Confirm final chunk ordinal/digest and mandatory material set": "packet_confirmation_invalid",
    "Packet recipient mismatch": "packet_recipient_mismatch",
    "Packet bootstrap mismatch": "packet_bootstrap_mismatch",
}
ERRORS = {
    *REJECTION_CODES.values(),
    "SOURCE_DRIFT",
    "RETRY_BUDGET_EXHAUSTED",
    "QUEUED_CAPACITY",
    "QUEUED_OWNERSHIP",
    "QUEUED_RESOURCE",
    "QUEUED_SNAPSHOT",
    "database_busy",
    "database_constraint",
    "database_corrupt",
    "database_error",
    "database_schema",
    "receiver_auth",
    "receiver_http",
    "receiver_protocol",
    "receiver_rejected",
    "receiver_unavailable",
    "io_error",
    "missing_key",
    "invalid_operation",
    "runtime_error",
    "executable_unavailable",
}
TRANSPORT_OPERATIONS = {"create", "show", "status", "prompt", "cancel", "close"}
JournalId = Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9_.:-]{1,96}$")]
InvocationId = Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{32}$")]
# Earlier journals accepted 32 hex digits. Current check executions use SHA-256.
ExecutionId = Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{64}$")]
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
    execution_id: NotRequired[ExecutionId]
    outcome: NotRequired[JournalId]
    error_code: NotRequired[JournalId]
    transport_operation: NotRequired[JournalId]
    component: NotRequired[Literal["workflow_store", "lesson_index"]]


JOURNAL_RECORD = TypeAdapter[JournalRecord](JournalRecord)


def valid_record(raw: object) -> TypeGuard[JournalRecord]:
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


def decode_record(payload: str) -> JournalRecord | None:
    if not isinstance(payload, str) or len(payload.encode()) > MAX_RECORD_BYTES:
        return None
    try:
        record = json.loads(payload)
    except ValueError, RecursionError:
        return None
    return record if valid_record(record) else None


def error_code(exc: BaseException) -> str:
    cause = exc if isinstance(exc, sqlite3.Error) else exc.__cause__
    if isinstance(cause, sqlite3.Error):
        code = getattr(cause, "sqlite_errorcode", 0) & 255
        if code in (sqlite3.SQLITE_BUSY, sqlite3.SQLITE_LOCKED):
            return "database_busy"
        if code in (sqlite3.SQLITE_CORRUPT, sqlite3.SQLITE_NOTADB):
            return "database_corrupt"
        return "database_constraint" if code == sqlite3.SQLITE_CONSTRAINT else "database_error"
    message = str(exc) if isinstance(exc, ValueError) else ""
    if code_name := REJECTION_CODES.get(message.partition(":")[0]):
        return code_name
    if message in {"Unsupported workflow database", "Unsupported lesson index"}:
        return "database_schema"
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
