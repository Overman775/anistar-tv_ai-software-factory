"""Index checkout documents and search their current revisions."""

import re
from collections.abc import Callable
from pathlib import Path
from typing import Protocol

type IndexDocument = Callable[[str, bytes], tuple[str, str] | None]


class LessonIndexError(OSError):
    def __init__(self, message: str, error_type: str) -> None:
        super().__init__(message)
        self.error_type = error_type


class LessonIndex(Protocol):
    def search(
        self, root: Path, files: dict[str, bytes], terms: tuple[str, ...], describe: IndexDocument
    ) -> tuple[list[str], dict[str, str]]: ...


def search_terms(query: str) -> tuple[str, ...]:
    return tuple(dict.fromkeys(re.findall(r"[^\W_]+", query.casefold())))
