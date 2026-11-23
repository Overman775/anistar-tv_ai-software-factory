"""Encode named scalar attributes in OTLP envelopes."""

from collections.abc import Iterator, Mapping

from opentelemetry.proto.common.v1.common_pb2 import KeyValue

from factory.runtime.observability.observations import Scalar


def attribute(key: str, value: Scalar) -> KeyValue:
    field = KeyValue(key=key)
    if isinstance(value, bool):
        field.value.bool_value = value
    elif isinstance(value, int):
        field.value.int_value = value
    elif isinstance(value, float):
        field.value.double_value = value
    else:
        field.value.string_value = value
    return field


def attributes(fields: Mapping[str, Scalar | None]) -> Iterator[KeyValue]:
    return (attribute(key, value) for key, value in fields.items() if value is not None)
