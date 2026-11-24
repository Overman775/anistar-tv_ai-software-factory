"""Project-local factory commands and their discoverable help."""

from __future__ import annotations

import argparse
import sqlite3
import sys
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from functools import partial

from pydantic import ValidationError

from factory import quality
from factory.adapters import acpx_adapter
from factory.cli_help import (
    ArgumentParser,
    add_setup_options,
    children,
    describe,
    path_for,
    render_help,
    topic_names,
)
from factory.cli_output import (
    LAUNCHER,
    configure_process_io,
    emit_error,
    json_requested,
    output_mode,
)
from factory.cli_topics import ERROR_GUIDANCE, command_summary, help_details
from factory.context import context
from factory.decompose import assemble, generate_task_graph, source_lock
from factory.decompose.staging import metadata
from factory.diagnostics.records import error_code
from factory.gates import catalog
from factory.github import fetch_note, fetch_recent_notes
from factory.planning import validate_plan
from factory.project import project
from factory.review import review_run, run_tool_checks, validate_review_protocol
from factory.runtime import workflow_cli
from factory.runtime.knowledge import cli as lessons
from factory.runtime.observability import cli as telemetry

type Handler = Callable[[argparse.Namespace], int | None]
type ParserHandler = Callable[[argparse.Namespace, argparse.ArgumentParser], int | None]
type Configure = Callable[[argparse.ArgumentParser], argparse.ArgumentParser]


@dataclass(frozen=True)
class Command:
    name: str
    configure: Configure
    bind: Callable[[argparse.ArgumentParser], Handler]


@dataclass(frozen=True)
class Group:
    name: str
    commands: tuple[Command | Group, ...]


def command(name: str, configure: Configure, run: Handler) -> Command:
    return Command(name, configure, lambda _parser: run)


def parser_command(name: str, configure: Configure, run: ParserHandler) -> Command:
    def bind(parser: argparse.ArgumentParser) -> Handler:
        return lambda args: run(args, parser)

    return Command(name, configure, bind)


def routes() -> tuple[Command | Group, ...]:
    return (
        parser_command("workflow", workflow_cli.build_parser, workflow_cli.run),
        parser_command("checks", partial(workflow_cli.build_parser, checks=True), workflow_cli.run),
        parser_command("lessons", lessons.command_parser, lessons.run),
        parser_command("project", project.build_parser, project.run),
        parser_command("context", context.build_parser, context.run),
        command("catalog", catalog.build_parser, catalog.run),
        command("telemetry", telemetry.build_parser, telemetry.run),
        parser_command("acpx", acpx_adapter.build_parser, acpx_adapter.run),
        Group("tooling", (parser_command("check", quality.build_parser, quality.run),)),
        Group(
            "planning",
            (command("validate", validate_plan.build_parser, validate_plan.run),),
        ),
        Group(
            "decompose",
            (
                command("graph", generate_task_graph.build_parser, generate_task_graph.run),
                parser_command("assemble", assemble.build_parser, assemble.run),
                parser_command("metadata", metadata.build_parser, metadata.run),
                command("source-lock", source_lock.build_parser, source_lock.run),
            ),
        ),
        Group(
            "review",
            (
                command("run", review_run.build_parser, review_run.run),
                command(
                    "validate",
                    validate_review_protocol.build_parser,
                    validate_review_protocol.run,
                ),
                command("checks", run_tool_checks.build_parser, run_tool_checks.run),
            ),
        ),
        Group(
            "pr",
            (
                command("note", fetch_note.build_parser, fetch_note.run),
                command(
                    "recent-notes",
                    fetch_recent_notes.build_parser,
                    fetch_recent_notes.run,
                ),
            ),
        ),
    )


def add_routes(
    subcommands: argparse._SubParsersAction[argparse.ArgumentParser],
    path: tuple[str, ...],
    commands: tuple[Command | Group, ...],
) -> None:
    for command in commands:
        command_path = (*path, command.name)
        summary = command_summary(command_path)
        parser = subcommands.add_parser(command.name, help=summary)
        if isinstance(command, Group):
            children = parser.add_subparsers(required=True, title="commands", metavar="COMMAND")
            add_routes(children, command_path, command.commands)
        else:
            command.configure(parser)
            parser.set_defaults(_factory_handler=command.bind(parser))


def build_parser() -> argparse.ArgumentParser:
    parser: argparse.ArgumentParser = ArgumentParser(
        prog=LAUNCHER,
        description=help_details(()).description,
        epilog=f"Start with `{LAUNCHER} help agents`. Use `{LAUNCHER} help --json` for the command catalog.",
        allow_abbrev=False,
    )
    subcommands = parser.add_subparsers(title="commands", metavar="COMMAND")
    help_parser = subcommands.add_parser("help", help=command_summary(("help",)))
    help_parser.add_argument("path", nargs="*", metavar="COMMAND_OR_TOPIC")
    help_parser.set_defaults(
        _factory_handler=lambda args: render_help(parser, args.path, as_json=args.json)
    )
    help_parser.epilog = "Topics: " + ", ".join(topic_names()) + "."
    setup = subcommands.add_parser("setup", help=command_summary(("setup",)))
    add_setup_options(setup)
    setup.set_defaults(
        _factory_handler=lambda _args: setup.error("Use the project launcher to set up Python")
    )

    add_routes(subcommands, path_for(parser), routes())
    prepare_help(parser)
    return parser


def prepare_help(
    parser: argparse.ArgumentParser, ancestors: tuple[argparse.ArgumentParser, ...] = ()
) -> None:
    describe(parser, ancestors)
    for child in dict.fromkeys(children(parser).values()):
        prepare_help(child, (*ancestors, parser))


def normalize_help_args(args: list[str]) -> list[str]:
    # The help path has variable length, so argparse cannot intermix it with options.
    before_delimiter = args.index("--") if "--" in args else len(args)
    options = args[:before_delimiter]
    remaining = [arg for arg in options if arg != "--json"]
    if remaining[:1] == ["help"] and len(remaining) != len(options):
        return ["--json", *remaining, *args[before_delimiter:]]
    return args


def main(argv: Sequence[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    args = normalize_help_args(args)
    as_json = json_requested(args)
    with output_mode(as_json):
        try:
            parser = build_parser()
            namespace = parser.parse_args(args, namespace=argparse.Namespace(json=as_json))
            handler: Handler | None = getattr(namespace, "_factory_handler", None)
            if handler is None:
                parser.print_help()
                return 0
            return handler(namespace) or 0
        except Exception as exc:
            if as_json:
                report_error(exc)
            elif isinstance(exc, (OSError, ValueError, KeyError)):
                print(f"BLOCKED: {exc}", file=sys.stderr)
            else:
                raise
            return 1


def report_error(exc: Exception) -> None:
    code = error_code(exc)
    if isinstance(exc, ValidationError):
        message = "Input does not match the command contract."
    elif isinstance(exc, (OSError, ValueError, KeyError)):
        message = str(exc)
    elif isinstance(exc, sqlite3.Error):
        message = "The command could not access its SQLite data."
    else:
        message = "The command failed while processing its inputs or runtime state."
    emit_error(code, message, next_action=ERROR_GUIDANCE.get(code))


if __name__ == "__main__":
    configure_process_io(sys.argv[1:])
    sys.exit(main())
