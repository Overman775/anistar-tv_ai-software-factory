"""Reserve command execution and reconcile receipts with the originating dispatch."""

from __future__ import annotations

import platform
import shutil
import time
from contextlib import nullcontext
from pathlib import Path
from typing import Any, Literal

from factory.project.profile_rules import project_check_graph
from factory.runtime import command_worker
from factory.runtime.commands.evidence import active_commands
from factory.runtime.commands.execution import CheckExecution
from factory.runtime.contracts import CommandResult, ExecutionReceipt, PendingCheck, State
from factory.runtime.history.artifact_ref import Artifact
from factory.runtime.packets.content import pending_packet_confirmations
from factory.runtime.reports import finish_requirements
from factory.runtime.run_journal import RunJournal
from factory.runtime.transport import evidence as transport_evidence
from factory.runtime.workflow_config import check_config
from factory.runtime.workflow_core import Invalid, relative, require, snapshot
from factory.runtime.workflow_graph import validate_graph


def run_check(
    journal: RunJournal,
    node_id: str,
    check_id: str,
    request_id: str | None = None,
    *,
    expected_dispatch: str | None = None,
    dry_run: bool = False,
) -> CommandResult | PendingCheck | dict[str, object]:
    """Persist intent, run outside the ledger lock, then reconcile real process facts."""
    process = None
    with nullcontext() if dry_run else journal.locked():
        state = journal.read()
        current = state["nodes"][node_id]
        dispatch_id = current.get("dispatch_id")
        require(
            expected_dispatch is None or expected_dispatch == dispatch_id,
            "Execution request dispatch is stale",
        )
        if dispatch_id is not None:
            journal.diagnostic_attempt = (node_id, dispatch_id)
        request_id = check_id if request_id is None else request_id
        executions = state.get("executions", {})
        rid = CheckExecution.request_key(state["run_id"], node_id, dispatch_id, request_id)
        record = executions.get(rid)
        if record is not None:
            CheckExecution(rid, record).require_same_check(check_id)
        else:
            record = _check_intent(journal, state, node_id, check_id, rid, request_id)
            if not dry_run:
                relative(journal.root, record["output"]).parent.mkdir(parents=True, exist_ok=True)
                state.setdefault("executions", {})[rid] = record
                journal.save(state, "check_started", node=node_id, execution_id=rid)
                # Start after the intent commit. The supervisor cannot execute until it
                # acquires the ledger lock, rechecks the intent and registers ownership.
                try:
                    process = command_worker.launch(journal.root, rid, record)
                except OSError:
                    # No owner exists yet. Reconcile or explicitly abandon the intent.
                    return CheckExecution(rid, record).pending()
        if dry_run:
            stages = [stage["spec"] for stage in record.get("composite_stages", [])]
            return {
                "dry_run": True,
                "run_id": state["run_id"],
                "node_id": node_id,
                "dispatch_id": dispatch_id,
                "request_id": request_id,
                "execution_id": rid,
                "existing_result": executions[rid]["status"] if rid in executions else None,
                "stages": [
                    {"check_id": spec["id"], **spec["execution"]}
                    for spec in (stages or [record["spec"]])
                ],
                "input_scope": record["input_scope"],
            }
    if process is not None:
        process.wait()
    return reconcile_check(journal, rid)


