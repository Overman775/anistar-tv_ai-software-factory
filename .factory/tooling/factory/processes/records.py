"""Run and attempt records shared by standalone processes."""

from pathlib import Path
from typing import Any, Literal, Protocol

from pydantic import BaseModel, ConfigDict, Field

type Process = Literal["planning", "decompose", "code-review", "retune"]


class Record(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid")


class Attempt(Record):
    role: str
    node: str
    dispatch: str
    number: int
    status: Literal["reserved", "running", "unknown", "done", "failed"] = "reserved"
    handle: str | None = None
    evidence: list[dict[str, Any]] = Field(default_factory=list)
    outcome: str | None = None


class ProcessState(Record):
    phase: str
    attempts: dict[str, list[Attempt]] = Field(default_factory=dict)
    facts: dict[str, Any] = Field(default_factory=dict)
    paused: str | None = None
    terminal: Literal["completed", "cancelled"] | None = None


class ProcessRun(Record):
    run_id: str
    process: Process
    subject: dict[str, Any]
    definitions: dict[str, str]
    handlers: dict[str, str]
    state: ProcessState
    revision: int


class ProcessRepository(Protocol):
    def exists(self, root: Path, run_id: str) -> bool: ...
    def create(self, root: Path, run: ProcessRun) -> ProcessRun: ...
    def get(self, root: Path, run_id: str) -> ProcessRun: ...
    def receipt(self, root: Path, run_id: str, key: str, command: str) -> dict[str, Any] | None: ...
    def save(
        self,
        root: Path,
        run: ProcessRun,
        key: str,
        command: str,
        event: str,
        result: dict[str, Any],
    ) -> None: ...
    def history(self, root: Path, run_id: str) -> list[dict[str, Any]]: ...
