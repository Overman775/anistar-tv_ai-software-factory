"""Issue native assignments and authenticate delivery and receipt for the bound worker."""

from __future__ import annotations

from typing import Any

from factory.runtime.contracts import Dispatch, Node, State, agent_key
from factory.runtime.history.artifact_ref import Artifact
from factory.runtime.packets.content import (
    acknowledgement,
    confirm_delivery,
    encode_packet,
    freeze_packet,
    material_digest,
    packet_bootstrap,
    packet_chunks,
    packet_confirmed,
    packet_diagnostics,
    packet_response,
    read_packet_bytes,
    serve_chunk,
)
from factory.runtime.run_journal import RunJournal
from factory.runtime.scheduling.assignment import implement_packet
from factory.runtime.workflow_config import check_capabilities, check_config
from factory.runtime.workflow_core import Invalid, acceptance_guard, digest, require


def packet(journal: RunJournal, node_id: str) -> dict[str, Any]:
    """Materialize native instructions; caller performs actual host dispatch."""
    with journal.locked():
        s = journal.read()
        require(s["status"] == "active", "Run is not active")
        check_config(s)
        n = next(n for n in s["graph"]["nodes"] if n["id"] == node_id)
        v = s["nodes"][node_id]
        require(v["status"] in {"reserved", "running"}, "Reserve node before packet")
        profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
        require(profile["runner"] == "native", "Use ACP prepare for ACP profile")
        check_capabilities(profile, n)
        task = s["graph"]["tasks"][n["task"]]
        journal.check_sources(s, task)
        packet = acceptance_guard(implement_packet, s, node_id)
        data = encode_packet(packet)
        name = (
            f".factory/memory/history/{s['run_id']}/packets/{v['dispatch_id']}-{digest(data)}.json"
        )
        journal.runs.store_artifact(
            journal.root,
            s["run_id"],
            Artifact(name, "inline-packet", data, node_id, v["dispatch_id"]),
        )
        return packet


def prepare_packet(
    journal: RunJournal, node_id: str, *, with_diagnostics: bool = False
) -> dict[str, Any]:
    """Freeze a native assignment and return its worker bootstrap."""
    with journal.locked():
        s = journal.read()
        n, v = packet_dispatch(journal, s, node_id)
        already_prepared = "packet_file" in v
        meta, data = freeze_packet(
            journal.root, s, n, v, packets=journal.packets, history=journal.history
        )
        if not already_prepared:
            v["packet_receipt"] = meta["dispatch_id"]
            journal.save_artifacts(
                s,
                "packet_prepared",
                (Artifact(meta["path"], "packet", data, node_id, v["dispatch_id"]),),
                node=node_id,
                dispatch_id=v["dispatch_id"],
            )
        bootstrap = packet_bootstrap(journal.root, s, n, meta)
        if with_diagnostics:
            data = read_packet_bytes(
                journal.root, s, n, meta, meta, packets=journal.packets, history=journal.history
            )
            return {"bootstrap": bootstrap, "diagnostics": packet_diagnostics(data)}
        return bootstrap


def packet_dispatch(
    journal: RunJournal, s: State, node_id: str, *, runner: str = "native"
) -> tuple[Node, Dispatch]:
    require(s["status"] == "active", "Run is not active")
    require(s["workspace"] == str(journal.root), "Packet workspace mismatch")
    check_config(s)
    n = next((n for n in s["graph"]["nodes"] if n["id"] == node_id), None)
    if n is None or node_id not in s["nodes"]:
        raise Invalid("Unknown packet node")
    v = s["nodes"][node_id]
    require(v["status"] in {"reserved", "running"}, "Reserve node before packet")
    agent = s["graph"]["agents"][agent_key(n)]
    profile = s["config"]["profiles"][agent["profile"]]
    require(
        v["profile"] == agent["profile"] and v["role"] == agent["role"],
        "Packet assignment profile mismatch",
    )
    require(profile["runner"] == runner, f"Packet requires {runner} profile")
    check_capabilities(profile, n)
    journal.check_sources(s, s["graph"]["tasks"][n["task"]])
    return n, v


def read_packet(
    journal: RunJournal,
    node_id: str,
    bootstrap: object,
    chunk: int,
    received: str | None = None,
    *,
    recipient: str | None = None,
) -> dict[str, Any]:
    """Serve one bounded chunk; only an acknowledged response advances delivery."""
    with journal.locked():
        s = journal.read()
        n, v = packet_dispatch(journal, s, node_id)
        handle = packet_recipient(v, recipient)
        expected = v.get("packet_file")
        if expected is None:
            raise Invalid("Prepare packet first")
        data = read_packet_bytes(
            journal.root,
            s,
            n,
            expected,
            bootstrap,
            packets=journal.packets,
            history=journal.history,
        )
        journal.diagnostic_attempt = (node_id, expected["dispatch_id"])
        chunks = packet_chunks(data)
        total = len(chunks)
        require(type(chunk) is int and 1 <= chunk <= total, "Invalid packet chunk")
        content = chunks[chunk - 1]
        response = {
            "ordinal": chunk,
            "total": total,
            "next": chunk + 1 if chunk < total else None,
            "content": content,
            "content_bytes": len(content.encode("utf-8")),
            "acknowledgement": acknowledgement(chunks, chunk),
            "materials": material_digest(data) if chunk == total else None,
            "binding": v["status"],
            "ready_for_work": packet_confirmed(v),
        }
        packet_response(response)
        serve_chunk(
            journal.root, expected, chunks, chunk, received, handle, packets=journal.packets
        )
        return response


def packet_recipient(dispatch: Dispatch, recipient: str | None) -> str:
    handle = dispatch.get("handle")
    if dispatch["status"] != "running" or not handle:
        raise Invalid("Bind actual recipient before reading or confirming packet")
    require(recipient is None or recipient == handle, "Packet recipient mismatch")
    return handle


def confirm_packet(
    journal: RunJournal,
    node_id: str,
    bootstrap: object,
    received: str = "",
    materials: str = "",
    *,
    recipient: str | None = None,
) -> None:
    with journal.locked():
        s = journal.read()
        n, dispatch = packet_dispatch(journal, s, node_id)
        expected = dispatch.get("packet_file")
        if expected is None:
            raise Invalid("Prepare packet first")
        handle = packet_recipient(dispatch, recipient)
        data = read_packet_bytes(
            journal.root,
            s,
            n,
            expected,
            bootstrap,
            packets=journal.packets,
            history=journal.history,
        )
        journal.diagnostic_attempt = (node_id, expected["dispatch_id"])
        confirm_delivery(
            journal.root, expected, data, received, materials, handle, packets=journal.packets
        )
        if packet_confirmed(dispatch):
            return
        dispatch["packet_confirmed"] = True
        dispatch["packet_delivery_version"] = 2
        journal.save(
            s,
            "packet_confirmed",
            node=node_id,
            dispatch_id=expected["dispatch_id"],
            sha256=expected["sha256"],
            handle=handle,
        )
