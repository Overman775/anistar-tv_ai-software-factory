"""Commands shared by native and ACP workers and the Teacher role."""

import argparse
import json
import sys
from pathlib import Path

from factory.cli_output import json_mode
from factory.database.port import DatabaseBackend
from factory.database.provider import current_database
from factory.diagnostics.events import event
from factory.logging_config import diagnostic_operation
from factory.runtime import teacher
from factory.runtime.knowledge.case_search import search_cases
from factory.runtime.lessons import Lesson, search_lessons
from factory.runtime.observability import lesson_telemetry
from factory.runtime.teacher import owner_instructions as owner_instructions
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import read_json, require
from factory.runtime.workspace import checkout_ref


def teacher_launch(root: Path) -> dict[str, object]:
    config = load_config(root / ".factory/factory.yaml")
    name = config["_defaults"].get("teacher")
    if name is None:
        raise ValueError("Configure profiles.teacher in .factory/factory.yaml")
    profile = config["profiles"][name]
    model = config["models"][profile["model"]]
    require(model["id"] and model.get("effort"), "Teacher requires an explicit model ID and effort")
    adapter = config["adapters"][profile["adapter"]]
    return {"profile_name": name, "profile": profile, "model": model, "adapter": adapter}


def capture_case(
    root: Path, reference: str, observation: str, *, database: DatabaseBackend | None = None
) -> str:
    """Read the CLI reference file and dispatch the Teacher use case."""
    database = current_database() if database is None else database
    return teacher.capture_case(
        root, read_json(reference), observation, history=database.history, jobs=database.teacher
    )


def command_parser(
    parser: argparse.ArgumentParser | None = None,
) -> argparse.ArgumentParser:
    parser = parser or argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path.cwd())
    sub = parser.add_subparsers(dest="command", required=True)
    search = sub.add_parser("search", help="Search active lessons and optionally history")
    search.add_argument("query")
    search.add_argument("--run", help="Run ID from the assignment packet")
    search.add_argument("--dispatch", help="Dispatch ID from the same packet")
    trace = sub.add_parser("telemetry", help="Read the local lesson evidence projection as JSON")
    trace.add_argument("--json", action="store_true", help=argparse.SUPPRESS)
    trace.add_argument("--run", help="Limit to this run and its final Teacher review")
    trace.add_argument("--limit", type=int, default=20, help="Maximum rows per section (1–200)")
    search.add_argument(
        "--english", default="", help="Optional English wording for cross-language matches"
    )
    search.add_argument(
        "--include-history",
        action="store_true",
        help="Also search accepted archived task reports from this checkout",
    )
    capture = sub.add_parser("capture-case", help="Send demonstrated reuse to Teacher")
    capture.add_argument("reference", help="File containing the result's exact report_ref object")
    capture.add_argument(
        "observation", help="Current occurrence, evidence and what proved reusable"
    )
    feedback = sub.add_parser(
        "feedback", help="Read local lesson searches for one accepted incident"
    )
    feedback.add_argument("event")
    feedback.add_argument("incident")
    sub.add_parser("pending")
    sub.add_parser("waiting")
    sub.add_parser("route").add_argument("event")
    park = sub.add_parser("wait-owner")
    park.add_argument("event")
    park.add_argument("question")
    sub.add_parser("teacher-launch")
    for kind in ("retro", "user"):
        intake = sub.add_parser(kind)
        intake.add_argument("incident")
        intake.add_argument("source")
        intake.add_argument("observation", help="Relevant excerpt from the source")
        if kind == "retro":
            intake.add_argument(
                "--confirmed",
                action="store_true",
                required=True,
                help="The owner requested Teacher for this specific retro finding",
            )
        else:
            mode = intake.add_mutually_exclusive_group()
            mode.add_argument("--new-observation", action="store_const", const=True)
            mode.add_argument("--edit", metavar="LESSON_ID")
            mode.add_argument("--audit", dest="operation", action="store_const", const="audit")
            mode.add_argument("--capture", dest="operation", action="store_const", const="capture")
            mode.add_argument("--delete", metavar="LESSON_ID", help="Explicit deletion target")
    delete = sub.add_parser("delete")
    delete.add_argument("event")
    delete.add_argument("--revision", required=True)
    for command in ("packet", "complete", "publish"):
        child = sub.add_parser(command)
        child.add_argument("event")
        if command == "complete":
            child.add_argument(
                "--reason", help="Short outcome, especially when no card was published"
            )
            child.add_argument(
                "--cancelled-by", help="Owner message resolving an outstanding deletion"
            )
        if command == "publish":
            child.add_argument("--incident", help="Incident ID from a completed run packet")
            child.add_argument("lesson", help="JSON path or - for stdin")
            child.add_argument("--revision", help="Expected current lesson hash for updates")
    return parser


