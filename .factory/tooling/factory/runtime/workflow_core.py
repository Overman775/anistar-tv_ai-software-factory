"""Workflow errors, safe paths, snapshots and atomic JSON persistence."""

from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from factory import file_reader


class Invalid(ValueError):
    pass


def require(condition: object, message: str) -> None:
    if not condition:
        raise Invalid(message)


@contextmanager
def lock(path: Path, *, create_parents: bool = True, wait: bool = False) -> Iterator[None]:
    """The kernel releases ownership when a caller dies. Keep one stable lock inode."""
    if create_parents:
        path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as file:
        try:
            if sys.platform != "win32":
                import fcntl

                fcntl.flock(file.fileno(), fcntl.LOCK_EX | (0 if wait else fcntl.LOCK_NB))
            else:
                import msvcrt

                file.seek(0)
                msvcrt.locking(file.fileno(), msvcrt.LK_LOCK if wait else msvcrt.LK_NBLCK, 1)
        except OSError as exc:
            raise Invalid("Ledger locked; retry after the current transaction") from exc
        yield


def acceptance_guard[**P, R](function: Callable[P, R], *args: P.args, **kwargs: P.kwargs) -> R:
    try:
        return function(*args, **kwargs)
    except ValueError as exc:
        raise Invalid(str(exc)) from exc


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def identity(value: object) -> str:
    return digest(json.dumps(value, sort_keys=True, ensure_ascii=False).encode())


def read_json(path: str | Path) -> Any:
    return json.loads(file_reader.read_text(Path(path), encoding="utf-8"))


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
        if p.exists():
            with file_reader.open_binary(p) as f:
                result[rel] = hashlib.file_digest(f, "sha256").hexdigest()
        else:
            result[rel] = "DELETED"
    return result
