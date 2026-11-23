"""Validate the returned Done Signal against the exact staged task files."""

import json
import re
from pathlib import Path, PureWindowsPath
from typing import Annotated, Literal, NotRequired

from pydantic import ConfigDict, Field, StringConstraints, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory import file_reader
from factory.decompose.contracts import Text
from factory.decompose.staging.output_safety import reject_symlink_ancestors
from factory.project.profile_io import sha
from factory.validation import validation_message

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


def read_done_signal(path: str | Path, staging: str | Path) -> dict[str, str]:
    root = Path(staging).absolute()
    reject_symlink_ancestors(root)
    try:
        done = DONE_SIGNAL.validate_json(file_reader.read_bytes(Path(path)))
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid Done Signal", exc, DONE_SIGNAL)) from None
    if Path(done["staging_root"]).resolve() != root.resolve():
        raise ValueError("Done Signal staging root does not match the selected staging root")
    files = {entry["path"]: entry["sha256"] for entry in done["files"]}
    if len(files) != len(done["files"]):
        raise ValueError("Duplicate path in Done Signal")
    expected, count = staged_manifest(root)
    if count != done["task_count"] or files != expected:
        raise ValueError("Done Signal file manifest or task count differs from staged tasks")
    return files


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
