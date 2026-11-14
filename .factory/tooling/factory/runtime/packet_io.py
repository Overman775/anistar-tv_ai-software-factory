"""Frozen packet file mechanics; callers own ledger locking and transitions."""

import json
import os
import platform
import shlex
import tempfile
from pathlib import Path
from typing import Any

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.context.context import WORKER_PROFILE_FIELDS
from factory.runtime import finish_requirements, report_history
from factory.runtime.assignment import (
    dependency_results,
    implement_packet,
    projected_task,
    validate_packet,
    worker_node,
)
from factory.runtime.contracts import (
    Dispatch,
    Node,
    PacketRef,
    State,
    agent_key,
)
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    atomic_json,
    digest,
    read_json,
    relative,
    require,
)
from factory.validation import validation_message


@with_config(ConfigDict(strict=True, extra="forbid"))
class DeliveryReceipt(TypedDict):
    packet: PacketRef
    acknowledged: int
    served: int


PACKET_REFERENCE = TypeAdapter[PacketRef](PacketRef)
DELIVERY_RECEIPT = TypeAdapter[DeliveryReceipt](DeliveryReceipt)


def freeze_packet(root: Path, directory: Path, s: State, n: Node, v: Dispatch) -> PacketRef:
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
    meta = PACKET_REFERENCE.validate_python(
        {
            "path": rel,
            "sha256": digest(data),
            "run_id": s["run_id"],
            "node_id": node_id,
            "dispatch_id": v["dispatch_id"],
            "source_hash": s["graph"]["sources"][task["source"]]["hash"],
            "revision": str(s["revision"]),
        }
    )
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
    packet = acceptance_guard(validate_packet, json.loads(data))

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
    root: Path, s: State, n: Node, expected: PacketRef, supplied: object
) -> bytes:
    v = s["nodes"][n["id"]]
    try:
        supplied = PACKET_REFERENCE.validate_python(supplied)
    except ValidationError as exc:
        raise Invalid(
            validation_message("Invalid packet bootstrap", exc, PACKET_REFERENCE)
        ) from None
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
    packet = acceptance_guard(validate_packet, json.loads(data))
    agent = s["graph"]["agents"][agent_key(n)]
    profile = s["config"]["profiles"][agent["profile"]]
    worker_profile = {k: value for k, value in profile.items() if k in WORKER_PROFILE_FIELDS}
    obligations = finish_requirements.requirements(
        s["config"]["_project"]["data"], n, task, agent["role"]
    )
    require(
        packet["workspace"] == str(root)
        and packet.get("run_id") == s["run_id"]
        and packet.get("node_id") == n["id"]
        and packet.get("dispatch_id") == v["dispatch_id"]
        and packet.get("source_hash") == expected["source_hash"]
        and packet.get("role") == v["role"]
        and packet.get("profile") == worker_profile
        and packet.get("model") == s["config"]["models"][profile["model"]]
        and packet.get("source") == s["graph"]["sources"][task["source"]]
        and packet.get("node") == worker_node(n)
        and packet.get("task") == projected_task(task, n, obligations)
        and packet.get("finish_requirements") == obligations
        and packet.get("assignment_sha256") == report_history.identity(v["assignment"])
        and packet.get("dependency_results") == dependency_results(s, n),
        "Packet content identity mismatch",
    )
    for item in packet["dependency_results"].values():
        if "report_ref" in item:
            report_history.read(root, item["report_ref"])
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


def receipt_path(root: Path, meta: PacketRef) -> Path:
    return relative(root, f"{meta['path']}.{meta['sha256']}.delivery.json")


def delivery_state(root: Path, meta: PacketRef, total: int) -> dict[str, int]:
    path = receipt_path(root, meta)
    if not path.exists():
        return {"acknowledged": 0, "served": 0}
    try:
        record = DELIVERY_RECEIPT.validate_python(read_json(path))
    except ValidationError as exc:
        raise Invalid(
            validation_message("Invalid packet delivery receipt", exc, DELIVERY_RECEIPT)
        ) from None
    require(
        record["packet"] == meta
        and 0 <= record["acknowledged"] <= record["served"] <= total
        and record["served"] - record["acknowledged"] <= 1,
        "Invalid packet delivery receipt",
    )
    return {"acknowledged": record["acknowledged"], "served": record["served"]}


