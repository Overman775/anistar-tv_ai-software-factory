"""Public standalone graph commands. Reopen a process by its own ID in the checkout."""

import argparse
from pathlib import Path
from typing import Any

from factory import file_reader
from factory.cli_output import emit_error, emit_json
from factory.context import context
from factory.database.provider import current_database
from factory.paths import FACTORY_ROOT
from factory.processes import bundle, decompose, engine, planning, publication
from factory.processes.records import Process, ProcessRun
from factory.project.profile_io import parse_yaml
from factory.runtime.workflow_config import default_profile, load_config
from factory.runtime.workflow_core import require


def build_parser(parser: argparse.ArgumentParser | None = None) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action",
        choices=[
            "init",
            "validate",
            "manifest",
            "deliver",
            "authorize-repair",
            "confirm-files",
            "packet",
            "status",
            "history",
            "diagram",
            "claim",
            "bind",
            "lost",
            "stopped",
            "pause",
            "resume",
            "cancel",
            "clean",
            "question",
            "note",
            "report",
            "answer",
            "review",
            "prepare-publication",
            "publish",
        ],
    )
    parser.add_argument("--workspace", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, default=FACTORY_ROOT / "factory.yaml")
    parser.add_argument("--run", help="Standalone process ID")
    parser.add_argument("--request", help="Stable request ID for a mutation")
    parser.add_argument("--task", help="Authorized planning goal")
    parser.add_argument("--destination", help="Public artifact path relative to the workspace")
    parser.add_argument(
        "--previous", help="Authorized existing plan content SHA-256 for replacement"
    )
    parser.add_argument(
        "--continuation", choices=["none", "implement", "decompose"], default="none"
    )
    parser.add_argument("--authorization", help="Cited owner authority for the continuation")
    parser.add_argument("--dispatch", help="Exact worker ticket")
    parser.add_argument("--handle", help="Observed worker handle")
    parser.add_argument("--actor", help="Independent coordinator identity")
    parser.add_argument("--outcome", help="Typed worker result or coordinator verdict")
    parser.add_argument("--file", type=Path, help="Exact delivered UTF-8 artifact bytes")
    parser.add_argument(
        "--sketch", type=Path, help="Proposed planning steps and dependencies in YAML"
    )
    parser.add_argument("--evidence", help="Observation, reason, question or answer")
    parser.add_argument("--cite", action="append", help="Source file:line, repeatable")
    parser.add_argument("--plan", help="Approved plan path inside the checkout")
    parser.add_argument("--path", help="Relative name of the delivered artifact")
    parser.add_argument("--allow", dest="paths", action="append", help="An authorized repair path")
    parser.add_argument("--source", help="Required source that could not be read")
    parser.add_argument("--basis", help="Exact candidate hash for the independent review")
    parser.add_argument("--reference", help="Owner decision or supporting reference")
    return parser


def initialize(root: Path, args: argparse.Namespace, process: Process) -> dict[str, Any]:
    require(args.request, "Start with a stable --request")
    config = args.config.resolve()
    intake = {
        k: getattr(args, k)
        for k in ("task", "plan", "destination", "continuation", "previous", "authorization")
    }
    intake["config"] = str(config)
    repo = current_database().processes
    run_id = engine.identifier(process, args.request)
    if repo.exists(root, run_id):
        prior = repo.get(root, run_id)
        require(prior.subject["intake"] == intake, "Intake request already binds another subject")
        return engine.status(prior)
    if process == "decompose":
        subject = decompose.subject(root, config, args.plan, args.destination, args.authorization)
        return engine.status(
            engine.start(
                root, process, args.request, {**subject, "intake": intake}, config.parent / "graphs"
            )
        )
    require(
        args.request and args.task and args.destination,
        "Start with --request, --task and --destination",
    )
    require(
        args.continuation == "none" or args.authorization,
        "Continuation requires cited owner authority",
    )
    target = publication.destination(root, args.destination)
    existing = publication.identity(target)
    require(
        (existing is None and not args.previous)
        or (existing and existing["digest"] == args.previous),
        "Existing public plan requires exact previous revision authority",
    )
    subject = {
        "intake": intake,
        "task": args.task,
        "destination": args.destination,
        "previous_identity": existing,
        "previous_text": file_reader.read_bytes(target).decode() if existing else None,
        "continuation": args.continuation,
        "authorization": args.authorization,
        "config": str(args.config.resolve()),
        "workspace": str(root),
        "policy_hash": planning.policy_basis(config, root),
    }
    record = engine.start(
        root, process, args.request, subject, args.config.resolve().parent / "graphs"
    )
    return engine.status(record)


