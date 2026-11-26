"""SQLite terminal inventories and their immutable evidence files."""

import json
import os
import sqlite3
from pathlib import Path
from tempfile import NamedTemporaryFile

from pydantic import BaseModel, ConfigDict

from factory.database.sqlite import artifacts, graph_documents, graph_state
from factory.database.sqlite.workflow_db import DATABASE as DATABASE
from factory.database.sqlite.workflow_db import database as database
from factory.paths import MEMORY as BASE
from factory.runtime.contracts import State
from factory.runtime.state_io import parse_state
from factory.runtime.transport.evidence import file_hash as file_hash
from factory.runtime.transport.evidence import pending_transports as pending_transports
from factory.runtime.transport.evidence import transport_paths as transport_paths
from factory.runtime.workflow_core import Invalid, relative, require


class Inventory(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")
    state: State
    files: dict[str, str]


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()


def _inventory(db: sqlite3.Connection, run: str) -> Inventory:
    row = db.execute(
        "SELECT sha256 FROM runs WHERE run_id=? AND sha256 IS NOT NULL", (run,)
    ).fetchone()
    if row is None:
        raise FileNotFoundError(run)
    graph_state.verify_seal(db, run, row[0])
    state = parse_state(graph_state.read(db, run))
    require(state["status"] in {"completed", "cancelled"}, "Invalid terminal inventory")
    files = dict(db.execute("SELECT path,sha256 FROM sealed_artifacts WHERE run_id=?", (run,)))
    return Inventory(state=state, files=files)


def inventory(root: Path, run: str) -> Inventory:
    if not relative(root, DATABASE).is_file():
        raise FileNotFoundError(run)
    with database(root) as db:
        db.execute("BEGIN")
        return _inventory(db, run)


def confirmed_files(
    db: sqlite3.Connection, root: Path, state: State, pending: dict[str, tuple[str, str, str]]
) -> dict[str, str]:
    run = state["run_id"]
    folder = relative(root, f"{BASE}/history/{run}")
    hashes = dict(db.execute("SELECT path,sha256 FROM artifacts WHERE run_id=?", (run,)))
    paths = transport_paths(root, state)

    def failed(exc: OSError) -> None:
        raise exc

    if folder.exists():
        require(folder.is_dir(), "Expected run history directory")
        for parent, dirs, names in folder.walk(on_error=failed):
            for entry in dirs + names:
                path = relative(root, (parent / entry).relative_to(root).as_posix())
                if not path.is_dir():
                    require(path.is_file(), f"Expected regular artifact: {path.name}")
                    paths.append(path)
    for path in paths:
        name = path.relative_to(root).as_posix()
        path = relative(root, name)
        if path.is_dir() or not path.exists():
            continue
        if name in hashes:
            require(file_hash(path) == hashes[name], f"Changed working artifact: {name}")
            continue
        if name in pending:
            kind, node, dispatch = pending[name]
            hashes[name] = artifacts.put(
                db, run, artifacts.Artifact(name, kind, path, node, dispatch)
            )
            continue
        kind = "attachment"
        if name.startswith(f"{BASE}/state/"):
            kind = "transport"
        elif path.is_relative_to(folder / "checks"):
            kind = "check-evidence"
        hashes[name] = artifacts.put(db, run, artifacts.Artifact(name, kind, path))
    expected = {
        v["output"]: v["output_hash"]
        for v in state.get("executions", {}).values()
        if "output_hash" in v
    }
    expected.update(state.get("packet_hashes", {}))
    expected.update(state.get("report_hashes", {}))
    for name, sha in expected.items():
        require(hashes.get(name) == sha, f"Missing or altered evidence: {name}")
    return hashes


def current(root: Path) -> State:
    if relative(root, DATABASE).is_file():
        with database(root) as db:
            db.execute("BEGIN")
            row = db.execute("SELECT run_id,sha256 FROM runs WHERE current=1").fetchone()
            if row is not None:
                run, checksum = row
                if checksum is not None:
                    graph_state.verify_seal(db, run, checksum)
                return parse_state(graph_state.read(db, run))
    raise FileNotFoundError("No current workflow run")


def seal_run(
    db: sqlite3.Connection,
    root: Path,
    state: State,
    usage: object,
    pending: dict[str, tuple[str, str, str]],
) -> None:
    run = state["run_id"]
    require(
        db.execute(
            "UPDATE runs SET status=?,summary=?,revision=? WHERE run_id=? AND current=1 AND status='active' AND sha256 IS NULL",
            (state["status"], state.get("summary"), state["revision"], run),
        ).rowcount
        == 1,
        "Run already closed",
    )
    graph_state.write(db, parse_state(state))
    name = f"{BASE}/history/{run}/usage.acpx.json"
    artifacts.put(db, run, artifacts.Artifact(name, "usage", json_bytes(usage)))
    files = confirmed_files(db, root, state, pending)
    artifacts.verify_manifest(db, run, files)
    db.execute(
        "INSERT INTO sealed_artifacts SELECT run_id,path,kind,node_id,dispatch_id,sha256,document_id FROM artifacts WHERE run_id=?",
        (run,),
    )
    db.execute("UPDATE runs SET sha256=? WHERE run_id=?", (graph_state.seal(db, run), run))


def check_inventory(root: Path, record: Inventory) -> None:
    run = record.state["run_id"]
    with database(root) as db:
        db.execute("BEGIN")
        artifacts.verify_manifest(db, run, record.files)


def cleanup_paths(root: Path, state: State) -> list[Path]:
    record = inventory(root, state["run_id"])
    require(record.state == state, "Terminal state differs")
    check_inventory(root, record)
    transport = set(transport_paths(root, state))
    folder = relative(root, f"{BASE}/history/{state['run_id']}")
    paths = []
    for name, sha in record.files.items():
        path = relative(root, name)
        require(path in transport or path.is_relative_to(folder), "Invalid cleanup ownership")
        if path.exists():
            require(path.is_file() and file_hash(path) == sha, f"Working artifact changed: {name}")
            paths.append(path)
    return paths


def member(root: Path, run: str, name: str) -> bytes:
    with database(root) as db:
        db.execute("BEGIN")
        expected = _inventory(db, run).files.get(name)
        require(expected is not None, "Unregistered historical artifact")
        assert expected is not None
        return artifacts.read(db, run, name, expected)


def listing(root: Path, run: str) -> list[dict[str, object]]:
    with database(root) as db:
        require(
            db.execute("SELECT 1 FROM runs WHERE run_id=?", (run,)).fetchone() is not None,
            f"Run not found: {run}",
        )
        cursor = db.execute(
            """SELECT a.path,a.kind,a.node_id,a.dispatch_id,a.sha256,length(b.body) AS bytes
               FROM artifacts a JOIN artifact_blobs b ON a.sha256=b.sha256
               WHERE a.run_id=? ORDER BY a.path""",
            (run,),
        )
        keys = [col[0] for col in cursor.description]
        return [dict(zip(keys, row, strict=True)) for row in cursor]


def export(root: Path, run: str, name: str, output: Path) -> None:
    with database(root) as db:
        db.execute("BEGIN")
        row = db.execute(
            "SELECT a.sha256,r.sha256 FROM artifacts a JOIN runs r ON a.run_id=r.run_id WHERE a.run_id=? AND a.path=?",
            (run, name),
        ).fetchone()
        require(row is not None, "Unregistered artifact")
        assert row is not None
        if row[1] is not None:
            require(
                _inventory(db, run).files.get(name) == row[0],
                "Artifact inventory mismatch",
            )
        with NamedTemporaryFile(dir=output.parent, delete=False) as target:
            temporary = Path(target.name)
            try:
                for chunk in artifacts.contents(db, run, name, row[0]):
                    target.write(chunk)
                target.flush()
                os.fsync(target.fileno())
                target.close()
                os.link(temporary, output)
            finally:
                target.close()
                temporary.unlink(missing_ok=True)


def rebind(root: Path, record: Inventory) -> None:
    run = record.state["run_id"]
    with database(root) as db:
        db.execute(
            "INSERT OR REPLACE INTO history_bindings VALUES (?,?,?)",
            (run, record.state["workspace"], str(root.resolve())),
        )


def visible(root: Path, run: str, workspace: str) -> bool:
    if str(root) == workspace:
        return True
    with database(root) as db:
        return (
            db.execute(
                "SELECT 1 FROM history_bindings WHERE run_id=? AND source=? AND target=?",
                (run, workspace, str(root)),
            ).fetchone()
            is not None
        )


def archived_state(root: Path, run: str) -> State:
    return inventory(root, run).state


def verify_history(root: Path, run: str, *, bind: bool) -> int:
    record = inventory(root, run)
    check_inventory(root, record)
    if bind:
        rebind(root, record)
    return len(record.files)


def document(root: Path, run: str, name: str, checksum: str, kind: str) -> object:
    with database(root) as db:
        db.execute("BEGIN")
        row = db.execute(
            "SELECT a.document_id,r.sha256 FROM artifacts a JOIN runs r USING(run_id) WHERE a.run_id=? AND a.path=? AND a.sha256=? AND a.kind=?",
            (run, name, checksum, kind),
        ).fetchone()
        require(row is not None and row[0], "Missing or changed graph document")
        assert row is not None
        if row[1] is not None:
            graph_state.verify_seal(db, run, row[1])
            sealed = db.execute(
                "SELECT document_id,sha256 FROM sealed_artifacts WHERE run_id=? AND path=?",
                (run, name),
            ).fetchone()
            require(sealed == (row[0], checksum), "Graph document inventory mismatch")
        return graph_documents.read(db, kind, row[0])


def stored_evidence(root: Path, run: str, name: str, *, allow_loose: bool) -> bytes | None:
    """Return the verified original, or permit a caller to read its active loose file."""
    if not relative(root, DATABASE).is_file():
        raise Invalid(f"Run not found: {run}")
    with database(root) as db:
        row = db.execute("SELECT sha256,current FROM runs WHERE run_id=?", (run,)).fetchone()
        require(row is not None, f"Run not found: {run}")
        assert row is not None
        if row[0] is None:
            require(row[1] == 1, "Run is not current")
            ref = db.execute(
                "SELECT sha256 FROM artifacts WHERE run_id=? AND path=?", (run, name)
            ).fetchone()
            if ref:
                return artifacts.read(db, run, name, ref[0])
            require(allow_loose, "Unregistered artifact")
            return None
    return member(root, run, name)
