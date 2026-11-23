"""Immutable reference to evidence for a run."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Artifact:
    name: str
    kind: str
    source: bytes | Path
    node: str | None = None
    dispatch: str | None = None
    expected: str | None = None


def transport_report(run: str, node: str, dispatch: str) -> str:
    return f".factory/memory/state/{run}-{node}-{dispatch}.report.json"
