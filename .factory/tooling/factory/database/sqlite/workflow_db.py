"""One checkout's workflow state, Teacher outbox and packet receipts."""

import json
import sqlite3
from collections.abc import Iterator
from contextlib import closing, contextmanager
from pathlib import Path

from factory.database.sqlite.artifacts import Artifact, put
from factory.diagnostics.events import event
from factory.diagnostics.records import error_code
from factory.runtime.contracts import State
from factory.runtime.observability import export_policy
from factory.runtime.workflow_core import Invalid, relative, require

DATABASE = ".factory/memory/workflow.sqlite3"
SCHEMA_VERSION = 2
SCHEMA = """
CREATE TABLE runs (
    run_id TEXT PRIMARY KEY NOT NULL,
    record TEXT NOT NULL,
    otlp_eligible INTEGER NOT NULL DEFAULT 0 CHECK (otlp_eligible IN (0, 1)),
    current INTEGER NOT NULL CHECK (current IN (0, 1)),
    sha256 TEXT,
    status TEXT GENERATED ALWAYS AS (
        coalesce(json_extract(record, '$.state.status'), json_extract(record, '$.status'))
    ) STORED NOT NULL
);
CREATE UNIQUE INDEX one_current_run ON runs(current) WHERE current = 1;
CREATE INDEX closed_run_hashes ON runs(run_id, sha256) WHERE sha256 IS NOT NULL;

CREATE VIEW closed_runs AS
    SELECT run_id, record, status, json_extract(record, '$.state.summary') AS summary
    FROM runs WHERE sha256 IS NOT NULL;
CREATE VIEW closed_steps AS
    SELECT r.run_id, n.key AS node_id, n.value ->> '$.status' AS status,
           n.value ->> '$.attempt' AS attempt, n.value ->> '$.report_ref.path' AS report_path
    FROM closed_runs r, json_each(r.record, '$.state.nodes') n;
CREATE VIEW closed_attempts AS
    SELECT r.run_id, a.key AS dispatch_id, a.value ->> '$.node_id' AS node_id,
           a.value ->> '$.path' AS report_path, a.value ->> '$.sha256' AS sha256
    FROM closed_runs r, json_each(r.record, '$.state.report_index') a;

CREATE TABLE artifact_blobs (
    sha256 TEXT NOT NULL UNIQUE,
    body BLOB NOT NULL
);
CREATE TABLE artifacts (
    artifact_id INTEGER PRIMARY KEY,
    run_id TEXT NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
    path TEXT NOT NULL,
    kind TEXT NOT NULL,
    sha256 TEXT NOT NULL REFERENCES artifact_blobs(sha256),
    node_id TEXT,
    dispatch_id TEXT,
    UNIQUE (run_id, path)
);
CREATE INDEX artifacts_by_dispatch ON artifacts(run_id, dispatch_id, kind);
CREATE VIEW acpx_session_records AS
    SELECT a.run_id, json_extract(CAST(b.body AS TEXT), '$.project_id') AS project_id,
           s.value AS session
    FROM artifacts a JOIN closed_runs r ON r.run_id=a.run_id
    JOIN artifact_blobs b ON b.sha256=a.sha256,
         json_each(CAST(b.body AS TEXT), '$.sessions') s
    WHERE a.kind='usage' AND a.path='.factory/memory/history/' || a.run_id || '/usage.acpx.json';
CREATE VIEW acpx_sessions AS
    SELECT run_id, project_id, session ->> '$.connection' AS connection,
           session ->> '$.cwd' AS cwd, session ->> '$.name' AS session_name,
           session ->> '$.collection' AS collection, session ->> '$.acpx_record_id' AS acpx_record_id,
           session ->> '$.acp_session_id' AS acp_session_id,
           session ->> '$.agent_session_id' AS agent_session_id,
           session ->> '$.cumulative_cost.amount' AS cost_amount,
           session ->> '$.cumulative_cost.currency' AS cost_currency
    FROM acpx_session_records;
CREATE VIEW acpx_attempts AS
    SELECT run_id, session ->> '$.connection' AS connection, session ->> '$.cwd' AS cwd,
           session ->> '$.name' AS session_name, a.value ->> '$.node_id' AS node_id,
           a.value ->> '$.dispatch_id' AS dispatch_id, a.value ->> '$.agent' AS agent,
           a.value ->> '$.role' AS role, a.value ->> '$.harness' AS harness,
           a.value ->> '$.requested_model' AS requested_model,
           a.value ->> '$.requested_effort' AS requested_effort,
           a.value ->> '$.effective_model' AS effective_model
    FROM acpx_session_records, json_each(session, '$.attempts') a;
CREATE VIEW acpx_request_usage AS
    SELECT run_id, session ->> '$.connection' AS connection, session ->> '$.cwd' AS cwd,
           session ->> '$.name' AS session_name, u.key AS request_id,
           u.value ->> '$.input_tokens' AS input_tokens, u.value ->> '$.output_tokens' AS output_tokens,
           u.value ->> '$.cache_read_input_tokens' AS cache_read_input_tokens,
           u.value ->> '$.cache_creation_input_tokens' AS cache_creation_input_tokens,
           u.value ->> '$.thought_tokens' AS thought_tokens, u.value ->> '$.total_tokens' AS total_tokens
    FROM acpx_session_records, json_each(session, '$.request_token_usage') u;
CREATE TABLE packet_deliveries (
    artifact_id INTEGER NOT NULL REFERENCES artifacts(artifact_id) ON DELETE CASCADE,
    recipient TEXT NOT NULL CHECK (length(recipient) > 0),
    source_hash TEXT NOT NULL,
    revision TEXT NOT NULL,
    served INTEGER NOT NULL,
    acknowledged INTEGER NOT NULL,
    CHECK (acknowledged >= 0 AND served - acknowledged BETWEEN 0 AND 1),
    PRIMARY KEY (artifact_id, recipient)
) STRICT;

CREATE TABLE lesson_searches (
    id INTEGER PRIMARY KEY,
    at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    run_id TEXT REFERENCES runs(run_id) ON DELETE CASCADE,
    node_id TEXT, dispatch_id TEXT,
    elapsed_ms INTEGER NOT NULL CHECK(elapsed_ms >= 0),
    status TEXT NOT NULL CHECK(status IN ('hit','miss','error')),
    query_sha256 TEXT NOT NULL, matches TEXT NOT NULL CHECK(json_type(matches)='array'),
    error_type TEXT,
    CHECK ((run_id IS NULL) = (dispatch_id IS NULL) AND (run_id IS NULL) = (node_id IS NULL))
) STRICT;
CREATE INDEX lesson_searches_by_run ON lesson_searches(run_id,dispatch_id,id);
CREATE TABLE lesson_search_evidence (
    search_id INTEGER PRIMARY KEY REFERENCES lesson_searches(id) ON DELETE CASCADE,
    query TEXT NOT NULL CHECK(length(query) BETWEEN 1 AND 512),
    catalog_sha256 TEXT NOT NULL
) STRICT;
CREATE VIEW lesson_applications AS
    SELECT DISTINCT a.artifact_id AS report_id, a.run_id, a.node_id, a.dispatch_id, a.path AS report_path,
           json_extract(CAST(b.body AS TEXT),'$.report.outcome') AS report_outcome,
           l.value ->> '$.id' AS lesson_id, l.value ->> '$.revision' AS revision,
           l.value ->> '$.result' AS result,
           (SELECT max(s.id) FROM lesson_searches s, json_each(s.matches) m
            WHERE s.run_id=a.run_id AND s.dispatch_id=a.dispatch_id
              AND m.value ->> '$.id'=l.value ->> '$.id'
              AND m.value ->> '$.revision'=l.value ->> '$.revision') AS search_id
    FROM artifacts a JOIN artifact_blobs b ON b.sha256=a.sha256,
         json_each(CAST(b.body AS TEXT),'$.report.applied_lessons') l
    WHERE a.kind='report';

CREATE TABLE teacher_jobs (
    id TEXT PRIMARY KEY NOT NULL,
    record TEXT NOT NULL,
    otlp_eligible INTEGER NOT NULL DEFAULT 0 CHECK (otlp_eligible IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    done INTEGER GENERATED ALWAYS AS (json_extract(record, '$.done')) STORED NOT NULL
);
CREATE INDEX open_jobs ON teacher_jobs(id) WHERE done = 0;
CREATE TABLE telemetry_feed (
    seq INTEGER PRIMARY KEY, event_id TEXT NOT NULL DEFAULT (lower(hex(randomblob(16)))),
    kind TEXT NOT NULL, ref TEXT NOT NULL, at TEXT NOT NULL, eligible INTEGER NOT NULL DEFAULT 0 CHECK (eligible IN (0, 1)), UNIQUE(kind,ref)
) STRICT;
CREATE TABLE telemetry_offsets (
    receiver TEXT PRIMARY KEY, seq INTEGER NOT NULL, span_offset INTEGER NOT NULL DEFAULT 0
) STRICT;
CREATE TABLE history_bindings (
    run_id TEXT PRIMARY KEY NOT NULL REFERENCES runs(run_id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    target TEXT NOT NULL
);
CREATE TABLE case_index_state (
    run_id TEXT PRIMARY KEY,
    indexed_sha256 TEXT NOT NULL
) WITHOUT ROWID;
CREATE VIRTUAL TABLE cases USING fts5(
    title, body, run UNINDEXED, task UNINDEXED, ref UNINDEXED, branch UNINDEXED,
    workspace UNINDEXED, tokenize='porter unicode61'
);
"""


