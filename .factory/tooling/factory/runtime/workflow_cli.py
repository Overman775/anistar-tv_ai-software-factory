"""Command-line interface for the workflow ledger."""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

from factory.context.context import accepted_bytes, accepted_path
from factory.database.provider import current_database
from factory.database.sqlite.workflow_db import read_only
from factory.diagnostics.events import event
from factory.diagnostics.query import read_journal
from factory.diagnostics.records import error_code
from factory.graphs.definition import load as load_definitions
from factory.logging_config import diagnostic_operation, finish, initialize
from factory.paths import FACTORY_ROOT
from factory.project.profile_io import material_entries
from factory.runtime import workflow_query
from factory.runtime.contracts import RoleMaterial, WriteOffer
from factory.runtime.knowledge.case_search import CaseIndex
from factory.runtime.packets.content import packet_response
from factory.runtime.reports import role_material, write_handoff
from factory.runtime.scheduling import intake
from factory.runtime.scheduling.orchestrator_graph import orchestrator_graph
from factory.runtime.state_io import parse_report
from factory.runtime.transitions.revisions import TestRetryRequest
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_config import (
    check_config,
    instruction_pin,
    load_config,
    verify_instruction_pin,
)
from factory.runtime.workflow_core import Invalid, digest, graph_identity, require
from factory.runtime.workflow_graph import (
    diagram,
    execution_graph,
    expand_intake_checks,
    validate_assignment_lineage,
    validate_graph,
)
from factory.runtime.workflow_sources import SOURCE, lock_source
from factory.runtime.workspace import check_workspace, prepare_workspace


