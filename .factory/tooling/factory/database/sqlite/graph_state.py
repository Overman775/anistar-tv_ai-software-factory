"""Persist executable topology, current attempts and their typed evidence in one transaction."""

from __future__ import annotations

import hashlib
import sqlite3
from collections.abc import Iterable
from typing import Any

from factory.database.sqlite import graph_records
from factory.runtime.contracts import State
from factory.runtime.workflow_core import require

HEADER = ("revision", "status", "workspace", "summary")
STEP = ("id", "task", "stage", "agent")
ATTEMPT = ("status", "attempt", "dispatch_id", "profile", "pool", "handle", "role")


def _topology(db: sqlite3.Connection, run: str, state: State) -> None:
    steps = [
        (run, n["id"], i, n["task"], n["stage"], n["agent"])
        for i, n in enumerate(state["graph"]["nodes"])
    ]
    edges = [
        (run, n["id"], i, parent)
        for n in state["graph"]["nodes"]
        for i, parent in enumerate(n["depends_on"])
    ]
    # Step identities and edges change together on a revision. Keep unchanged checkpoints cheap.
    if steps != [
        tuple(row)
        for row in db.execute("SELECT * FROM graph_steps WHERE run_id=? ORDER BY ordinal", (run,))
    ] or sorted(edges) != [
        tuple(row)
        for row in db.execute(
            "SELECT * FROM graph_edges WHERE run_id=? ORDER BY node_id,ordinal", (run,)
        )
    ]:
        db.execute("DELETE FROM graph_edges WHERE run_id=?", (run,))
        db.execute("DELETE FROM graph_steps WHERE run_id=?", (run,))
        db.executemany("INSERT INTO graph_steps VALUES (?,?,?,?,?,?)", steps)
        db.executemany("INSERT INTO graph_edges VALUES (?,?,?,?)", edges)
    db.execute("DELETE FROM graph_attempts WHERE run_id=?", (run,))
    db.executemany(
        "INSERT INTO graph_attempts VALUES (?,?,?,?,?,?,?,?,?,?)",
        (
            (run, key, i, *(d.get(col) for col in ATTEMPT))
            for i, (key, d) in enumerate(state["nodes"].items())
        ),
    )


def definitions(db: sqlite3.Connection, run: str) -> dict[str, str]:
    rows = db.execute(
        "SELECT graph_id,yaml,sha256 FROM workflow_definitions WHERE run_id=?", (run,)
    )
    values = {}
    for graph, raw, expected in rows:
        require(
            hashlib.sha256(raw.encode()).hexdigest() == expected,
            f"Workflow definition digest mismatch: {graph}",
        )
        values[graph] = raw
    return values


def write(db: sqlite3.Connection, state: State) -> None:
    run = state["run_id"]
    previous = definitions(db, run)
    if previous:
        require(previous == state["definitions"], "Cannot replace pinned workflow definitions")
    else:
        db.executemany(
            "INSERT INTO workflow_definitions VALUES (?,?,?,?)",
            (
                (run, key, raw, hashlib.sha256(raw.encode()).hexdigest())
                for key, raw in state["definitions"].items()
            ),
        )
    _topology(db, run, state)
    groups = [
        graph_records.Collection("run", key, value)
        for key, value in state.items()
        if key not in (*HEADER, "run_id", "graph", "nodes", "definitions")
    ]
    groups.extend(
        graph_records.Collection("plan", key, value)
        for key, value in state["graph"].items()
        if key != "nodes"
    )
    steps = {
        node["id"]: {k: v for k, v in node.items() if k not in (*STEP, "depends_on")}
        for node in state["graph"]["nodes"]
    }
    details = {
        key: {k: v for k, v in dispatch.items() if k not in ATTEMPT}
        for key, dispatch in state["nodes"].items()
    }
    groups.extend(
        (
            graph_records.Collection("step", "materials", steps),
            graph_records.Collection("attempt", "evidence", details),
        )
    )
    graph_records.write(db, run, groups)


def read(db: sqlite3.Connection, run: str) -> dict[str, Any]:
    row = db.execute(
        "SELECT revision,status,workspace,summary FROM runs WHERE run_id=?", (run,)
    ).fetchone()
    if row is None:
        raise FileNotFoundError(run)
    fields = graph_records.read(db, run)
    state = {name: val for (domain, name), val in fields.items() if domain == "run"}
    state.update((k, v) for k, v in zip(HEADER, row, strict=True) if v is not None)
    state["run_id"] = run
    state["definitions"] = definitions(db, run)
    graph = {name: val for (domain, name), val in fields.items() if domain == "plan"}
    parents: dict[str, list[str]] = {}
    for key, parent in db.execute(
        "SELECT node_id,predecessor FROM graph_edges WHERE run_id=? ORDER BY node_id,ordinal",
        (run,),
    ):
        parents.setdefault(key, []).append(parent)
    graph["nodes"] = [
        {
            **dict(zip(STEP, step, strict=True)),
            "depends_on": parents.get(step[0], []),
            **fields["step", "materials"][step[0]],
        }
        for step in db.execute(
            "SELECT node_id,task,stage,agent FROM graph_steps WHERE run_id=? ORDER BY ordinal",
            (run,),
        )
    ]
    state["graph"] = graph
    state["nodes"] = {
        key: {
            **{k: v for k, v in zip(ATTEMPT, values, strict=True) if v is not None},
            **fields["attempt", "evidence"][key],
        }
        for key, *values in db.execute(
            "SELECT node_id,status,attempt,dispatch_id,profile,pool,handle,role FROM graph_attempts WHERE run_id=? ORDER BY ordinal",
            (run,),
        )
    }
    return state


def seal(db: sqlite3.Connection, run: str) -> str:
    """Bind archive identity to typed values, graph order and immutable artifact references."""
    checksum = hashlib.sha256()
    queries = (
        "SELECT run_id,revision,status,workspace,summary,project_id FROM runs WHERE run_id=?",
        "SELECT * FROM workflow_definitions WHERE run_id=? ORDER BY graph_id",
        "SELECT * FROM graph_steps WHERE run_id=? ORDER BY ordinal",
        "SELECT * FROM graph_edges WHERE run_id=? ORDER BY node_id,ordinal",
        "SELECT * FROM graph_attempts WHERE run_id=? ORDER BY ordinal",
        "SELECT domain,name,shape FROM graph_collections WHERE run_id=? ORDER BY domain,name",
        """SELECT r.domain,r.collection,r.name,r.ordinal,f.ordinal,f.parent,f.name,f.kind,f.value
        FROM graph_records r LEFT JOIN graph_fields f ON f.record_id=r.id WHERE r.run_id=?
        ORDER BY r.domain,r.collection,r.ordinal,f.ordinal""",
        "SELECT path,kind,node_id,dispatch_id,sha256,document_id FROM sealed_artifacts WHERE run_id=? ORDER BY path",
    )
    for query in queries:
        checksum.update(b"T")
        rows: Iterable[tuple[Any, ...]] = db.execute(query, (run,))
        for row in rows:
            checksum.update(b"R")
            for value in row:
                data = (type(value).__name__ + ":" + str(value)).encode()
                checksum.update(len(data).to_bytes(8))
                checksum.update(data)
    return checksum.hexdigest()


def verify_seal(db: sqlite3.Connection, run: str, expected: str) -> None:
    require(seal(db, run) == expected, "Closed journal digest mismatch")
