"""Shared Markdown table parsing."""

import re


def split_row(line: str) -> list[str]:
    """Split on unescaped pipes while preserving the original cell text."""
    line = line.strip()
    cells: list[str] = []
    start = 0
    for match in re.finditer(r"(?<!\\)(?:\\\\)*\|", line):
        delimiter = match.end() - 1
        cells.append(line[start:delimiter].strip())
        start = delimiter + 1
    cells.append(line[start:].strip())
    if line.startswith("|"):
        cells.pop(0)
    if start == len(line):
        cells.pop()
    return cells