def build_parser(
    parser: argparse.ArgumentParser | None = None, *, checks: bool = False
) -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__) if parser is None else parser
    p.add_argument("--workspace", default=".")
    p.add_argument("--config", default=str(FACTORY_ROOT / "factory.yaml"))
    sub = p.add_subparsers(dest="action", metavar="COMMAND", title="commands", required=True)

    def command(
        name: str,
        dispatch: Callable[[argparse.Namespace, Ledger], tuple[bool, object]],
        **options: Any,
    ) -> argparse.ArgumentParser:
        parser = sub.add_parser(name, **options)
        parser.set_defaults(command_handler=dispatch)
        return parser

    if checks:
        check = command("run", _dispatch_packets_checks, help="Run a registered check")
        check.set_defaults(action="run-check")
        check.add_argument("node")
        check.add_argument("check_id")
        check.add_argument(
            "--request", required=True, help="Stable request ID; reuse it after a lost response"
        )
        check.add_argument(
            "--dispatch", required=True, help="Dispatch ID from the bound worker packet"
        )
        check.add_argument("--dry-run", action="store_true", help="Preview the registered stages")
        results = command("results", _dispatch_packets_checks, help="Read finished check receipts")
        results.set_defaults(action="check-results")
        results.add_argument("execution_id")
        reconciled = command("reconcile", _dispatch_packets_checks, help="Recover a check result")
        reconciled.set_defaults(action="reconcile-check")
        reconciled.add_argument("execution_id")
        reconciled.add_argument(
            "--abandon-unstarted",
            action="store_true",
            help="Abandon a pending intent only if no process owner ever registered",
        )
        return p

    diagnostic = sub.add_parser("diagnostics")
    selectors = diagnostic.add_mutually_exclusive_group(required=True)
    selectors.add_argument("--invocation")
    selectors.add_argument("--run")
    selectors.add_argument("--dispatch")
    selectors.add_argument("--operation", help="Recent events for one diagnostic operation")
    diagnostic.add_argument("--cursor", type=int, default=0)
    diagnostic.add_argument("--limit", type=int, default=30)
    command("config", _dispatch_setup)
    workspace = sub.add_parser("prepare-workspace")
    workspace.add_argument("--dry-run", action="store_true", help="Preview workspace selection")
    instructions = command("read-instructions", _dispatch_setup)
    instructions.add_argument(
        "pin", help="Instruction pin from workflow config, or - for the active run"
    )
    instructions.add_argument("paths", nargs="+")
    command("read-project", _dispatch_setup)
    for name in ("validate", "init"):
        parser = command(name, _dispatch_setup)
        parser.add_argument(
            "graph", help="Content ID returned by graph_inputs.propose in this workspace"
        )
        if name == "init":
            parser.add_argument(
                "--config-pin", help="Instruction pin obtained before reading factory instructions"
            )
    corr = command("correct", _dispatch_workflow)
    corr.add_argument("node")
    corr.add_argument("decision")
    resume = command("resume-task", _dispatch_workflow)
    resume.add_argument("task")
    resume.add_argument("evidence")
    resume.add_argument("--stop", required=True, help="Current stop ID from workflow status")
    approved = command("resume-approved", _dispatch_workflow)
    approved.add_argument("node")
    approved.add_argument("request_id")
    approved.add_argument("evidence")
    explain = command("explain", _dispatch_workflow, help="Read evidence for one dispatch")
    explain.add_argument("node")
    explain.add_argument("--dispatch", required=True)
    explain.add_argument("--run", help="Run ID for an archived or current attempt")
    next_action = command("status", _dispatch_workflow, aliases=["next"])
    next_action.add_argument("--after")
    paused = command("pause", _dispatch_workflow)
    paused.add_argument("reason")
    command("resume", _dispatch_workflow)
    acknowledged = command("ack-result", _dispatch_workflow)
    acknowledged.add_argument("node")
    acknowledged.add_argument("dispatch_id")
    diagram_command = command("diagram", _dispatch_workflow)
    diagram_command.add_argument("--run", help="Read a named run, including its sealed archive")
    diagram_command.add_argument(
        "--view",
        choices=("sequence", "pydantic", "orchestrator"),
        default="sequence",
        help="Show agent lifelines, task dependencies or the orchestrator routing graph",
    )
    expand = command("expand-scope", _dispatch_workflow)
    expand.add_argument("task")
    expand.add_argument("--reason", required=True)
    expand.add_argument("paths", nargs="+")
    rev = command("revise", _dispatch_workflow)
    rev.add_argument("graph")
    rev.add_argument("reason")
    rev.add_argument(
        "--retry-tests",
        nargs=4,
        metavar=("TEST_NODE", "FAILED_DISPATCH", "DIAGNOSIS_NODE", "REPAIR_NODE"),
        help="Reopen a failed Tester node after the diagnosed Implementer repair",
    )
    intake = command(
        "reintake",
        _dispatch_workflow,
        description="Refresh all sources in the authorized graph and any named documents.",
    )
    intake.add_argument("graph")
    intake.add_argument("reason")
    intake.add_argument("authorization")
    intake.add_argument(
        "--document", action="append", help="Authorized workspace-relative replacement"
    )
    rep = command("replace-session", _dispatch_workflow)
    rep.add_argument("agent")
    rep.add_argument("reason")
    rep.add_argument("terminal_evidence")
    handoff = rep.add_mutually_exclusive_group(required=True)
    handoff.add_argument("handoff", nargs="?", help="Summary for a single assigned task")
    handoff.add_argument("--task-handoff", action="append", nargs=2, metavar=("TASK", "SUMMARY"))
    claim = command("claim", _dispatch_workflow)
    claim.add_argument("node")
    claim.add_argument(
        "--ticket", help="Assignment ticket issued by workflow status. Required to reserve a node."
    )
    claim.add_argument("--dry-run", action="store_true", help="Check claim eligibility")
    note = command(
        "note", _dispatch_packets_checks, help="Read or record scoped specialist evidence"
    )
    note.add_argument("node")
    note.add_argument("--dispatch", required=True)
    note.add_argument("--request", help="Stable material delivery ID")
    note.add_argument("--kind", choices=sorted(set.union(*role_material.MATERIAL.values())))
    note.add_argument("--observation", help="What was observed or checked")
    note.add_argument("--path", action="append", help="Scoped source or document")
    note.add_argument("--check", action="append", help="Requested registered command")
    note.add_argument("--receipt", action="append", help="Returned execution ID")
    authorize = command(
        "authorize-check",
        _dispatch_packets_checks,
        help="Grant a focused Tester assignment for a recorded investigation request",
    )
    authorize.add_argument("node")
    authorize.add_argument("--dispatch", required=True)
    authorize.add_argument("--request", required=True)
    material = command(
        "handoff",
        _dispatch_packets_checks,
        help="Read or supplement a running Implementer assignment",
    )
    material.add_argument("node", help="Implementer node ID")
    material.add_argument("--dispatch", required=True, help="Active assignment ticket")
    material.add_argument("--request", help="Stable delivery ID; repeat with identical evidence")
    material.add_argument("--code", action="append", help="Owned changed path, repeatable")
    material.add_argument(
        "--test", action="append", help="Scoped regression file or registered check ID, repeatable"
    )
    docs = material.add_mutually_exclusive_group()
    docs.add_argument(
        "--docs", action="append", help="Updated scoped documentation path, repeatable"
    )
    docs.add_argument("--docs-current", help="Why the current documentation still applies")
    material.add_argument(
        "--dry-run", action="store_true", help="Validate evidence without recording delivery"
    )
    for name in ("accept", "packet"):
        command(name, _dispatch_workflow).add_argument("node")
    prepare = command("prepare-packet", _dispatch_packets_checks)
    prepare.add_argument("node")
    prepare.add_argument("--with-diagnostics", action="store_true")
    for name in ("read-packet", "confirm-packet"):
        packet = command(name, _dispatch_packets_checks)
        for field in (
            "node",
            "path",
            "sha256",
            "run_id",
            "dispatch_id",
            "source_hash",
            "revision",
        ):
            packet.add_argument(field)
        packet.add_argument("--recipient", required=True)
        packet.add_argument("--ack", required=name == "confirm-packet")
        if name == "read-packet":
            packet.add_argument("--chunk", type=int, default=1)
        else:
            packet.add_argument("--materials", required=True)
    b = command("bind", _dispatch_packets_checks)
    b.add_argument("node")
    b.add_argument("handle")
    b.add_argument("model")
    b.add_argument("--dispatch", required=True)
    command(
        "reset-history-index",
        _dispatch_workflow,
        help="Discard derived case rows; the next search repopulates them",
    )
    export = command(
        "export-artifact", _dispatch_history, help="Write verified original bytes to a new file"
    )
    export.add_argument("run_id")
    export.add_argument("path", help="Logical path from list-artifacts")
    export.add_argument("output", type=Path)
    for cmd in ("verify-history", "rebind-history", "list-artifacts"):
        command(cmd, _dispatch_history).add_argument("run_id")
    reference = command("read-report", _dispatch_packets_checks)
    reference.add_argument("run_id")
    reference.add_argument("node")
    reference.add_argument("dispatch_id")
    report = command("prepare-report", _dispatch_packets_checks)
    report.add_argument("node")
    report.add_argument("report")
    report.add_argument("receipt_ids", nargs="*")
    f = command("finish", _dispatch_completion)
    f.add_argument("node")
    f.add_argument("report")
    u = command("unknown", _dispatch_completion)
    u.add_argument("node")
    u.add_argument("reason")
    rec = command("resolve", _dispatch_completion)
    rec.add_argument("node")
    rec.add_argument("status")
    rec.add_argument("evidence")
    r = command("retry", _dispatch_completion)
    r.add_argument("node")
    r.add_argument("stage")
    r.add_argument("reason")
    r.add_argument("terminal_evidence")
    r.add_argument("--evidence-dispatch", help="Failed attempt ID from the active repair route")
    for command_parser in (u, rec, r):
        command_parser.add_argument(
            "--dispatch", required=True, help="Exact assignment ID being reconciled or retried"
        )
    r.add_argument("--dry-run", action="store_true", help="Preview budget and affected nodes")
    retro = command(
        "record-retro",
        _dispatch_completion,
        help="Attach retrospective evidence to this run’s final Teacher review",
    )
    for field in ("run_id", "incident", "source", "observation"):
        retro.add_argument(field)
    a = command("archive", _dispatch_completion)
    a.add_argument("outcome")
    a.add_argument("summary")
    command("clean", _dispatch_completion)
    return p


