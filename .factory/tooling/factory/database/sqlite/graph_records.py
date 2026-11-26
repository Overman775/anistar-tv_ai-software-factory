"""Relational fields for the compound values owned by tasks, events and evidence."""

from __future__ import annotations

import hashlib
import sqlite3
from collections.abc import Iterator
from dataclasses import dataclass
from itertools import groupby
from typing import Any, Literal

from factory.runtime.workflow_core import Invalid

type Scalar = str | int | float | None
type Value = Scalar | list[Value] | dict[str, Value]
type Field = tuple[int, int, str, str, Scalar]
type Shape = Literal["map", "list", "one"]


def flatten(value: object) -> list[Field]:
    rows: list[Field] = []

    def visit(parent: int, name: str, child: object) -> None:
        index = len(rows)
        if isinstance(child, dict):
            rows.append((index, parent, name, "map", None))
            for key, item in child.items():
                visit(index, key, item)
        elif isinstance(child, list):
            rows.append((index, parent, name, "list", None))
            for item in child:
                visit(index, "", item)
        elif child is None:
            rows.append((index, parent, name, "null", None))
        elif isinstance(child, bool):
            rows.append((index, parent, name, "bool", int(child)))
        elif isinstance(child, str | int | float):
            rows.append((index, parent, name, type(child).__name__, child))
        else:
            raise Invalid("Unsupported graph field type")

    visit(-1, "", value)
    return rows


def inflate(rows: list[Field]) -> Value:
    items: list[Value] = []
    for index, parent, name, kind, value in rows:
        if index != len(items) or (parent == -1) != (index == 0) or not -1 <= parent < index:
            raise Invalid("Invalid graph field ownership")
        item: Value
        match kind:
            case "map":
                item = {}
            case "list":
                item = []
            case "bool":
                if value not in (0, 1):
                    raise Invalid("Invalid graph boolean")
                item = bool(value)
            case _:
                item = value
        if parent != -1:
            owner = items[parent]
            if isinstance(owner, list):
                owner.append(item)
            elif isinstance(owner, dict) and name not in owner:
                owner[name] = item
            else:
                raise Invalid("Invalid graph field parent")
        items.append(item)
    if not items:
        raise Invalid("Missing graph record fields")
    return items[0]


def fingerprint(rows: list[Field]) -> bytes:
    checksum = hashlib.sha256()
    for _, parent, name, kind, value in rows:
        checksum.update(parent.to_bytes(8, signed=True))
        for part in (name, kind, str(value)):
            data = part.encode()
            checksum.update(len(data).to_bytes(8))
            checksum.update(data)
    return checksum.digest()


@dataclass(frozen=True)
class Collection:
    domain: str
    name: str
    value: Any

    @property
    def shape(self) -> Shape:
        if isinstance(self.value, dict):
            return "map"
        return "list" if isinstance(self.value, list) else "one"

    def entries(self) -> Iterator[tuple[str, object]]:
        if self.shape == "map":
            yield from self.value.items()
        elif self.shape == "list":
            yield from ((str(i), item) for i, item in enumerate(self.value))
        else:
            yield "", self.value


def write(db: sqlite3.Connection, run: str, groups: list[Collection]) -> None:
    previous = {
        (domain, group, key): (record, ordinal, checksum)
        for domain, group, key, record, ordinal, checksum in db.execute(
            "SELECT domain,collection,name,id,ordinal,sha256 FROM graph_records WHERE run_id=?",
            (run,),
        )
    }
    layouts = dict(
        ((domain, name), shape)
        for domain, name, shape in db.execute(
            "SELECT domain,name,shape FROM graph_collections WHERE run_id=?", (run,)
        )
    )
    for group in groups:
        domain, name = group.domain, group.name
        if layouts.pop((domain, name), None) != group.shape:
            db.execute(
                "INSERT INTO graph_collections VALUES (?,?,?,?) ON CONFLICT(run_id,domain,name) DO UPDATE SET shape=excluded.shape",
                (run, domain, name, group.shape),
            )
        for ordinal, (key, value) in enumerate(group.entries()):
            rows = flatten(value)
            checksum = fingerprint(rows)
            prior = previous.pop((domain, name, key), None)
            if prior and prior[2] == checksum:
                if prior[1] != ordinal:
                    db.execute("UPDATE graph_records SET ordinal=? WHERE id=?", (ordinal, prior[0]))
                continue
            if prior:
                db.execute("DELETE FROM graph_records WHERE id=?", (prior[0],))
            record_id = db.execute(
                "INSERT INTO graph_records(run_id,domain,collection,name,ordinal,sha256) VALUES (?,?,?,?,?,?)",
                (run, domain, name, key, ordinal, checksum),
            ).lastrowid
            db.executemany(
                "INSERT INTO graph_fields VALUES (?,?,?,?,?,?)", ((record_id, *row) for row in rows)
            )
    db.executemany("DELETE FROM graph_records WHERE id=?", ((row[0],) for row in previous.values()))
    db.executemany(
        "DELETE FROM graph_collections WHERE run_id=? AND domain=? AND name=?",
        ((run, domain, name) for domain, name in layouts),
    )


def read(
    db: sqlite3.Connection, run: str, *, domain: str | None = None, name: str | None = None
) -> dict[tuple[str, str], Any]:
    query = "run_id=?"
    params = [run]
    if domain is not None:
        query += " AND domain=?"
        params.append(domain)
    if name is not None:
        query += " AND name=?"
        params.append(name)
    layouts = {
        (d, n): shape
        for d, n, shape in db.execute(
            f"SELECT domain,name,shape FROM graph_collections WHERE {query}", params
        )
    }
    result: dict[tuple[str, str], Any] = {
        key: {} if shape == "map" else [] if shape == "list" else None
        for key, shape in layouts.items()
    }
    cursor = db.execute(
        f"""SELECT r.domain,r.collection,r.name,f.ordinal,f.parent,f.name,f.kind,f.value
        FROM (SELECT g.* FROM graph_records g JOIN (SELECT domain,name AS collection FROM graph_collections WHERE {query}) USING(domain,collection) WHERE g.run_id=?) r JOIN graph_fields f ON f.record_id=r.id
        ORDER BY r.domain,r.collection,r.ordinal,f.ordinal""",
        (*params, run),
    )

    for (d, n, key), fields in groupby(cursor, lambda row: (row[0], row[1], row[2])):
        value = inflate([tuple(row[3:]) for row in fields])
        match layouts[d, n]:
            case "map":
                result[d, n][key] = value
            case "list":
                result[d, n].append(value)
            case "one":
                result[d, n] = value
    return result