def _configure_collection(db: sqlite3.Connection, enabled: bool) -> None:
    """Store committed source references in delivery order, never duplicate source payloads."""
    for table, key in (("runs", "run_id"), ("teacher_jobs", "id")):
        # Eligibility follows the whole lifecycle. A dev-created or mixed run stays local.
        if enabled:
            db.execute(f"""CREATE TEMP TRIGGER otlp_begin_{table} AFTER INSERT ON main.{table}
                BEGIN UPDATE {table} SET otlp_eligible=1 WHERE {key}=NEW.{key}; END""")
        else:
            db.execute(f"""CREATE TEMP TRIGGER otlp_exclude_{table} AFTER UPDATE OF record ON main.{table}
                WHEN OLD.otlp_eligible=1
                BEGIN UPDATE {table} SET otlp_eligible=0 WHERE {key}=NEW.{key}; END""")
    if not enabled:
        return
    now = "strftime('%Y-%m-%dT%H:%M:%fZ','now')"
    for kind, table, transition, condition, ref, at in (
        (
            "run",
            "runs",
            "UPDATE OF sha256",
            "NEW.otlp_eligible=1 AND NEW.sha256 IS NOT NULL AND OLD.sha256 IS NULL",
            "NEW.run_id",
            now,
        ),
        (
            "search",
            "lesson_searches",
            "INSERT",
            "NEW.run_id IS NULL OR EXISTS (SELECT 1 FROM runs WHERE run_id=NEW.run_id AND otlp_eligible=1)",
            "NEW.id",
            "NEW.at",
        ),
        (
            "teacher",
            "teacher_jobs",
            "UPDATE OF record",
            "NEW.otlp_eligible=1 AND NEW.done=1 AND OLD.done=0",
            "NEW.id",
            "NEW.updated_at",
        ),
    ):
        uid = "lower(hex(randomblob(16)))"
        if kind == "teacher":
            # A pending run finalizer already has a local observation ID.
            uid = f"CASE WHEN NEW.record ->> '$.kind'='accept' THEN 'teacher:' || NEW.id ELSE {uid} END"
        db.execute(f"""CREATE TEMP TRIGGER telemetry_{kind} AFTER {transition} ON main.{table}
            WHEN {condition} BEGIN INSERT INTO telemetry_feed(kind,ref,at,eligible,event_id)
            VALUES ('{kind}',{ref},{at},1,{uid}); END""")