def _dispatch_setup(args: argparse.Namespace, ledger: Ledger) -> tuple[bool, object]:
    result: object = None
    if args.action == "config":
        config = load_config(args.config)
        pin = instruction_pin(config)
        if not getattr(args, "json", False):
            print(pin)
            return True, None
        result = {"pin": pin, "profiles": config["profiles"], "limits": config["_limits"]}
    elif args.action == "read-instructions":
        if args.pin == "-":
            state = ledger.read()
            require(state["status"] == "active", "Run is not active")
            check_config(state)
            c = state["config"]
        else:
            c = load_config(args.config)
            verify_instruction_pin(c, args.pin)
        instruction_entries: list[dict[str, str]] = []
        for name in args.paths:
            file = accepted_path(c, Path(c["_path"]).parent, name)
            require(str(file) in c["_files"], "Document is outside the accepted configuration")
            raw = accepted_bytes(c, file)
            instruction_entries.append({"path": str(file), "content": raw.decode("utf-8")})
        result = instruction_entries
    elif args.action == "read-project":
        state = ledger.read()
        require(state["status"] == "active", "Run is not active")
        check_config(state)
        c = state["config"]
        task_scope = sorted({p for t in state["graph"]["tasks"].values() for p in t["scope"]})
        user = Path(c["_path"]).parent / "memory/USER.md"
        instructions = material_entries(
            c["_project"],
            ledger.root,
            process="implement",
            audience="coordinator",
            scope=task_scope,
            resolve=lambda root, rel: accepted_path(c, root, rel),
            read_bytes=lambda file: accepted_bytes(c, file),
            user=user if str(user) in c["_files"] else None,
        )
        agents = accepted_path(c, ledger.root, "AGENTS.md")
        raw = accepted_bytes(c, agents)
        if all(entry["path"] != str(agents) for entry in instructions):
            instructions.append(
                dict(
                    path=str(agents),
                    content=raw.decode("utf-8"),
                    sha256=digest(raw),
                    reason="accepted project instructions",
                    audience="coordinator",
                )
            )
        result = {"policy": c["_project"]["data"], "instructions": instructions}
    elif args.action in {"init", "validate"}:
        c = load_config(args.config)
        if args.action == "init":
            check_workspace(ledger.root, c)
        proposal = ledger.runs.read_input(ledger.root, "plan", args.graph)
        g = expand_intake_checks(proposal, c)
        if args.action == "init":
            state = ledger.init(g, c, config_pin=args.config_pin)
            result = {
                "run_id": state["run_id"],
                "revision": state["revision"],
                "status": state["status"],
            }
        else:
            intake.configure(
                g, c, load_definitions(Path(c["_path"]).parent / "graphs", "implement")
            )
            g["sources"] = {
                key: SOURCE.validate_python(lock_source(ledger.root, source))
                for key, source in g["sources"].items()
            }
            result = list(validate_graph(g, c, ledger.root))
            validate_assignment_lineage(g, c)
    return False, result


