"""Inspect stored bytes and inject persistence failures in a disposable checkout."""

import json

from factory.database.sqlite import workflow_db
from factory.runtime.workflow import Ledger


def has_current(ledger: Ledger) -> bool:
    return workflow_db.current_row(ledger.root) is not None


def record_bytes(ledger: Ledger) -> bytes:
    row = workflow_db.current_row(ledger.root)
    assert row is not None
    return row[1].encode()


def overwrite(ledger: Ledger, value: object) -> None:
    with workflow_db.database(ledger.root) as db:
        db.execute(
            "UPDATE runs SET record=? WHERE current=1", (json.dumps(value, ensure_ascii=False),)
        )