def control(
    root: Path, run: ProcessRun, selected: engine.Offer, action: str, data: dict[str, Any]
) -> dict[str, Any]:
    if action == "claim":
        return engine.claim(run, selected)
    if action in {"bind", "lost", "stopped"}:
        attempt = engine.ticket(run, data.get("dispatch"))
        if action == "bind":
            require(
                attempt.node == selected.action, "Cannot bind a worker from a different active node"
            )
        if action == "bind" and run.process == "decompose":
            if selected.action in {"repair", "recheck"}:
                require(
                    data.get("handle") == run.state.facts.get("reviewer"),
                    "Original TaskReviewer must return",
                )
            if selected.action in {"review", "recheck"}:
                decompose.require_independent(run, data.get("handle"))

        require(attempt.status in {"reserved", "running", "unknown"}, "Attempt already closed")
        if action == "bind":
            require(
                data.get("handle") and attempt.handle in {None, data["handle"]},
                "Observe and bind the original worker handle",
            )
            attempt.handle = data["handle"]
            attempt.status = "running"
        else:
            require(data.get("evidence"), "Need transport evidence")
            attempt.evidence.append({"transport": action, "evidence": data["evidence"]})
            attempt.status = "unknown" if action == "lost" else "failed"
        return attempt.model_dump()
    if action == "resume":
        require(run.state.paused, "Run is not paused")
        run.state.paused = None
    elif action == "pause":
        require(data.get("evidence"), "Give a reason for the pause")
        run.state.paused = data["evidence"]
    elif action == "cancel":
        require(
            data.get("evidence")
            and not any(
                a.status in {"reserved", "running", "unknown"}
                for bucket in run.state.attempts.values()
                for a in bucket
            ),
            "Confirm outstanding workers stopped and supply a reason",
        )
        if op := run.state.facts.get("publication"):
            publication.cancel(root, op)
        run.state.terminal = "cancelled"
        run.state.facts["reason"] = data["evidence"]
    return {"phase": run.state.phase, "paused": run.state.paused, "terminal": run.state.terminal}


def worker_packet(root: Path, run: ProcessRun, args: argparse.Namespace) -> dict[str, Any]:
    process = run.process
    attempt = engine.ticket(run, args.dispatch)
    require(
        attempt.status == "running" and attempt.handle == args.handle,
        "Need the bound worker handle and ticket",
    )
    require(engine.resolve(run).action == attempt.node, "Assignment is not the current node")
    if process == "decompose":
        bundle.fresh(run)
    else:
        planning.fresh(run)
    config = run.subject["config"]
    source = {"kind": process, "run_id": run.run_id}
    assignment: dict[str, Any] = {"source": source}
    if attempt.role == "task-reviewer":
        assignment["decompose_mode"] = "repair" if attempt.node == "repair" else "review"
    instructions = context.build(
        load_config(config),
        root,
        default_profile(config, attempt.role),
        attempt.role,
        process,
        assignment,
    )
    result: dict[str, Any] = {
        "context": instructions,
        "run_id": run.run_id,
        "dispatch": attempt.dispatch,
        "role": attempt.role,
        "subject": run.subject,
        "observations": attempt.evidence,
    }
    prefix = [process, "run"]
    identity = ["--run", run.run_id, "--dispatch", attempt.dispatch]
    common = [*identity, "--request", "REQUEST_ID"]
    result["status_command"] = [*prefix, "status", *identity, "--handle", attempt.handle]
    if attempt.role == "architect":
        result["returns"] = {
            "PLAN_READY": [
                *prefix,
                "report",
                *common,
                "--outcome",
                "PLAN_READY",
                "--file",
                "DRAFT",
                "--evidence",
                "BASIS",
            ],
            "NEEDS_USER_DECISION": [
                *prefix,
                "report",
                *common,
                "--outcome",
                "NEEDS_USER_DECISION",
                "--evidence",
                "QUESTION",
            ],
            "BLOCKED_REQUIREMENTS": [
                *prefix,
                "report",
                *common,
                "--outcome",
                "BLOCKED_REQUIREMENTS",
                "--evidence",
                "MISSING_FACT",
            ],
        }
    elif attempt.role == "code-explorer":
        result["returns"] = {
            "ANALYSIS_READY": [
                *prefix,
                "report",
                *common,
                "--outcome",
                "ANALYSIS_READY",
                "--cite",
                "FILE:LINE",
                "--evidence",
                "OBSERVATION",
            ],
            "BLOCKED_EXTERNAL_SOURCE": [
                *prefix,
                "report",
                *common,
                "--outcome",
                "BLOCKED_EXTERNAL_SOURCE",
                "--source",
                "SOURCE",
                "--evidence",
                "REASON",
            ],
        }
    elif attempt.node in {"generate", "repair"}:
        result["returns"] = {
            "file": [*prefix, "deliver", *common, "--path", "RELATIVE_PATH", "--file", "FILE"],
            "manifest": [*prefix, "manifest", *common, "--file", "MANIFEST"],
            "SEMANTIC_GAP": [
                *prefix,
                "report",
                *common,
                "--outcome",
                "SEMANTIC_GAP",
                "--evidence",
                "QUESTION",
            ],
        }
    else:
        result["returns"] = {"assessment": [*prefix, "report", *common, "--file", "REVIEW_REPORT"]}
    if process == "planning":
        facts = run.state.facts
        fields = (
            ("question",)
            if attempt.role == "code-explorer"
            else ("question", "analysis", "answers", "candidate", "review")
        )
        result["materials"] = {k: facts[k] for k in fields if k in facts}
    if process == "decompose":
        result.update(progress=decompose.progress(run), files=run.state.facts.get("files", {}))
        if attempt.node in {"review", "recheck"}:
            result["review_request"] = decompose.review_request(run, attempt)
        if attempt.node == "repair":
            result.update(
                allowed=run.state.facts["allowed"],
                findings=run.state.facts["reviews"][-1]["report"]["findings"],
            )
    return result


