"""Validate the returned Done Signal against the exact staged task files."""

import json
import re
from pathlib import Path, PureWindowsPath
from typing import Annotated, Literal, NotRequired

from pydantic import ConfigDict, Field, StringConstraints, TypeAdapter, with_config
from typing_extensions import TypedDict

from factory import file_reader
from factory.decompose.contracts import Text
from factory.project.profile_io import sha

Sha256 = Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{64}$")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ManifestFile(TypedDict):
    path: Text
    sha256: Sha256
    content_base64: NotRequired[str]


@with_config(ConfigDict(strict=True, extra="forbid"))
class DoneSignal(TypedDict):
    status: Literal["DONE"]
    staging_root: Text
    task_count: Annotated[int, Field(gt=0)]
    blockers: Annotated[list[Text], Field(max_length=0)]
    files: Annotated[list[ManifestFile], Field(min_length=1)]


DONE_SIGNAL = TypeAdapter[DoneSignal](DoneSignal)


def staged_manifest(root: Path) -> tuple[dict[str, str], int]:
    expected: dict[str, str] = {}
    count = 0
    paths = sorted(root.rglob("*"))
    if any(path.is_symlink() or not (path.is_dir() or path.is_file()) for path in paths):
        raise ValueError("Staging contains an unsafe entry")
    actual = {path.relative_to(root).as_posix() for path in paths if path.is_file()}
    for envelope in sorted(root.rglob("task_result.json")):
        raw = file_reader.read_bytes(envelope)
        document = json.loads(raw)
        if not isinstance(document, dict) or not isinstance(tasks := document.get("tasks"), list):
            raise ValueError("Done Signal references an invalid task list")
        count += len(tasks)
        expected[envelope.relative_to(root).as_posix()] = sha(raw)
        for task in tasks:
            name = task.get("filename") if isinstance(task, dict) else None
            if not isinstance(name, str) or not valid_markdown_name(name):
                raise ValueError("Done Signal references an unsafe task filename")
            path = envelope.with_name(name)
            relative = path.relative_to(root).as_posix()
            if relative in expected:
                raise ValueError("Multiple tasks reference the same staged Markdown")
            expected[relative] = sha(file_reader.read_bytes(path))
    if expected.keys() != actual or not count:
        raise ValueError("Staging must contain exactly the task envelopes and referenced Markdown")
    return expected, count


def valid_markdown_name(name: str) -> bool:
    return re.fullmatch(r"[^/\\\x00]+\.md", name) is not None and not PureWindowsPath(name).drive