def _dispatch_history(args: argparse.Namespace, ledger: Ledger) -> tuple[bool, object]:
    history = ledger.history
    root = ledger.root
    if args.action == "list-artifacts":
        return False, history.listing(root, args.run_id)
    if args.action == "export-artifact":
        history.export(root, args.run_id, args.path, args.output)
        return False, {"output": str(args.output)}
    count = history.verify_history(root, args.run_id, bind=args.action == "rebind-history")
    return False, {"run_id": args.run_id, "verified_files": count}


def _dispatch_workflow(
    args: argparse.Namespace,
    ledger: Ledger,
    *,
    cases: CaseIndex | None = None,
) -> tuple[bool, object]:
    result: object = None
    if args.action == "reset-history-index":
        (current_database().cases if cases is None else cases).reset(ledger.root)
        result = {"index": "cleared"}
    elif args.action == "correct":
        result = ledger.correct(
            args.node, ledger.runs.read_input(ledger.root, "correction", args.decision)
        )
    elif args.action == "resume-task":
        ledger.resume_task(args.task, args.evidence, stop_id=args.stop)
        result = None
    elif args.action in {"next", "status"}:
        result = ledger.next_actions(args.after)
    elif args.action in {"pause", "resume"}:
        ledger.set_paused(args.reason if args.action == "pause" else None)
        result = None
    elif args.action == "ack-result":
        ledger.acknowledge_result(args.node, args.dispatch_id)
        result = None
    elif args.action == "explain":
        result = workflow_query.explain(ledger, args.node, args.dispatch, args.run)
    elif args.action == "diagram":
        state = workflow_query.lookup_state(ledger, args.run)
        if args.view == "pydantic":
            nodes = {node["id"]: node for node in state["graph"]["nodes"]}
            rendered = execution_graph(nodes).program.render(direction="LR")
        elif args.view == "orchestrator":
            rendered = orchestrator_graph(state["definitions"]).render(direction="LR")
        else:
            rendered = diagram(state)
        if not getattr(args, "json", False):
            print(rendered)
            return True, None
        result = {
            "run_id": state["run_id"],
            "mermaid": rendered,
            **({"route_holds": state["route_holds"]} if state.get("route_holds") else {}),
        }
    elif args.action == "resume-approved":
        ledger.resume_approved(args.node, args.request_id, args.evidence)
        result = None
    elif args.action == "expand-scope":
        ledger.expand_scope(args.task, args.paths, args.reason)
        result = None
    elif args.action == "revise":
        retry_tests = TestRetryRequest(*args.retry_tests) if args.retry_tests is not None else None
        ledger.revise(
            expand_intake_checks(
                ledger.runs.read_input(ledger.root, "plan", args.graph), ledger.read()["config"]
            ),
            args.reason,
            retry_tests=retry_tests,
        )
        result = None
    elif args.action == "reintake":
        ledger.reintake(
            expand_intake_checks(
                ledger.runs.read_input(ledger.root, "plan", args.graph), ledger.read()["config"]
            ),
            args.reason,
            args.authorization,
            documents=args.document,
        )
        result = None
    elif args.action == "replace-session":
        handoffs = dict(args.task_handoff or [])
        require(len(handoffs) == len(args.task_handoff or []), "Duplicate task handoff")
        ledger.replace_session(
            args.agent, args.reason, args.terminal_evidence, handoffs or args.handoff
        )
        result = None
    elif args.action == "claim":
        result = ledger.claim(args.node, ticket=args.ticket, dry_run=args.dry_run)
    elif args.action in {"accept", "packet"}:
        result = getattr(ledger, args.action)(args.node)
    return False, result


