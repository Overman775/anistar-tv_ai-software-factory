"""Coordinate three independent review assignments on the pinned process graph."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any, cast
from uuid import uuid4

from pydantic import TypeAdapter
from pydantic_graph import StepContext

from factory.cli_output import emit_json
from factory.database.provider import current_database
from factory.dependency_graph import compile_dependencies
from factory.graphs.program import Operations
from factory.paths import FACTORY_ROOT
from factory.processes import engine
from factory.processes.records import Attempt, ProcessRun
from factory.review import subject
from factory.review.protocol.artifact_io import load_object
from factory.review.protocol.contracts import IDENTITY_FIELDS
from factory.review.protocol.diff import load_diff_context
from factory.review.protocol.evidence import validate_tool_results
from factory.review.protocol.lenses import validate_lens
from factory.review.protocol.plan import questions
from factory.review.protocol.shapes import CommandResult, ReviewAssignment
from factory.review.render_review_report import render_report_text
from factory.review.run_tool_checks import collect_results, run_command
from factory.review.validate_review_protocol import validate_protocol
from factory.runtime.workflow_core import graph_identity, lock, require

REVIEW_ASSIGNMENT = TypeAdapter[ReviewAssignment](ReviewAssignment)
DIRECTIONS = {
    "system-design": "architecture",
    "runtime-safety": "runtime",
    "verification-quality": "acceptance",
}


async def review_assignment(ctx: StepContext) -> engine.Offer:
    phase = cast(ProcessRun, ctx.inputs).state.phase
    direction = next((name for name, expected in DIRECTIONS.items() if phase == expected), None)
    if direction is None:
        return engine.Offer("hold", reason="A Reviewer assignment requires an eligible direction")
    return engine.Offer(direction, "reviewer")


def operations() -> Operations:
    return engine.register(
        ("intake", "architecture", "runtime", "acceptance", "command", "verification", "archived"),
        "review_boundary",
        {
            "present_review": engine.offer("coordinate"),
            "review_assignment": review_assignment,
            "run_project_check": engine.offer("check"),
            "verify_results": engine.offer("finish"),
            "review_history": engine.offer("history"),
        },
    )


def identifier(name: str | Path) -> str:
    key = str(name)
    return (
        key
        if re.fullmatch(r"code-review-[0-9a-f]{28}", key)
        else engine.identifier("code-review", key)
    )


def record(name: str | Path) -> ProcessRun:
    return current_database().processes.get(Path.cwd(), identifier(name))


def initialize(request: Path, name: str | Path) -> dict[str, Any]:
    root = Path.cwd()
    run_id = identifier(name)
    raw = load_object(request)
    repo = current_database().processes
    if repo.exists(root, run_id):
        run = repo.get(root, run_id)
        require(
            run.subject["request_hash"] == graph_identity(raw),
            "Review intake already binds a different subject",
        )
    else:
        require(run_id != str(name), "Unknown review ID; use a new intake name")
        captured = subject.capture(request, FACTORY_ROOT)
        captured["request_hash"] = graph_identity(raw)
        run = engine.start(
            root,
            "code-review",
            str(name),
            captured,
            FACTORY_ROOT / "graphs",
            definitions=subject.accepted_graph(captured["manifest"], FACTORY_ROOT),
        )
    return {"run_id": run.run_id, **inspect(run, run.subject["manifest"])}


def inspect(run: ProcessRun, manifest: dict[str, Any]) -> dict[str, Any]:
    facts = run.state.facts
    checks = facts.get("checks", {})
    _, counts, errors, _ = validate_tool_results(
        [bucket[-1] for bucket in checks.values()], manifest
    )
    diff, issues = load_diff_context(manifest)
    registry = {a["id"]: a["criteria"] for a in manifest["assignments"]}
    reviewers = {}
    for direction in registry:
        reports = facts.get("reports", {}).get(direction, [])
        failures = (
            validate_lens(reports[-1], manifest, diff, counts, registry)[2] if reports else []
        )
        reviewers[direction] = {
            "status": "PENDING" if not reports else "FAILED" if failures else "COMPLETE",
            "errors": failures,
        }
    commands = []
    if run.state.terminal:
        commands.append(
            [
                "review",
                "run",
                "report" if run.state.terminal == "completed" else "history",
                "--run",
                run.run_id,
            ]
        )
    else:
        for direction in registry:
            attempts = run.state.attempts.get(direction, [])
            last = attempts[-1] if attempts else None
            if select(run, DIRECTIONS[direction]).action != direction:
                continue
            if last is None or (last.status == "failed" and len(attempts) < 2):
                commands.append(
                    [
                        "review",
                        "run",
                        "assignment",
                        "--id",
                        direction,
                        "--run",
                        run.run_id,
                        "--request",
                        "REQUEST_ID",
                    ]
                )
            elif last.status == "running":
                commands.append(
                    [
                        "review",
                        "run",
                        "packet",
                        "--id",
                        direction,
                        "--run",
                        run.run_id,
                        "--dispatch",
                        last.dispatch,
                        "--handle",
                        last.handle or "HANDLE",
                    ]
                )
            elif last.status in {"reserved", "unknown"}:
                commands.append(
                    [
                        "review",
                        "run",
                        "bind",
                        "--id",
                        direction,
                        "--run",
                        run.run_id,
                        "--dispatch",
                        last.dispatch,
                        "--handle",
                        "OBSERVED_HANDLE",
                        "--request",
                        "REQUEST_ID",
                    ]
                )
        for check in manifest["checks"]:
            key = check["id"]
            history = checks.get(key, [])
            if pending := facts.get("executing", {}).get(key):
                commands.append(
                    [
                        "review",
                        "run",
                        "reconcile-check",
                        "--id",
                        key,
                        "--run",
                        run.run_id,
                        "--original-request",
                        pending["request"],
                        "--evidence",
                        "CONFIRMED_STOP",
                        "--request",
                        "REQUEST_ID",
                    ]
                )
                continue
            if len(history) >= 2:
                continue
            if history and history[-1]["status"] not in {"BLOCKED", "NOT_RUN"}:
                continue
            if (
                all(
                    checks.get(dep) and checks[dep][-1]["status"] == "PASS"
                    for dep in check.get("after", [])
                )
                and select(run, "command").action == "check"
            ):
                commands.append(
                    [
                        "review",
                        "run",
                        "check",
                        "--id",
                        key,
                        "--run",
                        run.run_id,
                        "--request",
                        "REQUEST_ID",
                    ]
                )
        if (
            facts.get("reports")
            and not facts.get("executing")
            and select(run, "verification").action == "finish"
        ):
            commands.append(
                [
                    "review",
                    "run",
                    "finish",
                    "--run",
                    run.run_id,
                    "--input",
                    "QA_FILE",
                    "--request",
                    "REQUEST_ID",
                ]
            )
    return {
        "commands": commands,
        "reviewers": reviewers,
        "source_errors": issues,
        "check_errors": errors,
        "checks": {
            c["id"]: checks[c["id"]][-1]["status"] if c["id"] in checks else "PENDING"
            for c in manifest["checks"]
        },
        "outstanding_checks": facts.get("executing", {}),
        "terminal": run.state.terminal,
    }


def select(run: ProcessRun, phase: str) -> engine.Offer:
    focused = run.model_copy(update={"state": run.state.model_copy(update={"phase": phase})})
    return engine.resolve(focused)


def packet(run: ProcessRun, manifest: dict[str, Any], attempt: Attempt) -> dict[str, Any]:
    direction = attempt.node
    assignment = next(a for a in manifest["assignments"] if a["id"] == direction)
    return dict(
        REVIEW_ASSIGNMENT.validate_python(
            {
                **{k: manifest[k] for k in IDENTITY_FIELDS},
                "dispatch": attempt.dispatch,
                "name": assignment["name"],
                "profile": assignment["profile"],
                "lens": direction,
                "source": {"kind": "review", "target": manifest["target"]},
                "task": {"scope": manifest["scope_files"]},
                "project_policy": manifest["project_policy"],
                "manifest": run.run_id,
                "context": manifest["context"],
                "owned_gates": questions(manifest, direction),
                "parent_evidence": list(run.state.facts.get("checks", {})),
                "check_receipts": {
                    key: bucket[-1] for key, bucket in run.state.facts.get("checks", {}).items()
                },
            }
        )
    )


def worker_action(
    run: ProcessRun, manifest: dict[str, Any], args: argparse.Namespace, value: dict[str, Any]
) -> dict[str, Any]:
    direction = args.id
    require(direction in DIRECTIONS, "Unknown reviewer direction")
    selected = select(run, DIRECTIONS[direction])
    require(
        selected.role == "reviewer" and selected.action == direction,
        "Direction is unavailable in the pinned graph",
    )
    if args.action == "assignment":
        attempts = run.state.attempts.get(direction, [])
        if not attempts or attempts[-1].status == "failed":
            require(len(attempts) < 2, "recovery exhausted; retain partial results")
            engine.claim(run, selected)
        worker = run.state.attempts[direction][-1]
        require(
            worker.status in {"reserved", "running", "unknown"},
            "Healthy assignment cannot be replaced",
        )
        return packet(run, manifest, worker)
    worker = engine.active(run, direction, args.dispatch)
    require(worker.status in {"reserved", "running", "unknown"}, "Assignment is closed")
    require(
        worker.status != "unknown" or args.action in {"bind", "stopped", "lost"},
        "Reconcile the original reviewer handle",
    )
    if args.action == "bind":
        require(
            args.handle and worker.handle in {None, args.handle}, "Bind the actual reviewer handle"
        )
        require(
            not any(
                a.handle == args.handle
                for k, attempts in run.state.attempts.items()
                if k != direction
                for a in attempts
            ),
            "Each direction needs an independent reviewer",
        )
        worker.handle, worker.status = args.handle, "running"
        return {"dispatch": worker.dispatch, "handle": worker.handle}
    require(
        (worker.handle and args.handle == worker.handle)
        or (args.action == "stopped" and worker.handle is None and not args.handle),
        "Report or next step must use the original reviewer handle",
    )
    if args.action == "lost":
        require(args.evidence, "Supply the session observation")
        worker.status = "unknown"
        worker.evidence.append({"transport": "unknown", "observation": args.evidence})
        return {"dispatch": worker.dispatch, "action": "reconcile", "handle": worker.handle}
    if args.action == "stopped":
        require(args.evidence, "Supply evidence the previous reviewer stopped")
        worker.status = "failed"
        worker.evidence.append({"transport": "stopped", "observation": args.evidence})
        return {
            "dispatch": worker.dispatch,
            "action": "retry" if worker.number < 2 else "exhausted",
        }
    if args.action == "note":
        require(args.evidence, "Supply partial observations")
        worker.evidence.append({"observation": args.evidence})
        return {"dispatch": worker.dispatch, "observations": worker.evidence}
    require(args.action == "submit" and value.get("lens") == direction, "Wrong assignment")
    reports = run.state.facts.setdefault("reports", {}).setdefault(direction, [])
    require(len(reports) < 2, "recovery exhausted; retain partial results")
    diff, _ = load_diff_context(manifest)
    checks = run.state.facts.get("checks", {})
    _, counts, _, _ = validate_tool_results([b[-1] for b in checks.values()], manifest)
    registry = {a["id"]: a["criteria"] for a in manifest["assignments"]}
    if reports:
        retained = validate_lens(reports[-1], manifest, diff, counts, registry)[1]
        supplied = value.get("findings")
        findings = list(supplied) if isinstance(supplied, list) else []
        for finding in retained:
            original = {k: v for k, v in finding.items() if k not in {"found_by", "source_ids"}}
            matches = [
                f
                for f in findings
                if isinstance(f, dict) and f.get("finding_id") == finding["finding_id"]
            ]
            require(
                all(f == original for f in matches), "Recovery cannot rewrite a validated finding"
            )
            if not matches:
                findings.append(original)
        value = {**value, "findings": findings}
    reports.append(value)
    issues = validate_lens(value, manifest, diff, counts, registry)[2]
    worker.status = "failed" if issues else "done"
    worker.outcome = "INCOMPLETE" if issues else "COMPLETE"
    return {
        "lens": direction,
        "dispatch": worker.dispatch,
        "status": worker.outcome,
        "errors": issues,
    }


def check_lock(root: Path, run_id: str, key: str) -> Path:
    return root / ".factory/memory/review-logs" / run_id / (graph_identity(key) + ".lock")


def check(name: str, key: str, request: str) -> dict[str, Any]:
    root = Path.cwd()
    run_id = identifier(name)
    with lock(check_lock(root, run_id, key)):
        return execute_check(root, run_id, key, request)


def execute_check(root: Path, run_id: str, key: str, request: str) -> dict[str, Any]:
    repo = current_database().processes

    def reserve(run: ProcessRun, _: engine.Offer) -> dict[str, Any]:
        manifest = subject.fresh(run.subject)
        require(select(run, "command").action == "check", "Project checks are unavailable")
        commands = {c["id"]: c for c in manifest["checks"]}
        require(key in commands, "Unknown check")
        facts = run.state.facts
        active = facts.setdefault("executing", {})
        require(
            key not in active,
            "An interrupted check has unknown outcome; reconcile the original execution",
        )
        previous = facts.get("checks", {}).get(key, [])
        require(len(previous) < 2, "recovery exhausted; retain partial results")
        require(
            not previous or previous[-1]["status"] in {"BLOCKED", "NOT_RUN"},
            "Completed command cannot be rerun",
        )
        graph = compile_dependencies({k: c.get("after", []) for k, c in commands.items()})
        passed = frozenset(
            k for k, b in facts.get("checks", {}).items() if b[-1]["status"] == "PASS"
        )
        require(key in graph.ready(passed), "Check dependency has no current PASS")
        active[key] = {"request": request, "attempt": len(previous) + 1}
        return dict(active[key])

    inputs = {"check": key}
    # Claim once before side effects. A second caller must observe an unknown owner until the receipt commits.
    owner = uuid4().hex

    def claim_command(run: ProcessRun, selected: engine.Offer) -> dict[str, Any]:
        reserved = reserve(run, selected)
        reserved["owner"] = owner
        return reserved

    receipt = engine.change(
        root, "code-review", run_id, request, "reserve-check", inputs, claim_command
    )
    run = repo.get(root, run_id)
    finish_key = "internal:review-check:" + graph_identity(request)
    finished = repo.receipt(root, run_id, finish_key, graph_identity(["check", inputs]))
    if finished is not None:
        return finished
    if reconciled := run.state.facts.get("check_reconciliations", {}).get(request):
        return dict(reconciled)
    require(
        receipt["owner"] == owner,
        "An interrupted check has unknown outcome; reconcile the original execution",
    )
    manifest = subject.fresh(run.subject)
    declaration = next(c for c in manifest["checks"] if c["id"] == key)["execution"]
    execution = {k: v for k, v in declaration.items() if k in {"argv", "cwd", "timeout_seconds"}}

    def accepted_tool(argv: list[str], cwd: str, timeout: int) -> CommandResult:
        with subject.command_arguments(run.subject["tool_revision"], argv, cwd) as effective:
            observation = run_command(
                effective, cwd, timeout, log_dir=root / ".factory/memory/review-logs" / run_id
            )
            observation["argv"] = argv
            return observation

    value = collect_results(
        manifest,
        key,
        [json.dumps(execution)],
        run=accepted_tool,
    )

    def finish(record: ProcessRun, _: engine.Offer) -> dict[str, Any]:
        facts = record.state.facts
        require(facts["executing"][key]["request"] == request, "Different pending check")
        del facts["executing"][key]
        facts.setdefault("checks", {}).setdefault(key, []).append(value)
        return value

    result = engine.change(root, "code-review", run_id, finish_key, "check", inputs, finish)
    subject.fresh(run.subject)
    return result


def reconcile_check(
    run: ProcessRun, key: str, original: str | None, evidence: str | None
) -> dict[str, Any]:
    facts = run.state.facts
    pending = facts.get("executing", {}).get(key)
    require(
        pending and original == pending["request"] and evidence and evidence.strip(),
        "Identify the original execution and supply an observation that it stopped",
    )
    manifest = run.subject["manifest"]
    operation = next(c["execution"] for c in manifest["checks"] if c["id"] == key)
    result = {
        **{field: manifest[field] for field in IDENTITY_FIELDS},
        "tool_id": key,
        "status": "BLOCKED",
        "commands": [
            {
                **{k: v for k, v in operation.items() if k in {"argv", "cwd", "timeout_seconds"}},
                "exit_code": None,
                "error": "Stopped without a confirmed exit status: " + str(evidence),
                "stdout_excerpt": "",
                "stderr_excerpt": "",
                "stdout_truncated": False,
                "stderr_truncated": False,
            }
        ],
    }
    del facts["executing"][key]
    facts.setdefault("checks", {}).setdefault(key, []).append(result)
    facts.setdefault("check_reconciliations", {})[original] = result
    return result


def build_parser(parser: argparse.ArgumentParser | None = None) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=[
            "init",
            "status",
            "history",
            "diagram",
            "assignment",
            "bind",
            "packet",
            "note",
            "lost",
            "stopped",
            "check",
            "reconcile-check",
            "cancel",
            "submit",
            "finish",
            "clean",
            "report",
        ],
    )
    parser.add_argument("--run", required=True, help="Stable intake name or returned process ID")
    parser.add_argument(
        "--input", type=Path, help="Delivered review subject, report or QA evidence"
    )
    parser.add_argument("--id", help="Direction or registered check ID")
    parser.add_argument("--dispatch", help="Original worker ticket")
    parser.add_argument("--handle", help="Bound worker session handle")
    parser.add_argument(
        "--original-request", help="Reservation being reconciled after confirmed stop"
    )
    parser.add_argument("--evidence", help="Partial observation")
    parser.add_argument("--request", help="Stable mutation ID; reuse after a lost reply")
    return parser


def operate(args: argparse.Namespace) -> dict[str, Any]:
    name = args.run
    if args.dispatch and args.action in {
        "assignment",
        "history",
        "report",
        "check",
        "reconcile-check",
        "cancel",
        "finish",
        "init",
        "clean",
        "diagram",
    }:
        raise ValueError("The worker ticket permits only its own packet, observations or report")
    if args.action == "status" and args.dispatch:
        args.action = "packet"
    if args.action == "init":
        require(args.input, "Supply the authorized review --input")
        return initialize(args.input, name)
    saved = record(name)
    repo = current_database().processes
    if args.action == "history":
        return {
            "run_id": saved.run_id,
            "subject": saved.subject,
            "state": saved.state.model_dump(),
            "events": repo.history(Path.cwd(), saved.run_id),
        }
    if args.action == "diagram":
        graph = engine.program(saved.process, tuple(sorted(saved.definitions.items())))
        return {"run_id": saved.run_id, "mermaid": graph.render(direction="LR")}
    if args.action == "clean":
        require(saved.state.terminal, "Only a completed review can be cleaned")
        return {"run_id": saved.run_id, "history": "retained"}
    if args.action == "report":
        require(saved.state.facts.get("final"), "No QA report yet")
        return {"markdown": render_report_text(saved.state.facts["final"][-1]["result"])}
    if args.action == "status":
        return {"run_id": saved.run_id, **inspect(saved, subject.fresh(saved.subject))}
    if args.action == "packet":
        worker = engine.active(saved, args.id, args.dispatch)
        require(
            args.handle and worker.handle == args.handle and worker.status == "running",
            "Need the live ticket and its bound handle",
        )
        return {
            **packet(saved, subject.fresh(saved.subject), worker),
            "observations": worker.evidence,
        }
    request = args.request or uuid4().hex
    require(not request.startswith("internal:"), "Reserved internal request namespace")
    if args.action == "check":
        return check(name, args.id, request)
    value = load_object(args.input) if args.input else {}

    def apply(current: ProcessRun, _: engine.Offer) -> dict[str, Any]:
        if args.action == "reconcile-check":
            return reconcile_check(current, args.id, args.original_request, args.evidence)
        if args.action == "cancel":
            require(
                args.evidence
                and not current.state.facts.get("executing")
                and not any(
                    a.status in {"reserved", "running", "unknown"}
                    for group in current.state.attempts.values()
                    for a in group
                ),
                "Reconcile active checks and stop outstanding workers before cancellation",
            )
            current.state.terminal = "cancelled"
            current.state.facts["reason"] = args.evidence
            return {"terminal": "cancelled", "reason": args.evidence}
        manifest = (
            current.subject["manifest"]
            if args.action == "stopped"
            else subject.fresh(current.subject)
        )
        if args.action != "finish":
            return worker_action(current, manifest, args, value)
        require(
            select(current, "verification").action == "finish", "Final review gate is unavailable"
        )
        require(args.input, "Supply QA evidence")
        facts = current.state.facts
        require(not facts.get("executing"), "Reconcile outstanding checks before QA")
        result, exit_code = validate_protocol(
            argparse.Namespace(
                manifest=manifest,
                qa_output=value,
                lens_output=[b[-1] for b in facts.get("reports", {}).values()],
                tool_result=[b[-1] for b in facts.get("checks", {}).values()],
            )
        )
        subject.fresh(current.subject)
        facts.setdefault("final", []).append({"qa": value, "result": result})
        if result["pipeline_status"] == "COMPLETE":
            current.state.terminal = "completed"
            current.state.phase = "archived"
        return dict(result)

    inputs = {
        "id": args.id,
        "dispatch": args.dispatch,
        "handle": args.handle,
        "evidence": args.evidence,
        "value": value,
        "original_request": args.original_request,
    }
    if args.action == "reconcile-check":
        with lock(check_lock(Path.cwd(), saved.run_id, args.id)):
            return engine.change(
                Path.cwd(), "code-review", saved.run_id, request, args.action, inputs, apply
            )
    return engine.change(
        Path.cwd(), "code-review", saved.run_id, request, args.action, inputs, apply
    )


def run(args: argparse.Namespace) -> int:
    try:
        emit_json(operate(args))
    except (
        ValueError,
        OSError,
        KeyError,
        subprocess.CalledProcessError,
        StopIteration,
        TypeError,
    ) as exc:
        if getattr(args, "json", False):
            from factory.cli_output import emit_error

            emit_error("review_run", str(exc))
        else:
            import sys

            print(str(exc) or "Unknown review assignment", file=sys.stderr)
        return 1
    return 0
