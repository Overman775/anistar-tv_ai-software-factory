"""Track writable ACPX output handles across adapter and child process lifetimes."""

import sys
from pathlib import Path
from typing import IO

from factory.runtime.workflow_core import Invalid


def protect_writer(stream: IO[str]) -> None:
    if sys.platform != "win32":
        import fcntl

        # Child stdout/stderr inherit this open file description. Close, never unlock it.
        fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)


def require_idle(path: Path) -> None:
    try:
        if sys.platform == "win32":
            import _winapi
            from stat import FILE_ATTRIBUTE_NORMAL

            # FILE_SHARE_READ permits readers and conflicts with every extant write handle.
            handle = _winapi.CreateFile(
                str(path),
                _winapi.GENERIC_READ,
                1,
                0,
                _winapi.OPEN_EXISTING,
                FILE_ATTRIBUTE_NORMAL,
                0,
            )
            _winapi.CloseHandle(handle)
        else:
            import fcntl

            with path.open("rb") as reader:
                fcntl.flock(reader.fileno(), fcntl.LOCK_SH | fcntl.LOCK_NB)
    except FileNotFoundError:
        # The journaled request can precede creation of either stream.
        return
    except OSError as exc:
        if isinstance(exc, BlockingIOError) or getattr(exc, "winerror", None) == 32:
            raise Invalid(f"Transport output locked by a writer: {path.name}") from exc
        raise
