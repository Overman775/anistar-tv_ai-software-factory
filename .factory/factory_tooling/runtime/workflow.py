#!/usr/bin/env python3
"""Validated run ledger for an agent-driven workflow. Does not call a model."""

from __future__ import annotations

import json
import os
import platform
import shlex
import shutil
import time
import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from copy import deepcopy

# Direct CLI execution and import-by-path use the same tool modules.
from pathlib import Path
from typing import Any

from factory_tooling.decisions.decision_contract import (
    preserve_obligations as preserve_obligations,
)
from factory_tooling.logging_config import event as log_event
from factory_tooling.paths import FACTORY_ROOT as FACTORY_ROOT
from factory_tooling.project.contracts import ProjectCheck
from factory_tooling.project.profile_io import load_profile, parse_yaml
from factory_tooling.project.profile_rules import boundary_gates as boundary_gates
from factory_tooling.project.profile_rules import project_checks as project_checks
from factory_tooling.runtime import acceptance as acceptance
from factory_tooling.runtime import approval, run_archive
from factory_tooling.runtime import escalation as escalation
from factory_tooling.runtime import review_findings as review_findings
from factory_tooling.runtime import transition_gates as transition_gates
from factory_tooling.runtime.assignment import implement_packet as implement_packet
from factory_tooling.runtime.assignment import worker_node
from factory_tooling.runtime.check_evidence import check_receipts
from factory_tooling.runtime.check_process import execute_check as execute_check
from factory_tooling.runtime.contracts import Check as Check
from factory_tooling.runtime.contracts import Config as Config
from factory_tooling.runtime.contracts import Dispatch as Dispatch
from factory_tooling.runtime.contracts import ExecutionReceipt as ExecutionReceipt
from factory_tooling.runtime.contracts import Graph as Graph
from factory_tooling.runtime.contracts import Node as Node
from factory_tooling.runtime.contracts import State as State
from factory_tooling.runtime.contracts import Task as Task
from factory_tooling.runtime.contracts import agent_key as agent_key
from factory_tooling.runtime.packet_io import (
    freeze_packet,
    packet_chunks,
    packet_diagnostics,
    read_packet_bytes,
)
from factory_tooling.runtime.state_io import parse_state
from factory_tooling.runtime.workflow_config import (
    check_capabilities as check_capabilities,
)
from factory_tooling.runtime.workflow_config import check_config as check_config
from factory_tooling.runtime.workflow_config import freeze_project as freeze_project
from factory_tooling.runtime.workflow_config import load_config as load_config
from factory_tooling.runtime.workflow_config import pool as pool
from factory_tooling.runtime.workflow_config import validate_profile_decisions
from factory_tooling.runtime.workflow_core import Invalid as Invalid
from factory_tooling.runtime.workflow_core import acceptance_guard as acceptance_guard
from factory_tooling.runtime.workflow_core import atomic_json as atomic_json
from factory_tooling.runtime.workflow_core import digest as digest
from factory_tooling.runtime.workflow_core import read_json as read_json
from factory_tooling.runtime.workflow_core import relative as relative
from factory_tooling.runtime.workflow_core import require as require
from factory_tooling.runtime.workflow_core import snapshot as snapshot
from factory_tooling.runtime.workflow_graph import ancestors as ancestors
from factory_tooling.runtime.workflow_graph import diagram as diagram
from factory_tooling.runtime.workflow_graph import overlaps as overlaps
from factory_tooling.runtime.workflow_graph import validate_graph as validate_graph
from factory_tooling.runtime.workflow_graph import validate_profile_selections
from factory_tooling.runtime.workflow_sources import lock_source as lock_source

# Compatibility exports: existing imports and command entry points stay valid.


def has_prior_dispatch_evidence(state: State, node_id: str) -> bool:
    """Common reservation/correction evidence; callers retain their own policies."""
    return any(
        event.get("node") == node_id and event.get("event") == "reserved"
        for event in state["events"]
    ) or any(
        node_id in record.get("reassigned_nodes", []) or record.get("node_id") == node_id
        for record in state.get("corrections", [])
    )


def preserve_task_guards(before: Task, after: Task) -> None:
    """Keep checks, scope, risk and independent review across graph changes."""
    previous_checks = {check["id"]: check for check in before["required_checks"]}
    next_checks = {check["id"]: check for check in after["required_checks"]}
    require(
        all(next_checks.get(cid) == check for cid, check in previous_checks.items()),
        "Cannot remove or weaken required checks",
    )
    require(set(after["scope"]) >= set(before["scope"]), "Cannot remove verification scope")
    require(
        ["low", "moderate", "high"].index(after["risk"])
        >= ["low", "moderate", "high"].index(before["risk"]),
        "Cannot weaken risk assessment",
    )
    require(
        not before["independent_review"] or after["independent_review"],
        "Cannot remove independent review",
    )


