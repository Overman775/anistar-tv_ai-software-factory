"""Run commands with bounded waits and durable logs; callers interpret results."""

import os
import signal
import subprocess
import tempfile
from collections.abc import Callable
from contextlib import ExitStack
from pathlib import Path
from typing import BinaryIO, Literal, Protocol, TypedDict

from factory.checks.command import validate_execution


class Process(Protocol):
    """A started process whose kill method stops its configured execution scope."""

    @property
    def pid(self) -> int: ...
    def wait(self, timeout: float | None = None) -> int: ...
    def kill(self) -> None: ...


class Spawn(Protocol):
    def __call__(
        self,
        argv: list[str],
        *,
        cwd: Path,
        stdin: BinaryIO | int,
        stdout: BinaryIO,
        stderr: BinaryIO,
        start_new_session: bool,
    ) -> Process: ...


class ProcessResult(TypedDict):
    exit_code: int | None
    error: str | None


class _Subprocess:
    def __init__(self, process: subprocess.Popen[bytes], *, group: bool) -> None:
        self._process = process
        self._group = group

    @property
    def pid(self) -> int:
        return self._process.pid

    def wait(self, timeout: float | None = None) -> int:
        return self._process.wait(timeout=timeout)

    def kill(self) -> None:
        if self._group:
            os.killpg(self.pid, signal.SIGKILL)
        else:
            self._process.kill()


def start_process(
    argv: list[str],
    *,
    cwd: Path,
    stdin: BinaryIO | int,
    stdout: BinaryIO,
    stderr: BinaryIO,
    start_new_session: bool,
) -> Process:
    process = subprocess.Popen(
        argv,
        cwd=cwd,
        stdin=stdin,
        stdout=stdout,
        stderr=stderr,
        start_new_session=start_new_session,
    )
    return _Subprocess(process, group=start_new_session)


def run_process(
    execution: object,
    cwd: Path,
    output: Path,
    on_started: Callable[[int], None] | None = None,
    *,
    stderr: Path | None = None,
    input_bytes: bytes | None = None,
    popen: Spawn | None = None,
    separate_group: bool = True,
) -> ProcessResult:
    """Return exit_code/error facts, never a gate verdict.

    Logs are exclusive files. Optional stdin is spooled, avoiding pipe deadlocks.
    Publish PID before waiting. Reap the process after interruption or timeout;
    on POSIX kill its process group, including children. Windows kills the direct
    process only. The caller owns authorization, input hashes and receipt identity.
    """
    execution = validate_execution(execution)
    if "stages" in execution:
        raise ValueError("Composite execution cannot be run as a physical command")
    spawn: Spawn = start_process if popen is None else popen
    code, error = None, None
    with ExitStack() as stack:
        stdout = stack.enter_context(output.open("xb"))
        err = stack.enter_context(stderr.open("xb")) if stderr is not None else stdout
        stdin: BinaryIO | int = subprocess.DEVNULL
        if input_bytes is not None:
            stdin = stack.enter_context(tempfile.TemporaryFile())
            stdin.write(input_bytes)
            stdin.seek(0)
        try:
            process = spawn(
                execution["argv"],
                cwd=cwd,
                stdin=stdin,
                stdout=stdout,
                stderr=err,
                start_new_session=os.name == "posix" and separate_group,
            )
            try:
                if on_started is not None:
                    on_started(process.pid)
                code = process.wait(timeout=execution["timeout_seconds"])
            except BaseException:
                try:
                    process.kill()
                except ProcessLookupError:
                    pass
                process.wait()
                raise
        except (OSError, subprocess.TimeoutExpired, KeyboardInterrupt) as exc:
            error = type(exc).__name__ + (": " + str(exc) if str(exc) else "")
        finally:
            for log in {stdout, err}:
                log.flush()
                os.fsync(log.fileno())
    return {"exit_code": code, "error": error}


def execute_check(
    execution: object,
    cwd: Path,
    output: Path,
    on_started: Callable[[int], None],
    *,
    popen: Spawn | None = None,
) -> tuple[int | None, Literal["PASS", "FAIL", "BLOCKED"], str | None]:
    """Implement receipts interpret a normal nonzero command exit as FAIL."""
    result = run_process(execution, cwd, output, on_started, popen=popen)
    code, error = result["exit_code"], result["error"]
    status: Literal["PASS", "FAIL", "BLOCKED"] = (
        "BLOCKED" if error else "PASS" if code == 0 else "FAIL"
    )
    return code, status, error
