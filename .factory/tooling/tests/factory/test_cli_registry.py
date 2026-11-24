"""Register commands through the same route and metadata interfaces as the CLI."""

from __future__ import annotations

import argparse
import json
import unittest
from contextlib import redirect_stdout
from io import StringIO
from unittest.mock import patch

from factory import cli
from factory.cli_metadata.model import details
from factory.cli_output import emit_json
from factory.cli_topics import COMMAND_HELP


class CLIRegistryTests(unittest.TestCase):
    def test_new_group_and_commands_share_parser_for_help_and_execution(self) -> None:
        configured: list[argparse.ArgumentParser] = []
        received: list[str] = []

        def configure(parser: argparse.ArgumentParser) -> argparse.ArgumentParser:
            configured.append(parser)
            parser.add_argument("--value", required=True)
            return parser

        def run(args: argparse.Namespace) -> None:
            received.append(args.value)
            emit_json({"value": args.value})

        def run_with_parser(args: argparse.Namespace, parser: argparse.ArgumentParser) -> None:
            self.assertIs(parser, configured[-1])
            self.assertTrue(parser.prog.endswith("demo aware"))
            run(args)

        routes = (
            *cli.routes(),
            cli.Group(
                "demo",
                (
                    cli.command("echo", configure, run),
                    cli.parser_command("aware", configure, run_with_parser),
                ),
            ),
        )
        metadata = dict(
            [
                details("demo", "Inspect test commands.", "None.", "None.", "--help"),
                details("demo echo", "Echo a value.", "A value.", "None.", "--value hello"),
                details(
                    "demo aware", "Echo with parser access.", "A value.", "None.", "--value hello"
                ),
            ]
        )
        with patch.object(cli, "routes", return_value=routes), patch.dict(COMMAND_HELP, metadata):
            catalog = StringIO()
            with redirect_stdout(catalog):
                self.assertEqual(cli.main(["help", "--json"]), 0)
            entries = {
                tuple(row["path"]): row for row in json.loads(catalog.getvalue())["commands"]
            }
            self.assertEqual(entries[("demo",)]["subcommands"], ["echo", "aware"])
            self.assertEqual(entries["demo", "echo"]["description"], "Echo a value.")
            self.assertTrue(
                any(
                    arg["flags"] == ["--value"] and arg["required"]
                    for arg in entries["demo", "echo"]["arguments"]
                )
            )
            self.assertEqual(received, [])
            for subcommand in ("echo", "aware"):
                with self.subTest(subcommand=subcommand):
                    result = StringIO()
                    with redirect_stdout(result):
                        self.assertEqual(
                            cli.main(["demo", subcommand, "--value", "hello", "--json"]), 0
                        )
                    self.assertEqual(json.loads(result.getvalue()), {"value": "hello"})
        self.assertEqual(received, ["hello", "hello"])