@contextmanager
def database(root: Path, *, timeout: float = 5) -> Iterator[sqlite3.Connection]:
    path = relative(root, DATABASE)
    path.parent.mkdir(parents=True, exist_ok=True)
    for suffix in ("-wal", "-shm", "-journal"):
        relative(root, DATABASE + suffix)
    try:
        with closing(sqlite3.connect(path, timeout=timeout)) as db, db:
            db.execute("PRAGMA foreign_keys=ON")
            if db.execute("PRAGMA user_version").fetchone()[0] in (0, 1):
                # Recheck under the write lock so simultaneous first opens share one schema.
                db.execute("BEGIN IMMEDIATE")
                version = db.execute("PRAGMA user_version").fetchone()[0]
                if version == 0:
                    require(
                        db.execute("SELECT 1 FROM sqlite_master LIMIT 1").fetchone() is None,
                        "Unsupported workflow database",
                    )
                    for statement in SCHEMA.strip().split(";"):
                        if statement.strip():
                            db.execute(statement)
                    db.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
                elif version == 1:
                    require(
                        db.execute(
                            "SELECT 1 FROM sqlite_schema WHERE type='table' AND name='lesson_search_evidence'"
                        ).fetchone()
                        is not None,
                        "Unsupported workflow database",
                    )
                    for kind in ("run", "teacher", "search"):
                        db.execute(f"DROP TRIGGER telemetry_{kind}")
                    for table in ("runs", "teacher_jobs"):
                        db.execute(
                            f"ALTER TABLE {table} ADD COLUMN otlp_eligible INTEGER NOT NULL DEFAULT 0 CHECK (otlp_eligible IN (0, 1))"
                        )
                    db.execute("UPDATE telemetry_offsets SET span_offset=0 WHERE span_offset<>0")
                    # v1 queued every run, including development. Preserve rows and offsets locally.
                    db.execute(
                        "ALTER TABLE telemetry_feed ADD COLUMN eligible INTEGER NOT NULL DEFAULT 0 CHECK (eligible IN (0, 1))"
                    )
                    db.execute(f"PRAGMA user_version={SCHEMA_VERSION}")
                db.commit()
            require(
                db.execute("PRAGMA user_version").fetchone() == (SCHEMA_VERSION,)
                and db.execute(
                    "SELECT 1 FROM sqlite_schema WHERE type='table' AND name='lesson_search_evidence'"
                ).fetchone()
                is not None,
                "Unsupported workflow database",
            )
            _configure_collection(db, export_policy.enabled(root))
            yield db
    except sqlite3.Error as exc:
        event("database_failed", component="workflow_store", error_code=error_code(exc))
        raise Invalid(f"Workflow database: {exc}") from exc


