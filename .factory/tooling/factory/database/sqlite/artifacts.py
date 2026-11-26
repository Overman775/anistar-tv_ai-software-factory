"""Immutable run references to content-addressed bytes in the workflow database."""

import sqlite3
from collections.abc import Iterator
from hashlib import file_digest, sha256
from io import BytesIO
from typing import BinaryIO

from factory import file_reader
from factory.database.sqlite import graph_documents
from factory.runtime.history.artifact_ref import Artifact as Artifact
from factory.runtime.workflow_core import digest, require


def contents(db: sqlite3.Connection, run: str, name: str, checksum: str) -> Iterator[bytes]:
    row = db.execute(
        """SELECT b.rowid FROM artifacts a JOIN artifact_blobs b ON a.sha256=b.sha256
           WHERE a.run_id=? AND a.path=? AND a.sha256=?""",
        (run, name, checksum),
    ).fetchone()
    require(row is not None, f"Missing or changed artifact: {name}")
    assert row is not None
    yield from _blob_chunks(db, row[0], checksum, name)


def _blob_chunks(db: sqlite3.Connection, blob_id: int, checksum: str, name: str) -> Iterator[bytes]:
    measured = sha256()
    with db.blobopen("artifact_blobs", "body", blob_id, readonly=True) as blob:
        while chunk := blob.read(1024 * 1024):
            measured.update(chunk)
            yield chunk
    require(measured.hexdigest() == checksum, f"Artifact digest mismatch: {name}")


def verify_manifest(db: sqlite3.Connection, run: str, expected: dict[str, str]) -> None:
    rows = db.execute(
        """SELECT a.path,a.sha256,b.rowid FROM artifacts a
                         LEFT JOIN artifact_blobs b ON b.sha256=a.sha256 WHERE a.run_id=?""",
        (run,),
    ).fetchall()
    require(len(rows) == len(expected), "Missing or changed artifact inventory")
    checked: set[str] = set()
    for path, checksum, blob_id in rows:
        require(
            expected.get(path) == checksum and blob_id is not None,
            f"Missing or changed artifact: {path}",
        )
        if checksum not in checked:
            for _ in _blob_chunks(db, blob_id, checksum, path):
                pass
            checked.add(checksum)


def read(db: sqlite3.Connection, run: str, name: str, checksum: str) -> bytes:
    return b"".join(contents(db, run, name, checksum))


def put(db: sqlite3.Connection, run: str, item: Artifact) -> str:
    stream: BinaryIO
    if isinstance(item.source, bytes):
        checksum = digest(item.source)
        size = len(item.source)
        stream = BytesIO(item.source)
    else:
        stream = file_reader.open_binary(item.source)
    with stream:
        if not isinstance(item.source, bytes):
            checksum = file_digest(stream, "sha256").hexdigest()
            size = stream.seek(0, 2)
            stream.seek(0)
        require(
            item.expected is None or item.expected == checksum,
            f"Artifact digest mismatch: {item.name}",
        )
        inserted = db.execute(
            "INSERT INTO artifact_blobs(sha256,body) VALUES (?,zeroblob(?)) ON CONFLICT DO NOTHING",
            (checksum, size),
        )
        if inserted.rowcount:
            assert inserted.lastrowid is not None
            with db.blobopen("artifact_blobs", "body", inserted.lastrowid) as blob:
                copied = sha256()
                while chunk := stream.read(1024 * 1024):
                    blob.write(chunk)
                    copied.update(chunk)
                require(
                    copied.hexdigest() == checksum, f"Artifact changed while saving: {item.name}"
                )
        document_id = (
            graph_documents.write(db, item.kind, item.document)
            if item.document is not None
            else None
        )
        reference = db.execute(
            "INSERT INTO artifacts(run_id,path,kind,sha256,node_id,dispatch_id,document_id) VALUES (?,?,?,?,?,?,?) "
            "ON CONFLICT(run_id,path) DO NOTHING",
            (run, item.name, item.kind, checksum, item.node, item.dispatch, document_id),
        )
        row = db.execute(
            "SELECT sha256,kind,node_id,dispatch_id,document_id FROM artifacts WHERE run_id=? AND path=?",
            (run, item.name),
        ).fetchone()
        require(
            row == (checksum, item.kind, item.node, item.dispatch, document_id),
            f"Immutable artifact differs: {item.name}",
        )
        if reference.rowcount and item.kind == "report" and isinstance(item.document, dict):
            report = item.document["report"]
            db.executemany(
                "INSERT INTO report_lessons VALUES (?,?,?,?,?)",
                (
                    (
                        reference.lastrowid,
                        lesson["id"],
                        lesson["revision"],
                        lesson["result"],
                        report["outcome"],
                    )
                    for lesson in report.get("applied_lessons", [])
                ),
            )
        if not inserted.rowcount:
            for _ in contents(db, run, item.name, checksum):
                pass
        return checksum
