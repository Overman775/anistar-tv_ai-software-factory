"""Typed standalone states and receipts share the workflow database across CLI processes."""

from pathlib import Path
from typing import Any, cast

from factory.database.sqlite import graph_documents as docs
from factory.database.sqlite.workflow_db import database
from factory.processes.records import ProcessRun
from factory.runtime.workflow_core import graph_identity, require


def create(root: Path, run: ProcessRun) -> ProcessRun:
    with database(root) as db:
        db.execute("BEGIN IMMEDIATE")
        row = db.execute(
            "SELECT subject_id FROM process_runs WHERE run_id=?", (run.run_id,)
        ).fetchone()
        if row:
            require(
                row[0] == graph_identity(["process-subject", run.subject]),
                "Intake request already binds another subject",
            )
        else:
            db.execute(
                "INSERT INTO process_runs VALUES (?,?,?,?,?,?,0,0)",
                (
                    run.run_id,
                    run.process,
                    docs.write(db, "process-subject", run.subject),
                    docs.write(db, "process-definitions", run.definitions),
                    docs.write(db, "process-handlers", run.handlers),
                    docs.write(db, "process-state", run.state.model_dump()),
                ),
            )
    return get(root, run.run_id)


def exists(root: Path, run_id: str) -> bool:
    with database(root) as db:
        return (
            db.execute("SELECT 1 FROM process_runs WHERE run_id=?", (run_id,)).fetchone()
            is not None
        )


def get(root: Path, run_id: str) -> ProcessRun:
    with database(root) as db:
        row = db.execute(
            "SELECT process,subject_id,definitions_id,handlers_id,state_id,revision FROM process_runs WHERE run_id=?",
            (run_id,),
        ).fetchone()
        require(row is not None, "Unknown standalone run ID")
        assert row is not None
        return ProcessRun.model_validate(
            {
                "run_id": run_id,
                "process": row[0],
                "subject": docs.read(db, "process-subject", row[1]),
                "definitions": docs.read(db, "process-definitions", row[2]),
                "handlers": docs.read(db, "process-handlers", row[3]),
                "state": docs.read(db, "process-state", row[4]),
                "revision": row[5],
            }
        )


def receipt(root: Path, run_id: str, key: str, command: str) -> dict[str, Any] | None:
    with database(root) as db:
        row = db.execute(
            "SELECT command,result_id FROM process_transitions WHERE run_id=? AND request_id=?",
            (run_id, key),
        ).fetchone()
        if row is None:
            return None
        require(command == row[0], "Request ID already binds different process input")
        return cast(dict[str, Any], docs.read(db, "process-result", row[1]))


def save(
    root: Path, run: ProcessRun, key: str, command: str, event: str, result: dict[str, Any]
) -> None:
    with database(root) as db:
        db.execute("BEGIN IMMEDIATE")
        state = docs.write(db, "process-state", run.state.model_dump())
        matched = db.execute(
            "UPDATE process_runs SET state_id=?,revision=revision+1,closed=? WHERE run_id=? AND revision=? AND closed=0",
            (state, int(run.state.terminal is not None), run.run_id, run.revision),
        )
        require(matched.rowcount == 1, "Standalone run advanced or closed; reread its status")
        db.execute(
            "INSERT INTO process_transitions VALUES (?,?,?,?,?,?,?)",
            (
                run.run_id,
                run.revision + 1,
                key,
                command,
                event,
                docs.write(db, "process-result", result),
                state,
            ),
        )


def history(root: Path, run_id: str) -> list[dict[str, Any]]:
    with database(root) as db:
        return [
            {
                "revision": rev,
                "request": key,
                "event": event,
                "result": docs.read(db, "process-result", result),
                "state_id": state,
            }
            for rev, key, event, result, state in db.execute(
                "SELECT revision,request_id,event,result_id,state_id FROM process_transitions WHERE run_id=? ORDER BY revision",
                (run_id,),
            )
        ]
