#!/usr/bin/env python3
"""Validated run ledger for an agent-driven workflow. Does not call a model."""

from __future__ import annotations

import platform
import shlex
import shutil
import time
import uuid
from contextlib import AbstractContextManager
from copy import deepcopy

# Direct CLI execution and import-by-path use the same tool modules.
from pathlib import Path
from typing import Any, Literal, cast

from pydantic import ConfigDict, TypeAdapter, ValidationError

from factory_tooling.decisions.decision_contract import (
    preserve_obligations as preserve_obligations,
)
from factory_tooling.logging_config import event as log_event
from factory_tooling.paths import FACTORY_ROOT as FACTORY_ROOT
from factory_tooling.project.profile_io import load_profile, parse_yaml
from factory_tooling.project.profile_rules import boundary_gates as boundary_gates
from factory_tooling.project.profile_rules import project_checks as project_checks
from factory_tooling.runtime import acceptance as acceptance
from factory_tooling.runtime import (
    approval,
    command_worker,
    finish_requirements,
    report_history,
    run_archive,
)
from factory_tooling.runtime import escalation as escalation
from factory_tooling.runtime import review_findings as review_findings
from factory_tooling.runtime import transition_gates as transition_gates
from factory_tooling.runtime.assignment import implement_packet as implement_packet
from factory_tooling.runtime.assignment import worker_node
from factory_tooling.runtime.check_evidence import check_generated, check_receipts
from factory_tooling.runtime.check_process import execute_check as execute_check
from factory_tooling.runtime.contracts import (
    CommandResult,
    GraphTopology,
    LedgerEvent,
    LockedGraph,
    Nonblank,
    PacketRef,
    PendingCheck,
    Report,
)
from factory_tooling.runtime.contracts import Config as Config
from factory_tooling.runtime.contracts import Dispatch as Dispatch
from factory_tooling.runtime.contracts import ExecutionReceipt as ExecutionReceipt
from factory_tooling.runtime.contracts import Graph as Graph
from factory_tooling.runtime.contracts import Node as Node
from factory_tooling.runtime.contracts import State as State
from factory_tooling.runtime.contracts import Task as Task
from factory_tooling.runtime.contracts import agent_key as agent_key
from factory_tooling.runtime.packet_io import (
    acknowledgement,
    confirm_delivery,
    freeze_packet,
    material_digest,
    packet_chunks,
    packet_diagnostics,
    read_packet_bytes,
    receipt_path,
    serve_chunk,
)
from factory_tooling.runtime.state_io import (
    parse_report,
    parse_report_draft,
    parse_state,
)
from factory_tooling.runtime.workflow_config import (
    check_capabilities as check_capabilities,
)
from factory_tooling.runtime.workflow_config import check_config as check_config
from factory_tooling.runtime.workflow_config import freeze_project as freeze_project
from factory_tooling.runtime.workflow_config import load_config as load_config
from factory_tooling.runtime.workflow_config import pool as pool
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
from factory_tooling.runtime.workflow_graph import (
    parse_graph,
    validate_assignment_lineage,
)
from factory_tooling.runtime.workflow_graph import validate_graph as validate_graph
from factory_tooling.runtime.workflow_sources import lock_source as lock_source
from factory_tooling.validation import validation_message

# Compatibility exports: existing imports and command entry points stay valid.


LEDGER_EVENT = TypeAdapter[LedgerEvent](LedgerEvent)
TASK_HANDOFFS = TypeAdapter[dict[str, str]](dict[str, Nonblank], config=ConfigDict(strict=True))


def has_prior_dispatch_evidence(state: State, node_id: str) -> bool:
    """Common reservation/correction evidence; callers retain their own policies."""
    return any(
        event.get("node") == node_id and event.get("event") == "reserved"
        for event in state["events"]
    ) or any(
        node_id in record.get("reassigned_nodes", []) or record.get("node_id") == node_id
        for record in state.get("corrections", [])
    )


