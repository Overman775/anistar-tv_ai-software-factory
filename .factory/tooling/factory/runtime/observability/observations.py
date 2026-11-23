"""Local observation format shared by the history reader and external encoders."""

import hashlib
import json
from dataclasses import dataclass, field
from datetime import UTC, datetime

type Scalar = str | float | int | bool


@dataclass(frozen=True)
class ReportReference:
    dispatch_id: str
    path: str
    sha256: str


@dataclass(frozen=True)
class ObservationLink:
    trace_id: str
    span_id: str


@dataclass(frozen=True)
class ObservationEvent:
    name: str
    time_ns: int | None
    attributes: dict[str, Scalar]
    reports: tuple[ReportReference, ...] = ()


@dataclass(frozen=True)
class Observation:
    name: str
    trace_id: str
    span_id: str
    parent_span_id: str | None
    start_ns: int | None
    end_ns: int | None
    failed: bool
    attributes: dict[str, Scalar]
    events: list[ObservationEvent] = field(default_factory=list)
    links: list[ObservationLink] = field(default_factory=list)
    reports: tuple[ReportReference, ...] = ()


def ident(*parts: str, size: int = 8) -> str:
    return hashlib.sha256(json.dumps(parts, ensure_ascii=False).encode()).digest()[:size].hex()


def nanos(at: str) -> int:
    instant = datetime.fromisoformat(at)
    if instant.tzinfo is None:
        instant = instant.replace(tzinfo=UTC)
    elapsed = instant - datetime(1970, 1, 1, tzinfo=UTC)
    return ((elapsed.days * 86400 + elapsed.seconds) * 1_000_000 + elapsed.microseconds) * 1000
