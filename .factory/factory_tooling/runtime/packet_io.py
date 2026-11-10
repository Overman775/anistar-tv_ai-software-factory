"""Frozen packet file mechanics; callers own ledger locking and transitions."""

import json
import os
import tempfile
from pathlib import Path

from factory_tooling.context.context import WORKER_PROFILE_FIELDS
from factory_tooling.runtime.assignment import implement_packet, worker_node
from factory_tooling.runtime.contracts import Dispatch, Node, State, agent_key
from factory_tooling.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    digest,
    relative,
    require,
)


def freeze_packet(root: Path, directory: Path, s: State, n: Node, v: Dispatch) -> dict[str, str]:
    """Freeze a validated dispatch under the caller's ledger lock."""
    node_id = n["id"]
    task = s["graph"]["tasks"][n["task"]]
    rel = f".factory/memory/state/{s['run_id']}-{node_id}-{v['dispatch_id']}.packet.json"
    p = relative(root, rel)
    existing = v.get("packet_file")
    if existing is not None:
        read_packet_bytes(root, s, n, existing, existing)
        return existing
    require(not p.exists(), "Packet path already exists; reconcile artifact")
    packet = acceptance_guard(implement_packet, s, node_id)
    # acpx trims surrounding whitespace when reading prompt text from a file.
    data = json.dumps(packet, ensure_ascii=False, indent=2).encode("utf-8")
    meta = {
        "path": rel,
        "sha256": digest(data),
        "run_id": s["run_id"],
        "node_id": node_id,
        "dispatch_id": v["dispatch_id"],
        "source_hash": s["graph"]["sources"][task["source"]]["hash"],
        "revision": str(s["revision"]),
    }
    fd, temp = tempfile.mkstemp(prefix=".packet-", dir=directory)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        try:
            os.link(temp, p)
        except FileExistsError:
            raise Invalid("Packet path already exists; reconcile artifact") from None
    finally:
        os.unlink(temp)
    v["packet_file"] = meta
    s.setdefault("transport_artifacts", []).append(rel)
    s.setdefault("packet_hashes", {})[rel] = meta["sha256"]
    return meta


def packet_chunks(data: bytes) -> list[str]:
    chunks = []
    start = 0
    while start < len(data):
        end = min(start + 12000, len(data))
        while end < len(data) and data[end] & 0xC0 == 0x80:
            end -= 1
        chunks.append(data[start:end].decode("utf-8"))
        start = end
    return chunks


def packet_diagnostics(data: bytes) -> dict[str, object]:
    packet = json.loads(data)

    def size(value: object) -> int:
        return len(json.dumps(value, ensure_ascii=False, indent=2).encode("utf-8"))

    sections = {key: size(value) for key, value in packet.items()}
    instructions = {entry["path"]: size(entry) for entry in packet["instructions"]}
    return {
        "bytes": len(data),
        "chunks": len(packet_chunks(data)),
        "section_bytes": dict(sorted(sections.items(), key=lambda item: -item[1])),
        "largest_instructions": dict(sorted(instructions.items(), key=lambda item: -item[1])[:5]),
    }


def read_packet_bytes(
    root: Path, s: State, n: Node, expected: dict[str, str], supplied: dict[str, str]
) -> bytes:
    v = s["nodes"][n["id"]]
    require(expected == supplied, "Packet bootstrap mismatch")
    require(
        expected["run_id"] == s["run_id"]
        and expected["node_id"] == n["id"]
        and expected["dispatch_id"] == v["dispatch_id"]
        and expected["revision"] == str(s["revision"]),
        "Stale packet identity",
    )
    task = s["graph"]["tasks"][n["task"]]
    require(
        expected["source_hash"] == s["graph"]["sources"][task["source"]]["hash"],
        "Packet source mismatch",
    )
    rel = f".factory/memory/state/{s['run_id']}-{n['id']}-{v['dispatch_id']}.packet.json"
    require(
        expected["path"] == rel and rel in s.get("transport_artifacts", []),
        "Packet ownership mismatch",
    )
    p = relative(root, rel)
    require(p.is_file(), "Packet file missing")
    fd = os.open(p, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    with os.fdopen(fd, "rb") as source:
        require(os.fstat(source.fileno()).st_nlink == 1, "Hardlinked packet")
        data = source.read()
    require(digest(data) == expected["sha256"], "Packet digest mismatch")
    packet = json.loads(data)
    agent = s["graph"]["agents"][agent_key(n)]
    profile = s["config"]["profiles"][agent["profile"]]
    worker_profile = {k: value for k, value in profile.items() if k in WORKER_PROFILE_FIELDS}
    require(
        isinstance(packet, dict)
        and packet.get("workspace") == str(root)
        and packet.get("run_id") == s["run_id"]
        and packet.get("node_id") == n["id"]
        and packet.get("dispatch_id") == v["dispatch_id"]
        and packet.get("source_hash") == expected["source_hash"]
        and packet.get("role") == v["role"]
        and packet.get("profile") == worker_profile
        and packet.get("model") == s["config"]["models"][profile["model"]]
        and packet.get("source") == s["graph"]["sources"][task["source"]]
        and packet.get("node") == worker_node(n)
        and packet.get("task") == task,
        "Packet content identity mismatch",
    )
    for entry in packet.get("instructions", []):
        if entry.get("reason") == "mandatory project reading":
            path = Path(entry["path"])
            require(
                path.is_absolute() and path.is_relative_to(root),
                "Packet instruction outside workspace",
            )
            current = relative(root, path.relative_to(root).as_posix())
            require(
                current.is_file() and digest(current.read_bytes()) == entry["sha256"],
                "Packet mandatory instruction drift",
            )
    return data
