"""SQLite observation snapshots and per-receiver offsets."""

import sqlite3
from contextlib import closing
from pathlib import Path

from factory.database.sqlite import artifacts, graph_records, workflow_db
from factory.database.sqlite.layout import check_layout
from factory.database.sqlite.lesson_hits import read_hits
from factory.database.sqlite.sqlite_teacher_job_repository import load_job
from factory.database.sqlite.workflow_schema import SCHEMA
from factory.runtime.contracts import ExecutionReceipt, LedgerEvent
from factory.runtime.knowledge.lesson_trace_repository import SearchRow
from factory.runtime.observability.acp_tools import summarize_tools
from factory.runtime.observability.acpx_usage import ArchiveUsage
from factory.runtime.observability.export_feed import (
    CheckObservation,
    Correction,
    LessonApplication,
    ObservationSource,
    RunEvent,
    RunObservation,
    SearchObservation,
    TeacherObservation,
    TransportCall,
)
from factory.runtime.observability.observations import ReportReference
from factory.runtime.workflow_core import relative, require


def exists(root: Path) -> bool:
    return relative(root, workflow_db.DATABASE).is_file()


def checkpoint(root: Path, key: str) -> tuple[int, int, int]:
    with workflow_db.database(root) as db:
        cursor = db.execute(
            "SELECT seq,span_offset FROM telemetry_offsets WHERE receiver=?", (key,)
        ).fetchone()
        after, offset = cursor if cursor else (0, 0)
        until = db.execute(
            "SELECT coalesce(max(seq),0) FROM telemetry_feed WHERE eligible=1"
        ).fetchone()[0]
    return after, offset, until


def _transports(db: sqlite3.Connection, run: str, events: list[LedgerEvent]) -> list[TransportCall]:
    calls: dict[tuple[str, str], TransportCall] = {}
    for ordinal, record in enumerate(events):
        event, at = record["event"], record["at"]
        if event not in {"transport_requested", "transport_interrupted", "transport_returned"}:
            continue
        node, dispatch = record.get("node"), record.get("dispatch_id")
        op, output = record.get("operation"), record.get("stdout")
        code, status = record.get("exit_code"), record.get("status")
        if (
            not output
            or not dispatch
            or not node
            or op not in ("create", "prompt", "show", "status", "close", "cancel")
        ):
            continue
        key = dispatch, output
        if event == "transport_requested":
            call = TransportCall(ordinal, dispatch, node, op, at)
            calls[key] = call
            if op == "prompt":
                blob = db.execute(
                    "SELECT sha256 FROM artifacts WHERE run_id=? AND path=? AND dispatch_id=? AND kind='stdout'",
                    (run, output, dispatch),
                ).fetchone()
                if blob:
                    call.tools = summarize_tools(artifacts.contents(db, run, output, blob[0]))
        elif (pending := calls.get(key)) is not None and pending.operation == op:
            pending.end, pending.exit_code, pending.stale = at, code, status == "stale"
            if event == "transport_interrupted":
                pending.outcome = "interrupted"
            elif code is not None:
                pending.outcome = "success" if code == 0 else "failure"
    return list(calls.values())


def _run(
    db: sqlite3.Connection, run: str, at: str | None, *, local: bool = False
) -> RunObservation:
    row = db.execute(
        """SELECT status, sha256 IS NOT NULL FROM runs WHERE run_id=?""", (run,)
    ).fetchone()
    if row is None:
        raise LookupError("Unknown workflow run")
    status, archived = row
    require(local or archived, "Expected archived workflow run")
    events: list[LedgerEvent] = graph_records.read(db, run, domain="run", name="events")[
        "run", "events"
    ]
    published = {
        "created",
        "reserved",
        "finished",
        "reconciled",
        "archived",
        "retry",
        "revised",
        "accepted",
        "correction_decided",
    }
    corrections = graph_records.read(db, run, domain="run", name="corrections").get(
        ("run", "corrections"), []
    )
    eligible_search = "" if local else "AND f.eligible=1"
    applications = db.execute(
        f"""SELECT DISTINCT dispatch_id,lesson_id,revision,report_outcome,search_id,f.event_id
           FROM lesson_applications LEFT JOIN telemetry_feed f ON f.kind='search'
           AND f.ref=CAST(search_id AS TEXT) {eligible_search} WHERE run_id=? ORDER BY dispatch_id,lesson_id,revision""",
        (run,),
    )
    checks: dict[str, ExecutionReceipt] = graph_records.read(
        db, run, domain="run", name="executions"
    ).get(("run", "executions"), {})
    # Existing offsets count spans in the order of the original usage archive.
    name = f".factory/memory/history/{run}/usage.acpx.json"
    blob = db.execute(
        "SELECT sha256 FROM artifacts WHERE run_id=? AND path=? AND kind='usage'", (run, name)
    ).fetchone()
    sessions = (
        ArchiveUsage.model_validate_json(artifacts.read(db, run, name, blob[0])).sessions
        if blob
        else []
    )
    return RunObservation(
        run,
        _project_id(db, run),
        status,
        at,
        [
            RunEvent(
                e["event"],
                e["at"],
                e.get("node"),
                e.get("dispatch_id"),
                e.get("outcome"),
                e.get("status"),
                e.get("role"),
                e.get("harness"),
                e.get("stage"),
                e.get("decision"),
                e.get("target"),
            )
            for e in events
            if e["event"] in published
        ],
        [
            Correction(
                c["node_id"],
                c["decision"],
                c["from_profile"],
                c["to_profile"],
                c["cause"],
                *c["identity"][1:],
            )
            for c in corrections
            if c.get("cause") in {"static", "tests", "docs", "review"}
            and isinstance(c.get("from_profile"), str)
            and len(c.get("identity", [])) == 4
        ],
        {
            row[0]
            for row in db.execute(
                "SELECT dispatch_id FROM graph_attempts WHERE run_id=? AND dispatch_id IS NOT NULL",
                (run,),
            )
        },
        [
            LessonApplication(
                dispatch,
                lesson,
                revision,
                outcome,
                search,
                uid or (f"search:{run}:{search}" if local and search is not None else None),
            )
            for dispatch, lesson, revision, outcome, search, uid in applications
        ],
        sessions,
        _transports(db, run, events),
        [
            CheckObservation(
                key,
                receipt["dispatch_id"],
                receipt["node_id"],
                receipt["spec"]["id"],
                receipt["started_at"],
                receipt.get("ended_at"),
                receipt["status"],
                receipt["result"].get("exit_code") if "result" in receipt else None,
            )
            for key, receipt in sorted(checks.items())
            if "composite_parent" not in receipt
        ],
        {
            dispatch: ReportReference(dispatch, path, sha)
            for dispatch, path, sha in db.execute(
                "SELECT dispatch_id,path,sha256 FROM artifacts WHERE run_id=? AND kind='report'",
                (run,),
            )
        },
    )


