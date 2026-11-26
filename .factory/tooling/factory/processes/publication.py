"""Stage owned output beside its destination and reconcile installation by inode and bytes."""

import ctypes
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

from factory import file_reader
from factory.runtime.workflow_core import digest, graph_identity, relative, require


def destination(root: Path, name: str) -> Path:
    require(
        Path(name).parts and Path(name).parts[0] not in {".git", ".factory"},
        "Use a public project output path",
    )
    return relative(root, name)


def identity(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        require(not path.is_symlink(), "Symlink at publication target")
        return None
    require(not path.is_symlink(), "Symlink at publication target")
    stat = path.stat()
    if path.is_dir():
        entries = {}
        for item in sorted(path.rglob("*")):
            name = item.relative_to(path).as_posix()
            require(not item.is_symlink(), "Symlink inside publication")
            entries[name] = (
                "directory"
                if item.is_dir()
                else digest(file_reader.read_bytes(relative(path, name)))
            )
        checksum = graph_identity(entries)
    else:
        require(path.is_file() and stat.st_nlink == 1, "Unexpected publication object")
        checksum = digest(file_reader.read_bytes(path))
    return {"device": stat.st_dev, "inode": stat.st_ino, "digest": checksum}


def prepare(
    root: Path,
    name: str,
    files: dict[str, str],
    expected: dict[str, Any] | None,
    *,
    directory: bool,
) -> dict[str, Any]:
    target = destination(root, name)
    require(identity(target) == expected, "Publication destination changed before preparation")
    target.parent.mkdir(parents=True, exist_ok=True)
    private = Path(tempfile.mkdtemp(prefix=".factory-publication-", dir=target.parent))
    staged = private / "payload"
    if directory:
        require(expected is None and files, "A task directory must be new and nonempty")
        staged.mkdir()
        for key, content in files.items():
            file = relative(staged, key)
            file.parent.mkdir(parents=True, exist_ok=True)
            with file.open("xb") as stream:
                stream.write(content.encode())
                stream.flush()
                os.fsync(stream.fileno())
    else:
        require(set(files) == {"content"}, "Plan publication needs one exact document")
        with staged.open("xb") as stream:
            stream.write(files["content"].encode())
            stream.flush()
            os.fsync(stream.fileno())
    return {
        "destination": name,
        "staged": staged.relative_to(root).as_posix(),
        "owned": identity(staged),
        "previous": expected,
    }


def move_new(source: Path, target: Path) -> None:
    """Unlike POSIX rename, this also preserves an unrelated empty target directory."""
    if os.name == "nt":
        os.rename(source, target)
        return
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == "darwin":
        error = libc.renamex_np(os.fsencode(source), os.fsencode(target), 4)  # RENAME_EXCL
    else:
        error = libc.renameat2(
            -100, os.fsencode(source), -100, os.fsencode(target), 1
        )  # RENAME_NOREPLACE
    if error:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number), str(target))


def install(root: Path, operation: dict[str, Any]) -> dict[str, Any]:
    target = destination(root, operation["destination"])
    staged = relative(root, operation["staged"])
    backup = staged.with_name("previous")
    old, new = operation["previous"], operation["owned"]
    actual = identity(target)
    if actual == new:
        require(not staged.exists(), "Installation ownership is ambiguous")
    else:
        require(identity(staged) == new, "Staged publication changed or disappeared")
        if old is not None and not backup.exists():
            require(actual == old, "Prior plan revision was replaced or edited")
            move_new(target, backup)
        if old is not None and identity(backup) != old:
            if backup.exists() and not target.exists():
                move_new(backup, target)
            raise ValueError("Prior plan revision changed during publication")
        require(not target.exists(), "Foreign output at publication destination")
        move_new(staged, target)
    require(identity(target) == new, "Installed output no longer matches the owned operation")
    return {"destination": operation["destination"], "identity": new}


def cancel(root: Path, operation: dict[str, Any]) -> None:
    stage = relative(root, operation["staged"])
    backup = stage.with_name("previous")
    target = destination(root, operation["destination"])
    require(
        identity(target) != operation["owned"],
        "The owned publication was installed; reconcile it with publish before closing",
    )
    if backup.exists():
        require(
            operation["previous"] is not None and identity(backup) == operation["previous"],
            "The displaced version changed; reconcile the publication before cancellation",
        )
        require(
            identity(target) is None, "Foreign destination prevents restoring the previous plan"
        )
        move_new(backup, target)


def discard_cancelled(root: Path, operation: dict[str, Any]) -> None:
    stage = relative(root, operation["staged"])
    require(
        not stage.with_name("previous").exists(), "Previous publication still needs reconciliation"
    )
    if stage.exists():
        require(identity(stage) == operation["owned"], "Staged object changed before cleanup")
        if stage.is_dir():
            shutil.rmtree(stage)
        else:
            stage.unlink()
    if stage.parent.is_dir() and not any(stage.parent.iterdir()):
        stage.parent.rmdir()


def release(root: Path, operation: dict[str, Any]) -> None:
    """Only remove a known displaced version after the successful commit."""
    stage = relative(root, operation["staged"])
    backup = stage.with_name("previous")
    if (
        backup.exists()
        and operation["previous"] is not None
        and identity(backup) == operation["previous"]
    ):
        backup.unlink()
    if stage.parent.is_dir() and not any(stage.parent.iterdir()):
        stage.parent.rmdir()
