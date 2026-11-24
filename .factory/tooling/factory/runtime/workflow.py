#!/usr/bin/env python3
"""Validated run ledger for an agent-driven workflow. Does not call a model."""

from __future__ import annotations

import time
import uuid
from contextlib import nullcontext
from typing import Any, Literal, cast, overload

from pydantic import ConfigDict, TypeAdapter, ValidationError

from factory.decisions.decision_contract import (
    preserve_obligations as preserve_obligations,
)
from factory.diagnostics.events import event as log_event
from factory.paths import FACTORY_ROOT as FACTORY_ROOT
from factory.project.profile_io import check_frozen
from factory.project.profile_rules import boundary_gates as boundary_gates
from factory.project.profile_rules import project_checks as project_checks
from factory.runtime import teacher, workflow_query
from factory.runtime.commands import evidence as check_evidence
from factory.runtime.commands.evidence import check_generated, check_receipts
from factory.runtime.commands.process import execute_check as execute_check
from factory.runtime.contracts import (
    CommandResult,
    CorrectionRecord,
    LockedGraph,
    Nonblank,
    PendingCheck,
    Report,
    ReportDraft,
    RetroNote,
)
from factory.runtime.contracts import Config as Config
from factory.runtime.contracts import Dispatch as Dispatch
from factory.runtime.contracts import ExecutionReceipt as ExecutionReceipt
from factory.runtime.contracts import Graph as Graph
from factory.runtime.contracts import Node as Node
from factory.runtime.contracts import State as State
from factory.runtime.contracts import agent_key as agent_key
from factory.runtime.history import report_history
from factory.runtime.observability import acpx_usage as telemetry
from factory.runtime.reports import acceptance as acceptance
from factory.runtime.reports import approval, finish_requirements
from factory.runtime.reports import review_findings as review_findings
from factory.runtime.reports import transition_gates as transition_gates
from factory.runtime.run_journal import LEDGER_EVENT as LEDGER_EVENT
from factory.runtime.run_journal import RunJournal
from factory.runtime.scheduling import dispatch
from factory.runtime.scheduling import escalation as escalation
from factory.runtime.scheduling.assignment import implement_packet as implement_packet
from factory.runtime.scheduling.claim_policy import check_contention
from factory.runtime.scheduling.escalation_policy import RetryBudget
from factory.runtime.scheduling.run_sessions import RunSessions
from factory.runtime.transitions import checks, packets, reports, revisions
from factory.runtime.transitions.revisions import (
    has_prior_dispatch_evidence as has_prior_dispatch_evidence,
)
from factory.runtime.transitions.revisions import (
    preserve_task_guards as preserve_task_guards,
)
from factory.runtime.transitions.revisions import (
    validate_assignment_change as validate_assignment_change,
)
from factory.runtime.transport import evidence as transport_evidence
from factory.runtime.workflow_config import (
    check_capabilities as check_capabilities,
)
from factory.runtime.workflow_config import check_config as check_config
from factory.runtime.workflow_config import freeze_project as freeze_project
from factory.runtime.workflow_config import load_config as load_config
from factory.runtime.workflow_config import pool as pool
from factory.runtime.workflow_config import reconcile_source_documents
from factory.runtime.workflow_core import Invalid as Invalid
from factory.runtime.workflow_core import acceptance_guard as acceptance_guard
from factory.runtime.workflow_core import atomic_json as atomic_json
from factory.runtime.workflow_core import digest as digest
from factory.runtime.workflow_core import read_json as read_json
from factory.runtime.workflow_core import relative as relative
from factory.runtime.workflow_core import require as require
from factory.runtime.workflow_core import snapshot as snapshot
from factory.runtime.workflow_graph import ancestors as ancestors
from factory.runtime.workflow_graph import diagram as diagram
from factory.runtime.workflow_graph import (
    expand_intake_checks,
    parse_graph,
    validate_assignment_lineage,
)
from factory.runtime.workflow_graph import overlaps as overlaps
from factory.runtime.workflow_graph import validate_graph as validate_graph
from factory.runtime.workflow_sources import lock_source as lock_source
from factory.runtime.workspace import check_workspace, checkout_ref
from factory.tasks.contracts import Task as Task
from factory.validation import validation_message

_NO_CONFIG_PIN = object()

