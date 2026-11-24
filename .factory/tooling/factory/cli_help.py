"""Render the live parser as command help and a versioned JSON catalog."""

from __future__ import annotations

import argparse
from pathlib import Path
from textwrap import fill
from typing import TYPE_CHECKING, Never, cast

from factory.cli_output import LAUNCHER, emit_error, emit_json, json_mode
from factory.cli_topics import ERROR_GUIDANCE, GUIDES, help_details

if TYPE_CHECKING:
    from _typeshed import SupportsWrite

PROGRAM = "cli"
SCHEMA_VERSION = 1


class ArgumentParser(argparse.ArgumentParser):
    """Render help and parser failures in the selected output format."""

    _ancestors: tuple[argparse.ArgumentParser, ...] = ()

    def print_help(self, file: SupportsWrite[str] | None = None) -> None:
        if json_mode.get():
            render_catalog(self, self._ancestors)
        else:
            super().print_help(file)

    def error(self, message: str) -> Never:
        if json_mode.get():
            usage = f"Run `{self.prog} --help` for accepted arguments."
            emit_error("usage_error", message, next_action=usage)
            super().exit(2)
        super().error(message)

    def exit(self, status: int = 0, message: str | None = None) -> Never:
        if json_mode.get() and status and message is not None:
            emit_error(
                "invalid_operation",
                message.strip().removeprefix("BLOCKED: "),
                next_action=ERROR_GUIDANCE["invalid_operation"],
            )
            super().exit(status)
        super().exit(status, message)


def add_setup_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--dev", action="store_true", help="Include checker dependencies")


class SetupParser(ArgumentParser):
    """Publish the same setup contract before the project dependencies exist."""

    def print_help(self, file: SupportsWrite[str] | None = None) -> None:
        if json_mode.get():
            emit_json(catalog_document(self))
        else:
            super().print_help(file)


def setup_parser() -> SetupParser:
    parser = SetupParser(prog=f"{LAUNCHER} setup", allow_abbrev=False)
    add_setup_options(parser)
    describe(parser)
    return parser


def subcommands(
    parser: argparse.ArgumentParser,
) -> argparse._SubParsersAction[argparse.ArgumentParser] | None:
    for action in parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            return cast("argparse._SubParsersAction[argparse.ArgumentParser]", action)
    return None


def children(parser: argparse.ArgumentParser) -> dict[str, argparse.ArgumentParser]:
    action = subcommands(parser)
    return action.choices if action is not None else {}


def topic_names() -> tuple[str, ...]:
    return tuple(GUIDES)


def path_for(parser: argparse.ArgumentParser) -> tuple[str, ...]:
    return tuple(parser.prog.split()[1:])


def describe(
    parser: argparse.ArgumentParser,
    ancestors: tuple[argparse.ArgumentParser, ...] = (),
) -> None:
    if isinstance(parser, ArgumentParser):
        parser._ancestors = ancestors
    json_help = "Emit a single JSON document"
    existing = next(
        (action for action in parser._actions if "--json" in action.option_strings), None
    )
    if existing is None:
        parser.add_argument(
            "--json", action="store_true", default=argparse.SUPPRESS, help=json_help
        )
    else:
        existing.default = argparse.SUPPRESS
        existing.help = json_help
    parser.allow_abbrev = False
    parser.color = False
    path = path_for(parser)
    details = help_details(path)
    if path and details.description:
        parser.description = details.description
    if (command_group := subcommands(parser)) is not None and path:
        command_group.metavar = "COMMAND"
        command_group._choices_actions = [
            command_group._ChoicesPseudoAction(
                path_for(child)[-1],
                [
                    name
                    for name in command_group.choices
                    if name != path_for(child)[-1] and command_group.choices[name] is child
                ],
                help_details(path_for(child)).description,
            )
            for child in dict.fromkeys(command_group.choices.values())
        ]
    if not path or path == ("help",):
        return
    sections = []
    if ancestors and group_actions(ancestors[-1]):
        group = " ".join(path[:-1])
        sections.append(f"Group options go before the command. See `{LAUNCHER} {group} --help`.")
    if details.requirements:
        sections.append(fill("Requires: " + details.requirements, width=86))
    if details.effects:
        sections.append(fill("Effects: " + details.effects, width=86))
    if has_dry_run(parser):
        sections.append(f"Dry run: supported with --dry-run. See `{LAUNCHER} help dry-run`.")
    if details.examples:
        sections.append("Examples:\n  " + "\n  ".join(details.examples))
    if sections:
        parser.formatter_class = argparse.RawDescriptionHelpFormatter
        parser.epilog = "\n\n".join(sections)