def _dispatch_packets_checks(args: argparse.Namespace, ledger: Ledger) -> tuple[bool, object]:
    result: object = None
    if args.action == "prepare-packet":
        result = ledger.prepare_packet(args.node, with_diagnostics=args.with_diagnostics)
    elif args.action in {"read-packet", "confirm-packet"}:
        bootstrap = {
            "node_id": args.node,
            "path": args.path,
            "sha256": args.sha256,
            "run_id": args.run_id,
            "dispatch_id": args.dispatch_id,
            "source_hash": args.source_hash,
            "revision": args.revision,
        }
        if args.action == "read-packet":
            result = ledger.read_packet(
                args.node, bootstrap, args.chunk, args.ack, recipient=args.recipient
            )
        else:
            ledger.confirm_packet(
                args.node, bootstrap, args.ack, args.materials, recipient=args.recipient
            )
            result = None
    elif args.action == "bind":
        ledger.bind(args.node, args.handle, args.model, expected_dispatch=args.dispatch)
        result = None
    elif args.action == "run-check":
        result = ledger.run_check(
            args.node,
            args.check_id,
            args.request,
            expected_dispatch=args.dispatch,
            dry_run=args.dry_run,
        )
    elif args.action == "reconcile-check":
        result = ledger.reconcile_check(args.execution_id, args.abandon_unstarted)
    elif args.action == "check-results":
        result = ledger.check_results(args.execution_id)
    elif args.action == "read-report":
        attempt = workflow_query.explain(ledger, args.node, args.dispatch_id, args.run_id)
        require(attempt["report"] is not None, "Attempt has no terminal report")
        result = attempt["report"]
    elif args.action == "note":
        material: RoleMaterial | None = None
        if args.kind:
            require(
                args.observation and args.observation.strip(), "Provide the observation or question"
            )
            material = {
                "kind": args.kind,
                "observation": args.observation,
                "paths": args.path or [],
            }
            if args.check:
                material["checks"] = args.check
            if args.receipt:
                material["receipts"] = args.receipt
        else:
            require(
                not (args.observation or args.path or args.check or args.receipt),
                "Choose the evidence kind",
            )
        result = role_material.note(ledger, args.node, args.dispatch, args.request, material)
    elif args.action == "authorize-check":
        result = role_material.authorize_check(ledger, args.node, args.dispatch, args.request)
    elif args.action == "handoff":
        offer: WriteOffer = {}
        if args.code:
            offer["code"] = args.code
        if args.test:
            offer["tests"] = args.test
        if args.docs:
            offer["docs"] = args.docs
        if args.docs_current is not None:
            require(args.docs_current.strip(), "Need a documentation applicability reason")
            offer["docs_current"] = args.docs_current
        result = write_handoff.exchange(
            ledger, args.node, args.dispatch, args.request, offer, dry_run=args.dry_run
        )
    elif args.action == "prepare-report":
        draft = ledger.runs.read_input(ledger.root, "draft", args.report)
        report = ledger.prepare_report(args.node, draft, args.receipt_ids, submit=True)
        result = {
            "report_id": graph_identity(["submission", report]),
            "dispatch_id": report["dispatch_id"],
        }
    return False, result