def validate_assignment_change(state: State, graph: GraphTopology) -> None:
    validate_assignment_lineage(graph, state["config"], state.get("corrections", []))
    old = state["graph"]
    new_nodes = {n["id"]: n for n in graph["nodes"]}
    old_ids = {n["id"] for n in old["nodes"]}
    for previous in old["nodes"]:
        node_id = previous["id"]
        require(node_id in new_nodes, "Retain stable node IDs/history")
        node = new_nodes[node_id]
        require(
            node["task"] == previous["task"] and node["stage"] == previous["stage"],
            "Keep task/stage identity for existing nodes",
        )
        if not (state["nodes"][node_id]["attempt"] or has_prior_dispatch_evidence(state, node_id)):
            continue
        aid = previous.get("agent")
        if aid is None:
            continue
        assignment = old["agents"][aid]
        require(
            node.get("agent") == aid and graph["agents"].get(aid) == assignment,
            "Started assignments require correct",
        )
        if assignment["role"] not in {"developer", "test-writer"}:
            continue
        owns = previous.get("owns", [])
        require(set(owns) <= set(node.get("owns", [])), "Keep started assignment ownership")
        for added in (n for n in graph["nodes"] if n["id"] not in old_ids):
            if added["task"] == previous["task"] and overlaps(owns, added.get("owns", [])):
                require(
                    node_id in ancestors(new_nodes, added["id"]),
                    "New overlapping work must follow the started assignment",
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

    def locked(self) -> AbstractContextManager[None]:
        return command_worker.lock(relative(self.root, ".factory/memory/state/workflow.lock"))

    def read(self) -> State:
        path = relative(self.root, ".factory/memory/state/workflow.json")
        state = parse_state(read_json(path))
        self.diagnostic_state = {
            "run_id": state["run_id"],
            "nodes": {n["id"]: n["task"] for n in state["graph"]["nodes"]},
        }
        return state

    def save(self, state: State, event: str, **details: object) -> None:
        require(
            state["status"] == "active",
            "Terminal run is immutable; start a new authorized run",
        )
        try:
            state["events"].append(
                LEDGER_EVENT.validate_python({"at": time.time(), "event": event, **details})
            )
        except ValidationError as exc:
            raise Invalid(validation_message("Invalid workflow event", exc, LEDGER_EVENT)) from None
        parse_state(state)
        atomic_json(relative(self.root, ".factory/memory/state/workflow.json"), state)
        node_id = details.get("node")
        node = next((n for n in state["graph"]["nodes"] if n["id"] == node_id), None)
        attempt = state["nodes"].get(node_id) if isinstance(node_id, str) else None
        event_fields: dict[str, object] = {"run_id": state["run_id"]}
        if node is not None:
            event_fields.update(node_id=node["id"], task_id=node["task"])
        elif isinstance(details.get("task"), str) and details["task"] in state["graph"]["tasks"]:
            event_fields["task_id"] = details["task"]
        if attempt and attempt.get("dispatch_id"):
            event_fields["dispatch_id"] = attempt["dispatch_id"]
        elif event in {"retry", "correction_decided"}:
            for prior in reversed(state["events"][:-1]):
                if prior.get("event") != "invalidated":
                    break
                if prior.get("node") == node_id:
                    previous = prior.get("previous")
                    if previous is not None and (dispatch_id := previous.get("dispatch_id")):
                        event_fields["dispatch_id"] = dispatch_id
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
        validate_assignment_lineage(graph, config)
        config = freeze_project(config, graph, self.root)
        for task in graph["tasks"].values():
            for p in task["scope"]:
                relative(self.root, p)
        for node in graph["nodes"]:
            for p in node.get("owns", []):
                relative(self.root, p)
        with self.locked():
            require(not self.path.exists(), "Existing run: resume or archive/clean it first")
            locked_graph: LockedGraph = {
                **graph,
                "sources": {k: lock_source(self.root, src) for k, src in graph["sources"].items()},
            }
            state: State = {
                "run_id": "run-" + uuid.uuid4().hex[:12],
                "revision": 1,
                "status": "active",
                "workspace": str(self.root),
                "graph": locked_graph,
                "config": config,
                "events": [],
                "counters": {},
                "sessions": {},
                "nodes": {n["id"]: {"status": "pending", "attempt": 0} for n in graph["nodes"]},
            }
            check_config(state)
            self.save(state, "created")
            input_graph["sources"] = parse_graph(locked_graph)["sources"]
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
                receipt = receipt_path(self.root, meta).relative_to(self.root).as_posix()
                v["packet_receipt"] = receipt
                s.setdefault("transport_artifacts", []).append(receipt)
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

    def _packet_bootstrap(self, s: State, n: Node, meta: PacketRef) -> dict[str, Any]:
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
                "Run read_command in read_shell. For each next chunk set --chunk to next "
                "and --ack to the last result's acknowledgement. Retry a lost response "
                "with identical arguments. After receiving the last chunk, append --ack "
                "and --materials from that result to confirm_command. Wait for confirmation "
                "before writes or assigned commands."
            ),
        }

    def read_packet(
        self, node_id: str, bootstrap: object, chunk: int, received: str | None = None
    ) -> dict[str, Any]:
        """Serve one bounded chunk; only an acknowledged response advances delivery."""
        with self.locked():
            s = self.read()
            n, v = self.packet_dispatch(s, node_id)
            expected = v.get("packet_file")
            if expected is None:
                raise Invalid("Prepare packet first")
            data = read_packet_bytes(self.root, s, n, expected, bootstrap)
            chunks = packet_chunks(data)
            total = len(chunks)
            serve_chunk(self.root, expected, chunks, chunk, received)
            return {
                "ordinal": chunk,
                "total": total,
                "next": chunk + 1 if chunk < total else None,
                "content": chunks[chunk - 1],
                "acknowledgement": acknowledgement(chunks, chunk),
                "materials": material_digest(data) if chunk == total else None,
                "binding": v["status"],
                "ready_for_work": bool(v.get("packet_confirmed")),
            }

    def confirm_packet(
        self, node_id: str, bootstrap: object, received: str = "", materials: str = ""
    ) -> None:
        with self.locked():
            s = self.read()
            n, dispatch = self.packet_dispatch(s, node_id)
            expected = dispatch.get("packet_file")
            if expected is None:
                raise Invalid("Prepare packet first")
            require(dispatch["status"] == "running", "Bind before confirming packet")
            data = read_packet_bytes(self.root, s, n, expected, bootstrap)
            if dispatch.get("packet_confirmed"):
                chunks = packet_chunks(data)
                require(
                    received == acknowledgement(chunks, len(chunks))
                    and materials == material_digest(data),
                    "Confirmation does not match the authorized delivery",
                )
                return
            confirm_delivery(self.root, expected, data, received, materials)
            dispatch["packet_confirmed"] = True
            self.save(
                s,
                "packet_confirmed",
                node=node_id,
                dispatch_id=expected["dispatch_id"],
                sha256=expected["sha256"],
            )

    def set_paused(self, reason: str | None) -> None:
        with self.locked():
            state = self.read()
            require(state["status"] == "active", "Run is not active")
            if reason is None:
                require(state.get("pause_reason"), "Run is not paused")
                del state["pause_reason"]
                self.save(state, "resumed")
            else:
                require(reason.strip(), "User pause/stop reason required")
                state["pause_reason"] = reason
                self.save(state, "paused", reason=reason)

    def acknowledge_result(self, node_id: str, dispatch_id: str) -> None:
        with self.locked():
            state = self.read()
            ref = state.get("report_index", {}).get(dispatch_id)
            require(
                ref is not None and ref["node_id"] == node_id,
                "Result dispatch is stale or unavailable",
            )
            processed = state.setdefault("processed_results", [])
            if dispatch_id not in processed:
                processed.append(dispatch_id)
                self.save(state, "result_acknowledged", node=node_id)

    def next_actions(self, after: str | None = None) -> dict[str, Any]:
        with self.locked():
            state = self.read()
            require(
                after is None or after.startswith(state["run_id"] + ":"),
                "Cursor belongs to a different run",
            )
            active = {
                key: {
                    field: value
                    for field, value in current.items()
                    if field in {"status", "dispatch_id", "profile", "handle", "reason"}
                }
                for key, current in state["nodes"].items()
                if current["status"] in escalation.ACTIVE
            }
            commands = {
                rid: {
                    "node_id": r["node_id"],
                    "dispatch_id": r["dispatch_id"],
                    "check_id": r["spec"]["id"],
                    "owner_registered": command_worker.artifact(
                        self.root, r, ".owner.json"
                    ).exists(),
                }
                for rid, r in self.active_commands(state).items()
            }
            result: dict[str, Any] = {
                "run_status": state["status"],
                "pause_reason": state.get("pause_reason"),
                "automatic_continuation": False,
                "dispatches": active,
                "sessions": {
                    key: session
                    for key, session in state["sessions"].items()
                    if any(
                        n["id"] in active and n.get("agent") == key for n in state["graph"]["nodes"]
                    )
                },
                "commands": commands,
            }
            results = {}
            ready, accepts = [], []
            blockers: dict[str, str] = {}
            corrections: dict[str, list[str]] = {}
            if state["status"] == "active":
                nodes = validate_graph(state["graph"], state["config"], self.root)
                try:
                    check_config(state)
                    validate_assignment_lineage(
                        state["graph"], state["config"], state.get("corrections", [])
                    )
                except Invalid as exc:
                    blockers["run"] = str(exc)
                for key, current in state["nodes"].items():
                    report = current.get("report")
                    if report and current.get("dispatch_id") not in state.get(
                        "processed_results", []
                    ):
                        results[key] = {
                            "dispatch_id": current["dispatch_id"],
                            "outcome": report["outcome"],
                            "stage_result": report.get("stage_result"),
                            "report_ref": current.get("report_ref"),
                        }
                    if current["status"] == "unknown":
                        blockers[key] = "Reconcile actual transport ownership before retry"
                    if current["status"] == "blocked":
                        blockers[key] = (
                            str(report.get("stage_result", "Blocked")) if report else "Blocked"
                        )
                        if (
                            not active
                            and not commands
                            and not state.get("pause_reason")
                            and "run" not in blockers
                        ):
                            corrections[key] = escalation.possible_actions(
                                state, nodes[key], current
                            )
                    if current["status"] != "pending" or "run" in blockers:
                        continue
                    try:
                        if nodes[key]["stage"] == "accept":
                            self.acceptance_task(state, nodes, key)
                            accepts.append(key)
                        else:
                            self.claim_pool(state, nodes, key)
                            ready.append(key)
                    except Invalid as exc:
                        blockers[key] = str(exc)
            completion = False
            if state["status"] == "active" and not active:
                try:
                    self.check_completion(state)
                    completion = True
                except Invalid as exc:
                    blockers["completion"] = str(exc)
            result = {
                **result,
                "results": results,
                "runnable": ready,
                "acceptance": accepts,
                "blockers": blockers,
                "corrections": corrections,
                "completion_eligible": completion,
            }

            cursor = (
                f"{state['run_id']}:{len(state['events'])}:{report_history.identity(result)[:16]}"
            )
            if after == cursor and not commands:
                return {"cursor": cursor, "unchanged": True, "run_status": state["status"]}
            return {**result, "cursor": cursor, "unchanged": False}

    def claim_pool(self, s: State, nodes: dict[str, Node], node_id: str) -> str:
        """Authoritative claim eligibility shared by planning and reservation."""
        require(s["status"] == "active", "Run is not active")
        require(not s.get("pause_reason"), "Run is paused by user")
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
            k for k, v in s["nodes"].items() if v["status"] in {"reserved", "running", "unknown"}
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
        active = self.active_commands(s)
        require(
            not active or not (n.get("owns") or "project-checks" in n.get("resources", [])),
            "QUEUED_COMMAND_RESOURCE",
        )
        return p

    def claim(self, node_id: str) -> dict[str, object]:
        with self.locked():
            s = self.read()
            require(s["status"] == "active", "Run is not active")
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            validate_assignment_lineage(s["graph"], s["config"], s.get("corrections", []))
            n, current = nodes[node_id], s["nodes"][node_id]
            p = self.claim_pool(s, nodes, node_id)
            profile_id = s["graph"]["agents"][agent_key(n)]["profile"]
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
            current["assignment"] = report_history.assignment(s, n, self.finish_requirements(s, n))
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

    def run_check(
        self,
        node_id: str,
        check_id: str,
        request_id: str | None = None,
        *,
        expected_dispatch: str | None = None,
    ) -> CommandResult | PendingCheck:
        """Persist intent, run outside the ledger lock, then reconcile real process facts."""
        process = None
        with self.locked():
            state = self.read()
            current = state["nodes"][node_id]
            dispatch_id = current.get("dispatch_id")
            require(
                expected_dispatch is None or expected_dispatch == dispatch_id,
                "Execution request dispatch is stale",
            )
            request_id = check_id if request_id is None else request_id
            require(request_id.strip(), "Execution request ID required")
            executions = state.setdefault("executions", {})
            rid = report_history.identity([state["run_id"], node_id, dispatch_id, request_id])
            record = executions.get(rid)
            if record is not None:
                require(
                    record["spec"]["id"] == check_id,
                    "Execution request ID already refers to different commands",
                )
            else:
                record = self._check_intent(state, node_id, check_id, rid, request_id)
                executions[rid] = record
                self.save(state, "check_started", node=node_id, execution_id=rid)
                # Start after the intent commit. The supervisor cannot execute until it
                # acquires the ledger lock, rechecks the intent and registers ownership.
                try:
                    process = command_worker.launch(
                        self.root, FACTORY_ROOT / "tools/workflow.py", rid, record
                    )
                except OSError:
                    # No owner exists yet. Reconcile or explicitly abandon the intent.
                    return self._pending_check(rid, record)
        if process is not None:
            process.wait()
        return self.reconcile_check(rid)

    def _check_intent(
        self,
        state: State,
        node_id: str,
        check_id: str,
        rid: str,
        request_id: str,
    ) -> ExecutionReceipt:
        require(state["status"] == "active", "Run is not active")
        require(not state.get("pause_reason"), "Run is paused by user")

        check_config(state)
        nodes = validate_graph(state["graph"], state["config"], self.root)
        node, dispatch = nodes[node_id], state["nodes"][node_id]
        require(dispatch["status"] == "running", "Check needs a bound running node")
        require(
            not any(
                d["status"] in {"reserved", "running"}
                and "packet_receipt" in d
                and not d.get("packet_confirmed")
                for d in state["nodes"].values()
            ),
            "Wait for outstanding native packet delivery before running checks",
        )
        require(
            "project-checks" in node.get("resources", []), "Check needs project-checks reservation"
        )
        require(
            not self.active_commands(state),
            "Unresolved command; reconcile process before retrying node",
        )
        task = state["graph"]["tasks"][node["task"]]
        self.check_sources(state, task)
        obligations = self.finish_requirements(state, node)
        available = {
            c["id"]: c for c in obligations["allowed_checks"] if c["kind"] != "observation"
        }
        require(check_id in available, "Unknown assigned command")
        child_ids = available[check_id]["execution"].get("stages", [])
        require(
            len(set(child_ids)) == len(child_ids)
            and check_id not in child_ids
            and set(child_ids) <= set(available),
            "Composite requires distinct assigned command stages",
        )
        registrations = {c["id"]: c for c in project_checks(state["config"]["_project"]["data"])}
        require(
            not child_ids or {check_id, *child_ids} <= set(registrations),
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
            cwd = self.root if execution["cwd"] == "." else relative(self.root, execution["cwd"])
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
            for dependency in registrations[cid].get("after", []) if cid in registrations else []:
                if dependency in included:
                    continue
                prior = previous.get(dependency)
                require(
                    prior is not None
                    and prior["status"] == "PASS"
                    and prior["after_files"] == snapshot(self.root, prior["input_scope"]),
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
        relative(self.root, output).parent.mkdir(parents=True, exist_ok=True)
        return {
            "run_id": state["run_id"],
            "node_id": node_id,
            "dispatch_id": dispatch["dispatch_id"],
            "source_hash": state["graph"]["sources"][task["source"]]["hash"],
            "spec": available[check_id],
            "input_scope": scope,
            "files": snapshot(self.root, scope),
            "status": "RUNNING",
            "started_at": time.time(),
            "request_id": request_id,
            "output": output,
            "environment": {
                "platform": platform.platform(),
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

    @staticmethod
    def _pending_check(rid: str, record: ExecutionReceipt) -> PendingCheck:
        return {"id": record["spec"]["id"], "execution_id": rid, "result": "RUNNING"}

    @staticmethod
    def active_commands(state: State) -> dict[str, ExecutionReceipt]:
        return {
            key: record
            for key, record in state.get("executions", {}).items()
            if record["status"] == "RUNNING"
        }

    def reconcile_check(
        self, rid: str, abandon_unstarted: bool = False
    ) -> CommandResult | PendingCheck:
        with self.locked():
            state = self.read()
            record = state.get("executions", {}).get(rid)
            if record is None:
                raise Invalid("Unknown execution")
            if record["status"] != "RUNNING":
                return record["result"]
            facts = command_worker.facts(self.root, rid, record)
            if facts is None:
                if not abandon_unstarted:
                    return self._pending_check(rid, record)
                require(
                    not command_worker.artifact(self.root, record, ".owner.json").exists(),
                    "Cannot abandon a registered process; reconcile after its group terminates",
                )
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
            if state["nodes"][node_id].get("dispatch_id") != record["dispatch_id"] or (
                state["nodes"][node_id]["status"] != "running"
            ):
                error = "Execution returned to a stale dispatch"
            else:
                try:
                    check_config(state)
                    self.check_sources(state, task)
                except Invalid as exc:
                    error = str(exc)
            parent = self._complete_check(rid, record, stages.get(rid), error)
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
                if stages[child_id].get("selection"):
                    child["selection"] = stages[child_id]["selection"]
                self._complete_check(child_id, child, stages[child_id], error)
                state["executions"][child_id] = child
            self.save(
                state, "check_finished", node=node_id, execution_id=rid, result=parent["result"]
            )
            return parent

    def check_results(self, rid: str) -> list[CommandResult]:
        with self.locked():
            state = self.read()
            record = state.get("executions", {}).get(rid)
            require(
                record is not None and record.get("result"), "Execution is unknown or not finished"
            )
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
        self,
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
            after = snapshot(self.root, record["input_scope"])
        else:
            code = observed["exit_code"]
            scope, before, after = (
                observed["input_scope"],
                observed["files"],
                observed["after_files"],
            )
            record.update({"input_scope": scope, "files": before})
            outputs = execution.get("outputs", [])
            if any(before[path] != after[path] for path in scope if path not in outputs):
                error = "Files changed during check"
            if outputs:
                record["output_before"] = {path: before[path] for path in outputs}
                record["output_after"] = {path: after[path] for path in outputs}
            error = error or observed["error"]
        if after != snapshot(self.root, record["input_scope"]):
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
        output = relative(self.root, record["output"])
        if output.is_file():
            record["output_hash"] = digest(output.read_bytes())
        return result

    def finish_requirements(
        self, state: State, node: Node
    ) -> finish_requirements.FinishRequirements:
        return acceptance_guard(
            finish_requirements.requirements,
            state["config"]["_project"]["data"],
            node,
            state["graph"]["tasks"][node["task"]],
            state["graph"]["agents"][agent_key(node)]["role"],
        )

    def prepare_report(self, node_id: str, draft: object, receipt_ids: list[str]) -> Report:
        """Capture the author's evidence at handoff for its exact running dispatch."""
        with self.locked():
            state = self.read()
            node = next((n for n in state["graph"]["nodes"] if n["id"] == node_id), None)
            if node is None or node_id not in state["nodes"]:
                raise Invalid("Unknown report node")
            if isinstance(draft, dict):
                require("files" not in draft, "Existing evidence cannot be refreshed")
            report = parse_report_draft(draft)
            report.pop("observed_source_drift", None)
            checks = report.get("checks", [])
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
            require(len(set(receipt_ids)) == len(receipt_ids), "Duplicate receipt")
            outcome = report["outcome"]
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
            obligations = self.finish_requirements(state, node)
            acceptance_guard(finish_requirements.validate_selection, obligations, checks)
            result = parse_report(
                {
                    **report,
                    "task_id": node["task"],
                    "slice_id": task["slice"],
                    "checks": checks,
                    "files": snapshot(self.root, task["scope"]),
                }
            )
            if require_pass:
                acceptance_guard(finish_requirements.validate_pass, obligations, result)
            self.source_drifted(state, task, outcome)
            return result

    def finish(self, node_id: str, raw: object) -> None:
        # Runtime facts are derived from current evidence.
        if isinstance(raw, dict):
            raw = {
                key: value
                for key, value in raw.items()
                if key not in {"gate_results", "observed_source_drift"}
            }
        report = parse_report(raw)
        with self.locked():
            s = self.read()
            n = next(n for n in s["graph"]["nodes"] if n["id"] == node_id)
            v, task = s["nodes"][node_id], s["graph"]["tasks"][n["task"]]
            require(v["status"] == "running", "Cannot finish unbound/unknown work")
            require(
                not any(r["node_id"] == node_id for r in self.active_commands(s).values()),
                "Unresolved command result not passed; reconcile execution before finish",
            )
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
            outcome = report["outcome"]
            if outcome == "PASS":
                require(
                    "packet_receipt" not in v or v.get("packet_confirmed"),
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
            findings = report.get("findings", [])
            if outcome == "PASS" and n["stage"] != "review":
                for finding in findings:
                    require(
                        "blocking" in finding,
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
            obligations = self.finish_requirements(s, n)
            acceptance_guard(finish_requirements.validate_selection, obligations, checks)
            if outcome == "PASS":
                acceptance_guard(finish_requirements.validate_pass, obligations, report)
            check_receipts(
                self.root, s, node_id, checks, complete=False, require_pass=outcome == "PASS"
            )
            if outcome == "PASS":
                report["gate_results"] = acceptance_guard(
                    transition_gates.evaluate, s["config"]["_project"]["data"], n, task, report
                )
            if report.get("stage_result") == "APPROVAL_REQUIRED" or "approval_request" in report:
                require("approval_request" in report, "Invalid approval request: field required")
                approval.bind_request(self.root, s, n, task, report)
                validate_graph(approval.expanded_graph(s, n, report), s["config"], self.root)
            acceptance_guard(review_findings.apply, s, n, report)
            if "implement." + n["stage"] in transition_gates.CORE_BOUNDARIES:
                core_gate = transition_gates.stage_result(s, n, report)
                report = {
                    **report,
                    "gate_results": [core_gate, *report.get("gate_results", [])],
                }
            unsuccessful = report.get("unsuccessful_attempt")
            if unsuccessful is not None:
                require(
                    outcome == "FAIL" and report.get("stage_result") in {"FAIL_CODE", "FAIL_TEST"},
                    "Unsuccessful attempt needs actual work, an unmet requirement and evidence",
                )
            report_ref = report_history.store(self.root, s, v, report)
            s.setdefault("report_hashes", {})[report_ref["path"]] = report_ref["sha256"]
            s.setdefault("report_index", {})[v["dispatch_id"]] = report_ref
            v.update(
                {
                    "status": "done" if outcome == "PASS" else "blocked",
                    "report": report,
                    "report_ref": report_ref,
                }
            )
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
            if status not in ("reserved", "running", "blocked"):
                raise Invalid("Invalid reconciliation state")
            if status == "running":
                require(v.get("handle"), "Bind actual handle before claiming running")
            if status == "reserved":
                require(
                    not v.get("prompt_submitted") and not v.get("handle"),
                    "Cannot redispatch an already sent assignment",
                )
            v["status"] = cast(Literal["reserved", "running", "blocked"], status)
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
            validate_assignment_lineage(s["graph"], s["config"], s.get("corrections", []))
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
                    handoffs = TASK_HANDOFFS.validate_json(handoff)
                except ValidationError as exc:
                    raise Invalid(
                        validation_message(
                            "Multi-task replacement needs a JSON task-to-handoff mapping",
                            exc,
                            TASK_HANDOFFS,
                        )
                    ) from None
                require(
                    set(handoffs) == tasks,
                    "Multi-task replacement needs one handoff per assigned task",
                )
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

    def expand_scope(self, task_id: str, paths: list[str], reason: str) -> None:
        with self.locked():
            state = self.read()
            require(task_id in state["graph"]["tasks"], "Unknown task")
            require(paths and reason.strip(), "Need added verification paths and reason")
            graph = deepcopy(state["graph"])
            for path in paths:
                relative(self.root, path)
            task = graph["tasks"][task_id]
            task["scope"] = list(dict.fromkeys([*task["scope"], *paths]))
            for integration in graph["tasks"].values():
                if integration["kind"] == "integration" and task_id in integration.get(
                    "depends_on", []
                ):
                    integration["scope"] = list(dict.fromkeys([*integration["scope"], *paths]))
            self._revise(state, graph, reason)

    def revise(self, graph: Graph | LockedGraph, reason: str) -> None:
        with self.locked():
            self._revise(self.read(), graph, reason)

    def _revise(self, s: State, graph: Graph | LockedGraph, reason: str) -> None:
        require(not s.get("pause_reason"), "Run is paused by user")
        require(
            s["status"] == "active" and reason,
            "Need active run and revision reason",
        )
        require(
            not any(v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()),
            "Quiesce runtime before graph revision",
        )
        require(not self.active_commands(s), "Unresolved project commands")
        check_config(s)
        validate_graph(graph, s["config"], self.root)
        old = s["graph"]
        if graph == old:
            return
        validate_assignment_change(s, graph)
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
        s["graph"] = {**graph, "sources": old["sources"]}
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
                prior_task = old["tasks"][n["task"]]
                current_task = graph["tasks"][n["task"]]
                verify_changed = n["stage"] in {"verify", "review"} and any(
                    prior_task.get(field) != current_task.get(field)
                    for field in ("scope", "required_checks")
                )
                if prev["status"] != "blocked" or (
                    verify_changed
                    and prev.get("report", {}).get("outcome") == "FAIL"
                    and n["task"] not in s.get("escalation_stops", {})
                ):
                    s["nodes"][n["id"]] = {
                        "status": "pending",
                        "attempt": prev["attempt"],
                    }
        self.save(s, "revised", reason=reason, previous_graph=old)

    def reintake(self, graph: Graph | LockedGraph, reason: str, authorization: str) -> None:
        graph = parse_graph(graph)
        with self.locked():
            s = self.read()
            require(not s.get("pause_reason"), "Run is paused by user")
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
            require(not self.active_commands(s), "Unresolved project commands")
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
            new_config["_files"].update(new_policy["files"])
            require(
                freeze_project(new_config, s["graph"], self.root)["_project_documents"]
                == old_config["_project_documents"],
                "Project document drift requires separate reconciliation",
            )
            s["config"] = freeze_project(new_config, graph, self.root)
            check_config(s, graph=graph)
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
            locked_graph: LockedGraph = {**graph, "sources": refreshed_sources}
            validate_graph(locked_graph, s["config"], self.root)
            validate_assignment_change(s, graph)
            for a in s["sessions"]:
                require(
                    graph["agents"].get(a) == s["graph"]["agents"].get(a),
                    "Replace session before role/profile change",
                )
            previous, previous_nodes = s["graph"], s["nodes"]
            s["graph"], s["revision"] = locked_graph, s["revision"] + 1
            s["nodes"] = {
                n["id"]: (
                    previous_nodes[n["id"]]
                    if n["id"] in previous_nodes and previous_nodes[n["id"]]["status"] == "blocked"
                    else {
                        "status": "pending",
                        "attempt": previous_nodes[n["id"]]["attempt"]
                        if n["id"] in previous_nodes
                        else 0,
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
            require(not s.get("pause_reason"), "Run is paused by user")
            nodes = {n["id"]: n for n in s["graph"]["nodes"]}
            n, v = nodes[node_id], s["nodes"][node_id]
            require(terminal_evidence and reason, "Reconcile old writer and explain retry")
            require(not self.active_commands(s), "Unresolved project commands")
            require(
                v["status"] in {"blocked", "unknown", "done"},
                "Cannot retry a live writer",
            )
            limits = escalation.limits(s, n["task"])
            profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
            acceptance_guard(escalation.guard, s, n["task"])
            require(
                stage == "recovery" or not profile.get("escalation"),
                "Use correct for an escalating profile's quality decision",
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
            require(not state.get("pause_reason"), "Run is paused by user")
            require(not self.active_commands(state), "Unresolved project commands")
            check_config(state)
            return acceptance_guard(escalation.correct, self, state, node_id, request)

    def resume_task(self, task_id: str, evidence: str) -> None:
        with self.locked():
            state = self.read()
            require(
                state["status"] == "active" and evidence.strip(),
                "Need active run and resolved blocker/human decision",
            )
            require(not state.get("pause_reason"), "Run is paused by user")
            require(not self.active_commands(state), "Unresolved project commands")
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
            require(not state.get("pause_reason"), "Run is paused by user")
            require(not self.active_commands(state), "Unresolved project commands")
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

    def acceptance_task(self, s: State, nodes: dict[str, Node], node_id: str) -> Task:
        require(s["status"] == "active", "Run is not active")
        require(not s.get("pause_reason"), "Run is paused by user")
        n = nodes[node_id]
        require(n["stage"] == "accept", "Not an acceptance node")
        acceptance_guard(escalation.guard, s, n["task"])
        require(not self.active_commands(s), "Unresolved project commands")
        require(s["nodes"][node_id]["status"] == "pending", "Already accepted")
        require(
            all(s["nodes"][k]["status"] == "done" for k in ancestors(nodes, node_id)),
            "Required work not done",
        )
        task = s["graph"]["tasks"][n["task"]]
        self.check_sources(s, task)
        for key in ancestors(nodes, node_id):
            predecessor = nodes[key]
            if predecessor["task"] != n["task"]:
                continue
            report = s["nodes"][key].get("report")
            if predecessor["stage"] in {"verify", "review"}:
                if report is None:
                    raise Invalid(f"Missing verification report: {key}")
                self.check_current_verification(
                    s, predecessor, report, "Evidence invalidated by later write"
                )
            check_generated(self.root, s, key, report["checks"] if report else [])
        acceptance_guard(
            review_findings.gate,
            s,
            n["task"],
            snapshot(self.root, task["scope"]),
            s["graph"]["sources"][task["source"]]["hash"],
        )
        return task

    def accept(self, node_id: str) -> None:
        with self.locked():
            s = self.read()
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            n = nodes[node_id]
            task = self.acceptance_task(s, nodes, node_id)
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

    def check_current_verification(
        self, state: State, node: Node, report: Report, stale_message: str
    ) -> None:
        task = state["graph"]["tasks"][node["task"]]
        obligations = self.finish_requirements(state, node)
        acceptance_guard(finish_requirements.validate_pass, obligations, report)
        check_receipts(self.root, state, node["id"], report.get("checks", []), complete=False)
        require(report["files"] == snapshot(self.root, task["scope"]), stale_message)
        acceptance_guard(
            transition_gates.evaluate, state["config"]["_project"]["data"], node, task, report
        )

    def check_completion(self, s: State) -> None:
        require(not s.get("pause_reason"), "Run is paused by user")
        require(not self.active_commands(s), "Unresolved project commands")
        check_config(s)
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
            report = s["nodes"][n["id"]].get("report", {})
            check_generated(self.root, s, n["id"], report.get("checks", []))
            task = s["graph"]["tasks"][n["task"]]
            self.check_sources(s, task)
            current_final = len(s["graph"]["tasks"]) == 1 or task["kind"] == "integration"
            if current_final and n["stage"] in {"verify", "review"}:
                self.check_current_verification(
                    s, n, s["nodes"][n["id"]]["report"], "Final evidence stale"
                )

    def archive(self, outcome: str, summary: str) -> str:
        with self.locked():
            s = self.read()
            if outcome not in ("completed", "cancelled"):
                raise Invalid("Only terminal runs can be archived")
            require(summary, "Final summary required")
            require(not self.active_commands(s), "Unresolved project commands")
            if s["status"] in {"completed", "cancelled"}:
                require(
                    s["status"] == outcome and s["summary"] == summary,
                    "Terminal history is immutable",
                )
                run_archive.verified_cleanup_paths(self.root, s)
                return str(relative(self.root, s["archive_path"]))
            require(
                not any(
                    v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()
                ),
                "Outstanding runtime work",
            )
            if outcome == "completed":
                self.check_completion(s)
            s["status"], s["summary"] = cast(Literal["completed", "cancelled"], outcome), summary
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
            require("archive_path" in s, "Archive required before cleanup")
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
