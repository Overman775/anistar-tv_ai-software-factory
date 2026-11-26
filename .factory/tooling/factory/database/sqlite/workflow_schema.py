"""Current workflow store layout, shared with the dependency-free setup preflight."""

SCHEMA = """
CREATE TABLE process_runs (
    run_id TEXT PRIMARY KEY, process TEXT NOT NULL,
    subject_id TEXT NOT NULL REFERENCES graph_documents, definitions_id TEXT NOT NULL REFERENCES graph_documents,
    handlers_id TEXT NOT NULL REFERENCES graph_documents, state_id TEXT NOT NULL REFERENCES graph_documents,
    revision INTEGER NOT NULL, closed INTEGER NOT NULL CHECK(closed IN (0,1))
) STRICT;
CREATE TABLE process_transitions (
    run_id TEXT NOT NULL REFERENCES process_runs, revision INTEGER NOT NULL,
    request_id TEXT NOT NULL, command TEXT NOT NULL, event TEXT NOT NULL,
    result_id TEXT NOT NULL REFERENCES graph_documents, state_id TEXT NOT NULL REFERENCES graph_documents,
    PRIMARY KEY(run_id,revision), UNIQUE(run_id,request_id)
) STRICT;
CREATE TABLE runs (
    run_id TEXT PRIMARY KEY NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('active','completed','cancelled')),
    revision INTEGER NOT NULL, workspace TEXT NOT NULL, summary TEXT, project_id TEXT,
    otlp_eligible INTEGER NOT NULL DEFAULT 0 CHECK (otlp_eligible IN (0, 1)),
    current INTEGER NOT NULL CHECK (current IN (0, 1)),
    sha256 TEXT
) STRICT;
CREATE UNIQUE INDEX one_current_run ON runs(current) WHERE current = 1;
CREATE INDEX closed_run_hashes ON runs(run_id, sha256) WHERE sha256 IS NOT NULL;

CREATE TABLE workflow_definitions (
    run_id TEXT NOT NULL REFERENCES runs ON DELETE CASCADE,
    graph_id TEXT NOT NULL, yaml TEXT NOT NULL, sha256 TEXT NOT NULL,
    PRIMARY KEY(run_id,graph_id)
) STRICT;

CREATE TABLE sealed_artifacts (
    run_id TEXT NOT NULL REFERENCES runs ON DELETE CASCADE, path TEXT NOT NULL,
    kind TEXT NOT NULL,node_id TEXT,dispatch_id TEXT,sha256 TEXT NOT NULL,document_id TEXT,
    PRIMARY KEY(run_id,path)
) STRICT;
CREATE TABLE graph_steps (
    run_id TEXT NOT NULL REFERENCES runs ON DELETE CASCADE,
    node_id TEXT NOT NULL, ordinal INTEGER NOT NULL, task TEXT NOT NULL, stage TEXT NOT NULL,
    agent TEXT, PRIMARY KEY(run_id,node_id), UNIQUE(run_id,ordinal)
) STRICT;
CREATE TABLE graph_edges (
    run_id TEXT NOT NULL, node_id TEXT NOT NULL, ordinal INTEGER NOT NULL, predecessor TEXT NOT NULL,
    PRIMARY KEY(run_id,node_id,ordinal),
    FOREIGN KEY(run_id,node_id) REFERENCES graph_steps ON DELETE CASCADE,
    FOREIGN KEY(run_id,predecessor) REFERENCES graph_steps
) STRICT;
CREATE TABLE graph_attempts (
    run_id TEXT NOT NULL REFERENCES runs ON DELETE CASCADE,
    node_id TEXT NOT NULL, ordinal INTEGER NOT NULL, status TEXT NOT NULL, attempt INTEGER NOT NULL,
    dispatch_id TEXT, profile TEXT, pool TEXT, handle TEXT, role TEXT,
    PRIMARY KEY(run_id,node_id), UNIQUE(run_id,dispatch_id),
    FOREIGN KEY(run_id,node_id) REFERENCES graph_steps ON DELETE CASCADE
) STRICT;

CREATE TABLE graph_collections (
    run_id TEXT NOT NULL REFERENCES runs ON DELETE CASCADE,
    domain TEXT NOT NULL, name TEXT NOT NULL, shape TEXT NOT NULL,
    PRIMARY KEY(run_id,domain,name)
) STRICT;
CREATE TABLE graph_records (
    id INTEGER PRIMARY KEY, run_id TEXT NOT NULL, domain TEXT NOT NULL, collection TEXT NOT NULL,
    name TEXT NOT NULL, ordinal INTEGER NOT NULL, sha256 BLOB NOT NULL,
    FOREIGN KEY(run_id,domain,collection) REFERENCES graph_collections ON DELETE CASCADE,
    UNIQUE(run_id,domain,collection,name)
) STRICT;
CREATE TABLE graph_fields (
    record_id INTEGER NOT NULL REFERENCES graph_records ON DELETE CASCADE,
    ordinal INTEGER NOT NULL, parent INTEGER NOT NULL, name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('map','list','str','int','bool','null','float')),
    value ANY,
    PRIMARY KEY(record_id,ordinal)
) STRICT, WITHOUT ROWID;

CREATE VIEW closed_runs AS
    SELECT run_id,status,summary FROM runs WHERE sha256 IS NOT NULL;
CREATE VIEW closed_steps AS
    SELECT s.run_id,s.node_id,s.status,s.attempt,a.path AS report_path
    FROM graph_attempts s JOIN closed_runs r USING(run_id)
    LEFT JOIN artifacts a ON a.run_id=s.run_id AND a.dispatch_id=s.dispatch_id AND a.kind='report';
CREATE VIEW closed_attempts AS
    SELECT a.run_id,a.dispatch_id,a.node_id,a.path AS report_path,a.sha256
    FROM artifacts a JOIN closed_runs r USING(run_id) WHERE a.kind='report';

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
    document_id TEXT REFERENCES graph_documents(id),
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
    query_sha256 TEXT NOT NULL,
    error_type TEXT,
    CHECK ((run_id IS NULL) = (dispatch_id IS NULL) AND (run_id IS NULL) = (node_id IS NULL))
) STRICT;
CREATE INDEX lesson_searches_by_run ON lesson_searches(run_id,dispatch_id,id);
CREATE TABLE lesson_hits (
    search_id INTEGER NOT NULL REFERENCES lesson_searches ON DELETE CASCADE, ordinal INTEGER NOT NULL,
    lesson_id TEXT NOT NULL, scope TEXT NOT NULL, revision TEXT NOT NULL,
    PRIMARY KEY(search_id,ordinal)
) STRICT, WITHOUT ROWID;
CREATE TABLE lesson_search_evidence (
    search_id INTEGER PRIMARY KEY REFERENCES lesson_searches(id) ON DELETE CASCADE,
    query TEXT NOT NULL CHECK(length(query) BETWEEN 1 AND 512),
    catalog_sha256 TEXT NOT NULL
) STRICT;
CREATE TABLE report_lessons (
    report_id INTEGER NOT NULL REFERENCES artifacts ON DELETE CASCADE,
    lesson_id TEXT NOT NULL, revision TEXT NOT NULL, result TEXT NOT NULL, outcome TEXT NOT NULL,
    PRIMARY KEY(report_id,lesson_id,revision)
) STRICT;
CREATE VIEW lesson_applications AS
    SELECT a.artifact_id AS report_id,a.run_id,a.node_id,a.dispatch_id,a.path AS report_path,
        l.outcome AS report_outcome,l.lesson_id,l.revision,l.result,
        (SELECT max(s.id) FROM lesson_searches s JOIN lesson_hits h ON h.search_id=s.id
         WHERE s.run_id=a.run_id AND s.dispatch_id=a.dispatch_id AND h.lesson_id=l.lesson_id
         AND h.revision=l.revision) AS search_id
    FROM report_lessons l JOIN artifacts a ON a.artifact_id=l.report_id;

CREATE TABLE teacher_jobs (
    id TEXT PRIMARY KEY NOT NULL,
    kind TEXT NOT NULL, incident TEXT NOT NULL, source TEXT NOT NULL,
    operation TEXT NOT NULL, observation TEXT NOT NULL, checkout TEXT, user_instructions TEXT NOT NULL,
    user_sha256 TEXT, delete_target TEXT, edit_target TEXT, cancelled_by TEXT, waiting_for TEXT,
    resolution TEXT, done INTEGER NOT NULL CHECK(done IN (0,1)),
    otlp_eligible INTEGER NOT NULL DEFAULT 0 CHECK (otlp_eligible IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
) STRICT;
CREATE TABLE teacher_fields (
    job_id TEXT NOT NULL REFERENCES teacher_jobs ON DELETE CASCADE, ordinal INTEGER NOT NULL,
    parent INTEGER NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL, value ANY,
    PRIMARY KEY(job_id,ordinal)
) STRICT, WITHOUT ROWID;
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
    title, body, run UNINDEXED, task UNINDEXED, node UNINDEXED, dispatch UNINDEXED, branch UNINDEXED,
    workspace UNINDEXED, tokenize='porter unicode61'
);

CREATE TABLE graph_documents (
    id TEXT PRIMARY KEY, kind TEXT NOT NULL
) STRICT;
CREATE TABLE graph_document_fields (
    document_id TEXT NOT NULL REFERENCES graph_documents ON DELETE CASCADE,
    ordinal INTEGER NOT NULL, parent INTEGER NOT NULL, name TEXT NOT NULL, kind TEXT NOT NULL,
    value ANY, PRIMARY KEY(document_id,ordinal)
) STRICT, WITHOUT ROWID;
"""
