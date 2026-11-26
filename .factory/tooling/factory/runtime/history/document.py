"""Readable transport view of a typed handoff. Orchestration consumes the typed record."""

from collections.abc import Mapping


def render(value: object) -> bytes:
    lines: list[str] = []

    def emit(label: str, item: object, depth: int) -> None:
        prefix = "  " * depth + "- " + label
        if isinstance(item, Mapping):
            lines.append(prefix)
            for key in sorted(item):
                emit(str(key), item[key], depth + 1)
        elif isinstance(item, list):
            lines.append(prefix)
            for i, element in enumerate(item, 1):
                emit(str(i), element, depth + 1)
        else:
            text = "null" if item is None else str(item)
            first, *rest = text.split("\n")
            lines.append(prefix + " = " + first)
            lines.extend("  " * (depth + 1) + line for line in rest)

    if not isinstance(value, Mapping):
        raise ValueError("Expected structured handoff")
    for key in sorted(value):
        emit(str(key), value[key], 0)
    return "\n".join(lines).encode()
