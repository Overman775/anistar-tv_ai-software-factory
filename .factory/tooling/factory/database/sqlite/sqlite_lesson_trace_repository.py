"""Local evidence of lesson retrieval, worker reports and Teacher decisions."""

import json
import sqlite3
import sys
from pathlib import Path

from factory.database.sqlite import workflow_db
from factory.diagnostics.events import event
from factory.diagnostics.records import error_code
from factory.runtime.knowledge.lesson_trace_repository import (
    ApplicationRow,
    LessonTrace,
    SearchHit,
    SearchRow,
    TeacherRow,
)
from factory.runtime.workflow_core import digest, relative, require


def record_search(
    root: Path,
    run_id: str | None,
    dispatch_id: str | None,
    query: str,
    elapsed: int,
    matches: list[SearchHit],
    error: str | None,
    catalog_sha256: str | None = None,
) -> None:
    try:
        with workflow_db.database(root, timeout=0.2) as db:
            db.execute("BEGIN IMMEDIATE")
            node = None
            if run_id is not None:
                owner = db.execute(
                    """SELECT n.key FROM runs r, json_each(r.record,'$.nodes') n
                       WHERE r.run_id=? AND r.current=1 AND r.sha256 IS NULL
                       AND n.value ->> '$.status' IN ('reserved','running')
                       AND n.value ->> '$.dispatch_id'=? LIMIT 1""",
                    (run_id, dispatch_id),
                ).fetchone()
                if owner:
                    node = owner[0]
                else:
                    print(
                        "Unknown lesson-search assignment; recorded without attribution",
                        file=sys.stderr,
                    )
                    run_id = dispatch_id = None
            search = db.execute(
                """INSERT INTO lesson_searches(run_id,node_id,dispatch_id,elapsed_ms,status,
                   query_sha256,matches,error_type) VALUES (?,?,?,?,?,?,?,?)""",
                (
                    run_id,
                    node,
                    dispatch_id,
                    elapsed,
                    "error" if error else "hit" if matches else "miss",
                    digest(query.strip().encode()),
                    json.dumps(matches),
                    error,
                ),
            )
            wording = query.strip()
            if (
                node is not None
                and catalog_sha256
                and 0 < len(wording) <= 512
                and "\x00" not in wording
            ):
                db.execute(
                    "INSERT INTO lesson_search_evidence(search_id,query,catalog_sha256) VALUES (?,?,?)",
                    (search.lastrowid, wording, catalog_sha256),
                )
        event(
            "lesson_search_recorded",
            run_id=run_id,
            dispatch_id=dispatch_id,
            node_id=node,
            outcome="error" if error else "hit" if matches else "miss",
        )
    except (OSError, ValueError, sqlite3.Error) as exc:
        event("lesson_trace_unavailable", error_code=error_code(exc))
        print("Lesson search telemetry unavailable", file=sys.stderr)


def read_trace(root: Path, run: str | None, limit: int) -> LessonTrace:
    require(1 <= limit <= 200, "Limit must be between 1 and 200")
    result = LessonTrace(run_id=run)
    if not relative(root, workflow_db.DATABASE).is_file():
        require(run is None, "Unknown run")
        return result
    where = " WHERE run_id=?" if run else ""
    args = (run,) if run else ()
    with workflow_db.database(root) as db:
        db.execute("BEGIN")
        db.row_factory = sqlite3.Row
        if run:
            require(db.execute("SELECT 1 FROM runs WHERE run_id=?", args).fetchone(), "Unknown run")
        result.search_counts.update(
            db.execute(
                "SELECT status,count(*) FROM lesson_searches" + where + " GROUP BY status", args
            )
        )
        for row in db.execute(
            "SELECT * FROM lesson_searches" + where + " ORDER BY id DESC LIMIT ?", (*args, limit)
        ):
            result.searches.append(SearchRow.model_validate(dict(row)))
        for row in db.execute(
            "SELECT *,count(*) OVER () AS total FROM lesson_applications"
            + where
            + " ORDER BY report_id DESC,lesson_id LIMIT ?",
            (*args, limit),
        ):
            fields = dict(row)
            result.reported_applications = fields.pop("total")
            result.applications.append(ApplicationRow.model_validate(fields))
        teacher_where = (
            " WHERE record ->> '$.kind'='accept' AND record ->> '$.incident'=?" if run else ""
        )
        states = """CASE WHEN record ->> '$.cancelled_by' IS NOT NULL THEN 'cancelled'
                    WHEN done=1 THEN 'completed' WHEN record ->> '$.waiting_for' IS NOT NULL
                    THEN 'waiting' ELSE 'pending' END"""
        result.teacher_counts = dict(
            db.execute(
                "SELECT " + states + ",count(*) FROM teacher_jobs" + teacher_where + " GROUP BY 1",
                args,
            )
        )
        for row in db.execute(
            "SELECT id,created_at,updated_at,"
            + states
            + """ AS status,
                record ->> '$.kind' AS kind, CASE WHEN record ->> '$.delete_target' IS NOT NULL
                THEN 'delete' ELSE record ->> '$.operation' END AS operation,
                CASE WHEN record ->> '$.kind'='accept' THEN record ->> '$.incident' END AS run_id,
                coalesce(record -> '$.changes','[]') AS changes, record ->> '$.resolution' AS reason
                FROM teacher_jobs"""
            + teacher_where
            + " ORDER BY updated_at DESC,id LIMIT ?",
            (*args, limit),
        ):
            result.teacher.append(TeacherRow.model_validate(dict(row)))
    return result