class Ledger:
    def __init__(self, workspace: str | Path) -> None:
        self.root = Path(workspace).resolve()
        self.dir = self.root / ".factory/memory/state"
        self.path = self.dir / "workflow.json"
        self.diagnostic_state: dict[str, Any] | None = None
        self.diagnostic_attempt: tuple[str, str] | None = None

    @contextmanager
    def locked(self) -> Iterator[None]:
        directory = relative(self.root, ".factory/memory/state")
        lock = relative(self.root, ".factory/memory/state/workflow.lock")
        directory.mkdir(parents=True, exist_ok=True)
        try:
            fd = os.open(lock, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            raise Invalid("Ledger locked; reconcile owner before removing a stale lock") from None
        try:
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            yield
        finally:
            lock.unlink()

    def read(self) -> State:
        path = relative(self.root, ".factory/memory/state/workflow.json")
        state = parse_state(read_json(path))
        self.diagnostic_state = {
            "run_id": state["run_id"],
            "nodes": {n["id"]: n["task"] for n in state["graph"]["nodes"]},
        }
        return state

    def save(self, state: State, event: str, **details: object) -> None:
        parse_state(state)
        require(
            state["status"] == "active",
            "Terminal run is immutable; start a new authorized run",
        )
        state["events"].append({"at": time.time(), "event": event, **details})
        atomic_json(relative(self.root, ".factory/memory/state/workflow.json"), state)
        node_id = details.get("node")
        node = next((n for n in state["graph"]["nodes"] if n["id"] == node_id), None)
        attempt = state["nodes"].get(node_id, {}) if isinstance(node_id, str) else {}
        event_fields: dict[str, object] = {"run_id": state["run_id"]}
        if node is not None:
            event_fields.update(node_id=node["id"], task_id=node["task"])
        elif isinstance(details.get("task"), str) and details["task"] in state["graph"]["tasks"]:
            event_fields["task_id"] = details["task"]
        if attempt.get("dispatch_id"):
            event_fields["dispatch_id"] = attempt["dispatch_id"]
        elif event in {"retry", "correction_decided"}:
            for prior in reversed(state["events"][:-1]):
                if prior.get("event") != "invalidated":
                    break
                if prior.get("node") == node_id:
                    previous = prior.get("previous", {})
                    if isinstance(previous, dict) and previous.get("dispatch_id"):
                        event_fields["dispatch_id"] = previous["dispatch_id"]
                    break
        if isinstance(details.get("result"), str) and details["result"] in {
            "PASS",
            "FAIL",
            "BLOCKED",
        }:
            event_fields["outcome"] = details["result"]
        if isinstance(details.get("outcome"), str) and details["outcome"] in {
            "PASS",
            "FAIL",
            "BLOCKED",
        }:
            event_fields["outcome"] = details["outcome"]
        if isinstance(details.get("execution_id"), str):
            event_fields["execution_id"] = details["execution_id"]
        if event.startswith("transport_") and details.get("operation") in (
            "create",
            "show",
            "status",
            "prompt",
            "cancel",
            "close",
        ):
            event_fields["transport_operation"] = details["operation"]
        if event == "transport_returned" and isinstance(details.get("exit_code"), int):
            event_fields["outcome"] = "success" if details["exit_code"] == 0 else "failure"
        log_event(event, **event_fields)

    def check_sources(self, state: State, task: Task) -> None:
        src = state["graph"]["sources"][task["source"]]
        if src.get("path"):
            path = relative(self.root, src["path"])
            require(
                path.is_file() and digest(path.read_bytes()) == src["content_hash"],
                "SOURCE_DRIFT",
            )

    def source_drifted(self, state: State, task: Task, outcome: str) -> bool:
        """Permit a terminal failure to record source drift; never hide other errors."""
        try:
            self.check_sources(state, task)
        except Invalid as exc:
            if str(exc) != "SOURCE_DRIFT" or outcome not in {"FAIL", "BLOCKED"}:
                raise
            return True
        return False

    def init(self, graph: Graph, config: Config) -> State:
        input_graph = graph
        graph = deepcopy(graph)
        validate_graph(graph, config, self.root)
        validate_profile_selections(graph, config)
        config = freeze_project(config, graph, self.root)
        for task in graph["tasks"].values():
            for p in task["scope"]:
                relative(self.root, p)
        for node in graph["nodes"]:
            for p in node.get("owns", []):
                relative(self.root, p)
        with self.locked():
            require(not self.path.exists(), "Existing run: resume or archive/clean it first")
            require(
                not (self.dir / "pipeline.md").exists(),
                "Legacy state exists; reconcile it first",
            )
            graph["sources"] = {
                k: lock_source(self.root, src) for k, src in graph["sources"].items()
            }
            state: State = {
                "run_id": "run-" + uuid.uuid4().hex[:12],
                "revision": 1,
                "status": "active",
                "workspace": str(self.root),
                "graph": graph,
                "config": config,
                "events": [],
                "counters": {},
                "sessions": {},
                "nodes": {n["id"]: {"status": "pending", "attempt": 0} for n in graph["nodes"]},
            }
            check_config(state)
            self.save(state, "created")
            input_graph["sources"] = graph["sources"]
            return state

    def packet(self, node_id: str) -> dict[str, Any]:
        """Materialize native instructions; caller performs actual host dispatch."""
        with self.locked():
            s = self.read()
            require(s["status"] == "active", "Run is not active")
            check_config(s)
            n = next(n for n in s["graph"]["nodes"] if n["id"] == node_id)
            v = s["nodes"][node_id]
            require(v["status"] in {"reserved", "running"}, "Reserve node before packet")
            profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
            require(profile["runner"] == "native", "Use ACP prepare for ACP profile")
            check_capabilities(profile, n)
            task = s["graph"]["tasks"][n["task"]]
            self.check_sources(s, task)
            return acceptance_guard(implement_packet, s, node_id)

    def prepare_packet(self, node_id: str, *, with_diagnostics: bool = False) -> dict[str, Any]:
        """Freeze a native assignment and return its worker bootstrap."""
        with self.locked():
            s = self.read()
            n, v = self.packet_dispatch(s, node_id)
            already_prepared = "packet_file" in v
            meta = freeze_packet(self.root, self.dir, s, n, v)
            if not already_prepared:
                v["packet_chunks_read"] = 0
                self.save(s, "packet_prepared", node=node_id, dispatch_id=v["dispatch_id"])
            bootstrap = self._packet_bootstrap(s, n, meta)
            if with_diagnostics:
                data = read_packet_bytes(self.root, s, n, meta, meta)
                return {"bootstrap": bootstrap, "diagnostics": packet_diagnostics(data)}
            return bootstrap

    def packet_dispatch(
        self, s: State, node_id: str, *, runner: str = "native"
    ) -> tuple[Node, Dispatch]:
        require(s["status"] == "active", "Run is not active")
        require(s["workspace"] == str(self.root), "Packet workspace mismatch")
        check_config(s)
        n = next((n for n in s["graph"]["nodes"] if n["id"] == node_id), None)
        if n is None or node_id not in s["nodes"]:
            raise Invalid("Unknown packet node")
        v = s["nodes"][node_id]
        require(v["status"] in {"reserved", "running"}, "Reserve node before packet")
        agent = s["graph"]["agents"][agent_key(n)]
        profile = s["config"]["profiles"][agent["profile"]]
        require(
            v["profile"] == agent["profile"] and v["role"] == agent["role"],
            "Packet assignment profile mismatch",
        )
        require(profile["runner"] == runner, f"Packet requires {runner} profile")
        check_capabilities(profile, n)
        self.check_sources(s, s["graph"]["tasks"][n["task"]])
        return n, v

    def _packet_bootstrap(self, s: State, n: Node, meta: dict[str, str]) -> dict[str, Any]:
        args = [
            ".factory/tools/workflow.py",
            "--workspace",
            str(self.root),
            "read-packet",
            meta["node_id"],
            meta["path"],
            meta["sha256"],
            meta["run_id"],
            meta["dispatch_id"],
            meta["source_hash"],
            meta["revision"],
        ]
        if platform.system() == "Windows":
            # PowerShell single quotes prevent shell interpolation of workspace paths.
            quote = lambda value: "'" + value.replace("'", "''") + "'"  # noqa: E731
            prefix = [
                ".\\.factory\\.venv\\Scripts\\python.exe",
                "-E",
                "-s",
                "-B",
                ".factory/tools/python_runtime.py",
                "run",
            ]
            shell = "PowerShell"
        else:
            quote = shlex.quote
            prefix = ["sh", ".factory/tools/python.sh"]
            shell = "POSIX shell"
        read_args = [*prefix, *args, "--chunk", "1"]
        confirm_args = [*prefix, *args[:3], "confirm-packet", *args[4:]]
        operator = "& " if shell == "PowerShell" else ""
        command = operator + " ".join(map(quote, read_args))
        confirm = operator + " ".join(map(quote, confirm_args))
        return {
            **meta,
            "workspace": str(self.root),
            "role": s["nodes"][n["id"]]["role"],
            "owns": n.get("owns", []),
            "stage": n["stage"],
            "read_command": command,
            "read_shell": shell,
            "confirm_command": confirm,
            "instruction": (
                "In read_shell, run read_command once per tool result. Follow next by changing --chunk; "
                "do not combine outputs or truncate. Read all chunks in order; "
                "wait for running bind before writes or assigned commands. "
                "Run confirm_command after receiving the last chunk."
            ),
        }

    def read_packet(self, node_id: str, bootstrap: dict[str, str], chunk: int) -> dict[str, Any]:
        """Validate the entire frozen assignment; emit one bounded, ordered text chunk."""
        with self.locked():
            s = self.read()
            n, v = self.packet_dispatch(s, node_id)
            expected = v.get("packet_file")
            if expected is None:
                raise Invalid("Prepare packet first")
            data = read_packet_bytes(self.root, s, n, expected, bootstrap)
            chunks = packet_chunks(data)
            total = len(chunks)
            require(type(chunk) is int and 1 <= chunk <= total, "Invalid packet chunk")
            if chunk == v.get("packet_chunks_read", 0) + 1:
                v["packet_chunks_read"] = chunk
                self.save(s, "packet_chunk_served", node=node_id, ordinal=chunk)
            return {
                "ordinal": chunk,
                "total": total,
                "next": chunk + 1 if chunk < total else None,
                "content": chunks[chunk - 1],
                "binding": v["status"],
                "ready_for_work": v["status"] == "running" and chunk == total,
                "ready_condition": "Only after reading all chunks in order and a running bind.",
            }

    def confirm_packet(self, node_id: str, bootstrap: dict[str, str]) -> None:
        with self.locked():
            s = self.read()
            n, dispatch = self.packet_dispatch(s, node_id)
            expected = dispatch.get("packet_file")
            if expected is None:
                raise Invalid("Prepare packet first")
            require(dispatch["status"] == "running", "Bind before confirming packet")
            data = read_packet_bytes(self.root, s, n, expected, bootstrap)
            require(
                dispatch.get("packet_chunks_read") == len(packet_chunks(data)),
                "Packet chunks must be served in order before confirmation",
            )
            if not dispatch.get("packet_confirmed"):
                dispatch["packet_confirmed"] = True
                self.save(
                    s,
                    "packet_confirmed",
                    node=node_id,
                    dispatch_id=expected["dispatch_id"],
                    sha256=expected["sha256"],
                )

    def claim(self, node_id: str) -> dict[str, object]:
        with self.locked():
            s = self.read()
            require(s["status"] == "active", "Run is not active")
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            validate_profile_selections(
                s["graph"], s["config"], s.get("corrections", []), s["events"]
            )
            n, current = nodes[node_id], s["nodes"][node_id]
            for path in n.get("owns", []):
                relative(self.root, path)
            require(n["stage"] != "accept", "Use accept for orchestrator node")
            profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
            check_capabilities(profile, n)
            require(
                current["status"] == "pending",
                "Already dispatched or unresolved; never redispatch blindly",
            )
            require(
                all(s["nodes"][d]["status"] == "done" for d in n["depends_on"]),
                "Dependencies not complete",
            )
            self.check_sources(s, s["graph"]["tasks"][n["task"]])
            profile_id = s["graph"]["agents"][agent_key(n)]["profile"]
            acceptance_guard(escalation.guard, s, n["task"], profile_id, node_id)
            p = pool(s["config"], profile_id)
            busy = [
                k
                for k, v in s["nodes"].items()
                if v["status"] in {"reserved", "running", "unknown"}
            ]
            used = sum(s["nodes"][k]["pool"] == p for k in busy)
            require(used < s["config"]["_limits"][p], "QUEUED_CAPACITY")
            for k in busy:
                other = nodes[k]
                require(n["agent"] != other["agent"], "One active turn per logical agent")
                require(
                    not overlaps(n.get("owns", []), other.get("owns", [])),
                    "QUEUED_OWNERSHIP",
                )
                require(
                    not set(n.get("resources", [])) & set(other.get("resources", [])),
                    "QUEUED_RESOURCE",
                )
                # Authoritative verification observes a quiescent shared checkout.
                require(
                    not (
                        (n["stage"] in {"verify", "review"} and other.get("owns"))
                        or (other["stage"] in {"verify", "review"} and n.get("owns"))
                    ),
                    "QUEUED_SNAPSHOT",
                )
            current.update(
                {
                    "status": "reserved",
                    "dispatch_id": uuid.uuid4().hex,
                    "pool": p,
                    "profile": profile_id,
                    "role": s["graph"]["agents"][agent_key(n)]["role"],
                    "attempt": current["attempt"] + 1,
                }
            )
            self.save(s, "reserved", node=node_id, dispatch_id=current["dispatch_id"])
            return {
                "run_id": s["run_id"],
                "node": n,
                "dispatch": current,
                "profile": s["config"]["profiles"][profile_id],
            }

    def bind(self, node_id: str, handle: str, model: str) -> None:
        with self.locked():
            s = self.read()
            n = next(n for n in s["graph"]["nodes"] if n["id"] == node_id)
            v = s["nodes"][node_id]
            require(v["status"] == "reserved", "Bind only a reserved dispatch")
            dispatch = v.get("dispatch_id")
            if dispatch is not None:
                self.diagnostic_attempt = (node_id, dispatch)
            require(handle and model, "Actual handle and model required")
            require(
                handle not in s.get("retired_handles", []),
                "Retired physical session cannot be rebound",
            )
            aid = agent_key(n)
            require(
                handle not in s.get("handle_owners", {}) or s["handle_owners"][handle] == aid,
                "Session previously belonged to a different logical agent",
            )
            for other, session in s["sessions"].items():
                require(
                    other == aid or session["handle"] != handle,
                    "Physical session shared between logical agents",
                )
            profile = s["config"]["profiles"][s["graph"]["agents"][aid]["profile"]]
            expected = s["config"]["models"][profile["model"]].get("id")
            if not (expected is None or expected == model):
                raise Invalid("Actual model differs from requested model")
            old = s["sessions"].get(aid)
            if not (old is None or old["handle"] == handle):
                raise Invalid("Use explicit session replacement with handoff")
            if not (old is None or old["model"] == model):
                raise Invalid("Effective model changed; replace physical session with handoff")
            s["sessions"][aid] = {"handle": handle, "model": model}
            s.setdefault("handle_owners", {})[handle] = aid
            v.update({"status": "running", "handle": handle})
            self.save(s, "bound", node=node_id, handle=handle, model=model)

    def run_check(self, node_id: str, check_id: str) -> Check:
        """Run one declared command synchronously; persist facts before returning.

        The ledger lock is intentionally held throughout this minimal runner.
        A killed runner leaves a RUNNING receipt, never a successful result.
        """
        with self.locked():
            s = self.read()
            require(s["status"] == "active", "Run is not active")
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            n, v = nodes[node_id], s["nodes"][node_id]
            require(v["status"] == "running", "Check needs a bound running node")
            require(
                not any(
                    d["status"] in {"reserved", "running"}
                    and "packet_chunks_read" in d
                    and not d.get("packet_confirmed")
                    for d in s["nodes"].values()
                ),
                "Wait for outstanding native packet delivery before running checks",
            )
            require(
                "project-checks" in n.get("resources", []),
                "Check needs project-checks reservation",
            )
            profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
            check_capabilities(profile, n)
            task = s["graph"]["tasks"][n["task"]]
            self.check_sources(s, task)
            spec = next((c for c in task["required_checks"] if c["id"] == check_id), None)
            if not (spec is not None and spec["kind"] != "observation"):
                raise Invalid("Unknown required command")
            policy_check = next(
                (c for c in project_checks(s["config"]["_project"]["data"]) if c["id"] == check_id),
                ProjectCheck(),
            )
            prior = [
                r
                for r in s.get("executions", {}).values()
                if r["node_id"] == node_id and r["dispatch_id"] == v["dispatch_id"]
            ]
            for dependency in policy_check.get("after", []):
                attempts = [r for r in prior if r["spec"]["id"] == dependency]
                require(
                    attempts
                    and attempts[-1]["status"] == "PASS"
                    and attempts[-1]["files"] == snapshot(self.root, attempts[-1]["input_scope"]),
                    "Project check dependency missing/failed/stale: " + dependency,
                )
            executions = s.setdefault("executions", {})
            require(
                not any(
                    r["node_id"] == node_id
                    and r["dispatch_id"] == v["dispatch_id"]
                    and r["status"] == "RUNNING"
                    for r in executions.values()
                ),
                "Unresolved command; reconcile process before retrying node",
            )
            execution = spec["execution"]
            cwd = self.root if execution["cwd"] == "." else relative(self.root, execution["cwd"])
            require(cwd.is_dir(), "Check cwd does not exist")
            input_scope = sorted(set(task["scope"] + execution.get("inputs", [])))
            before = snapshot(self.root, input_scope)
            rid = uuid.uuid4().hex
            output_rel = f".factory/memory/history/{s['run_id']}/checks/{rid}.log"
            output = relative(self.root, output_rel)
            output.parent.mkdir(parents=True, exist_ok=True)
            record: ExecutionReceipt = dict(
                run_id=s["run_id"],
                node_id=node_id,
                dispatch_id=v["dispatch_id"],
                source_hash=s["graph"]["sources"][task["source"]]["hash"],
                spec=spec,
                input_scope=input_scope,
                files=before,
                status="RUNNING",
                started_at=time.time(),
                runner_pid=os.getpid(),
                output=output_rel,
                environment={
                    "platform": platform.platform(),
                    "python": platform.python_version(),
                    "executable": shutil.which(execution["argv"][0], path=os.environ.get("PATH")),
                },
            )
            executions[rid] = record
            self.save(s, "check_started", node=node_id, execution_id=rid)

            def on_started(pid: int) -> None:
                record["pid"] = pid
                self.save(s, "check_process", node=node_id, execution_id=rid)

            code, status, error = execute_check(execution, cwd, output, on_started)
            after = snapshot(self.root, input_scope)
            if after != before:
                status, error = "BLOCKED", "Files changed during check"
            try:
                self.check_sources(s, task)
                check_config(s)
            except Invalid as exc:
                status, error = "BLOCKED", str(exc)
            result: Check = {
                **spec,
                "command": execution["argv"],
                "cwd": execution["cwd"],
                "exit_code": code,
                "result": status,
                "evidence": output_rel,
                "execution_id": rid,
            }
            record.update(
                {
                    "status": status,
                    "ended_at": time.time(),
                    "error": error,
                    "after_files": after,
                    "output_hash": digest(output.read_bytes()),
                    "result": result,
                }
            )
            self.save(s, "check_finished", node=node_id, execution_id=rid, result=status)
            return result

    def prepare_report(
        self, node_id: str, report: dict[str, Any], receipt_ids: list[str]
    ) -> dict[str, Any]:
        """Capture the author's evidence at handoff for its exact running dispatch."""
        if not isinstance(report, dict):
            raise Invalid("Report draft must be an object")
        report = {key: value for key, value in report.items() if key != "observed_source_drift"}
        with self.locked():
            state = self.read()
            node = next((n for n in state["graph"]["nodes"] if n["id"] == node_id), None)
            if node is None or node_id not in state["nodes"]:
                raise Invalid("Unknown report node")
            current = state["nodes"][node_id]
            task = state["graph"]["tasks"][node["task"]]
            require(
                state["status"] == "active" and current["status"] == "running",
                "Report needs a bound running node",
            )
            require(
                report.get("run_id") == state["run_id"]
                and report.get("dispatch_id") == current["dispatch_id"]
                and report.get("source_hash") == state["graph"]["sources"][task["source"]]["hash"]
                and report.get("node_id") == node_id
                and report.get("task_id", node["task"]) == node["task"]
                and report.get("slice_id", task["slice"]) == task["slice"],
                "Stale report identity",
            )
            require("files" not in report, "Existing evidence cannot be refreshed")
            checks = report.get("checks", [])
            require(
                isinstance(checks, list) and all(isinstance(check, dict) for check in checks),
                "Invalid checks",
            )
            require(len(set(receipt_ids)) == len(receipt_ids), "Duplicate receipt")
            outcome = report.get("outcome")
            if not isinstance(outcome, str) or outcome not in ("PASS", "FAIL", "BLOCKED"):
                raise Invalid("Invalid outcome")
            require_pass = outcome == "PASS"
            for receipt_id in receipt_ids:
                record = state.get("executions", {}).get(receipt_id)
                if record is None or record.get("result") is None:
                    raise Invalid("Unknown or incomplete receipt")
                require(record["result"].get("execution_id") == receipt_id, "Receipt ID mismatch")
                require(record["spec"] in task["required_checks"], "Receipt is not required")
                check_receipts(
                    self.root,
                    state,
                    node_id,
                    [record["result"]],
                    complete=False,
                    require_pass=require_pass,
                )
                require(
                    not any(check.get("id") == record["result"]["id"] for check in checks),
                    "Selected receipt duplicates a draft check",
                )
                checks = [*checks, record["result"]]
            check_receipts(
                self.root, state, node_id, checks, complete=False, require_pass=require_pass
            )
            self.source_drifted(state, task, outcome)
            return {
                **report,
                "task_id": node["task"],
                "slice_id": task["slice"],
                "checks": checks,
                "files": snapshot(self.root, task["scope"]),
            }

    def finish(self, node_id: str, report: Any) -> None:
        # Runtime facts are derived, never accepted from an agent.
        report = {
            key: value
            for key, value in report.items()
            if key not in {"gate_results", "observed_source_drift"}
        }
        with self.locked():
            s = self.read()
            n = next(n for n in s["graph"]["nodes"] if n["id"] == node_id)
            v, task = s["nodes"][node_id], s["graph"]["tasks"][n["task"]]
            require(v["status"] == "running", "Cannot finish unbound/unknown work")
            src = s["graph"]["sources"][task["source"]]
            require(
                report.get("run_id") == s["run_id"]
                and report.get("dispatch_id") == v["dispatch_id"]
                and report.get("source_hash") == src["hash"]
                and report.get("node_id") == node_id
                and report.get("task_id") == n["task"]
                and report.get("slice_id") == task["slice"],
                "Stale report identity",
            )
            self.diagnostic_attempt = (node_id, v["dispatch_id"])
            require(
                report.get("terminal") is True and report.get("summary"),
                "Need terminal result and summary",
            )
            outcome = report.get("outcome")
            require(outcome in {"PASS", "FAIL", "BLOCKED"}, "Invalid outcome")
            if outcome == "PASS":
                require(
                    "packet_chunks_read" not in v or v.get("packet_confirmed"),
                    "Confirm native packet before finishing successful work",
                )
                check_config(s)
            acceptance_guard(review_findings.consistent, report, n["stage"] == "review")
            if self.source_drifted(s, task, outcome):
                report["observed_source_drift"] = True
            require(
                report.get("files") == snapshot(self.root, task["scope"]),
                "Stale/incomplete file evidence",
            )
            checks = report.get("checks", [])
            if not (isinstance(checks, list) and all(isinstance(c, dict) for c in checks)):
                raise Invalid("Invalid checks")
            findings = report.get("findings", [])
            if not (isinstance(findings, list) and all(isinstance(f, dict) for f in findings)):
                raise Invalid("Invalid findings")
            if outcome == "PASS" and n["stage"] != "review":
                for finding in findings:
                    require(
                        type(finding.get("blocking")) is bool and finding.get("id"),
                        "Untyped finding",
                    )
                    require(
                        not finding["blocking"] or finding.get("status") in {"fixed", "dismissed"},
                        "Open blocking finding",
                    )
                    if finding.get("status") in {"fixed", "dismissed"}:
                        require(finding.get("evidence"), "Finding resolution needs evidence")
            if checks:
                if any(c.get("kind") in {"tests", "static", "build", "codegen"} for c in checks):
                    require(
                        "project-checks" in n.get("resources", []),
                        "Command executed without project-checks reservation",
                    )
                if outcome == "PASS":
                    require(
                        all(
                            acceptance.successful(c) or acceptance.resolved_extra(c) for c in checks
                        ),
                        "Failed/incomplete command evidence",
                    )
            if outcome == "PASS" and n["stage"] != "verify":
                check_receipts(self.root, s, node_id, checks, complete=False)
            if (
                outcome == "PASS"
                and n["stage"] == "work"
                and s["graph"]["agents"][agent_key(n)]["role"] == "test-writer"
                and "project-checks" in n.get("resources", [])
            ):
                require(
                    report.get("stage_result") != "WRITES_READY",
                    "TestWriter checks required",
                )
                test_ids = {c["id"] for c in task["required_checks"] if c["kind"] == "tests"}
                require(
                    any(c.get("id") in test_ids and acceptance.successful(c) for c in checks),
                    "TestWriter needs a successful tests receipt",
                )
            if outcome == "PASS":
                report = {
                    **report,
                    "gate_results": acceptance_guard(
                        transition_gates.evaluate,
                        s["config"]["_project"]["data"],
                        n,
                        task,
                        report,
                    ),
                }
            if (
                outcome == "PASS"
                and n.get("owns")
                and "project-checks" not in n.get("resources", [])
            ):
                require(
                    report.get("stage_result") == "WRITES_READY",
                    "Unlocked writer returns WRITES_READY, checks deferred",
                )
            if outcome == "PASS" and n["stage"] in {"verify", "review"}:
                require(
                    checks
                    and all(
                        acceptance.successful(c) or acceptance.resolved_extra(c) for c in checks
                    ),
                    "Missing/failed verification commands",
                )
                if n["stage"] == "verify":
                    acceptance_guard(acceptance.verify_results, task, checks)
                    check_receipts(self.root, s, node_id, checks)
                    kinds = {c.get("kind") for c in checks if acceptance.successful(c)}
                    for kind in ("static", "tests", "docs"):
                        skipped = report.get("not_applicable", {}).get(kind)
                        if not (kind in kinds or (isinstance(skipped, str) and skipped.strip())):
                            raise Invalid(f"Missing {kind} evidence/reason")
                        if kind == "tests" and task["risk"] == "high":
                            require(kind in kinds, "High risk cannot skip tests")
                if n["stage"] == "review":
                    require(
                        report.get("verdict") == "APPROVE",
                        "Missing independent APPROVE",
                    )
            if report.get("stage_result") == "APPROVAL_REQUIRED" or "approval_request" in report:
                require(
                    isinstance(report.get("approval_request"), dict),
                    "Invalid approval request",
                )
                approval.bind_request(self.root, s, n, task, report)
                validate_graph(approval.expanded_graph(s, n, report), s["config"], self.root)
            acceptance_guard(review_findings.apply, s, n, report)
            if "implement." + n["stage"] in transition_gates.CORE_BOUNDARIES:
                core_gate = transition_gates.stage_result(s, n, report)
                report = {
                    **report,
                    "gate_results": [core_gate, *report.get("gate_results", [])],
                }
            v.update({"status": "done" if outcome == "PASS" else "blocked", "report": report})
            self.save(s, "finished", node=node_id, outcome=outcome)

    def unknown(self, node_id: str, reason: str) -> None:
        with self.locked():
            s = self.read()
            require(
                s["nodes"][node_id]["status"] in {"reserved", "running"},
                "Not an in-flight request",
            )
            s["nodes"][node_id].update({"status": "unknown", "reason": reason})
            self.save(s, "unknown", node=node_id, reason=reason)

    def resolve(self, node_id: str, status: str, evidence: str) -> None:
        with self.locked():
            s = self.read()
            v = s["nodes"][node_id]
            require(
                v["status"] == "unknown" and evidence,
                "Reconcile unknown work with actual runtime/file evidence",
            )
            require(
                status in {"reserved", "running", "blocked"},
                "Invalid reconciliation state",
            )
            if status == "running":
                require(v.get("handle"), "Bind actual handle before claiming running")
            if status == "reserved":
                require(
                    not v.get("prompt_submitted") and not v.get("handle"),
                    "Cannot redispatch an already sent assignment",
                )
            v["status"] = status
            self.save(s, "reconciled", node=node_id, status=status, evidence=evidence)

    def replace_session(
        self, agent_id: str, reason: str, terminal_evidence: str, handoff: str
    ) -> None:
        with self.locked():
            s = self.read()
            require(
                reason and terminal_evidence and handoff,
                "Need reason, old terminal evidence and handoff",
            )
            require(agent_id in s["graph"]["agents"], "Unknown agent")
            own = [n["id"] for n in s["graph"]["nodes"] if n.get("agent") == agent_id]
            require(
                not any(s["nodes"][k]["status"] in {"reserved", "running", "unknown"} for k in own),
                "Resolve active/unknown assignments before session replacement",
            )
            tasks = {n["task"] for n in s["graph"]["nodes"] if n.get("agent") == agent_id}
            if len(tasks) == 1:
                handoffs = {next(iter(tasks)): handoff}
            else:
                try:
                    handoffs = json.loads(handoff)
                except (TypeError, ValueError):
                    raise Invalid(
                        "Multi-task replacement needs a JSON task-to-handoff mapping"
                    ) from None
                if not (
                    isinstance(handoffs, dict)
                    and set(handoffs) == tasks
                    and all(isinstance(v, str) and v.strip() for v in handoffs.values())
                ):
                    raise Invalid("Multi-task replacement needs one handoff per assigned task")
            previous = s["sessions"].pop(agent_id, None)
            epoch = s.get("epochs", {}).get(agent_id, 0)
            acp_name = f"{s['run_id']}-{agent_id}-e{epoch}"
            if not (previous is not None or acp_name in s.get("acp_created", {})):
                raise Invalid("No session/creation attempt to replace")
            if previous:
                s.setdefault("retired_handles", []).append(previous["handle"])
            s.setdefault("epochs", {})[agent_id] = s.get("epochs", {}).get(agent_id, 0) + 1
            self.save(
                s,
                "session_replaced",
                agent=agent_id,
                previous=previous,
                reason=reason,
                terminal_evidence=terminal_evidence,
                handoff=handoff,
                task_handoffs=handoffs,
            )

    def revise(self, graph: Graph, reason: str) -> None:
        with self.locked():
            s = self.read()
            require(
                s["status"] == "active" and reason,
                "Need active run and revision reason",
            )
            require(
                not any(
                    v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()
                ),
                "Quiesce runtime before graph revision",
            )
            check_config(s)
            validate_graph(graph, s["config"], self.root)
            old = s["graph"]
            validate_profile_selections(
                graph, s["config"], s.get("corrections", []), s["events"], s["graph"]
            )
            require(
                graph["sources"] == old["sources"] and set(graph["tasks"]) == set(old["tasks"]),
                "Revision cannot alter locked tasks/sources; re-intake required",
            )
            strengthened = set()
            for tid, before in old["tasks"].items():
                after = graph["tasks"][tid]
                mutable = {
                    "scope",
                    "risk",
                    "independent_review",
                    "reason",
                    "required_checks",
                    "policy_decisions",
                }
                require(
                    {k: v for k, v in before.items() if k not in mutable}
                    == {k: v for k, v in after.items() if k not in mutable},
                    "Revision cannot alter locked tasks/sources",
                )
                try:
                    preserve_obligations(
                        s["config"]["_project"]["data"].get("decisions", []),
                        before.get("policy_decisions", {}),
                        after.get("policy_decisions", {}),
                    )
                except ValueError as exc:
                    require(False, str(exc))
                preserve_task_guards(before, after)
                if before != after:
                    strengthened.add(tid)
            new_nodes = {n["id"]: n for n in graph["nodes"]}
            for old_node in old["nodes"]:
                new_node = new_nodes.get(old_node["id"])
                if new_node is None or not old_node.get("agent") or not new_node.get("agent"):
                    continue
                old_agent = old["agents"][agent_key(old_node)]
                new_agent = graph["agents"][agent_key(new_node)]
                if (
                    old_node.get("profile_selection") is not None
                    or new_node.get("profile_selection") is not None
                ) and (old_agent != new_agent or old_node["agent"] != new_node["agent"]):
                    require(
                        graph["agents"].get(agent_key(old_node)) == old_agent,
                        "Keep previous logical agent unchanged",
                    )
                    require(
                        old_agent == new_agent
                        or (
                            old_node["agent"] != new_node["agent"]
                            and new_node["agent"] not in old["agents"]
                        ),
                        "Profile change needs a new logical agent",
                    )
                    require(
                        s["nodes"][old_node["id"]]["status"] == "pending"
                        and s["nodes"][old_node["id"]].get("attempt", 0) == 0
                        and not has_prior_dispatch_evidence(s, old_node["id"])
                        and not any(
                            e.get("node") == old_node["id"]
                            and e.get("event") in {"bound", "correction_decided"}
                            for e in s["events"]
                        ),
                        "Started assignments require correct",
                    )
                if any(
                    old_node["id"] in r.get("reassigned_nodes", [])
                    for r in s.get("corrections", [])
                ):
                    require(
                        old_node.get("profile_selection") == new_node.get("profile_selection"),
                        "Corrected assignment retains initial choice",
                    )
            invalidate = set()
            for n in old["nodes"]:
                require(
                    n["id"] in new_nodes,
                    "Keep stable node identities; do not erase work",
                )
                require(
                    n["task"] == new_nodes[n["id"]]["task"]
                    and n["stage"] == new_nodes[n["id"]]["stage"],
                    "Keep task/stage identity for existing nodes",
                )
                if worker_node(n) != worker_node(new_nodes[n["id"]]) or (
                    n["task"] in strengthened and n["stage"] in {"verify", "review", "accept"}
                ):
                    invalidate.add(n["id"])
            invalidate |= {k for k in new_nodes if ancestors(new_nodes, k) & invalidate}
            for a, old_assignment in old["agents"].items():
                if a in s["sessions"]:
                    require(
                        graph["agents"].get(a) == old_assignment,
                        "Replace physical session before changing role/profile",
                    )
            s["config"] = freeze_project(s["config"], graph, self.root)
            s["graph"] = graph
            s["revision"] += 1
            for n in graph["nodes"]:
                s["nodes"].setdefault(n["id"], {"status": "pending", "attempt": 0})
                if n["id"] in invalidate:
                    prev = s["nodes"][n["id"]]
                    s["events"].append(
                        {
                            "at": time.time(),
                            "event": "invalidated",
                            "node": n["id"],
                            "previous": prev,
                        }
                    )
                    # A technical graph edit is not a free retry of failed work.
                    if prev["status"] != "blocked":
                        s["nodes"][n["id"]] = {
                            "status": "pending",
                            "attempt": prev["attempt"],
                        }
            self.save(s, "revised", reason=reason, previous_graph=old)

    def reintake(self, graph: Graph, reason: str, authorization: str) -> None:
        with self.locked():
            s = self.read()
            require(
                s["status"] == "active" and reason and authorization,
                "Source re-intake requires reason and source/user authorization evidence",
            )
            require(
                not any(
                    v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()
                ),
                "Quiesce workers before re-intake",
            )
            require(
                set(graph["tasks"]) == set(s["graph"]["tasks"])
                and set(graph["sources"]) == set(s["graph"]["sources"]),
                "New tasks/sources need a separate run",
            )
            # Refresh only decision definitions, never arbitrary model, gate or security config.
            old_config = s["config"]
            old_policy = old_config["_project"]
            new_policy = acceptance_guard(load_profile, old_policy["path"])
            old_data, new_data = old_policy["data"], new_policy["data"]
            require(
                {k: v for k, v in old_data.items() if k != "decisions"}
                == {k: v for k, v in new_data.items() if k != "decisions"},
                "Only decision policy changes can be refreshed in re-intake",
            )
            raw = acceptance_guard(parse_yaml, Path(old_policy["path"]).read_bytes())
            allowed = {old_policy["path"]} | {
                str(Path(old_policy["path"]).parent / rel) for rel in raw.get("decision_files", [])
            }
            require(
                set(old_policy["files"]) == set(new_policy["files"])
                and all(
                    old_policy["files"][p] == new_policy["files"][p]
                    for p in old_policy["files"]
                    if p not in allowed
                ),
                "Only existing decision policy files can change in re-intake",
            )
            new_config = deepcopy(old_config)
            new_config["_project"] = new_policy
            validate_profile_decisions(new_config)
            new_config["_files"].update(new_policy["files"])
            require(
                freeze_project(new_config, s["graph"], self.root)["_project_documents"]
                == old_config["_project_documents"],
                "Project document drift requires separate reconciliation",
            )
            s["config"] = freeze_project(new_config, graph, self.root)
            checked_state = deepcopy(s)
            checked_state["graph"] = graph
            check_config(checked_state)
            for tid, before in s["graph"]["tasks"].items():
                after = graph["tasks"][tid]
                try:
                    preserve_obligations(
                        s["config"]["_project"]["data"].get("decisions", []),
                        before.get("policy_decisions", {}),
                        after.get("policy_decisions", {}),
                        reintake=True,
                        previous_definitions=old_data.get("decisions", []),
                    )
                except ValueError as exc:
                    require(False, str(exc))
                preserve_task_guards(before, after)
            refreshed_sources = {
                k: lock_source(self.root, src, check_expected=False)
                for k, src in graph["sources"].items()
            }
            previous_by_id = {n["id"]: n for n in s["graph"]["nodes"]}
            for node in graph["nodes"]:
                previous_node = previous_by_id.get(node["id"])
                if previous_node:
                    require(
                        node["task"] == previous_node["task"]
                        and node["stage"] == previous_node["stage"],
                        "Keep task/stage identity for existing nodes",
                    )
                    if (
                        previous_node.get("agent")
                        and node.get("agent")
                        and (
                            previous_node.get("profile_selection") is not None
                            or node.get("profile_selection") is not None
                        )
                    ):
                        prior_agent = agent_key(previous_node)
                        next_agent = agent_key(node)
                        prior_profile = s["graph"]["agents"][prior_agent]["profile"]
                        next_profile = graph["agents"][next_agent]["profile"]
                        started = s["nodes"][node["id"]].get(
                            "attempt", 0
                        ) > 0 or has_prior_dispatch_evidence(s, node["id"])
                        if started:
                            require(
                                prior_profile == next_profile and prior_agent == next_agent,
                                "Started assignments require correct",
                            )
                        elif prior_profile != next_profile:
                            source_id = graph["tasks"][node["task"]]["source"]
                            decision_id = s["config"]["profiles"][next_profile].get(
                                "initial_profile_decision"
                            )
                            old_definition = next(
                                (
                                    d
                                    for d in old_data.get("decisions", [])
                                    if d["id"] == decision_id
                                ),
                                None,
                            )
                            new_definition = next(
                                (
                                    d
                                    for d in new_data.get("decisions", [])
                                    if d["id"] == decision_id
                                ),
                                None,
                            )
                            require(
                                refreshed_sources[source_id] != s["graph"]["sources"][source_id]
                                or old_definition != new_definition,
                                "Profile change without source or policy change requires revise",
                            )
                            require(
                                graph["agents"].get(prior_agent)
                                == s["graph"]["agents"][prior_agent],
                                "Keep previous logical agent unchanged",
                            )
                            require(
                                prior_agent != next_agent
                                and next_agent not in s["graph"]["agents"],
                                "Profile change needs a new logical agent",
                            )
                        require(
                            next_profile
                            not in s.get("retired_node_profiles", {}).get(node["id"], []),
                            "Retired profile cannot be restored",
                        )
            old_nodes = {n["id"] for n in s["graph"]["nodes"]}
            require(
                old_nodes <= {n["id"] for n in graph["nodes"]},
                "Retain stable node IDs/history",
            )
            graph["sources"] = refreshed_sources
            validate_graph(graph, s["config"], self.root)
            validate_profile_selections(
                graph,
                s["config"],
                s.get("corrections", []),
                [*s["events"], {"previous_graph": s["graph"], "previous_config": old_config}],
                s["graph"],
            )
            for a in s["sessions"]:
                require(
                    graph["agents"].get(a) == s["graph"]["agents"].get(a),
                    "Replace session before role/profile change",
                )
            previous, previous_nodes = s["graph"], s["nodes"]
            s["graph"], s["revision"] = graph, s["revision"] + 1
            s["nodes"] = {
                n["id"]: (
                    previous_nodes[n["id"]]
                    if previous_nodes.get(n["id"], {}).get("status") == "blocked"
                    else {
                        "status": "pending",
                        "attempt": previous_nodes.get(n["id"], {}).get("attempt", 0),
                    }
                )
                for n in graph["nodes"]
            }
            # Re-intake authorizes a new source, not a free retry of a quality
            # failure. Only explicit source-drift blockers gain a recovery route.
            for tid in graph["tasks"]:
                drift_nodes = [
                    nid
                    for nid, old in previous_nodes.items()
                    if old["status"] == "blocked"
                    and nid in s["nodes"]
                    and next(n for n in graph["nodes"] if n["id"] == nid)["task"] == tid
                    and (
                        old.get("report", {}).get("stage_result") == "SOURCE_DRIFT"
                        or old.get("report", {}).get("observed_source_drift")
                    )
                ]
                if drift_nodes and tid not in s.get("escalation_stops", {}):
                    used = s["counters"].get(tid + ":recovery", 0)
                    s.setdefault("escalation_stops", {})[tid] = dict(
                        reason=reason,
                        decision="blocked",
                        node_id=drift_nodes[0],
                        node_ids=drift_nodes,
                        kind="source_reintake",
                        cause="recovery",
                        budget_exhausted=used >= escalation.limits(s, tid)["recovery"],
                        authorization=authorization,
                    )
            self.save(
                s,
                "source_reintake",
                reason=reason,
                authorization=authorization,
                previous_graph=previous,
                previous_nodes=previous_nodes,
                previous_config=old_config,
            )

    def retry(self, node_id: str, stage: str, reason: str, terminal_evidence: str) -> None:
        with self.locked():
            s = self.read()
            nodes = {n["id"]: n for n in s["graph"]["nodes"]}
            n, v = nodes[node_id], s["nodes"][node_id]
            require(terminal_evidence and reason, "Reconcile old writer and explain retry")
            require(
                v["status"] in {"blocked", "unknown", "done"},
                "Cannot retry a live writer",
            )
            limits = escalation.limits(s, n["task"])
            profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
            acceptance_guard(escalation.guard, s, n["task"])
            require(
                stage == "recovery" or not profile.get("escalation"),
                "Use correct for an escalating profile's quality/complexity decision",
            )
            require(stage in limits, "Unknown retry stage")
            key = n["task"] + ":" + stage
            require(s["counters"].get(key, 0) < limits[stage], "RETRY_BUDGET_EXHAUSTED")
            affected = {node_id} | {k for k in nodes if node_id in ancestors(nodes, k)}
            if profile.get("escalation"):
                require(
                    not any(
                        s["nodes"][k].get("report", {}).get("outcome") in {"FAIL", "BLOCKED"}
                        for k in affected
                    ),
                    "Use correct for a reported failure or blocker; recovery is transport-only",
                )
            require(
                not any(
                    s["nodes"][k]["status"] in {"reserved", "running", "unknown"}
                    for k in affected - {node_id}
                ),
                "Reconcile dependent workers first",
            )
            s["counters"][key] = s["counters"].get(key, 0) + 1
            for k in affected:
                old = s["nodes"][k]
                s["events"].append(
                    {
                        "at": time.time(),
                        "event": "invalidated",
                        "node": k,
                        "previous": old,
                    }
                )
                s["nodes"][k] = {"status": "pending", "attempt": old["attempt"]}
            self.save(
                s,
                "retry",
                node=node_id,
                stage=stage,
                reason=reason,
                terminal_evidence=terminal_evidence,
            )

    def correct(self, node_id: str, request: Any) -> dict[str, Any]:
        with self.locked():
            state = self.read()
            require(state["status"] == "active", "Run is not active")
            check_config(state)
            return acceptance_guard(escalation.correct, self, state, node_id, request)

    def resume_task(self, task_id: str, evidence: str) -> None:
        with self.locked():
            state = self.read()
            require(
                state["status"] == "active" and evidence.strip(),
                "Need active run and resolved blocker/human decision",
            )
            check_config(state)
            require(
                task_id in state.get("escalation_stops", {}),
                "Task has no escalation stop",
            )
            require(
                not any(v["status"] in escalation.ACTIVE for v in state["nodes"].values()),
                "Quiesce runtime before resume",
            )
            stop = state["escalation_stops"][task_id]
            self.check_sources(state, state["graph"]["tasks"][task_id])
            stage = "recovery" if stop["kind"] == "environment" else stop["cause"]
            key = task_id + ":" + stage
            used = state["counters"].get(key, 0)
            require(
                used < escalation.limits(state, task_id)[stage],
                "Budget exhausted; resume cannot reset limits",
            )
            nodes = validate_graph(state["graph"], state["config"], self.root)
            node_id = stop["node_id"]
            roots = set(stop.get("node_ids", [node_id]))
            affected = roots | {k for k in nodes if ancestors(nodes, k) & roots}
            for k in affected:
                old = state["nodes"][k]
                state["events"].append(
                    dict(at=time.time(), event="invalidated", node=k, previous=old)
                )
                state["nodes"][k] = dict(status="pending", attempt=old["attempt"])
            state["counters"][key] = used + 1
            del state["escalation_stops"][task_id]
            self.save(
                state,
                "task_resumed",
                task=task_id,
                evidence=evidence,
                previous=stop,
                retry_cause=stage,
            )
            # Work is pending; dispatch still requires a separate claim and bind.

    def resume_approved(self, node_id: str, request_id: str, evidence: str) -> None:
        with self.locked():
            state = self.read()
            require(state["status"] == "active", "Run is not active")
            check_config(state)
            require(
                not any(v["status"] in escalation.ACTIVE for v in state["nodes"].values()),
                "Quiesce runtime before resuming approval",
            )
            nodes = validate_graph(state["graph"], state["config"], self.root)
            node = nodes[node_id]
            task = state["graph"]["tasks"][node["task"]]
            self.check_sources(state, task)
            acceptance_guard(escalation.guard, state, node["task"])
            approval.validate_resume(self.root, state, node, task, request_id, evidence)
            graph = approval.expanded_graph(state, node, state["nodes"][node_id]["report"])
            added = sorted(set(graph["tasks"][node["task"]]["scope"]) - set(task["scope"]))
            if added:
                validate_graph(graph, state["config"], self.root)
                state["config"] = freeze_project(state["config"], graph, self.root)
                state["graph"] = graph
                state["revision"] += 1
            roots = {node_id} | {
                key
                for key, candidate in nodes.items()
                if candidate["task"] == node["task"]
                and candidate["stage"] in {"verify", "review"}
                and state["nodes"][key]["status"] == "done"
            }
            affected = roots | {key for key in nodes if ancestors(nodes, key) & roots}
            for key in sorted(affected):
                old = state["nodes"][key]
                if key != node_id and old["status"] == "blocked":
                    continue  # This approval resolves only its own blocker.
                state["events"].append(
                    dict(at=time.time(), event="invalidated", node=key, previous=old)
                )
                state["nodes"][key] = dict(status="pending", attempt=old["attempt"])
            self.save(
                state,
                "approval_resumed",
                node=node_id,
                request_id=request_id,
                evidence=evidence,
                added_scope=added,
            )

    def accept(self, node_id: str) -> None:
        with self.locked():
            s = self.read()
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            n = nodes[node_id]
            require(n["stage"] == "accept", "Not an acceptance node")
            acceptance_guard(escalation.guard, s, n["task"])
            require(s["nodes"][node_id]["status"] == "pending", "Already accepted")
            require(
                all(s["nodes"][k]["status"] == "done" for k in ancestors(nodes, node_id)),
                "Required work not done",
            )
            task = s["graph"]["tasks"][n["task"]]
            self.check_sources(s, task)
            for k in ancestors(nodes, node_id):
                if nodes[k]["task"] == n["task"] and nodes[k]["stage"] in {
                    "verify",
                    "review",
                }:
                    if nodes[k]["stage"] == "verify":
                        acceptance_guard(
                            acceptance.verify_results,
                            task,
                            s["nodes"][k]["report"].get("checks", []),
                        )
                    check_receipts(
                        self.root,
                        s,
                        k,
                        s["nodes"][k]["report"].get("checks", []),
                        complete=nodes[k]["stage"] == "verify",
                    )
                    require(
                        s["nodes"][k]["report"]["files"] == snapshot(self.root, task["scope"]),
                        "Evidence invalidated by later write",
                    )
                    acceptance_guard(
                        transition_gates.evaluate,
                        s["config"]["_project"]["data"],
                        nodes[k],
                        task,
                        s["nodes"][k]["report"],
                    )
            acceptance_guard(
                review_findings.gate,
                s,
                n["task"],
                snapshot(self.root, task["scope"]),
                s["graph"]["sources"][task["source"]]["hash"],
            )
            s["nodes"][node_id]["gate_result"] = transition_gates.stage_result(
                s,
                n,
                {
                    "outcome": "PASS",
                    "summary": "All current acceptance obligations passed",
                    "files": snapshot(self.root, task["scope"]),
                },
            )
            s["nodes"][node_id]["status"] = "done"
            self.save(s, "accepted", node=node_id)

    def archive(self, outcome: str, summary: str) -> str:
        with self.locked():
            s = self.read()
            require(
                outcome in {"completed", "cancelled"},
                "Only terminal runs can be archived",
            )
            require(summary, "Final summary required")
            if s["status"] in {"completed", "cancelled"}:
                require(
                    s["status"] == outcome and s["summary"] == summary,
                    "Terminal history is immutable",
                )
                if "archive_path" in s:
                    run_archive.verified_cleanup_paths(self.root, s)
                    return str(relative(self.root, s["archive_path"]))
                hist = relative(self.root, f".factory/memory/history/{s['run_id']}/run.json")
                require(read_json(hist) == s, "Terminal history is immutable")
                return self._save_terminal_archive(s)
            require(
                not any(
                    v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()
                ),
                "Outstanding runtime work",
            )
            if outcome == "completed":
                require(
                    all(v["status"] == "done" for v in s["nodes"].values()),
                    "Unfinished nodes",
                )
                for tid, task in s["graph"]["tasks"].items():
                    acceptance_guard(
                        review_findings.gate,
                        s,
                        tid,
                        snapshot(self.root, task["scope"]),
                        s["graph"]["sources"][task["source"]]["hash"],
                    )
                # Recheck every final acceptance, including cross-task invalidation.
                for n in s["graph"]["nodes"]:
                    task = s["graph"]["tasks"][n["task"]]
                    self.check_sources(s, task)
                    current_final = len(s["graph"]["tasks"]) == 1 or task["kind"] == "integration"
                    if current_final and n["stage"] in {"verify", "review"}:
                        check_receipts(
                            self.root,
                            s,
                            n["id"],
                            s["nodes"][n["id"]]["report"].get("checks", []),
                            complete=n["stage"] == "verify",
                        )
                        require(
                            s["nodes"][n["id"]]["report"]["files"]
                            == snapshot(self.root, task["scope"]),
                            "Final evidence stale",
                        )
                        acceptance_guard(
                            transition_gates.evaluate,
                            s["config"]["_project"]["data"],
                            n,
                            task,
                            s["nodes"][n["id"]]["report"],
                        )
            s["status"], s["summary"] = outcome, summary
            return self._save_terminal_archive(s)

    def _save_terminal_archive(self, state: State) -> str:
        path = run_archive.pack_run(self.root, state)
        atomic_json(self.path, state)
        log_event("archived", run_id=state["run_id"], outcome=state["status"])
        return str(path)

    def clean(self) -> None:
        with self.locked():
            s = self.read()
            require(s["status"] in {"completed", "cancelled"}, "Keep resumable state")
            require("archive_path" in s, "Archive legacy terminal run before cleanup")
            paths = run_archive.verified_cleanup_paths(self.root, s)
            for path in paths:
                path.unlink(missing_ok=True)
            # Remove empty run-owned history folders, preserving any late artifacts.
            history = relative(self.root, f".factory/memory/history/{s['run_id']}")
            parents = {p for path in paths for p in path.parents if p.is_relative_to(history)}
            for parent in sorted(parents, key=lambda p: -len(p.parts)):
                if parent.is_dir() and not any(parent.iterdir()):
                    parent.rmdir()
            self.path.unlink()  # Owns only this literal manifest, never foreign artifacts.


if __name__ == "__main__":
    from factory_tooling.runtime.workflow_cli import main

    main()