def _dispatch_completion(args: argparse.Namespace, ledger: Ledger) -> tuple[bool, object]:
    result: object = None
    if args.action == "finish":
        ledger.finish(
            args.node, parse_report(ledger.runs.read_input(ledger.root, "submission", args.report))
        )
        result = None
    elif args.action == "unknown":
        ledger.unknown(args.node, args.reason, expected_dispatch=args.dispatch)
        result = None
    elif args.action == "resolve":
        ledger.resolve(args.node, args.status, args.evidence, expected_dispatch=args.dispatch)
        result = None
    elif args.action == "retry":
        result = ledger.retry(
            args.node,
            args.stage,
            args.reason,
            args.terminal_evidence,
            dry_run=args.dry_run,
            expected_dispatch=args.dispatch,
            evidence_dispatch=args.evidence_dispatch,
        )
    elif args.action == "record-retro":
        ledger.record_retro(args.run_id, args.incident, args.source, args.observation)
    elif args.action == "archive":
        result = ledger.archive(args.outcome, args.summary)
    else:
        ledger.clean()
        result = None
    return False, result


def main() -> None:
    p = build_parser()
    run(p.parse_args(), p)


def _result(value: object) -> None:
    print(json.dumps({"ok": True, "result": value}, ensure_ascii=False, indent=2))


def run(args: argparse.Namespace, p: argparse.ArgumentParser) -> None:
    dry_run = getattr(args, "dry_run", False)
    as_json = getattr(args, "json", False)
    if args.action == "prepare-workspace":
        try:
            if dry_run:
                with read_only():
                    _result(
                        prepare_workspace(
                            Path(args.workspace).resolve(), load_config(args.config), dry_run=True
                        )
                    )
            else:
                selected = prepare_workspace(
                    Path(args.workspace).resolve(), load_config(args.config)
                )
                with diagnostic_operation(selected["workspace"], "prepare-workspace"):
                    _result(selected)
        except (Invalid, OSError, ValueError) as exc:
            if as_json:
                raise
            p.exit(1, f"BLOCKED: {exc}\n")
        return
    if args.action == "diagnostics":
        try:
            key, value = next(
                (key, value)
                for key, value in (
                    ("invocation_id", args.invocation),
                    ("run_id", args.run),
                    ("dispatch_id", args.dispatch),
                    ("operation", args.operation),
                )
                if value is not None
            )
            print(json.dumps(read_journal(args.workspace, key, value, args.cursor, args.limit)))
        except (OSError, ValueError) as exc:
            if as_json:
                raise
            p.exit(1, f"BLOCKED: {exc}\n")
        return
    database = current_database()
    ledger = Ledger(
        args.workspace,
        runs=database.runs,
        packets=database.packets,
        jobs=database.teacher,
        history=database.history,
    )
    if dry_run or args.action == "explain":
        try:
            with read_only():
                _, preview = args.command_handler(args, ledger)
            _result(preview)
        except (Invalid, KeyError, OSError, ValueError) as exc:
            if as_json:
                raise
            p.exit(1, f"BLOCKED: {exc}\n")
        return
    handler = initialize(args.workspace, args.action, store=database.diagnostics)
    failed = False
    result: object
    try:
        done, result = args.command_handler(args, ledger)
        if args.action in {"export-artifact", "rebind-history"}:
            event("operation_completed", run_id=args.run_id)
        elif args.action in {"clean", "reset-history-index"}:
            event("operation_completed", **ledger.failure_context(None))
        if done:
            return
        if args.action == "read-packet":
            sys.stdout.buffer.write(packet_response(result))
        else:
            _result(result)
    except BaseException as exc:
        failed = True
        event(
            "operation_failed",
            error_code=error_code(exc),
            **(
                ledger.failure_context(
                    getattr(args, "node", None),
                    expected_run=args.run_id
                    if args.action in {"read-packet", "confirm-packet"}
                    else None,
                )
                if args.action not in {"init", "validate", "config", "read-instructions"}
                else {}
            ),
        )
        if not as_json and isinstance(exc, (Invalid, KeyError, OSError, ValueError)):
            p.exit(1, f"BLOCKED: {exc}\n")
        raise
    finally:
        finish(handler, failed=failed)


if __name__ == "__main__":
    main()
