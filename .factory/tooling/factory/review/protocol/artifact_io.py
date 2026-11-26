"""Read review artifact JSON objects."""

import json
from pathlib import Path
from typing import Any

from factory import file_reader

type Document = Path | dict[str, Any]


def load_object(path: Document) -> dict[str, Any]:
    if isinstance(path, dict):
        return path
    value = json.loads(file_reader.read_text(path, encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path}: JSON object required")
    return value
