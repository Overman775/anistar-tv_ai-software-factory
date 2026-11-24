"""Dependency-free command help shared by the bootstrap and installed CLI."""

from dataclasses import dataclass
from typing import Literal

from factory.cli_output import LAUNCHER

type OutputFormat = Literal["text", "json", "jsonl", "none", "text+json"]


@dataclass(frozen=True)
class Details:
    description: str
    requirements: str
    effects: str
    examples: tuple[str, ...]
    summary: str
    # Targets can depend on flags, selected subcommands, or configuration.
    writes: tuple[str, ...]
    external: tuple[str, ...]
    default_output: OutputFormat | None


def details(
    command: str,
    description: str,
    requirements: str = "",
    effects: str = "",
    *example_args: str,
    summary: str = "",
    writes: tuple[str, ...] = (),
    external: tuple[str, ...] = (),
    default_output: OutputFormat | None = None,
) -> tuple[str, Details]:
    """Build one declaration, prefixing example arguments with the launcher and command."""
    examples = tuple(f"{LAUNCHER} {command} {args}".rstrip() for args in example_args)
    return command, Details(
        description, requirements, effects, examples, summary, writes, external, default_output
    )


CONFIG = "A valid factory configuration and its configured project profile."
RUN = f"An active run in this checkout. Use IDs from `{LAUNCHER} workflow status`."