def _project_id(db: sqlite3.Connection, run: str | None) -> str | None:
    row = db.execute(
        "SELECT project_id FROM runs WHERE run_id=?",
        (run,),
    ).fetchone()
    return row[0] if row else None


def _observation(
    db: sqlite3.Connection, kind: str, ref: str, uid: str, at: str
) -> ObservationSource:
    if kind == "run":
        return _run(db, ref, at)
    if kind == "search":
        row = db.execute("SELECT * FROM lesson_searches WHERE id=?", (ref,)).fetchone()
        search = SearchRow.model_validate({**dict(row), "matches": read_hits(db, row["id"])})
        return SearchObservation(uid, at, _project_id(db, search.run_id), search)
    if kind == "teacher":
        (created,) = db.execute("SELECT created_at FROM teacher_jobs WHERE id=?", (ref,)).fetchone()
        job = load_job(db, ref)
        project = _project_id(db, job.incident) if job.kind == "accept" else None
        return TeacherObservation(uid, at, project, ref, created, job)
    raise ValueError("Unknown telemetry feed kind")


def read_run(root: Path, run: str) -> list[ObservationSource]:
    """Read the domain records in one snapshot, independently of the delivery queue."""
    path = relative(root, workflow_db.DATABASE)
    if not path.is_file():
        raise FileNotFoundError("Workflow database not found")
    for suffix in ("-wal", "-shm", "-journal"):
        relative(root, workflow_db.DATABASE + suffix)
    try:
        with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
            return _read_snapshot(db, run)
    except sqlite3.Error as exc:
        raise ValueError("Could not read workflow observations") from exc


def _read_snapshot(db: sqlite3.Connection, run: str) -> list[ObservationSource]:
    db.row_factory = sqlite3.Row
    db.execute("BEGIN")
    check_layout(db, SCHEMA, "workflow database")
    closed = db.execute(
        "SELECT at FROM telemetry_feed WHERE kind='run' AND ref=?", (run,)
    ).fetchone()
    source = _run(db, run, closed[0] if closed else None, local=True)
    records: list[ObservationSource] = [source]
    for row in db.execute(
        """SELECT s.*, f.event_id FROM lesson_searches s LEFT JOIN telemetry_feed f
           ON f.kind='search' AND f.ref=CAST(s.id AS TEXT) WHERE s.run_id=? ORDER BY s.id""",
        (run,),
    ):
        data = dict(row)
        uid = data.pop("event_id") or f"search:{run}:{row['id']}"
        records.append(
            SearchObservation(
                uid,
                row["at"],
                source.project,
                SearchRow.model_validate({**data, "matches": read_hits(db, row["id"])}),
            )
        )
    for key, created, updated, uid in db.execute(
        """SELECT j.id,j.created_at,coalesce(f.at,j.updated_at),f.event_id
           FROM teacher_jobs j LEFT JOIN telemetry_feed f ON f.kind='teacher' AND f.ref=j.id
           WHERE j.kind='accept' AND j.incident=? ORDER BY j.id""",
        (run,),
    ):
        records.append(
            TeacherObservation(
                uid or "teacher:" + key,
                updated,
                source.project,
                key,
                created,
                load_job(db, key),
            )
        )
    return records


def next_observation(root: Path, after: int, until: int) -> tuple[int, ObservationSource] | None:
    with workflow_db.database(root) as db:
        db.row_factory = sqlite3.Row
        db.execute("BEGIN")
        row = db.execute(
            "SELECT * FROM telemetry_feed WHERE eligible=1 AND seq>? AND seq<=? ORDER BY seq LIMIT 1",
            (after, until),
        ).fetchone()
        if row is None:
            return None
        return row["seq"], _observation(db, row["kind"], row["ref"], row["event_id"], row["at"])


def acknowledge(root: Path, key: str, sequence: int, offset: int) -> None:
    with workflow_db.database(root) as db:
        db.execute(
            """INSERT INTO telemetry_offsets(receiver,seq,span_offset) VALUES (?,?,?)
            ON CONFLICT(receiver) DO UPDATE SET seq=excluded.seq,span_offset=excluded.span_offset""",
            (key, sequence, offset),
        )