def current_row(root: Path) -> tuple[str, str, str | None] | None:
    if not relative(root, DATABASE).is_file():
        return None
    with database(root) as db:
        row = db.execute("SELECT run_id, record, sha256 FROM runs WHERE current=1").fetchone()
        return (str(row[0]), str(row[1]), row[2]) if row else None


def save(
    root: Path, state: State, *, create: bool = False, evidence: tuple[Artifact, ...] = ()
) -> None:
    record = json.dumps(state, ensure_ascii=False)
    with database(root) as db:
        if create:
            db.execute(
                "INSERT INTO runs(run_id,record,current) VALUES (?,?,1)", (state["run_id"], record)
            )
        else:
            require(
                db.execute(
                    "UPDATE runs SET record=? WHERE run_id=? AND current=1 AND sha256 IS NULL",
                    (record, state["run_id"]),
                ).rowcount
                == 1,
                "Run is not current",
            )

        for item in evidence:
            put(db, state["run_id"], item)


def clean(root: Path, run: str) -> None:
    with database(root) as db:
        require(
            db.execute(
                "UPDATE runs SET current=0 WHERE run_id=? AND current=1 AND sha256 IS NOT NULL AND status IN ('completed','cancelled')",
                (run,),
            ).rowcount
            == 1,
            "Run is not terminal and current",
        )
