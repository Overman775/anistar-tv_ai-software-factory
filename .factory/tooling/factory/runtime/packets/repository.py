"""Frozen packet content and durable, monotonic delivery receipts."""

from pathlib import Path
from typing import Protocol

from factory.runtime.contracts import PacketRef
from factory.runtime.packets.delivery import PacketDelivery


class PacketRepository(Protocol):
    def read_packet(self, root: Path, meta: PacketRef) -> bytes: ...
    def save_receipt(
        self, root: Path, packet: PacketRef, recipient: str, progress: PacketDelivery
    ) -> None: ...
    def delivery_state(
        self, root: Path, meta: PacketRef, total: int, recipient: str | None = None
    ) -> dict[str, int]: ...