def _check_intent(
    journal: RunJournal,
    state: State,
    node_id: str,
    check_id: str,
    rid: str,
    request_id: str,
) -> ExecutionReceipt:
    require(state["status"] == "active", "Run is not active")
    require(not state.get("pause_reason"), "Run is paused by user")

    check_config(state)
    nodes = validate_graph(state["graph"], state["config"], journal.root)
    node, dispatch = nodes[node_id], state["nodes"][node_id]
    require(dispatch["status"] == "running", "Check needs a bound running node")
    pending = pending_packet_confirmations(state)
    require(
        not pending,
        f"Wait for outstanding native packet delivery before running checks: {', '.join(pending)}",
    )
    require("project-checks" in node.get("resources", []), "Check needs project-checks reservation")
    require(
        not active_commands(state),
        "Unresolved command; reconcile process before retrying node",
    )
    task = state["graph"]["tasks"][node["task"]]
    journal.check_sources(state, task)
    obligations = finish_requirements.for_node(state, node)
    available = {c["id"]: c for c in obligations["allowed_checks"] if c["kind"] != "observation"}
    require(check_id in available, "Unknown assigned command")
    child_ids = available[check_id]["execution"].get("stages", [])
    require(
        len(set(child_ids)) == len(child_ids)
        and check_id not in child_ids
        and set(child_ids) <= set(available),
        "Composite requires distinct assigned command stages",
    )
    dependencies = project_check_graph(state["config"]["_project"]["data"]).parents
    require(
        not child_ids or {check_id, *child_ids} <= dependencies.keys(),
        "Composite and child checks must be registered",
    )
    require(
        not any(available[cid]["execution"].get("stages") for cid in child_ids),
        "Composite children must be direct commands",
    )
    previous: dict[str, ExecutionReceipt] = {
        r["spec"]["id"]: r
        for r in state.get("executions", {}).values()
        if r["node_id"] == node_id and r["dispatch_id"] == dispatch["dispatch_id"]
    }
    included: set[str] = set()
    for cid in (check_id, *child_ids):
        spec = available[cid]
        execution = spec["execution"]
        cwd = journal.root if execution["cwd"] == "." else relative(journal.root, execution["cwd"])
        require(cwd.is_dir(), "Check cwd does not exist")
        outputs = execution.get("outputs", [])
        require(
            not outputs
            or (
                spec["kind"] == "codegen"
                and set(outputs) <= set(node.get("owns", []))
                and set(outputs) <= set(task["scope"])
            ),
            "Generator outputs must be exact owned task paths",
        )
        for dependency in dependencies.get(cid, ()):
            if dependency in included:
                continue
            prior = previous.get(dependency)
            require(
                prior is not None
                and prior["status"] == "PASS"
                and prior["after_files"] == snapshot(journal.root, prior["input_scope"]),
                "Project check dependency missing/failed/stale: " + dependency,
            )
        included.add(cid)
    execution = available[check_id]["execution"]
    # Freeze all declared inputs and outputs before the first stage starts.
    scope = sorted(
        set(task["scope"]).union(
            *[
                set(available[cid]["execution"].get("inputs", []))
                | set(available[cid]["execution"].get("outputs", []))
                for cid in (check_id, *child_ids)
            ]
        )
    )
    output = f".factory/memory/history/{state['run_id']}/checks/{rid}.log"
    relative(journal.root, output)
    return {
        "run_id": state["run_id"],
        "node_id": node_id,
        "dispatch_id": dispatch["dispatch_id"],
        "source_hash": state["graph"]["sources"][task["source"]]["hash"],
        "spec": available[check_id],
        "input_scope": scope,
        "files": snapshot(journal.root, scope),
        "status": "RUNNING",
        "started_at": time.time(),
        "request_id": request_id,
        "output": output,
        "environment": {
            "platform": "-".join((platform.system(), platform.release(), platform.machine())),
            "python": platform.python_version(),
            "executable": shutil.which(execution["argv"][0]) if execution["argv"] else None,
        },
        "composite_stages": [
            {
                "execution_id": f"{rid}-{cid}",
                "spec": available[cid],
                "output": f".factory/memory/history/{state['run_id']}/checks/{rid}-{cid}.log",
            }
            for cid in child_ids
        ],
    }