def acknowledgement(chunks: list[str], ordinal: int) -> str:
    return f"{ordinal}:{digest(chunks[ordinal - 1].encode('utf-8'))}"


def serve_chunk(
    root: Path, meta: PacketRef, chunks: list[str], ordinal: int, received: str | None
) -> None:
    require(type(ordinal) is int and 1 <= ordinal <= len(chunks), "Invalid packet chunk")
    expected = acknowledgement(chunks, ordinal - 1) if ordinal > 1 else None
    require(received == expected, "Acknowledge the preceding chunk ordinal and digest")
    progress = delivery_state(root, meta, len(chunks))
    require(
        ordinal <= progress["served"] + 1,
        "Chunk was not served in order; restart at chunk 1 if delivery receipt was lost",
    )
    updated = {
        "served": max(ordinal, progress["served"]),
        "acknowledged": max(ordinal - 1, progress["acknowledged"]),
    }
    if updated != progress:
        atomic_json(
            receipt_path(root, meta), DELIVERY_RECEIPT.validate_python({"packet": meta, **updated})
        )


def material_digest(data: bytes) -> str:
    packet = acceptance_guard(validate_packet, json.loads(data))
    return report_history.identity(
        {
            "instructions": [(entry["path"], entry["sha256"]) for entry in packet["instructions"]],
            "report_references": [
                item["report_ref"]
                for item in packet["dependency_results"].values()
                if "report_ref" in item
            ],
        }
    )


def confirm_delivery(
    root: Path, meta: PacketRef, data: bytes, received: str, materials: str
) -> None:
    chunks = packet_chunks(data)
    final = len(chunks)
    require(
        received == acknowledgement(chunks, final) and materials == material_digest(data),
        "Confirm final chunk ordinal/digest and mandatory material set",
    )
    progress = delivery_state(root, meta, final)
    require(
        progress["served"] == final and progress["acknowledged"] >= final - 1,
        "Packet chunks must be received in order before confirmation",
    )
    if progress["acknowledged"] != final:
        atomic_json(
            receipt_path(root, meta),
            DELIVERY_RECEIPT.validate_python(
                {"packet": meta, "served": final, "acknowledged": final}
            ),
        )


def packet_bootstrap(root: Path, s: State, n: Node, meta: PacketRef) -> dict[str, Any]:
    args = [
        ".factory/tooling/bin/workflow.py",
        "--workspace",
        str(root),
        "read-packet",
        meta["node_id"],
        meta["path"],
        meta["sha256"],
        meta["run_id"],
        meta["dispatch_id"],
        meta["source_hash"],
        meta["revision"],
    ]
    if platform.system() == "Windows":
        # PowerShell single quotes prevent shell interpolation of workspace paths.
        quote = lambda value: "'" + value.replace("'", "''") + "'"  # noqa: E731
        prefix = [
            ".\\.factory\\.venv\\Scripts\\python.exe",
            "-E",
            "-s",
            "-B",
            ".factory/tooling/bootstrap.py",
            "run",
        ]
        shell = "PowerShell"
    else:
        quote = shlex.quote
        prefix = ["sh", ".factory/tooling/bin/python.sh"]
        shell = "POSIX shell"
    read_args = [*prefix, *args, "--chunk", "1"]
    confirm_args = [*prefix, *args[:3], "confirm-packet", *args[4:]]
    operator = "& " if shell == "PowerShell" else ""
    command = operator + " ".join(map(quote, read_args))
    confirm = operator + " ".join(map(quote, confirm_args))
    return {
        **meta,
        "workspace": str(root),
        "role": s["nodes"][n["id"]]["role"],
        "owns": n.get("owns", []),
        "stage": n["stage"],
        "read_command": command,
        "read_shell": shell,
        "confirm_command": confirm,
        "instruction": (
            "Run read_command in read_shell. For each next chunk set --chunk to next "
            "and --ack to the last result's acknowledgement. Retry a lost response "
            "with identical arguments. After receiving the last chunk, append --ack "
            "and --materials from that result to confirm_command. Wait for confirmation "
            "before writes or assigned commands."
        ),
    }
