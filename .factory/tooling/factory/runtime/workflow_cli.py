"""Command-line interface for the workflow ledger."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from factory.logging_config import (
    error_code,
    event,
    failure_context,
    finish,
    initialize,
    read_journal,
)
from factory.paths import FACTORY_ROOT
from factory.runtime import command_worker, report_history
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid, digest, read_json, relative
from factory.runtime.workflow_graph import (
    diagram,
    validate_assignment_lineage,
    validate_graph,
)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--workspace", default=".")
    p.add_argument("--config", default=str(FACTORY_ROOT / "factory.yaml"))
    sub = p.add_subparsers(dest="action", required=True)
    diagnostic = sub.add_parser("diagnostics")
    selectors = diagnostic.add_mutually_exclusive_group(required=True)
    selectors.add_argument("--invocation")
    selectors.add_argument("--run")
    selectors.add_argument("--dispatch")
    diagnostic.add_argument("--cursor", type=int, default=0)
    diagnostic.add_argument("--limit", type=int, default=30)
    sub.add_parser("config")
    instructions = sub.add_parser("read-instructions")
    instructions.add_argument("pin")
    instructions.add_argument("paths", nargs="+")
    for name in ("validate", "init"):
        parser = sub.add_parser(name)
        parser.add_argument("graph")
        if name == "init":
            parser.add_argument(
                "--config-pin", help="JSON output from config before instruction reading"
            )
    corr = sub.add_parser("correct")
    corr.add_argument("node")
    corr.add_argument("decision")
    resume = sub.add_parser("resume-task")
    resume.add_argument("task")
    resume.add_argument("evidence")
    approved = sub.add_parser("resume-approved")
    approved.add_argument("node")
    approved.add_argument("request_id")
    approved.add_argument("evidence")
    sub.add_parser("show")
    next_action = sub.add_parser("next", aliases=["status"])
    next_action.add_argument("--after")
    paused = sub.add_parser("pause")
    paused.add_argument("reason")
    sub.add_parser("resume")
    acknowledged = sub.add_parser("ack-result")
    acknowledged.add_argument("node")
    acknowledged.add_argument("dispatch_id")
    sub.add_parser("diagram")
    expand = sub.add_parser("expand-scope")
    expand.add_argument("task")
    expand.add_argument("--reason", required=True)
    expand.add_argument("paths", nargs="+")
    rev = sub.add_parser("revise")
    rev.add_argument("graph")
    rev.add_argument("reason")
    intake = sub.add_parser("reintake")
    intake.add_argument("graph")
    intake.add_argument("reason")
    intake.add_argument("authorization")
    rep = sub.add_parser("replace-session")
    rep.add_argument("agent")
    rep.add_argument("reason")
    rep.add_argument("terminal_evidence")
    rep.add_argument("handoff")
    for name in ("claim", "accept", "packet"):
        sub.add_parser(name).add_argument("node")
    prepare = sub.add_parser("prepare-packet")
    prepare.add_argument("node")
    prepare.add_argument("--with-diagnostics", action="store_true")
    for name in ("read-packet", "confirm-packet"):
        packet = sub.add_parser(name)
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
        packet.add_argument("--ack", required=name == "confirm-packet")
        if name == "read-packet":
            packet.add_argument("--chunk", type=int, default=1)
        else:
            packet.add_argument("--materials", required=True)
    b = sub.add_parser("bind")
    b.add_argument("node")
    b.add_argument("handle")
    b.add_argument("model")
    check = sub.add_parser("run-check")
    check.add_argument("node")
    check.add_argument("check_id")
    check.add_argument("--request", required=True)
    check.add_argument("--dispatch", required=True)
    reconciled = sub.add_parser("reconcile-check")
    reconciled.add_argument("execution_id")
    reconciled.add_argument("--abandon-unstarted", action="store_true")
    sub.add_parser("check-results").add_argument("execution_id")
    sub.add_parser("_check-worker").add_argument("execution_id")
    sub.add_parser("read-report").add_argument("reference")
    report = sub.add_parser("prepare-report")
    report.add_argument("node")
    report.add_argument("report")
    report.add_argument("receipt_ids", nargs="*")
    f = sub.add_parser("finish")
    f.add_argument("node")
    f.add_argument("report")
    u = sub.add_parser("unknown")
    u.add_argument("node")
    u.add_argument("reason")
    rec = sub.add_parser("resolve")
    rec.add_argument("node")
    rec.add_argument("status")
    rec.add_argument("evidence")
    r = sub.add_parser("retry")
    r.add_argument("node")
    r.add_argument("stage")
    r.add_argument("reason")
    r.add_argument("terminal_evidence")
    a = sub.add_parser("archive")
    a.add_argument("outcome")
    a.add_argument("summary")
    sub.add_parser("clean")
    return p


def main() -> None:
    p = build_parser()
    args = p.parse_args()
    if args.action == "diagnostics":
        try:
            key, value = next(
                (key, value)
                for key, value in (
                    ("invocation_id", args.invocation),
                    ("run_id", args.run),
                    ("dispatch_id", args.dispatch),
                )
                if value is not None
            )
            print(json.dumps(read_journal(args.workspace, key, value, args.cursor, args.limit)))
        except (OSError, ValueError) as exc:
            p.exit(1, f"BLOCKED: {exc}\n")
        return
    ledger = Ledger(args.workspace)
    handler = initialize(args.workspace, args.action)
    failed = False
    result: object
    try:
        if args.action == "config":
            result = load_config(args.config)
        elif args.action == "read-instructions":
            pin = read_json(args.pin)
            c = load_config(args.config)
            if not (
                isinstance(pin, dict)
                and pin.get("ok") is True
                and isinstance(pin.get("result"), dict)
                and pin["result"].get("_path") == c["_path"]
                and isinstance(pin["result"].get("_files"), dict)
            ):
                raise Invalid("Invalid instruction snapshot")
            expected = pin["result"]["_files"]
            instruction_entries: list[dict[str, str]] = []
            for name in args.paths:
                file = relative(Path(c["_path"]).parent, name)
                raw = file.read_bytes()
                if expected.get(str(file)) != digest(raw):
                    raise Invalid("Instruction changed since snapshot; reload instructions")
                instruction_entries.append({"path": str(file), "content": raw.decode("utf-8")})
            result = instruction_entries
        elif args.action in {"init", "validate"}:
            c, g = load_config(args.config), read_json(args.graph)
            if args.action == "init" and args.config_pin:
                pin = read_json(args.config_pin)
                if not (
                    isinstance(pin, dict)
                    and pin.get("ok") is True
                    and isinstance(pin.get("result"), dict)
                    and pin["result"].get("_path") == c["_path"]
                    and pin["result"].get("_files") == c["_files"]
                ):
                    raise Invalid("Config/instructions changed since snapshot; reload instructions")
            if args.action == "init":
                result = ledger.init(g, c)
            else:
                result = list(validate_graph(g, c, ledger.root))
                validate_assignment_lineage(g, c)
        elif args.action == "correct":
            result = ledger.correct(args.node, read_json(args.decision))
        elif args.action == "resume-task":
            ledger.resume_task(args.task, args.evidence)
            result = None
        elif args.action in {"next", "status"}:
            result = ledger.next_actions(args.after)
        elif args.action in {"pause", "resume"}:
            ledger.set_paused(args.reason if args.action == "pause" else None)
            result = None
        elif args.action == "ack-result":
            ledger.acknowledge_result(args.node, args.dispatch_id)
            result = None
        elif args.action == "show":
            result = ledger.read()
        elif args.action == "diagram":
            print(diagram(ledger.read()))
            return
        elif args.action == "resume-approved":
            ledger.resume_approved(args.node, args.request_id, args.evidence)
            result = None
        elif args.action == "expand-scope":
            ledger.expand_scope(args.task, args.paths, args.reason)
            result = None
        elif args.action == "revise":
            ledger.revise(read_json(args.graph), args.reason)
            result = None
        elif args.action == "reintake":
            ledger.reintake(read_json(args.graph), args.reason, args.authorization)
            result = None
        elif args.action == "replace-session":
            ledger.replace_session(args.agent, args.reason, args.terminal_evidence, args.handoff)
            result = None
        elif args.action in {"claim", "accept", "packet"}:
            result = getattr(ledger, args.action)(args.node)
        elif args.action == "prepare-packet":
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
                result = ledger.read_packet(args.node, bootstrap, args.chunk, args.ack)
            else:
                ledger.confirm_packet(args.node, bootstrap, args.ack, args.materials)
                result = None
        elif args.action == "bind":
            ledger.bind(args.node, args.handle, args.model)
            result = None
        elif args.action == "run-check":
            result = ledger.run_check(
                args.node, args.check_id, args.request, expected_dispatch=args.dispatch
            )
        elif args.action == "reconcile-check":
            result = ledger.reconcile_check(args.execution_id, args.abandon_unstarted)
        elif args.action == "check-results":
            result = ledger.check_results(args.execution_id)
        elif args.action == "_check-worker":
            command_worker.supervise(ledger, args.execution_id)
            return
        elif args.action == "read-report":
            result = report_history.read(ledger.root, read_json(args.reference))
        elif args.action == "prepare-report":
            draft = json.load(sys.stdin) if args.report == "-" else read_json(args.report)
            result = ledger.prepare_report(args.node, draft, args.receipt_ids)
        elif args.action == "finish":
            ledger.finish(args.node, read_json(args.report))
            result = None
        elif args.action == "unknown":
            ledger.unknown(args.node, args.reason)
            result = None
        elif args.action == "resolve":
            ledger.resolve(args.node, args.status, args.evidence)
            result = None
        elif args.action == "retry":
            ledger.retry(args.node, args.stage, args.reason, args.terminal_evidence)
            result = None
        elif args.action == "archive":
            result = ledger.archive(args.outcome, args.summary)
        else:
            ledger.clean()
            result = None
        print(json.dumps({"ok": True, "result": result}, ensure_ascii=False, indent=2))
    except BaseException as exc:
        failed = True
        event(
            "operation_failed",
            error_code=error_code(exc),
            **(
                failure_context(ledger, getattr(args, "node", None))
                if args.action
                not in {"init", "validate", "config", "read-instructions", "read-packet"}
                else {}
            ),
        )
        if isinstance(exc, (Invalid, KeyError, OSError, ValueError)):
            p.exit(1, f"BLOCKED: {exc}\n")
        raise
    finally:
        finish(handler, failed=failed)


if __name__ == "__main__":
    main()
