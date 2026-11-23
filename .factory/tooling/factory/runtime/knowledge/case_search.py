"""Search visible accepted cases through a checkout-scoped index."""

from pathlib import Path

from factory.database.provider import current_database
from factory.runtime.knowledge.case_index import CaseIndex as CaseIndex
from factory.runtime.knowledge.case_index import CaseMatch as CaseMatch
from factory.runtime.knowledge.case_reports import AcceptedReport as AcceptedReport
from factory.runtime.knowledge.case_reports import verified_case as verified_case


def search_cases(
    root: Path, query: str, *, index: CaseIndex | None = None
) -> tuple[list[CaseMatch], list[str]]:
    index = current_database().cases if index is None else index
    return index.search_cases(root, query)
