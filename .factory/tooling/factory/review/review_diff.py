"""Git diff parsing and verified diff/source loading."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from factory.review.review_contracts import (
    feature_source_errors,
    sha256_text,
    valid_scope_path,
)


def decode_git_path(value: str) -> str:
    output = bytearray()
    index = 0
    while index < len(value):
        escaped = value[index : index + 4]
        if len(escaped) == 4 and escaped[0] == "\\" and re.fullmatch(r"\\[0-7]{3}", escaped):
            output.append(int(escaped[1:], 8))
            index += 4
        elif value[index] == "\\" and index + 1 < len(value):
            escapes = {
                "a": 7,
                "b": 8,
                "t": 9,
                "n": 10,
                "v": 11,
                "f": 12,
                "r": 13,
                '"': 34,
                "\\": 92,
            }
            escaped_char = value[index + 1]
            if escaped_char not in escapes:
                raise ValueError("diff: unsupported Git path escape")
            output.append(escapes[escaped_char])
            index += 2
        else:
            output.extend(value[index].encode("utf-8"))
            index += 1
    return output.decode("utf-8")


def parse_diff(diff: str) -> dict[str, Any]:
    paths: list[str] = []
    added: set[tuple[str, int]] = set()
    deleted: set[tuple[str, int]] = set()
    binary: set[str] = set()
    operations: dict[str, list[dict[str, str]]] = {}
    current: str | None = None
    previous: str | None = None
    metadata: dict[str, str] = {}

    def finish_section() -> None:
        if current is None:
            return
        records: list[dict[str, str]] = []
        if "old mode" in metadata or "new mode" in metadata:
            old_mode, new_mode = metadata.get("old mode"), metadata.get("new mode")
            if (
                not re.fullmatch(r"[0-7]{6}", old_mode or "")
                or not re.fullmatch(r"[0-7]{6}", new_mode or "")
                or old_mode == new_mode
            ):
                raise ValueError("diff: incomplete or invalid mode change")
            assert old_mode is not None and new_mode is not None
            records.append({"operation": "mode", "old_mode": old_mode, "new_mode": new_mode})
        if "rename from" in metadata or "rename to" in metadata:
            old_path, new_path = metadata.get("rename from"), metadata.get("rename to")
            if (
                not valid_scope_path(old_path)
                or not valid_scope_path(new_path)
                or old_path != previous
                or new_path != current
                or old_path == new_path
            ):
                raise ValueError("diff: incomplete or inconsistent rename")
            assert old_path is not None and new_path is not None
            records.append({"operation": "rename", "old_path": old_path, "new_path": new_path})
        operations[current] = records

    old_line: int | None = None
    new_line: int | None = None
    for line in diff.splitlines():
        if line.startswith("diff --git "):
            finish_section()
            # Git leaves spaces unquoted in file headers. Extended rename headers
            # below must still match both paths before they can prove an operation.
            match = re.fullmatch(
                r'diff --git ("(?:[^"\\]|\\.)*"|a/.*) ("(?:[^"\\]|\\.)*"|b/.*)',
                line,
            )
            if match is None:
                raise ValueError("diff: malformed file header")
            old, new = (value[1:-1] if value.startswith('"') else value for value in match.groups())
            if not old.startswith("a/") or not new.startswith("b/"):
                raise ValueError("diff: malformed file header")
            previous = decode_git_path(old[2:])
            current = decode_git_path(new[2:])
            if not valid_scope_path(previous) or not valid_scope_path(current):
                raise ValueError("diff: invalid file path")
            metadata = {}
            paths.append(current)
            old_line = new_line = None
            continue
        if current is None:
            continue
        if old_line is None and new_line is None:
            for field in ("old mode", "new mode", "rename from", "rename to"):
                if line.startswith(field + " "):
                    if field in metadata:
                        raise ValueError("diff: duplicate operation metadata")
                    value = line[len(field) + 1 :]
                    if field.startswith("rename"):
                        if value.startswith('"'):
                            if not value.endswith('"'):
                                raise ValueError("diff: malformed quoted rename path")
                            value = value[1:-1]
                        value = decode_git_path(value)
                    metadata[field] = value
                    break
        if line.startswith("Binary files ") or line == "GIT binary patch":
            binary.add(current)
            continue
        match = re.match(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        if match:
            old_line, new_line = int(match.group(1)), int(match.group(2))
            continue
        if old_line is None or new_line is None or line.startswith("\\ No newline"):
            continue
        if line.startswith("+"):
            added.add((current, new_line))
            new_line += 1
        elif line.startswith("-"):
            deleted.add((current, old_line))
            old_line += 1
        else:
            old_line += 1
            new_line += 1
    finish_section()
    if len(paths) != len(set(paths)):
        raise ValueError("diff: duplicate file section")
    return {
        "paths": sorted(paths),
        "new": added,
        "old": deleted,
        "binary": binary,
        "file_operations": operations,
    }


def load_diff_context(manifest: dict[str, Any]) -> tuple[dict[str, Any], list[str]]:
    if manifest.get("mode") == "feature":
        return {
            "paths": manifest.get("scope_files", []),
            "new": set(),
            "old": set(),
            "binary": set(),
            "feature_sources_valid": not feature_source_errors(manifest),
        }, []
    try:
        diff = Path(manifest["diff_file"]).read_text(encoding="utf-8")
        errors = []
        if sha256_text(diff) != manifest.get("diff_sha256"):
            errors.append("diff: sha256 mismatch")
        context = parse_diff(diff)
        if context["paths"] != manifest.get("scope_files"):
            errors.append("diff: paths do not equal manifest scope")
        if errors:
            return {"paths": [], "new": set(), "old": set(), "binary": set()}, errors
        return context, errors
    except (KeyError, OSError, UnicodeError, ValueError) as exc:
        return {"paths": [], "new": set(), "old": set(), "binary": set()}, [f"diff: {exc}"]
