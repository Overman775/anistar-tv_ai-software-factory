"""Look up accepted reports visible in the current checkout."""

from pathlib import Path
from typing import Literal, Protocol

from pydantic import BaseModel

from factory.runtime.contracts import ReportRef


class CaseMatch(BaseModel):
    source_type: Literal["case"] = "case"
    run_id: str
    task_id: str
    node: str
    dispatch_id: str
    ordinal: int
    report_ref: ReportRef
    sha256: str
    excerpt: str


class CaseIndex(Protocol):
    def search_cases(self, root: Path, query: str) -> tuple[list[CaseMatch], list[str]]: ...
    def reset(self, root: Path) -> None: ...
