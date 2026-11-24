"""Run registered commands under a durable, single-launch supervisor."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import TYPE_CHECKING, Literal, NotRequired

from pydantic import ConfigDict, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory import file_reader
from factory.diagnostics.events import event
from factory.runtime.commands import windows_job
from factory.runtime.commands.process import run_process
from factory.runtime.contracts import ExecutionReceipt, Nonblank, Positive, TestSelection
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import (
    Invalid,
    atomic_json,
    read_json,
    relative,
    require,
    snapshot,
)
from factory.runtime.workflow_core import lock as lock
from factory.validation import validation_message

if TYPE_CHECKING:
    from factory.runtime.run_journal import RunJournal


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProcessOwner(TypedDict):
    execution_id: Nonblank
    process_group: Positive
    platform: Literal["posix", "nt"]


@with_config(ConfigDict(strict=True, extra="forbid"))
class StageFacts(TypedDict):
    input_scope: list[str]
    files: dict[str, str]
    after_files: dict[str, str]
    exit_code: int | None
    error: str | None
    mode: NotRequired[Literal["full", "filtered", "update"] | None]
    selection: NotRequired[TestSelection | None]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ProcessFacts(TypedDict):
    execution_id: Nonblank
    process_group: Positive
    stages: dict[str, StageFacts]


PROCESS_OWNER = TypeAdapter[ProcessOwner](ProcessOwner)
PROCESS_FACTS = TypeAdapter[ProcessFacts](ProcessFacts)
TEST_SELECTION = TypeAdapter[TestSelection](TestSelection)


def artifact(root: Path, record: ExecutionReceipt, suffix: str) -> Path:
    return relative(root, record["output"] + suffix)


def launch(
    root: Path,
    execution_id: str,
    record: ExecutionReceipt,
) -> subprocess.Popen[bytes]:
    with artifact(root, record, ".supervisor.log").open("ab") as diagnostics:
        return subprocess.Popen(
            [
                sys.executable,
                "-E",
                "-s",
                "-B",
                "-P",
                "-m",
                "factory.runtime.command_worker",
                str(root),
                execution_id,
            ],
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


def own(ledger: RunJournal, execution_id: str) -> ExecutionReceipt:
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
                    PROCESS_OWNER.validate_python(
                        {
                            "execution_id": execution_id,
                            "process_group": os.getpid(),
                            "platform": os.name,
                        }
                    ),
                )
                event(
                    "check_process",
                    run_id=state["run_id"],
                    task_id=node["task"],
                    node_id=node["id"],
                    dispatch_id=record["dispatch_id"],
                    execution_id=execution_id,
                )
                return record
        except Invalid as exc:
            if not str(exc).startswith("Ledger locked") or attempt == 99:
                raise
            time.sleep(0.02)
    raise AssertionError("unreachable")


def test_selection(log: Path) -> TestSelection | None:
    """Read the selection emitted by the project test runner."""
    reports = []
    with file_reader.open_binary(log) as stream:
        for line in stream:
            if line.startswith(b"FACTORY_TEST_SELECTION "):
                try:
                    reports.append(json.loads(line[len(b"FACTORY_TEST_SELECTION ") :]))
                except ValueError:
                    return None
    if len(reports) != 1:
        return None
    try:
        report = TEST_SELECTION.validate_python(reports[0])
    except ValidationError:
        return None
    files = report.get("files", [])
    if report["selected"] != report["completed"] or len(set(files)) != len(files):
        return None
    return report


def selection_error(
    selection: TestSelection | None, before: dict[str, str], *, files_required: bool
) -> str | None:
    if not selection or (files_required and not selection.get("files")):
        return "Missing valid full test selection/completion evidence"
    omitted = sorted(
        path for path in selection.get("files", []) if before.get(path) in {None, "DELETED"}
    )
    if omitted:
        return "Executed test files missing from input snapshot: " + ", ".join(omitted)
    return None


def supervise(ledger: RunJournal, execution_id: str) -> None:
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
            files_required = execution.get("selection_files", False)
            if result["exit_code"] is not None and (
                files_required
                or (composite and spec["kind"] == "tests" and result["exit_code"] == 0)
            ):
                selection = test_selection(log)
                result["error"] = result["error"] or selection_error(
                    selection, before, files_required=files_required
                )
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
            PROCESS_FACTS.validate_python(
                {"execution_id": execution_id, "process_group": os.getpid(), "stages": results}
            ),
        )
    finally:
        # Reap surviving descendants before anyone may release the command resource.
        if os.name == "posix":
            os.killpg(os.getpid(), signal.SIGKILL)


def facts(root: Path, execution_id: str, record: ExecutionReceipt) -> dict[str, object] | None:
    owner = artifact(root, record, ".owner.json")
    if not owner.exists():
        return None
    try:
        identity = PROCESS_OWNER.validate_python(read_json(owner))
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid command owner", exc, PROCESS_OWNER)) from None
    try:
        pid = identity["process_group"]
        require(
            identity["execution_id"] == execution_id and pid > 1,
            "Invalid command process identity",
        )
        if windows_job.live(execution_id) if identity["platform"] == "nt" else group_live(pid):
            return None
        path = artifact(root, record, ".result.json")
        if not path.exists():
            return {"stages": {}, "process_group": pid}
        result = PROCESS_FACTS.validate_python(read_json(path))
        require(
            result["execution_id"] == execution_id and result["process_group"] == pid,
            "Invalid supervisor result identity",
        )
        return dict(result)
    except ValidationError as exc:
        raise Invalid(validation_message("Invalid command evidence", exc, PROCESS_FACTS)) from None


def main() -> None:
    """Start the private supervisor in the same Python environment as the workflow."""
    from factory.logging_config import diagnostic_operation
    from factory.runtime.run_journal import RunJournal

    workspace, execution_id = sys.argv[1:]
    with diagnostic_operation(workspace, "_check-worker"):
        supervise(RunJournal(workspace), execution_id)


if __name__ == "__main__":
    main()
