import json
import unittest
from contextlib import redirect_stdout
from io import StringIO
from unittest.mock import patch

from factory.cli import main
from factory.cli_contracts import HelpCatalog, validate_catalog, validate_topic


class CLIContractTests(unittest.TestCase):
    def read_catalog(self, *path: str) -> HelpCatalog:
        stdout = StringIO()
        with redirect_stdout(stdout):
            self.assertEqual(main(["help", *path, "--json"]), 0)
        return validate_catalog(json.loads(stdout.getvalue()))

    def test_live_catalog_preserves_parser_values(self) -> None:
        catalog = self.read_catalog()
        self.assertEqual(catalog["schema_version"], 1)
        self.assertEqual(catalog["program"], "cli")
        entries = {tuple(command["path"]): command for command in catalog["commands"]}
        args = {
            argument["name"]: argument for argument in entries[("workflow", "revise")]["arguments"]
        }
        self.assertEqual(args["retry_tests"]["flags"], ["--retry-tests"])
        self.assertEqual(args["retry_tests"]["nargs"], 4)
        self.assertEqual(
            args["retry_tests"]["metavar"],
            ["TEST_NODE", "FAILED_DISPATCH", "DIAGNOSIS_NODE", "REPAIR_NODE"],
        )
        self.assertIsNone(args["retry_tests"]["default"])
        self.assertIs(entries[("setup",)]["arguments"][0]["default"], False)

    def test_catalog_rejects_versions_and_program_names(self) -> None:
        catalog = self.read_catalog("setup")
        for version in (True, 1.0, "1", 2):
            with (
                self.subTest(version=version),
                self.assertRaisesRegex(ValueError, "schema_version"),
            ):
                validate_catalog({**catalog, "schema_version": version})
        with self.assertRaisesRegex(ValueError, "program"):
            validate_catalog({**catalog, "program": "factory"})

    def test_catalog_rejects_nested_extra_fields_and_coercion(self) -> None:
        catalog = self.read_catalog("workflow", "revise")
        command = catalog["commands"][0]
        argument = command["arguments"][0]
        bad_arguments = (
            ({"required": "false"}, "required"),
            ({"nargs": True}, "nargs"),
            ({"flags": ("--not-a-list",)}, "flags"),
            ({"default": ["value", object()]}, "default"),
            ({"default": [float("nan")]}, "default"),
            ({"default": [("string",)]}, "default"),
            ({"private_argument_field": "private input"}, r"\(extra field\)"),
        )
        for changes, location in bad_arguments:
            with self.subTest(location=location):
                with self.assertRaisesRegex(ValueError, location) as caught:
                    validate_catalog(
                        {
                            **catalog,
                            "commands": [{**command, "arguments": [{**argument, **changes}]}],
                        }
                    )
                self.assertNotIn("private", str(caught.exception))
        bad_commands = (
            ({"effects": {"description": "", "may_write": []}}, r"effects\.may_contact_or_run"),
            ({"output": {"default": "yaml", "json": "json"}}, r"output\.default"),
            (
                {"group_arguments": [{"path": ["workflow"], "arguments": [], "extra": 1}]},
                r"group_arguments\.0\.\(extra field\)",
            ),
            (
                {"exclusive_groups": [{"required": False, "members": [False]}]},
                r"exclusive_groups\.0\.members\.0",
            ),
        )
        for command_changes, location in bad_commands:
            with self.subTest(location=location), self.assertRaisesRegex(ValueError, location):
                validate_catalog({**catalog, "commands": [{**command, **command_changes}]})

    def test_json_help_publishes_error_instead_of_malformed_catalog(self) -> None:
        catalog = self.read_catalog("workflow", "revise")
        invalid = {**catalog, "private_field": "private input"}
        for args in (
            ["help", "workflow", "revise", "--json"],
            ["workflow", "revise", "--help", "--json"],
        ):
            with self.subTest(args=args):
                stdout = StringIO()
                with (
                    patch("factory.cli_help.catalog_document", return_value=invalid),
                    redirect_stdout(stdout),
                ):
                    self.assertEqual(main(args), 1)
                result = json.loads(stdout.getvalue())
                self.assertIs(result["ok"], False)
                self.assertIn("(extra field)", result["error"]["message"])
                self.assertNotIn("private", result["error"]["message"])

    def test_topic_shape_is_closed_and_strict(self) -> None:
        stdout = StringIO()
        with redirect_stdout(stdout):
            self.assertEqual(main(["help", "json", "--json"]), 0)
        topic = validate_topic(json.loads(stdout.getvalue()))
        self.assertEqual(topic["topic"], ["json"])
        self.assertTrue(topic["text"])
        with self.assertRaisesRegex(ValueError, r"topic\.0"):
            validate_topic({**topic, "topic": [42]})
        with self.assertRaisesRegex(ValueError, r"\(extra field\)"):
            validate_topic({**topic, "commands": []})
