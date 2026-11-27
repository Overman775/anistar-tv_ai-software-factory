#!/usr/bin/env python3
"""Validated run ledger for an agent-driven workflow. Does not call a model."""

from __future__ import annotations

import uuid
from contextlib import nullcontext
from pathlib import Path
from typing import Any, Literal, overload

from pydantic import ConfigDict, TypeAdapter, ValidationError

from factory.decisions.decision_contract import (
    preserve_obligations as preserve_obligations,
)
from factory.graphs.definition import load as load_definitions
from factory.graphs.definition import parse
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
from factory.runtime.reports import finish_requirements, write_handoff
from factory.runtime.reports import review_findings as review_findings
from factory.runtime.reports import transition_gates as transition_gates
from factory.runtime.run_journal import LEDGER_EVENT as LEDGER_EVENT
from factory.runtime.run_journal import RunJournal
from factory.runtime.scheduling import dispatch, intake, lifecycle_graph, recovery_graph
from factory.runtime.scheduling import escalation as escalation
from factory.runtime.scheduling.assignment import implement_packet as implement_packet
from factory.runtime.scheduling.attempt_graph import advance
from factory.runtime.scheduling.orchestrator_graph import (
    Accept,
    Assign,
    Checkpoint,
    Hold,
    assignment_ticket,
    orchestrator_graph,
)
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
from factory.runtime.transport.evidence import pending_transports
from factory.runtime.workflow_config import (
    check_capabilities as check_capabilities,
)
from factory.runtime.workflow_config import check_config as check_config
from factory.runtime.workflow_config import freeze_project as freeze_project
from factory.runtime.workflow_config import load_config as load_config
from factory.runtime.workflow_config import pool as pool
from factory.runtime.workflow_config import reconcile_source_documents, verify_instruction_pin
from factory.runtime.workflow_core import Invalid as Invalid
from factory.runtime.workflow_core import acceptance_guard as acceptance_guard
from factory.runtime.workflow_core import digest as digest
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

TASK_HANDOFFS = TypeAdapter[dict[str, str]](dict[str, Nonblank], config=ConfigDict(strict=True))