def has_dry_run(parser: argparse.ArgumentParser) -> bool:
    return any("--dry-run" in action.option_strings for action in parser._actions)


def actions(parser: argparse.ArgumentParser) -> list[argparse.Action]:
    return [
        action
        for action in parser._actions
        if action.help != argparse.SUPPRESS
        and not isinstance(action, (argparse._SubParsersAction, argparse._HelpAction))
    ]


def group_actions(parser: argparse.ArgumentParser) -> list[argparse.Action]:
    return [action for action in actions(parser) if "--json" not in action.option_strings]


def entry(
    parser: argparse.ArgumentParser, inherited: tuple[argparse.ArgumentParser, ...]
) -> dict[str, object]:
    path = path_for(parser)
    details = help_details(path)
    return {
        "path": list(path),
        "usage": parser.format_usage().strip(),
        "description": details.description,
        "arguments": [argument(action) for action in actions(parser)],
        "group_arguments": [
            {
                "path": list(path_for(parent)),
                "arguments": [argument(action) for action in group_actions(parent)],
            }
            for parent in inherited
            if group_actions(parent)
        ],
        "exclusive_groups": [
            {
                "required": group.required,
                "members": [
                    action.option_strings[0] if action.option_strings else action.dest
                    for action in group._group_actions
                    if action in actions(parser)
                ],
            }
            for group in parser._mutually_exclusive_groups
        ],
        "subcommands": list(children(parser)),
        "aliases": [
            name
            for name, child in children(inherited[-1]).items()
            if child is parser and name != path[-1]
        ]
        if inherited
        else [],
        "requirements": details.requirements,
        "effects": {
            "description": details.effects,
            "may_write": list(details.writes),
            "may_contact_or_run": list(details.external),
        },
        "examples": list(details.examples),
        "supports_dry_run": has_dry_run(parser),
        "output": {
            "default": details.default_output or ("text" if children(parser) else "json"),
            "json": "json",
        },
    }


def argument(action: argparse.Action) -> dict[str, object]:
    default = action.default
    if isinstance(default, Path):
        default = str(default)
    if default == argparse.SUPPRESS:
        default = None
    return {
        "name": action.dest,
        "flags": action.option_strings,
        "required": action.required,
        "nargs": action.nargs,
        "metavar": list(action.metavar) if isinstance(action.metavar, tuple) else action.metavar,
        "choices": list(action.choices) if action.choices is not None else None,
        "default": default,
        "value_type": getattr(action.type, "__name__", "string") if action.nargs != 0 else None,
        "repeatable": isinstance(action, argparse._AppendAction),
        "description": action.help or "",
    }


def entries(
    parser: argparse.ArgumentParser, inherited: tuple[argparse.ArgumentParser, ...] = ()
) -> list[dict[str, object]]:
    result = [entry(parser, inherited)]
    for child in dict.fromkeys(children(parser).values()):
        result.extend(entries(child, (*inherited, parser)))
    return result


def catalog_document(
    parser: argparse.ArgumentParser, ancestors: tuple[argparse.ArgumentParser, ...] = ()
) -> dict[str, object]:
    return {
        "schema_version": SCHEMA_VERSION,
        "program": PROGRAM,
        "topics": list(topic_names()),
        "commands": entries(parser, ancestors),
    }


def render_catalog(
    parser: argparse.ArgumentParser, ancestors: tuple[argparse.ArgumentParser, ...] = ()
) -> None:
    from factory.cli_contracts import validate_catalog

    emit_json(validate_catalog(catalog_document(parser, ancestors)))


def render_help(parser: argparse.ArgumentParser, path: list[str], *, as_json: bool) -> int:
    if path and path[0] in GUIDES:
        from factory.cli_topics import guide

        content = guide(path, parser)
        if as_json:
            from factory.cli_contracts import validate_topic

            emit_json(
                validate_topic({"schema_version": SCHEMA_VERSION, "topic": path, "text": content})
            )
        else:
            print(content)
        return 0
    selected = parser
    ancestors: tuple[argparse.ArgumentParser, ...] = ()
    for part in path:
        child = children(selected).get(part)
        if child is None:
            parser.error(f"unknown help path: {' '.join(path)}")
        ancestors = (*ancestors, selected)
        selected = child
    if as_json:
        render_catalog(selected, ancestors)
    else:
        selected.print_help()
    return 0
