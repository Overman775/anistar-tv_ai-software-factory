"""Monotonic delivery progress for one packet and recipient."""

from dataclasses import dataclass

from factory.runtime.workflow_core import require


@dataclass(frozen=True)
class PacketDelivery:
    served: int
    acknowledged: int

    def __post_init__(self) -> None:
        require(
            0 <= self.acknowledged <= self.served <= self.acknowledged + 1,
            "Invalid packet delivery progress",
        )

    def serve(self, ordinal: int) -> PacketDelivery:
        require(
            1 <= ordinal <= self.served + 1,
            "Chunk was not served in order; restart at chunk 1 if delivery receipt was lost",
        )
        return PacketDelivery(max(self.served, ordinal), max(self.acknowledged, ordinal - 1))

    def confirm(self, final: int) -> PacketDelivery:
        require(
            final >= 1 and self.served == final and self.acknowledged >= final - 1,
            "Packet chunks must be received in order before confirmation",
        )
        return PacketDelivery(final, final)
