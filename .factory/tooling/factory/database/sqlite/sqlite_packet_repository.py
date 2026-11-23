"""Packet originals and receipt updates in the workflow database."""

from pathlib import Path

from factory.database.sqlite import artifacts, workflow_db
from factory.runtime.contracts import PacketRef
from factory.runtime.packets.repository import DeliveryReceipt
from factory.runtime.workflow_core import require


def read_packet(root: Path, meta: PacketRef) -> bytes:
    with workflow_db.database(root) as db:
        return artifacts.read(db, meta["run_id"], meta["path"], meta["sha256"])


def save_receipt(root: Path, receipt: DeliveryReceipt) -> None:
    packet = receipt["packet"]
    recipient = receipt.get("recipient")
    require(receipt.get("version") == 2 and recipient, "Invalid packet delivery receipt")
    with workflow_db.database(root) as db:
        saved = db.execute(
            """INSERT INTO packet_deliveries(artifact_id,recipient,source_hash,revision,served,acknowledged)
               SELECT artifact_id,?,?,?,?,? FROM artifacts WHERE run_id=? AND path=? AND kind='packet'
               AND node_id=? AND dispatch_id=? AND sha256=?
               ON CONFLICT(artifact_id,recipient) DO UPDATE SET
                   served=max(served,excluded.served), acknowledged=max(acknowledged,excluded.acknowledged)
               WHERE source_hash=excluded.source_hash AND revision=excluded.revision""",
            (
                recipient,
                packet["source_hash"],
                packet["revision"],
                receipt["served"],
                receipt["acknowledged"],
                packet["run_id"],
                packet["path"],
                packet["node_id"],
                packet["dispatch_id"],
                packet["sha256"],
            ),
        )
        require(saved.rowcount == 1, "Invalid packet delivery receipt")


def delivery_state(
    root: Path, meta: PacketRef, total: int, recipient: str | None = None
) -> dict[str, int]:
    query = """SELECT d.served,d.acknowledged,d.source_hash,d.revision,a.path,a.node_id
               FROM artifacts a JOIN packet_deliveries d ON d.artifact_id=a.artifact_id
               WHERE a.run_id=? AND a.dispatch_id=? AND a.kind='packet' AND a.sha256=?"""
    args = [meta["run_id"], meta["dispatch_id"], meta["sha256"]]
    if recipient is not None:
        query += " AND d.recipient=?"
        args.append(recipient)
    else:
        query += " ORDER BY d.rowid DESC LIMIT 1"
    with workflow_db.database(root) as db:
        row = db.execute(query, args).fetchone()
    if row is None:
        return {"acknowledged": 0, "served": 0}
    served, acknowledged, source_hash, revision, path, node = row
    require(
        path == meta["path"]
        and node == meta["node_id"]
        and source_hash == meta["source_hash"]
        and revision == meta["revision"]
        and served <= total,
        "Invalid packet delivery receipt",
    )
    return {"acknowledged": acknowledged, "served": served}
