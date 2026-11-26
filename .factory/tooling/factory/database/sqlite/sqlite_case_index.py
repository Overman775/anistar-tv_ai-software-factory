"""Find current accepted reports in terminal archives from this checkout."""

import sqlite3
from pathlib import Path

from factory.database.sqlite import sqlite_history_repository, workflow_db
from factory.database.sqlite.sqlite_lesson_index import fts_query
from factory.runtime.knowledge.case_index import CaseMatch
from factory.runtime.knowledge.case_reports import (
    accepted_reports,
    archived_reference,
    verified_case,
)
from factory.runtime.knowledge.lesson_index import search_terms
from factory.runtime.workflow_core import relative
from factory.runtime.workspace import checkout_ref


def _sync_catalog(root: Path, db: sqlite3.Connection) -> set[str]:
    # Keep the index marker until its FTS rows have also been removed.
    removed = db.execute(
        """SELECT i.run_id FROM case_index_state i WHERE NOT EXISTS
           (SELECT 1 FROM runs r WHERE r.run_id=i.run_id AND r.sha256 IS NOT NULL)"""
    ).fetchall()
    for (run,) in removed:
        db.execute("DELETE FROM cases WHERE run=?", (run,))
        db.execute("DELETE FROM case_index_state WHERE run_id=?", (run,))
    changed = db.execute(
        """SELECT r.run_id,r.sha256 FROM runs r LEFT JOIN case_index_state i ON i.run_id=r.run_id
           WHERE r.sha256 IS NOT NULL AND r.sha256 IS NOT i.indexed_sha256"""
    ).fetchall()
    skipped: set[str] = set()
    for run, stamp in changed:
        try:
            state = sqlite_history_repository.inventory(root, run).state
            db.execute("DELETE FROM cases WHERE run=?", (run,))
            branches = {e["lesson_checkout"] for e in state["events"] if "lesson_checkout" in e}
            for branch in branches:
                for case in accepted_reports(Path(state["workspace"]), state, branch):
                    body = "\n".join((case.report["summary"], case.report.get("evidence", "")))
                    db.execute(
                        "INSERT INTO cases(title,body,run,task,node,dispatch,branch,workspace) VALUES (?,?,?,?,?,?,?,?)",
                        (
                            case.title,
                            body,
                            run,
                            case.report["task_id"],
                            case.ref["node_id"],
                            case.ref["dispatch_id"],
                            branch,
                            state["workspace"],
                        ),
                    )
            db.execute(
                "INSERT OR REPLACE INTO case_index_state(run_id,indexed_sha256) VALUES (?,?)",
                (run, stamp),
            )
        except ValueError, OSError:
            skipped.add(run)
            db.execute("DELETE FROM cases WHERE run=?", (run,))
            db.execute("DELETE FROM case_index_state WHERE run_id=?", (run,))
    return skipped


def search_cases(root: Path, query: str) -> tuple[list[CaseMatch], list[str]]:
    root = root.resolve()
    if not relative(root, workflow_db.DATABASE).is_file():
        return [], []
    terms = fts_query(search_terms(query))
    if not terms:
        return [], []
    branch = checkout_ref(root)
    found: list[CaseMatch] = []
    seen: set[tuple[str, str]] = set()
    with sqlite_history_repository.database(root) as db:
        skipped = _sync_catalog(root, db)
        for run, task, node, dispatch, excerpt in db.execute(
            """SELECT run,task,node,dispatch,snippet(cases,1,'','',' … ',32) FROM cases
               WHERE cases MATCH ? AND branch IS ? AND
                     (workspace=? OR EXISTS (SELECT 1 FROM history_bindings h
                       WHERE h.run_id=cases.run AND h.source=cases.workspace AND h.target=?))
               ORDER BY bm25(cases,0.5,1.0),rowid""",
            (terms, branch, str(root), str(root)),
        ):
            if (run, task) in seen:
                continue
            try:
                ref = archived_reference(
                    root, run, node, dispatch, history=sqlite_history_repository
                )
                case = verified_case(root, ref, history=sqlite_history_repository)
            except OSError, ValueError:
                skipped.add(run)
                continue
            ref = case.ref
            seen.add((run, task))
            found.append(
                CaseMatch(
                    run_id=run,
                    task_id=task,
                    node=ref["node_id"],
                    dispatch_id=ref["dispatch_id"],
                    ordinal=case.attempt,
                    report_ref=ref,
                    sha256=ref["sha256"],
                    excerpt=excerpt[:600],
                )
            )
            if len(found) == 3:
                break
    return found, sorted(skipped)


def reset(root: Path) -> None:
    with sqlite_history_repository.database(root) as db:
        db.execute("DELETE FROM cases")
        db.execute("DELETE FROM case_index_state")