class Ledger(RunJournal):
    """Public workflow commands for one checkout."""

    def init(
        self,
        graph: Graph,
        config: Config,
        *,
        config_pin: str | None = None,
    ) -> State:
        if config_pin is not None:
            verify_instruction_pin(config, config_pin)
        check_workspace(self.root, config)
        definitions = load_definitions(Path(config["_path"]).parent / "graphs", "implement")
        orchestrator_graph(definitions)
        write_handoff.assignment_program(tuple(sorted(definitions.items())))
        role = parse("implement", definitions["implement"]).assignments.get("teacher")
        require(role is not None, "Implement needs a Teacher assignment binding")
        assert role is not None
        teacher.validate_delivery(role, teacher.teacher_definitions(definitions, role))
        input_graph = graph
        graph = expand_intake_checks(graph, config)
        intake.configure(graph, config, definitions)
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
            if any(
                "decomposition_run" in source or source["kind"] == "factory_decompose_task"
                for source in locked_graph["sources"].values()
            ):
                validate_graph(locked_graph, config, self.root)
            state: State = {
                "definitions": definitions,
                "contract_baseline": snapshot(
                    self.root,
                    sorted(
                        {
                            path
                            for interface, docs in config["_project"]["data"]
                            .get("public_contracts", {})
                            .items()
                            for path in (interface, *docs)
                        }
                    ),
                ),
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
                "handle_owners": {},
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
        lifecycle_graph.set_paused(self, reason)

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

    def claim(
        self, node_id: str, *, ticket: str | None = None, dry_run: bool = False
    ) -> dict[str, object]:
        with nullcontext() if dry_run else self.locked(wait=True):
            s = self.read()
            require(s["status"] == "active", "Run is not active")
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            validate_assignment_lineage(s["graph"], s["config"], s.get("corrections", []))
            n, current = nodes[node_id], s["nodes"][node_id]
            if ticket and ticket == current.get("dispatch_id"):
                return {
                    "run_id": s["run_id"],
                    "node_id": node_id,
                    "dispatch_id": ticket,
                    "status": current["status"],
                    "replayed": True,
                    "action": "reconcile",
                }
            checkpoint = Checkpoint(s, nodes, self)
            permit = checkpoint.evaluate([node_id])[node_id]
            if isinstance(permit, Hold):
                if current["status"] != "pending":
                    raise Invalid(f"Already dispatched or unresolved: {permit.reason}")
                raise Invalid(permit.reason)
            require(n["stage"] != "accept", "Use accept for orchestrator node")
            if not isinstance(permit, Assign):
                raise Invalid("Already dispatched or unresolved; never redispatch blindly")
            p, profile_id = permit.pool, permit.profile
            expected = assignment_ticket(
                s["run_id"], s["revision"], node_id, current["attempt"] + 1
            )
            require(
                (dry_run and ticket is None) or expected == ticket,
                "Missing or stale assignment ticket; read workflow status",
            )
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
                    "ticket": expected,
                }
            current.update(
                {
                    "status": advance(current, "claim"),
                    "dispatch_id": expected,
                    "pool": p,
                    "profile": profile_id,
                    "role": s["graph"]["agents"][agent_key(n)]["role"],
                    "attempt": current["attempt"] + 1,
                }
            )
            current["assignment"] = assignment
            if current["role"] == "implementer" and current["attempt"] == 1 and n.get("owns"):
                current["initial_owned_files"] = snapshot(
                    self.root,
                    [
                        path
                        for path in s["graph"]["tasks"][n["task"]]["scope"]
                        if overlaps([path], n["owns"])
                    ],
                )
            if current["role"] == "doc-writer" and n.get("owns"):
                current["document_baseline"] = snapshot(self.root, n["owns"])
            self.save(
                s,
                "reserved",
                route=checkpoint.paths[node_id],
                node=node_id,
                dispatch_id=current["dispatch_id"],
                role=current["role"],
                harness=s["config"]["profiles"][profile_id].get("harness"),
            )
            return {
                "run_id": s["run_id"],
                "node": n,
                "dispatch": current,
                "delivery": {
                    "action": permit.action,
                    "runner": permit.runner,
                    "handle": permit.handle,
                    "dispatch_id": expected,
                },
                "profile": s["config"]["profiles"][profile_id],
            }

    def bind(
        self, node_id: str, handle: str, model: str, *, expected_dispatch: str | None = None
    ) -> None:
        with self.locked():
            s = self.read()
            n = next(n for n in s["graph"]["nodes"] if n["id"] == node_id)
            v = s["nodes"][node_id]
            require(
                expected_dispatch is None or expected_dispatch == v.get("dispatch_id"),
                "Stale session binding",
            )
            require(v["status"] == "reserved", "Bind only a reserved dispatch")
            dispatch = v.get("dispatch_id")
            if dispatch is not None:
                self.diagnostic_attempt = (node_id, dispatch)
            aid = agent_key(n)
            profile = s["config"]["profiles"][s["graph"]["agents"][aid]["profile"]]
            expected_model = s["config"]["models"][profile["model"]].get("id")
            RunSessions(s).bind(aid, handle, model, expected_model=expected_model)
            v.update({"status": advance(v, "bind"), "handle": handle})
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

    def prepare_report(
        self, node_id: str, draft: object, receipt_ids: list[str], *, submit: bool = False
    ) -> Report:
        return reports.prepare_report(self, node_id, draft, receipt_ids, submit=submit)

    def finish(self, node_id: str, raw: object) -> None:
        # Runtime facts are derived from current evidence.
        reports.finish(self, node_id, raw)

    def unknown(self, node_id: str, reason: str, *, expected_dispatch: str | None = None) -> None:
        with self.locked():
            s = self.read()
            dispatch.check_identity(s["nodes"][node_id], expected_dispatch)
            dispatch.mark_unknown(s["nodes"][node_id], reason)
            self.save(s, "unknown", node=node_id, reason=reason)

    def resolve(
        self, node_id: str, status: str, evidence: str, *, expected_dispatch: str | None = None
    ) -> None:
        with self.locked():
            s = self.read()
            v = s["nodes"][node_id]
            dispatch.check_identity(v, expected_dispatch)
            if status in {"blocked", "reserved"} and "dispatch_id" in v:
                pending_transports(self.root, s, dispatch_id=v["dispatch_id"], mutating_only=True)
            dispatch.reconcile(v, status, evidence)
            self.save(s, "reconciled", node=node_id, status=status, evidence=evidence)

    def replace_session(
        self, agent_id: str, reason: str, terminal_evidence: str, handoff: str | dict[str, str]
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
            if isinstance(handoff, str):
                require(
                    len(tasks) == 1, "Multi-task replacement needs one handoff per assigned task"
                )
                handoff = {next(iter(tasks)): handoff}
            try:
                handoffs = TASK_HANDOFFS.validate_python(handoff)
            except ValidationError as exc:
                raise Invalid(
                    validation_message("Invalid task handoff", exc, TASK_HANDOFFS)
                ) from None
            require(set(handoffs) == tasks, "Replacement needs one handoff per assigned task")
            previous = RunSessions(s).replace(agent_id)
            self.save(
                s,
                "session_replaced",
                agent=agent_id,
                previous=previous,
                reason=reason,
                terminal_evidence=terminal_evidence,
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
        expected_dispatch: str | None = None,
        evidence_dispatch: str | None = None,
    ) -> dict[str, object] | None:
        with nullcontext() if dry_run else self.locked():
            return recovery_graph.execute(
                self,
                self.read(),
                recovery_graph.Retry(
                    node_id,
                    stage,
                    reason,
                    terminal_evidence,
                    dry_run,
                    expected_dispatch,
                    evidence_dispatch,
                ),
            )

    def correct(self, node_id: str, request: object) -> CorrectionRecord:
        with self.locked():
            state = self.read()
            require(state["status"] == "active", "Run is not active")
            require(not state.get("pause_reason"), "Run is paused by user")
            require(not self.active_commands(state), "Unresolved project commands")
            check_config(state)
            return acceptance_guard(escalation.correct, self, state, node_id, request)

    def resume_task(self, task_id: str, evidence: str, *, stop_id: str | None = None) -> None:
        with self.locked():
            recovery_graph.execute(
                self, self.read(), recovery_graph.ResumeTask(task_id, evidence, stop_id)
            )

    def resume_approved(self, node_id: str, request_id: str, evidence: str) -> None:
        with self.locked():
            recovery_graph.execute(
                self, self.read(), recovery_graph.ResumeApproval(node_id, request_id, evidence)
            )

    def accept(self, node_id: str) -> None:
        with self.locked():
            s = self.read()
            check_config(s)
            nodes = validate_graph(s["graph"], s["config"], self.root)
            n = nodes[node_id]
            require(n["stage"] == "accept", "Not an acceptance node")
            validate_assignment_lineage(s["graph"], s["config"], s.get("corrections", []))
            checkpoint = Checkpoint(s, nodes, self)
            permit = checkpoint.evaluate([node_id])[node_id]
            if isinstance(permit, Hold):
                raise Invalid(permit.reason)
            if not isinstance(permit, Accept):
                raise Invalid("Already accepted")
            task = permit.task
            s["nodes"][node_id]["gate_result"] = transition_gates.stage_result(
                s,
                n,
                {
                    "outcome": "PASS",
                    "summary": "All current acceptance obligations passed",
                    "files": snapshot(self.root, task["scope"]),
                },
            )
            s["nodes"][node_id]["status"] = advance(s["nodes"][node_id], "accept")
            self.save(
                s,
                "accepted",
                node=node_id,
                route=checkpoint.paths[node_id],
                **teacher.acceptance_details(self.root, s, n),
            )

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
        return lifecycle_graph.archive(self, outcome, summary, probe)

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
