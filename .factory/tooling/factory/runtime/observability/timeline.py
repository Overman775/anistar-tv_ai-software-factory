"""Read a correlated workflow timeline without starting an exporter."""

from pathlib import Path

from factory.runtime.observability.export_feed import ObservationReader
from factory.runtime.observability.observations import Observation
from factory.runtime.observability.projection import observe


def timeline(
    root: Path, run: str, dispatch: str | None = None, *, reader: ObservationReader
) -> list[Observation]:
    records = reader.read_run(root, run)
    observations = [item for record in records for item in observe(record)]
    if dispatch is not None:
        attempts = {
            item.span_id
            for item in observations
            if item.name == "factory.attempt"
            and item.attributes.get("factory.dispatch.id") == dispatch
        }
        if not attempts:
            raise LookupError("Unknown workflow dispatch")
        observations = [
            item
            for item in observations
            if item.name == "factory.run"
            or item.attributes.get("factory.dispatch.id") == dispatch
            or any(link.span_id in attempts for link in item.links)
        ]
    return sorted(
        observations,
        key=lambda item: (
            item.name != "factory.run",
            item.start_ns is None,
            item.start_ns or 0,
            item.span_id,
        ),
    )
