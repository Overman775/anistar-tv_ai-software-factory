"""Encode public observation fields as OTLP. Evidence references are local."""

from collections.abc import Iterator

from opentelemetry.proto.trace.v1.trace_pb2 import Span, Status

from factory.runtime.observability.export_feed import ObservationSource
from factory.runtime.observability.observations import Observation
from factory.runtime.observability.otlp_fields import attribute, attributes
from factory.runtime.observability.projection import observe


def encode(record: Observation) -> Span:
    if record.start_ns is None:
        raise ValueError("Missing start time on exportable observation")
    result = Span(
        name=record.name,
        trace_id=bytes.fromhex(record.trace_id),
        span_id=bytes.fromhex(record.span_id),
        parent_span_id=bytes.fromhex(record.parent_span_id) if record.parent_span_id else b"",
        kind=Span.SPAN_KIND_INTERNAL,
        start_time_unix_nano=record.start_ns,
        end_time_unix_nano=record.end_ns if record.end_ns is not None else record.start_ns,
        status=Status(code=Status.STATUS_CODE_ERROR) if record.failed else None,
    )
    for name, value in record.attributes.items():
        if isinstance(value, int) and not -(2**63) <= value < 2**63:
            result.dropped_attributes_count += 1
        else:
            result.attributes.append(attribute(name, value))
    for event in record.events:
        result.events.add(
            name=event.name,
            time_unix_nano=event.time_ns if event.time_ns is not None else record.start_ns,
            attributes=attributes(event.attributes),
        )
    for link in record.links:
        result.links.add(trace_id=bytes.fromhex(link.trace_id), span_id=bytes.fromhex(link.span_id))
    return result


def project(record: ObservationSource) -> Iterator[Span]:
    return (encode(item) for item in observe(record))
