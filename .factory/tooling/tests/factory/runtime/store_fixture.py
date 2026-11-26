"""Inspect or corrupt one disposable relational run, bypassing the normal validation boundary."""

import json
from typing import Any, cast

from factory.database.sqlite import graph_state, workflow_db
from factory.runtime.contracts import State
from factory.runtime.workflow import Ledger


def has_current(ledger: Ledger) -> bool:
    return workflow_db.current_row(ledger.root) is not None


def record_bytes(ledger: Ledger) -> bytes:
    with workflow_db.database(ledger.root) as db:
        run = db.execute("SELECT run_id FROM runs WHERE current=1").fetchone()[0]
        return json.dumps(graph_state.read(db, run), ensure_ascii=False).encode()


def overwrite(ledger: Ledger, value: Any) -> None:
    with workflow_db.database(ledger.root) as db:
        run = db.execute("SELECT run_id FROM runs WHERE current=1").fetchone()[0]
        if "graph" not in value:
            db.execute(
                "DELETE FROM graph_collections WHERE run_id=? AND domain='run' AND name='config'",
                (run,),
            )
            return
        db.execute(
            "UPDATE runs SET revision=?,status=?,summary=?,workspace=? WHERE run_id=?",
            (value["revision"], value["status"], value.get("summary"), value["workspace"], run),
        )
        graph_state.write(db, cast(State, value))