TASK_HANDOFFS = TypeAdapter[dict[str, str]](dict[str, Nonblank], config=ConfigDict(strict=True))


class Ledger(RunJournal):
    """Public workflow commands for one checkout."""

    def init(
        self,
        graph: Graph,
        config: Config,
        *,
        config_pin: object = _NO_CONFIG_PIN,
    ) -> State:
        if config_pin is not _NO_CONFIG_PIN:
            require(
                isinstance(config_pin, dict)
                and config_pin.get("ok") is True
                and isinstance(config_pin.get("result"), dict)
                and config_pin["result"].get("_path") == config["_path"]
                and config_pin["result"].get("_files") == config["_files"],
                "Config/instructions changed since snapshot; reload instructions",
            )
        check_workspace(self.root, config)
        input_graph = graph
        graph = expand_intake_checks(graph, config)
        validate_graph(graph, config, self.root)
        validate_assignment_lineage(graph, config)
        acceptance_guard(check_frozen, config["_files"])
        config = freeze_project(config, graph, self.root)
        for task in graph["tasks"].values():
            for p in task["scope"]:
                relative(self.root, p)
        for node in graph["nodes"]:
            for p in node.get("owns", []):
                relative(self.root, p)
        with self.locked():
            require(
                not self.runs.has_current(self.root),
                "Existing run: resume or archive/clean it first",
            )
            locked_graph: LockedGraph = {
                **graph,
                "sources": {k: lock_source(self.root, src) for k, src in graph["sources"].items()},
            }
            reconcile_source_documents(config, self.root, locked_graph["sources"])
            state: State = {
                "lesson_run_checkout": checkout_ref(self.root),
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
        return packets.packet(self, node_id)

    def prepare_packet(self, node_id: str, *, with_diagnostics: bool = False) -> dict[str, Any]:
        return packets.prepare_packet(self, node_id, with_diagnostics=with_diagnostics)

    def packet_dispatch(
        self, s: State, node_id: str, *, runner: str = "native"
    ) -> tuple[Node, Dispatch]:
        return packets.packet_dispatch(self, s, node_id, runner=runner)

    def read_packet(
        self,
        node_id: str,
        bootstrap: object,
        chunk: int,
        received: str | None = None,
        *,
        recipient: str | None = None,
    ) -> dict[str, Any]:
        return packets.read_packet(self, node_id, bootstrap, chunk, received, recipient=recipient)

    @staticmethod
    def packet_recipient(dispatch: Dispatch, recipient: str | None) -> str:
        return packets.packet_recipient(dispatch, recipient)

    def confirm_packet(
        self,
        node_id: str,
        bootstrap: object,
        received: str = "",
        materials: str = "",
        *,
        recipient: str | None = None,
    ) -> None:
        packets.confirm_packet(self, node_id, bootstrap, received, materials, recipient=recipient)

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
                self.save(state, "result_acknowledged", node=node_id, dispatch_id=dispatch_id)

    def next_actions(self, after: str | None = None) -> dict[str, Any]:
        with self.locked():
            return workflow_query.next_actions(self, self.read(), after, jobs=self.jobs)

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
        check_contention(s, nodes, n, p, has_active_commands=bool(self.active_commands(s)))
        return p

    def claim(self, node_id: str, *, dry_run: bool = False) -> dict[str, object]:
        with nullcontext() if dry_run else self.locked():
            s = self.read()
            require(s["status"] == "active", "Run is not active")
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            validate_assignment_lineage(s["graph"], s["config"], s.get("corrections", []))
            n, current = nodes[node_id], s["nodes"][node_id]
            p = self.claim_pool(s, nodes, node_id)
            profile_id = s["graph"]["agents"][agent_key(n)]["profile"]
            assignment = report_history.assignment(s, n, self.finish_requirements(s, n))
            if dry_run:
                return {
                    "dry_run": True,
                    "run_id": s["run_id"],
                    "node_id": node_id,
                    "profile": profile_id,
                    "pool": p,
                    "attempt": current["attempt"] + 1,
                    "current_status": current["status"],
                    "planned_status": "reserved",
                }
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
            current["assignment"] = assignment
            self.save(
                s,
                "reserved",
                node=node_id,
                dispatch_id=current["dispatch_id"],
                role=current["role"],
                harness=s["config"]["profiles"][profile_id].get("harness"),
            )
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
            aid = agent_key(n)
            profile = s["config"]["profiles"][s["graph"]["agents"][aid]["profile"]]
            expected_model = s["config"]["models"][profile["model"]].get("id")
            RunSessions(s).bind(aid, handle, model, expected_model=expected_model)
            v.update({"status": "running", "handle": handle})
            self.save(
                s, "bound", node=node_id, dispatch_id=v["dispatch_id"], handle=handle, model=model
            )

    @overload
    def run_check(
        self,
        node_id: str,
        check_id: str,
        request_id: str | None = None,
        *,
        expected_dispatch: str | None = None,
        dry_run: Literal[False] = False,
    ) -> CommandResult | PendingCheck: ...

    @overload
    def run_check(
        self,
        node_id: str,
        check_id: str,
        request_id: str | None = None,
        *,
        expected_dispatch: str | None = None,
        dry_run: bool,
    ) -> CommandResult | PendingCheck | dict[str, object]: ...

    def run_check(
        self,
        node_id: str,
        check_id: str,
        request_id: str | None = None,
        *,
        expected_dispatch: str | None = None,
        dry_run: bool = False,
    ) -> CommandResult | PendingCheck | dict[str, object]:
        return checks.run_check(
            self,
            node_id,
            check_id,
            request_id,
            expected_dispatch=expected_dispatch,
            dry_run=dry_run,
        )

    @staticmethod
    def active_commands(state: State) -> dict[str, ExecutionReceipt]:
        return check_evidence.active_commands(state)

    def reconcile_check(
        self, rid: str, abandon_unstarted: bool = False
    ) -> CommandResult | PendingCheck:
        return checks.reconcile_check(self, rid, abandon_unstarted)

    def check_results(self, rid: str) -> list[CommandResult]:
        return checks.check_results(self, rid)

    def finish_requirements(
        self, state: State, node: Node
    ) -> finish_requirements.FinishRequirements:
        return finish_requirements.for_node(state, node)

    @staticmethod
    def report_scope(
        node: Node, task: Task, report: Report | ReportDraft, deferred_writer: bool
    ) -> list[str]:
        return reports.report_scope(node, task, report, deferred_writer)

    def prepare_report(self, node_id: str, draft: object, receipt_ids: list[str]) -> Report:
        return reports.prepare_report(self, node_id, draft, receipt_ids)

    def finish(self, node_id: str, raw: object) -> None:
        # Runtime facts are derived from current evidence.
        reports.finish(self, node_id, raw)

    def unknown(self, node_id: str, reason: str) -> None:
        with self.locked():
            s = self.read()
            dispatch.mark_unknown(s["nodes"][node_id], reason)
            self.save(s, "unknown", node=node_id, reason=reason)

    def resolve(self, node_id: str, status: str, evidence: str) -> None:
        with self.locked():
            s = self.read()
            v = s["nodes"][node_id]
            dispatch.reconcile(v, status, evidence)
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
            previous = RunSessions(s).replace(agent_id)
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
        revisions.expand_scope(self, task_id, paths, reason)

    def revise(
        self,
        graph: Graph | LockedGraph,
        reason: str,
        *,
        retry_tests: tuple[str, str, str, str] | None = None,
    ) -> None:
        revisions.revise(self, graph, reason, retry_tests=retry_tests)

    def reintake(
        self,
        graph: Graph | LockedGraph,
        reason: str,
        authorization: str,
        *,
        documents: list[str] | None = None,
    ) -> None:
        revisions.reintake(self, graph, reason, authorization, documents=documents)

    def retry(
        self,
        node_id: str,
        stage: str,
        reason: str,
        terminal_evidence: str,
        *,
        dry_run: bool = False,
    ) -> dict[str, object] | None:
        with nullcontext() if dry_run else self.locked():
            s = self.read()
            require(
                s["status"] == "active", "Terminal run is immutable; start a new authorized run"
            )
            require(not s.get("pause_reason"), "Run is paused by user")
            nodes = {n["id"]: n for n in s["graph"]["nodes"]}
            n, v = nodes[node_id], s["nodes"][node_id]
            require(terminal_evidence and reason, "Reconcile old writer and explain retry")
            require(not self.active_commands(s), "Unresolved project commands")
            require(
                v["status"] in {"blocked", "unknown", "done"},
                "Cannot retry a live writer",
            )
            profile = s["config"]["profiles"][s["graph"]["agents"][agent_key(n)]["profile"]]
            acceptance_guard(escalation.guard, s, n["task"])
            require(
                stage == "recovery" or not profile.get("escalation"),
                "Use correct for an escalating profile's quality decision",
            )
            budget = RetryBudget.for_task(s, n["task"], stage)
            budget.require_available()
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
            if dry_run:
                return {
                    "dry_run": True,
                    "run_id": s["run_id"],
                    "node_id": node_id,
                    "stage": stage,
                    "reason": reason,
                    "terminal_evidence": terminal_evidence,
                    "budget": {
                        "key": budget.key,
                        "used": budget.used,
                        "limit": budget.limit,
                        "planned_used": budget.used + 1,
                    },
                    "affected": {
                        key: {
                            "dispatch_id": s["nodes"][key].get("dispatch_id"),
                            "current_status": s["nodes"][key]["status"],
                            "planned_status": "pending",
                        }
                        for key in sorted(affected)
                    },
                }
            budget.spend()
            for k in sorted(affected):
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
        return None

    def correct(self, node_id: str, request: object) -> CorrectionRecord:
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
            budget = RetryBudget.for_task(state, task_id, stage)
            budget.require_available("Budget exhausted; resume cannot reset limits")
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
            budget.spend()
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
            self.save(s, "accepted", node=node_id, **teacher.acceptance_details(self.root, s, n))

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

    def check_completion(
        self, s: State, *, config_error: str | None = None, config_checked: bool = False
    ) -> None:
        require(not s.get("pause_reason"), "Run is paused by user")
        require(not self.active_commands(s), "Unresolved project commands")
        if config_error is not None:
            raise Invalid(config_error)
        if not config_checked:
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

    def record_retro(self, run_id: str, incident: str, source: str, observation: str) -> None:
        with self.locked():
            state = self.read()
            require(
                state["run_id"] == run_id and state["status"] == "active", "Need the active run"
            )
            require(
                state["lesson_run_checkout"] == checkout_ref(self.root),
                "Need the run-level Teacher checkout",
            )
            note: RetroNote = {"source": source, "observation": observation}
            if not any(
                event.get("lesson_incident") == incident and event.get("lesson_retro") == note
                for event in state["events"]
            ):
                self.save(state, "retro_recorded", lesson_incident=incident, lesson_retro=note)

    def archive(
        self,
        outcome: str,
        summary: str,
        *,
        probe: telemetry.SessionProbe | None = None,
    ) -> str:
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
                self.runs.cleanup_paths(self.root, s)
                return self.runs.reference(
                    self.root, s["run_id"], stored_source=s["archive_path"]
                ).location
            require(
                not any(
                    v["status"] in {"reserved", "running", "unknown"} for v in s["nodes"].values()
                ),
                "Outstanding runtime work",
            )
            if outcome == "completed":
                self.check_completion(s)
            s["status"], s["summary"] = cast(Literal["completed", "cancelled"], outcome), summary
            return self._save_terminal_archive(s, probe)

    def _save_terminal_archive(self, state: State, probe: telemetry.SessionProbe | None) -> str:
        archive = self.runs.reference(self.root, state["run_id"])
        state["archive_path"] = archive.source
        pending = transport_evidence.pending_transports(self.root, state)
        review = teacher.run_review_event(state)
        if review is not None:
            state["final_teacher_event"] = review.key()
        usage = telemetry.collect(state, probe=probe)
        state["events"].append({"event": "archived", "at": time.time()})
        self.runs.commit_archive(self.root, state, usage, pending, review)
        log_event("archived", run_id=state["run_id"], outcome=state["status"])
        return archive.location

    def clean(self) -> None:
        with self.locked():
            s = self.read()
            require(s["status"] in {"completed", "cancelled"}, "Keep resumable state")
            require("archive_path" in s, "Archive required before cleanup")
            paths = self.runs.cleanup_paths(self.root, s)
            for path in paths:
                path.unlink(missing_ok=True)
            folder = relative(self.root, f".factory/memory/history/{s['run_id']}")
            parents = {
                directory
                for path in paths
                for directory in path.parents
                if directory.is_relative_to(folder)
            }
            for directory in sorted(parents, reverse=True):
                if directory.is_dir() and not any(directory.iterdir()):
                    directory.rmdir()
            self.runs.release_current(self.root, s["run_id"])