def main() -> None:
    parser = command_parser()
    run(parser.parse_args(), parser)


def run(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
    root = args.workspace.resolve()
    database = current_database()
    result: object
    try:
        operation = "search_lessons" if args.command == "search" else args.command
        with diagnostic_operation(args.workspace, "lessons." + operation):
            if args.command == "search":
                query = f"{args.query} {args.english}"
                matches = [
                    match.model_dump()
                    for match in search_lessons(
                        root,
                        query,
                        run_id=args.run,
                        dispatch_id=args.dispatch,
                        index=database.lessons,
                        traces=database.traces,
                    )
                ]
                if args.include_history:
                    cases, skipped = search_cases(root, query, index=database.cases)
                    matches.extend(case.model_dump() for case in cases)
                    if skipped:
                        event("history_skipped")
                    for run_id in skipped:
                        print(f"Skipped unreadable archived evidence for {run_id}", file=sys.stderr)
                result = matches
            elif args.command == "telemetry":
                result = lesson_telemetry.report(root, args.run, args.limit, store=database.traces)
            elif args.command == "capture-case":
                result = capture_case(root, args.reference, args.observation, database=database)
            elif args.command == "teacher-launch":
                result = teacher_launch(root)
            elif args.command in {"pending", "waiting"}:
                result = teacher.pending(
                    root, waiting=args.command == "waiting", jobs=database.teacher
                )
            elif args.command == "route":
                result = teacher.route(root, args.event, jobs=database.teacher)
            elif args.command == "wait-owner":
                teacher.park(root, args.event, args.question, jobs=database.teacher)
                result = {"waiting": True}
            elif args.command in {"retro", "user"}:
                result = teacher.enqueue(
                    root,
                    teacher.TeacherJob(
                        kind=args.command,
                        operation=(
                            "capture"
                            if args.command == "retro"
                            else "edit"
                            if args.edit
                            else args.operation or "capture"
                        ),
                        edit_target=getattr(args, "edit", None),
                        new_observation=getattr(args, "new_observation", None),
                        delete_target=getattr(args, "delete", None),
                        incident=args.incident,
                        source=args.source,
                        observation=args.observation,
                        checkout=checkout_ref(root),
                        user_instructions=owner_instructions(root),
                    ),
                    jobs=database.teacher,
                )
            elif args.command == "feedback":
                result = [
                    row.model_dump()
                    for row in teacher.search_feedback(
                        root, args.event, args.incident, jobs=database.teacher
                    )
                ]
            elif args.command == "packet":
                result = teacher.packet(root, args.event, jobs=database.teacher)
            elif args.command == "delete":
                teacher.delete(root, args.event, args.revision, jobs=database.teacher)
                result = {"deleted": True}
            elif args.command == "publish":
                raw = json.load(sys.stdin) if args.lesson == "-" else read_json(args.lesson)
                result = teacher.apply(
                    root,
                    args.event,
                    Lesson.model_validate(raw),
                    args.revision,
                    args.incident,
                    jobs=database.teacher,
                )
            else:
                teacher.complete(
                    root, args.event, args.cancelled_by, args.reason, jobs=database.teacher
                )
                result = {"complete": True}
            print(json.dumps(result, ensure_ascii=False))
    except (OSError, ValueError) as exc:
        if json_mode.get():
            raise
        parser.exit(1, f"Cannot process lessons: {exc}\n")
