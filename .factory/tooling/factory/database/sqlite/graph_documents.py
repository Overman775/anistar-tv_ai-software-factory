"""Immutable typed graph inputs and handoffs, addressed by kind and content identity."""

import sqlite3

from factory.database.sqlite import graph_records
from factory.runtime.workflow_core import graph_identity, require


def write(db: sqlite3.Connection, kind: str, value: object) -> str:
    key = graph_identity([kind, value])
    if db.execute(
        "INSERT INTO graph_documents VALUES (?,?) ON CONFLICT(id) DO NOTHING", (key, kind)
    ).rowcount:
        db.executemany(
            "INSERT INTO graph_document_fields VALUES (?,?,?,?,?,?)",
            ((key, *row) for row in graph_records.flatten(value)),
        )
    else:
        read(db, kind, key)
    return key


def read(db: sqlite3.Connection, kind: str, key: str) -> object:
    require(
        db.execute("SELECT 1 FROM graph_documents WHERE id=? AND kind=?", (key, kind)).fetchone(),
        "Unknown graph input for this operation",
    )
    fields = db.execute(
        "SELECT ordinal,parent,name,kind,value FROM graph_document_fields WHERE document_id=? ORDER BY ordinal",
        (key,),
    )
    value = graph_records.inflate(fields.fetchall())
    require(graph_identity([kind, value]) == key, "Graph input digest mismatch")
    return value
