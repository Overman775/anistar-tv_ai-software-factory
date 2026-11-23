"""Frozen packet file mechanics; callers own ledger locking and transitions."""

import json
import os
import platform
import shlex
import tempfile
from pathlib import Path
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory import file_reader
from factory.context.context import WORKER_PROFILE_FIELDS
from factory.database.provider import current_database
from factory.runtime.contracts import (
    Dispatch,
    Node,
    PacketRef,
    State,
    agent_key,
)
from factory.runtime.history import report_history
from factory.runtime.history.history_repository import HistoryRepository
from factory.runtime.packets.delivery import PacketDelivery
from factory.runtime.packets.repository import DeliveryReceipt as DeliveryReceipt
from factory.runtime.packets.repository import PacketRepository
from factory.runtime.reports import finish_requirements
from factory.runtime.scheduling.assignment import (
    dependency_results,
    implement_packet,
    projected_task,
    validate_packet,
    worker_node,
)
from factory.runtime.workflow_core import (
    Invalid,
    acceptance_guard,
    digest,
    relative,
    require,
)
from factory.validation import validation_message

PACKET_REFERENCE = TypeAdapter[PacketRef](PacketRef)
DELIVERY_RECEIPT = TypeAdapter[DeliveryReceipt](DeliveryReceipt)
PACKET_CONTENT_LIMIT = 5500
PACKET_RESPONSE_LIMIT = 12000


def save_receipt(root: Path, receipt: DeliveryReceipt) -> None:
    current_database().packets.save_receipt(root, receipt)


def delivery_state(
    root: Path, meta: PacketRef, total: int, recipient: str | None = None
) -> dict[str, int]:
    return current_database().packets.delivery_state(root, meta, total, recipient)


def encode_packet(packet: dict[str, Any]) -> bytes:
    # acpx trims surrounding whitespace when reading prompt text from a file.
    return json.dumps(packet, ensure_ascii=False, indent=2).encode("utf-8")


def freeze_packet(
    root: Path,
    s: State,
    n: Node,
    v: Dispatch,
    *,
    packets: PacketRepository | None = None,
    history: HistoryRepository | None = None,
) -> tuple[PacketRef, bytes]:
    """Freeze a validated dispatch under the caller's ledger lock."""
    node_id = n["id"]
    task = s["graph"]["tasks"][n["task"]]
    rel = f".factory/memory/state/{s['run_id']}-{node_id}-{v['dispatch_id']}.packet.json"
    p = relative(root, rel)
    existing = v.get("packet_file")
    if existing is not None:
        return existing, read_packet_bytes(
            root, s, n, existing, existing, packets=packets, history=history
        )
    require(not p.exists(), "Packet path already exists; reconcile artifact")
    packet = acceptance_guard(implement_packet, s, node_id)
    data = encode_packet(packet)
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
    v["packet_file"] = meta
    s.setdefault("transport_artifacts", []).append(rel)
    s.setdefault("packet_hashes", {})[rel] = meta["sha256"]
    return meta, data


def materialize_packet(root: Path, meta: PacketRef, data: bytes) -> None:
    p = relative(root, meta["path"])
    if p.exists():
        require(digest(file_reader.read_bytes(p)) == meta["sha256"], "Packet digest mismatch")
        return
    fd, temp = tempfile.mkstemp(prefix=".packet-", dir=p.parent)
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


def packet_chunks(data: bytes) -> list[str]:
    chunks = []
    start = 0
    while start < len(data):
        end = min(start + PACKET_CONTENT_LIMIT, len(data))
        while end < len(data) and data[end] & 0xC0 == 0x80:
            end -= 1
        chunks.append(data[start:end].decode("utf-8"))
        start = end
    return chunks


def packet_response(result: object) -> bytes:
    response = json.dumps({"ok": True, "result": result}, ensure_ascii=False, indent=2)
    encoded = response.encode("utf-8") + b"\n"
    require(len(encoded) <= PACKET_RESPONSE_LIMIT, "Packet response exceeds display limit")
    return encoded


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
    root: Path,
    s: State,
    n: Node,
    expected: PacketRef,
    supplied: object,
    *,
    packets: PacketRepository | None = None,
    history: HistoryRepository | None = None,
) -> bytes:
    packets = current_database().packets if packets is None else packets
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
    data = packets.read_packet(root, expected)
    if p.exists():
        require(digest(file_reader.read_bytes(p)) == expected["sha256"], "Packet digest mismatch")
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
            report_history.read(root, item["report_ref"], history=history)
    return data


