"""Execute a registered check as a command worker and record its process evidence."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import TYPE_CHECKING, Literal

from pydantic import TypeAdapter, ValidationError

from factory import file_reader
from factory.runtime.commands import verification, windows_job
from factory.runtime.commands.process import run_process
from factory.runtime.contracts import ExecutionReceipt, ProcessFacts, ProcessOwner, TestSelection
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import (
    Invalid,
    relative,
    require,
    snapshot,
)
from factory.runtime.workflow_core import lock as lock

if TYPE_CHECKING:
    from factory.runtime.run_journal import RunJournal


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
                require("owner" not in record, "Command already has a launcher")
                if os.name == "nt":
                    windows_job.enter(execution_id)
                else:
                    require(os.getpgrp() == os.getpid(), "Supervisor must lead its process group")
                record["owner"] = PROCESS_OWNER.validate_python(
                    {
                        "execution_id": execution_id,
                        "process_group": os.getpid(),
                        "platform": os.name,
                    }
                )
                ledger.save(state, "check_process", node=node["id"], execution_id=execution_id)
                return record
        except Invalid as exc:
            if not str(exc).startswith("Ledger locked") or attempt == 99:
                raise
            time.sleep(0.02)
    raise AssertionError("unreachable")


def test_selection(log: Path, mode: Literal["full", "filtered"] = "full") -> TestSelection | None:
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
    if (
        report["mode"] != mode
        or report["selected"]
        != report["completed"] + (report.get("skipped", 0) if mode == "filtered" else 0)
        or (mode == "full" and report.get("skipped", 0) != 0)
        or len(set(files)) != len(files)
    ):
        return None
    return report


def filtered_selection(
    log: Path, observations: list[verification.Verification], *, structured: bool
) -> TestSelection | None:
    with file_reader.open_binary(log) as stream:
        marked = any(line.startswith(b"FACTORY_TEST_SELECTION ") for line in stream)
    test_observations = [item for item in observations if "complete" in item]
    if marked:
        if structured and any(
            item.get("complete") is not True or item["scope"] != "filtered"
            for item in test_observations
        ):
            return None
        return test_selection(log, "filtered")
    observations = test_observations
    if (
        not structured
        or not observations
        or any(
            item.get("complete") is not True or item["scope"] != "filtered" for item in observations
        )
    ):
        return None
    completed = sum(item["counts"].get("completed_test_count", 0) for item in observations)
    skipped = sum(item["counts"].get("skipped_test_count", 0) for item in observations)
    if completed <= 0:
        return None
    return {
        "mode": "filtered",
        "selected": completed + skipped,
        "completed": completed,
        "skipped": skipped,
    }


def selection_error(
    selection: TestSelection | None,
    before: dict[str, str],
    *,
    files_required: bool,
    mode: Literal["full", "filtered"] = "full",
) -> str | None:
    if (
        not selection
        or selection["mode"] != mode
        or (files_required and not selection.get("files"))
    ):
        return "Missing valid " + mode + " test selection/completion evidence"
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
            started = time.time()
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
            verification_result = verification.capture(
                log, cwd, started, result["exit_code"], result_format=execution.get("result_format")
            )
            if (
                spec["kind"] == "tests"
                and execution.get("mode") == "filtered"
                and not files_required
            ):
                selection = filtered_selection(
                    log, verification_result, structured=bool(execution.get("result_format"))
                )
                result["error"] = result["error"] or selection_error(
                    selection, before, files_required=False, mode="filtered"
                )
                if (
                    selection is not None
                    and len(verification_result) == 1
                    and verification_result[0]["suite"] == "unknown"
                ):
                    counts = verification_result[0]["counts"]
                    selected_counts = {
                        "selected": selection["selected"],
                        "completed_test_count": selection["completed"],
                        "skipped_test_count": selection.get("skipped", 0),
                    }
                    if any(
                        key in counts and counts[key] != value
                        for key, value in selected_counts.items()
                    ):
                        result["error"] = (
                            result["error"] or "Filtered selection contradicts command test counts"
                        )
                    else:
                        verification_result[0]["scope"] = "filtered"
                        counts.update(selected_counts)
            if (
                execution.get("result_format")
                and spec["kind"] == "tests"
                and not any(
                    item["counts"].get("completed_test_count", 0) > 0
                    for item in verification_result
                )
            ):
                result["error"] = (
                    result["error"] or "Missing nonempty structured test execution evidence"
                )
            if (execution.get("result_format") or spec["kind"] == "tests") and any(
                item["result"] == "BLOCKED" for item in verification_result
            ):
                result["error"] = (
                    result["error"] or "Structured command evidence incomplete or inconsistent"
                )
            results[stage_id] = {
                "input_scope": scope,
                "files": before,
                "after_files": after,
                "mode": execution.get("mode"),
                "selection": selection,
                "verification": verification_result,
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
        result_facts = PROCESS_FACTS.validate_python(
            {"execution_id": execution_id, "process_group": os.getpid(), "stages": results}
        )
        with ledger.locked(wait=True):
            state = ledger.read()
            current = state["executions"][execution_id]
            require(
                current["status"] == "RUNNING"
                and current.get("owner") == record["owner"]
                and current["dispatch_id"] == record["dispatch_id"],
                "Command result belongs to a different process or assignment",
            )
            current["process_facts"] = result_facts
            ledger.save(state, "check_returned", node=record["node_id"], execution_id=execution_id)
    finally:
        # Reap surviving descendants before anyone may release the command resource.
        if os.name == "posix":
            os.killpg(os.getpid(), signal.SIGKILL)


def facts(execution_id: str, record: ExecutionReceipt) -> dict[str, object] | None:
    owner = record.get("owner")
    if owner is None:
        return None
    pid = owner["process_group"]
    require(owner["execution_id"] == execution_id and pid > 1, "Invalid command process identity")
    if windows_job.live(execution_id) if owner["platform"] == "nt" else group_live(pid):
        return None
    result = record.get("process_facts")
    if result is None:
        return {"stages": {}, "process_group": pid}
    require(
        result["execution_id"] == execution_id and result["process_group"] == pid,
        "Invalid supervisor result identity",
    )
    return dict(result)


def main() -> None:
    """Start the private supervisor in the same Python environment as the workflow."""
    from factory.logging_config import diagnostic_operation
    from factory.runtime.run_journal import RunJournal

    workspace, execution_id = sys.argv[1:]
    with diagnostic_operation(workspace, "_check-worker"):
        supervise(RunJournal(workspace), execution_id)


if __name__ == "__main__":
    main()
