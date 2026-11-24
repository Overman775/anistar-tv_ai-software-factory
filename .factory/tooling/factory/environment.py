"""Read process settings and optional literal UTF-8 environment files."""

import os
import re
from collections.abc import Iterator, Mapping
from contextlib import contextmanager
from contextvars import ContextVar
from pathlib import Path

from factory import file_reader
from factory.paths import TOOLS

_environment: ContextVar[Mapping[str, str] | None] = ContextVar("factory_environment", default=None)


@contextmanager
def use_environment(environ: Mapping[str, str]) -> Iterator[None]:
    with _environment.set(environ):
        yield


def settings(
    file: Path | None = None, *, environ: Mapping[str, str] | None = None
) -> Mapping[str, str]:
    if environ is None:
        environ = _environment.get()
    process = os.environ if environ is None else environ
    if file is None:
        return process
    values: dict[str, str] = {}
    for number, line in enumerate(file_reader.read_text(file, encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        key, value = key.strip(), value.strip()
        if not sep or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            raise ValueError(f"Invalid environment assignment on line {number}")
        if value.startswith(("'", '"')):
            if len(value) < 2 or value[-1] != value[0]:
                raise ValueError(f"Unclosed environment value on line {number}")
            value = value[1:-1]
        values[key] = value
    return {**values, **process}


def bundle_python_environment() -> dict[str, str]:
    """Select this bundle for a child Python command, including disposable copies."""
    return {
        **{
            name: value
            for name, value in os.environ.items()
            if not name.upper().startswith("PYTHON")
        },
        "PYTHONPATH": str(TOOLS),
    }
