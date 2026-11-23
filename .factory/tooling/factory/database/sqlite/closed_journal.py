"""Encode a closed ledger using its verified report files for repeated dispatch data."""

import json
import sqlite3
from collections.abc import Iterator
from functools import cache
from typing import Any

from factory.database.sqlite import artifacts
from factory.runtime.workflow_core import require


def _dispatches(state: dict[str, Any]) -> Iterator[dict[str, Any]]:
    yield from state["nodes"].values()
    for event in state["events"]:
        previous = event.get("previous")
        if isinstance(previous, dict) and "report_ref" in previous:
            yield previous
        yield from event.get("previous_nodes", {}).values()


def transform(db: sqlite3.Connection, raw: bytes, *, restore: bool) -> bytes:
    """Only replace fields that match the original bytes' decoded value exactly."""
    record = json.loads(raw)
    state = record["state"]
    run = state["run_id"]

    @cache
    def original(path: str, sha256: str) -> dict[str, Any]:
        require(
            path.startswith(f".factory/memory/history/{run}/reports/"), "Wrong journal report owner"
        )
        require(sha256 == record["files"].get(path), "Journal report digest mismatch")
        data = artifacts.read(db, run, path, sha256)
        body: dict[str, Any] = json.loads(data)
        return body

    for entry in _dispatches(state):
        ref = entry.get("report_ref")
        if not ref:
            continue
        if restore:
            for field in entry.pop("_file_fields", []):
                require(field in ("report", "assignment"), "Unexpected journal report field")
                entry[field] = original(ref["path"], ref["sha256"])[field]
        else:
            body = original(ref["path"], ref["sha256"])
            fields = [k for k in ("report", "assignment") if k in entry and entry[k] == body[k]]
            for field in fields:
                del entry[field]
            if fields:
                entry["_file_fields"] = fields
    for correction in state.get("corrections", []):
        if restore:
            if ref := correction.pop("_evidence_ref", None):
                correction["evidence"] = original(ref["path"], ref["sha256"])["report"]
        else:
            evidence = correction["evidence"]
            ref = state.get("report_index", {}).get(evidence["dispatch_id"])
            if ref and evidence == original(ref["path"], ref["sha256"])["report"]:
                correction["_evidence_ref"] = ref
                del correction["evidence"]
    return json.dumps(record, ensure_ascii=False, separators=(",", ":")).encode()
