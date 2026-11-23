"""File contents used by a tooling invocation. Paths and locks stay with their owners."""

import shutil
from collections.abc import Iterator
from contextlib import contextmanager
from contextvars import ContextVar
from io import BufferedReader, BytesIO
from pathlib import Path
from typing import Protocol


class FileReader(Protocol):
    def read_bytes(self, path: Path) -> bytes: ...
    def read_text(self, path: Path, *, encoding: str, errors: str = "strict") -> str: ...
    def open_binary(self, path: Path) -> BufferedReader | BytesIO: ...


class LocalFileReader:
    def read_bytes(self, path: Path) -> bytes:
        return path.read_bytes()

    def read_text(self, path: Path, *, encoding: str, errors: str = "strict") -> str:
        return path.read_text(encoding=encoding, errors=errors)

    def open_binary(self, path: Path) -> BufferedReader | BytesIO:
        return path.open("rb")


_local_files = LocalFileReader()
_reader: ContextVar[FileReader] = ContextVar("factory_file_reader", default=_local_files)


@contextmanager
def use_reader(reader: FileReader) -> Iterator[None]:
    """Bind an input source across nested tooling calls and restore it on exit."""
    with _reader.set(reader):
        yield


def read_bytes(path: Path) -> bytes:
    return _reader.get().read_bytes(path)


def read_text(path: Path, *, encoding: str, errors: str = "strict") -> str:
    return _reader.get().read_text(path, encoding=encoding, errors=errors)


def open_binary(path: Path) -> BufferedReader | BytesIO:
    return _reader.get().open_binary(path)


def copy_file(source: Path, target: Path) -> None:
    """Copy selected input bytes into an owned staging directory."""
    if _reader.get() is _local_files:
        shutil.copyfile(source, target)
    else:
        with open_binary(source) as reader, target.open("wb") as output:
            shutil.copyfileobj(reader, output)


def copy_with_metadata(source: str, target: str) -> None:
    copy_file(Path(source), Path(target))
    shutil.copystat(source, target)