def packet_confirmed(dispatch: Dispatch) -> bool:
    return dispatch.get("packet_delivery_version") == 2 and bool(dispatch.get("packet_confirmed"))


def acknowledgement(chunks: list[str], ordinal: int) -> str:
    return f"v2:{ordinal}:{digest(chunks[ordinal - 1].encode('utf-8'))}"


def _save_delivery(
    root: Path,
    packets: PacketRepository,
    meta: PacketRef,
    recipient: str,
    before: PacketDelivery,
    after: PacketDelivery,
) -> None:
    if before != after:
        packets.save_receipt(
            root,
            DELIVERY_RECEIPT.validate_python(
                {
                    "packet": meta,
                    "recipient": recipient,
                    "version": 2,
                    "served": after.served,
                    "acknowledged": after.acknowledged,
                }
            ),
        )


def serve_chunk(
    root: Path,
    meta: PacketRef,
    chunks: list[str],
    ordinal: int,
    received: str | None,
    recipient: str,
    *,
    packets: PacketRepository | None = None,
) -> None:
    packets = current_database().packets if packets is None else packets
    expected = acknowledgement(chunks, ordinal - 1) if ordinal > 1 else None
    require(received == expected, "Acknowledge the preceding chunk ordinal and digest")
    progress = packets.delivery_state(root, meta, len(chunks), recipient)
    current = PacketDelivery(progress["served"], progress["acknowledged"])
    updated = current.serve(ordinal)
    _save_delivery(root, packets, meta, recipient, current, updated)


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
    root: Path,
    meta: PacketRef,
    data: bytes,
    received: str,
    materials: str,
    recipient: str,
    *,
    packets: PacketRepository | None = None,
) -> None:
    packets = current_database().packets if packets is None else packets
    chunks = packet_chunks(data)
    final = len(chunks)
    require(
        received == acknowledgement(chunks, final) and materials == material_digest(data),
        "Confirm final chunk ordinal/digest and mandatory material set",
    )
    progress = packets.delivery_state(root, meta, final, recipient)
    current = PacketDelivery(progress["served"], progress["acknowledged"])
    updated = current.confirm(final)
    _save_delivery(root, packets, meta, recipient, current, updated)


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
    recipient = s["nodes"][n["id"]].get("handle")
    if recipient:
        args.extend(["--recipient", recipient])
    read_args = [*prefix, *args, "--chunk", "1"]
    confirm_args = [*prefix, *args[:3], "confirm-packet", *args[4:]]
    operator = "& " if shell == "PowerShell" else ""
    command = operator + " ".join(map(quote, read_args))
    confirm = operator + " ".join(map(quote, confirm_args))
    return {
        **meta,
        "workspace": str(root),
        "role": s["nodes"][n["id"]]["role"],
        "recipient": recipient,
        "owns": n.get("owns", []),
        "stage": n["stage"],
        "read_command": command,
        "read_shell": shell,
        "confirm_command": confirm,
        "instruction": (
            "Run read_command in read_shell with a tool output limit of at least 12000 tokens. "
            "Use one command per response. After truncation or missing output, retry the same command "
            "with a large enough output limit. Require the complete JSON response and content. Set --chunk "
            "to next and --ack to its acknowledgement. After the last complete response, append "
            "--ack and --materials from it to confirm_command. Wait for confirmation before "
            "writes or assigned commands."
            if recipient
            else "Bind the actual worker first, then prepare this packet again for the bound recipient."
        ),
    }


def pending_packet_confirmations(state: State) -> list[str]:
    return [
        node_id
        for node_id, dispatch in state["nodes"].items()
        if dispatch["status"] in {"reserved", "running"}
        and "packet_receipt" in dispatch
        and not packet_confirmed(dispatch)
    ]
