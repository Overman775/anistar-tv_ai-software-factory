"""Persistence boundary for the best-effort local diagnostic journal."""

from collections.abc import Iterable
from contextlib import AbstractContextManager
from pathlib import Path
from typing import NamedTuple, Protocol


class JournalBusy(OSError):
    """The caller may retry within its remaining diagnostic budget."""


class LogRow(NamedTuple):
    payload: str
    run: str | None
    dispatch: str | None
    exportable: bool = False


class DiagnosticJournal(Protocol):
    def prepare(self, root: Path) -> None: ...
    def append(
        self, root: Path, invocation_id: str, rows: list[LogRow], timeout: float
    ) -> None: ...
    def records(
        self, root: Path, key: str, value: str, cursor: int
    ) -> AbstractContextManager[Iterable[tuple[int, str]]]:
        """Newest first by invocation_id, run_id, dispatch_id or operation; cursor is exclusive."""
        ...

    def snapshot(self, root: Path) -> list[str]:
        """Return retained payloads in insertion order from one read-only snapshot."""
        ...

    def delivery_window(self, root: Path, receiver: str) -> tuple[int, int]:
        """Last acknowledged sequence and highest eligible sequence ever written."""
        ...

    def delivery_batch(
        self, root: Path, after: int, until: int, limit: int
    ) -> list[tuple[int, str]]: ...
    def acknowledge(self, root: Path, receiver: str, sequence: int) -> None: ...
