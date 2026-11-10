"""Workflow errors, safe paths, snapshots and atomic JSON persistence."""

from __future__ import annotations

import hashlib
import json
import os
import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Any, ParamSpec, TypeVar


class Invalid(ValueError):
    pass


def require(condition: object, message: str) -> None:
    if not condition:
        raise Invalid(message)


P = ParamSpec("P")
R = TypeVar("R")


def acceptance_guard(function: Callable[P, R], *args: P.args, **kwargs: P.kwargs) -> R:
    try:
        return function(*args, **kwargs)
    except ValueError as exc:
        raise Invalid(str(exc)) from exc


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: str | Path) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def atomic_json(path: str | Path, value: object) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    require(not path.is_symlink(), f"Symlink output: {path}")
    fd, tmp = tempfile.mkstemp(prefix=".write-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(value, f, ensure_ascii=False, indent=2)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def relative(root: str | Path, path: str) -> Path:
    if not (isinstance(path, str) and path and (not Path(path).is_absolute())):
        raise Invalid(f"Expected relative path: {path}")
    require(".." not in Path(path).parts and path != ".", f"Unsafe path: {path}")
    require(Path(path).as_posix() == path and "\\" not in path, f"Noncanonical path: {path}")
    result = Path(root) / path
    cursor = Path(root)
    for part in Path(path).parts:
        cursor = cursor / part
        require(not cursor.is_symlink(), f"Symlink path: {path}")
    require(result.resolve().is_relative_to(Path(root).resolve()), f"Path escapes root: {path}")
    require(
        not result.is_file() or result.stat().st_nlink == 1,
        f"Hardlinked scope is ambiguous: {path}",
    )
    return result


def snapshot(workspace: str | Path, scope: list[str]) -> dict[str, str]:
    result = {}
    for rel in scope:
        p = relative(workspace, rel)
        require(not p.is_symlink() and not p.is_dir(), f"Scope must contain real files: {rel}")
        result[rel] = digest(p.read_bytes()) if p.exists() else "DELETED"
    return result
