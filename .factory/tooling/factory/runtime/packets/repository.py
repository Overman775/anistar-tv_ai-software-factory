"""Frozen packet content and durable, monotonic delivery receipts."""

from pathlib import Path
from typing import Literal, NotRequired, Protocol

from pydantic import ConfigDict, with_config
from typing_extensions import TypedDict

from factory.runtime.contracts import PacketRef


@with_config(ConfigDict(strict=True, extra="forbid"))
class DeliveryReceipt(TypedDict):
    packet: PacketRef
    acknowledged: int
    served: int
    recipient: NotRequired[str]
    version: NotRequired[Literal[2]]


class PacketRepository(Protocol):
    def read_packet(self, root: Path, meta: PacketRef) -> bytes: ...
    def save_receipt(self, root: Path, receipt: DeliveryReceipt) -> None: ...
    def delivery_state(
        self, root: Path, meta: PacketRef, total: int, recipient: str | None = None
    ) -> dict[str, int]: ...