def operate(args: argparse.Namespace, process: Process) -> dict[str, Any]:
    root = args.workspace.resolve()
    if args.action == "init":
        return initialize(root, args, process)
    require(args.run, "Select --run")
    repo = current_database().processes
    run = repo.get(root, args.run)
    require(run.process == process, "Run belongs to another process")
    if args.dispatch and args.action in {"status", "packet"}:
        attempt = engine.ticket(run, args.dispatch)
        require(args.handle and args.handle == attempt.handle, "Use the bound worker handle")
        incompatible = engine.handlers() != run.handlers
        if (
            incompatible
            or run.state.terminal
            or run.state.paused
            or attempt.status != "running"
            or engine.resolve(run).action != attempt.node
        ):
            return {
                "run_id": run.run_id,
                "dispatch": attempt.dispatch,
                "ticket_status": attempt.status,
                "action": "wait" if not run.state.terminal else "closed",
                "reason": "Restore the registered process handlers"
                if incompatible
                else run.state.paused or run.state.facts.get("reason") or run.state.phase,
            }
        args.action = "packet"
    if args.dispatch and args.action not in {
        "packet",
        "report",
        "note",
        "deliver",
        "manifest",
        "bind",
        "lost",
        "stopped",
        "question",
    }:
        raise ValueError("Use the coordinator for this operation")
    if args.action == "packet":
        return worker_packet(root, run, args)
    if args.action == "status" and process == "decompose":
        return {
            **engine.status(run),
            **decompose.progress(run),
            "gates": run.state.facts.get("gates", []),
        }
    if args.action == "status":
        return {
            **engine.status(run),
            "facts": {
                k: v
                for k, v in run.state.facts.items()
                if k not in {"publication", "candidate", "approved"}
            },
            "candidate": {
                k: v for k, v in run.state.facts.get("candidate", {}).items() if k != "text"
            },
        }
    if args.action == "history":
        return {
            "status": engine.status(run, verify=False),
            "subject": run.subject,
            "definitions": run.definitions,
            "attempts": run.state.model_dump()["attempts"],
            "facts": run.state.facts,
            "events": repo.history(root, args.run),
        }
    if args.action == "diagram":
        return {
            "run_id": args.run,
            "mermaid": engine.program(process, tuple(sorted(run.definitions.items()))).render(
                direction="LR"
            ),
        }
    if args.action == "clean":
        require(run.state.terminal, "Close the process before cleanup")
        if op := run.state.facts.get("publication"):
            if run.state.terminal == "cancelled":
                publication.discard_cancelled(root, op)
            else:
                publication.release(root, op)
        return {"run_id": args.run, "history": "retained"}
    require(args.request, "Use --request for a process transition")
    data = {
        k: v
        for k, v in vars(args).items()
        if k
        in {
            "path",
            "paths",
            "dispatch",
            "handle",
            "outcome",
            "evidence",
            "basis",
            "reference",
            "source",
            "cite",
            "actor",
        }
        and v is not None
    }
    if args.file:
        data["content"] = file_reader.read_bytes(args.file).decode()
    if args.sketch:
        data["sketch"] = parse_yaml(file_reader.read_bytes(args.sketch).decode())

    def apply(record: ProcessRun, selected: engine.Offer) -> dict[str, Any]:
        if process == "planning" and args.action not in {"lost", "stopped", "pause", "cancel"}:
            planning.fresh(record)
        if args.action in {"claim", "bind", "lost", "stopped", "pause", "resume", "cancel"}:
            if process == "decompose" and args.action in {"claim", "bind"}:
                bundle.fresh(record)
            return control(root, record, selected, args.action, data)
        perform = decompose.perform if process == "decompose" else planning.perform
        return perform(root, record, selected, args.action, data)

    return engine.change(root, process, args.run, args.request, args.action, data, apply)


def execute(process: Process, args: argparse.Namespace) -> int:
    try:
        emit_json(operate(args, process))
        return 0
    except (ValueError, OSError, KeyError) as exc:
        emit_error(process + "_run", str(exc))
        return 1