def reconcile_check(
    journal: RunJournal, rid: str, abandon_unstarted: bool = False
) -> CommandResult | PendingCheck:
    with journal.locked():
        state = journal.read()
        record = state.get("executions", {}).get(rid)
        if record is None:
            raise Invalid("Unknown execution")
        if record["status"] != "RUNNING":
            return record["result"]
        execution = CheckExecution(rid, record)
        facts = command_worker.facts(rid, record)
        if facts is None:
            if not abandon_unstarted:
                return execution.pending()
            execution.require_abandonable(owner_registered="owner" in record)
            # The worker needs this same lock to register. A delayed worker sees
            # the terminal receipt and cannot start project code after abandonment.
            facts = {"stages": {}}
        stages = facts["stages"]
        if not isinstance(stages, dict):
            raise Invalid("Invalid execution stage results")
        error = None
        node_id = record["node_id"]
        node = next(n for n in state["graph"]["nodes"] if n["id"] == node_id)
        task = state["graph"]["tasks"][node["task"]]
        if not execution.belongs_to_running_dispatch(state["nodes"][node_id]):
            error = "Execution returned to a stale dispatch"
        else:
            try:
                check_config(state)
                journal.check_sources(state, task)
            except Invalid as exc:
                error = str(exc)
        completed = [record]
        parent = _complete_check(journal.root, rid, record, stages.get(rid), error)
        for stage in record.get("composite_stages", []):
            child_id = stage["execution_id"]
            if child_id not in stages:
                continue
            child: ExecutionReceipt = {
                **record,
                "spec": stage["spec"],
                "output": stage["output"],
                "composite_parent": rid,
                "mode": stages[child_id]["mode"],
            }
            child.pop("composite_stages", None)
            child.pop("owner", None)
            child.pop("process_facts", None)
            _complete_check(journal.root, child_id, child, stages[child_id], error)
            state["executions"][child_id] = child
            completed.append(child)
        journal.save_artifacts(
            state,
            "check_finished",
            tuple(
                Artifact(
                    entry["output"],
                    "check",
                    relative(journal.root, entry["output"]),
                    node_id,
                    entry["dispatch_id"],
                    entry["output_hash"],
                )
                for entry in completed
                if "output_hash" in entry
            ),
            node=node_id,
            dispatch_id=record["dispatch_id"],
            execution_id=rid,
            result=parent["result"],
        )
        return parent


def check_results(journal: RunJournal, rid: str) -> list[CommandResult]:
    with journal.locked():
        state = journal.read()
        record = state.get("executions", {}).get(rid)
        require(record is not None and record.get("result"), "Execution is unknown or not finished")
        assert record is not None
        return [
            record["result"],
            *[
                child["result"]
                for child in state["executions"].values()
                if child.get("composite_parent") == rid
            ],
        ]


def _complete_check(
    root: Path,
    rid: str,
    record: ExecutionReceipt,
    observed: dict[str, Any] | None,
    error: str | None,
) -> CommandResult:
    spec = record["spec"]
    execution = spec["execution"]
    code = None
    if observed is None:
        error = error or "Process ended without a recorded exit status"
        after = snapshot(root, record["input_scope"])
    else:
        code = observed["exit_code"]
        scope, before, after = (
            observed["input_scope"],
            observed["files"],
            observed["after_files"],
        )
        record.update({"input_scope": scope, "files": before})
        if "verification" in observed:
            record["verification"] = observed["verification"]
        if selection := observed.get("selection"):
            record["selection"] = selection
        outputs = execution.get("outputs", [])
        if any(before[path] != after[path] for path in scope if path not in outputs):
            error = "Files changed during check"
        if outputs:
            record["output_before"] = {path: before[path] for path in outputs}
            record["output_after"] = {path: after[path] for path in outputs}
        error = error or observed["error"]
    if after != snapshot(root, record["input_scope"]):
        error = error or "Command output snapshot is stale"
    status: Literal["BLOCKED", "PASS", "FAIL"] = (
        "BLOCKED" if error else "PASS" if code == 0 else "FAIL"
    )
    result: CommandResult = {
        **spec,
        "command": execution["argv"]
        or "registered stages: " + ", ".join(execution.get("stages", [])),
        "cwd": execution["cwd"],
        "exit_code": code,
        "result": status,
        "evidence": record["output"],
        "execution_id": rid,
    }
    record.update(
        {
            "status": status,
            "ended_at": time.time(),
            "error": error,
            "after_files": after,
            "result": result,
        }
    )
    output = relative(root, record["output"])
    if output.is_file():
        record["output_hash"] = transport_evidence.file_hash(output)
    return result
