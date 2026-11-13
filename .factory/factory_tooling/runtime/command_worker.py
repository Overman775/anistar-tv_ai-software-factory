"""Run registered commands under a durable, single-launch supervisor."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING

from factory_tooling.runtime import windows_job
from factory_tooling.runtime.check_process import run_process
from factory_tooling.runtime.contracts import ExecutionReceipt
from factory_tooling.runtime.workflow_config import check_config
from factory_tooling.runtime.workflow_core import (
    Invalid,
    atomic_json,
    read_json,
    relative,
    require,
    snapshot,
)

if TYPE_CHECKING:
    from factory_tooling.runtime.workflow import Ledger


@contextmanager
def lock(path: Path) -> Iterator[None]:
    """The kernel releases ownership when a caller dies. Keep one stable lock inode."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as file:
        try:
            if sys.platform != "win32":
                import fcntl

                fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            else:
                import msvcrt

                file.seek(0)
                msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError as exc:
            raise Invalid("Ledger locked; retry after the current transaction") from exc
        yield


def artifact(root: Path, record: ExecutionReceipt, suffix: str) -> Path:
    return relative(root, record["output"] + suffix)


def launch(
    root: Path,
    wrapper: Path,
    execution_id: str,
    record: ExecutionReceipt,
) -> subprocess.Popen[bytes]:
    with artifact(root, record, ".supervisor.log").open("ab") as diagnostics:
        return subprocess.Popen(
            [sys.executable, str(wrapper), "--workspace", str(root), "_check-worker", execution_id],
            stdin=subprocess.DEVNULL,
            stdout=diagnostics,
            stderr=diagnostics,
            start_new_session=os.name == "posix",
        )


def group_live(pid: int) -> bool:
    try:
        os.killpg(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def own(ledger: Ledger, execution_id: str) -> ExecutionReceipt:
    # A delayed supervisor rechecks the durable intent before running any project code.
    for attempt in range(100):
        try:
            with ledger.locked():
                state = ledger.read()
                record = state.get("executions", {}).get(execution_id)
                if record is None or record["status"] != "RUNNING":
                    raise Invalid("Command intent is no longer active")
                require(
                    state["nodes"][record["node_id"]]["dispatch_id"] == record["dispatch_id"],
                    "Command launch dispatch changed",
                )
                require(
                    state["nodes"][record["node_id"]]["status"] == "running",
                    "Command launch dispatch is not running",
                )
                check_config(state)
                node = next(n for n in state["graph"]["nodes"] if n["id"] == record["node_id"])
                ledger.check_sources(state, state["graph"]["tasks"][node["task"]])
                path = artifact(ledger.root, record, ".owner.json")
                require(not path.exists(), "Command already has a launcher")
                if os.name == "nt":
                    windows_job.enter(execution_id)
                else:
                    require(os.getpgrp() == os.getpid(), "Supervisor must lead its process group")
                atomic_json(
                    path,
                    {
                        "execution_id": execution_id,
                        "process_group": os.getpid(),
                        "platform": os.name,
                    },
                )
                return record
        except Invalid as exc:
            if not str(exc).startswith("Ledger locked") or attempt == 99:
                raise
            time.sleep(0.02)
    raise AssertionError("unreachable")


def test_selection(log: Path) -> dict[str, int | str] | None:
    """Read the selected/completed counts emitted by a registered full test stage."""
    reports = []
    with log.open("rb") as stream:
        for line in stream:
            if line.startswith(b"FACTORY_TEST_SELECTION "):
                try:
                    reports.append(json.loads(line[len(b"FACTORY_TEST_SELECTION ") :]))
                except ValueError:
                    return None
    if len(reports) != 1:
        return None
    report = reports[0]
    if not (
        isinstance(report, dict)
        and set(report) == {"mode", "selected", "completed"}
        and report["mode"] == "full"
        and type(report["selected"]) is int
        and type(report["completed"]) is int
        and 0 < report["selected"] == report["completed"]
    ):
        return None
    return {"mode": "full", "selected": report["selected"], "completed": report["completed"]}


def supervise(ledger: Ledger, execution_id: str) -> None:
    record = own(ledger, execution_id)
    composite = record.get("composite_stages", [])
    stages = composite or [
        {"execution_id": execution_id, "spec": record["spec"], "output": record["output"]}
    ]
    results = {}
    scope = record["input_scope"]
    before_all = snapshot(ledger.root, scope)
    final_result: dict[str, int | str | None] = {"exit_code": None, "error": "No stages executed"}
    try:
        require(before_all == record["files"], "Command inputs drifted before launch")
        for stage in stages:
            stage_id, spec, output = stage["execution_id"], stage["spec"], stage["output"]
            execution = spec["execution"]
            cwd = (
                ledger.root if execution["cwd"] == "." else relative(ledger.root, execution["cwd"])
            )
            before = snapshot(ledger.root, scope)
            log = relative(ledger.root, output)
            result = run_process(execution, cwd, log, separate_group=False)
            selection = None
            if composite and spec["kind"] == "tests" and result["exit_code"] == 0:
                selection = test_selection(log)
                if selection is None:
                    result["error"] = "Missing valid full test selection/completion evidence"
            after = snapshot(ledger.root, scope)
            if any(before[p] != after[p] for p in scope if p not in execution.get("outputs", [])):
                result["error"] = "Files changed during check"
            results[stage_id] = {
                "input_scope": scope,
                "files": before,
                "after_files": after,
                "mode": execution.get("mode"),
                "selection": selection,
                **result,
            }
            final_result = {"exit_code": result["exit_code"], "error": result["error"]}
            if result["error"] or result["exit_code"] != 0:
                break
        if composite:
            with relative(ledger.root, record["output"]).open("x", encoding="utf-8") as summary:
                for stage in composite:
                    facts = results.get(stage["execution_id"])
                    status = (
                        f"exit={facts['exit_code']} error={facts['error']}" if facts else "skipped"
                    )
                    summary.write(f"{stage['spec']['id']}: {status} ({stage['output']})\n")
                summary.flush()
                os.fsync(summary.fileno())
            results[execution_id] = {
                "input_scope": scope,
                "files": before_all,
                "after_files": snapshot(ledger.root, scope),
                **final_result,
            }
        atomic_json(
            artifact(ledger.root, record, ".result.json"),
            {"execution_id": execution_id, "process_group": os.getpid(), "stages": results},
        )
    finally:
        # Reap surviving descendants before anyone may release the command resource.
        if os.name == "posix":
            os.killpg(os.getpid(), signal.SIGKILL)


def facts(root: Path, execution_id: str, record: ExecutionReceipt) -> dict[str, object] | None:
    owner = artifact(root, record, ".owner.json")
    if not owner.exists():
        return None
    identity = read_json(owner)
    pid = identity.get("process_group")
    require(
        identity.get("execution_id") == execution_id and type(pid) is int and pid > 1,
        "Invalid command process identity",
    )
    if windows_job.live(execution_id) if identity.get("platform") == "nt" else group_live(pid):
        return None
    path = artifact(root, record, ".result.json")
    if not path.exists():
        return {"stages": {}, "process_group": pid}
    result = read_json(path)
    require(
        result.get("execution_id") == execution_id
        and result.get("process_group") == pid
        and isinstance(result.get("stages"), dict),
        "Invalid supervisor result",
    )
    return dict(result)
