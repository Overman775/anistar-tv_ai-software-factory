"""Public help is executable documentation for the same command parser."""

from __future__ import annotations

import base64
import json
import os
import shlex
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
import venv
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

from factory.cli import build_parser, main
from factory.cli_output import CLI_ERROR_GUIDANCE, LAUNCHER
from factory.cli_topics import COMMAND_HELP, ERROR_GUIDANCE, collect_command_help, help_details
from factory.diagnostics.records import ERRORS
from factory.paths import TOOLS
from tests import CLI


class CLIHelpTests(unittest.TestCase):
    def launch(
        self, root: Path, *args: str, stdin: str | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [*CLI, *args],
            cwd=root,
            input=stdin,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

    def example_args(self, example: str) -> list[str]:
        self.assertTrue(example.startswith(LAUNCHER + " "), example)
        return shlex.split(example[len(LAUNCHER) + 1 :])

    def test_catalog_matches_live_parser_and_examples(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.launch(root, "help", "--json")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(list(root.iterdir()), [])
        catalog = json.loads(result.stdout)
        self.assertEqual(catalog["schema_version"], 1)
        parser = build_parser()
        by_path = {tuple(row["path"]): row for row in catalog["commands"]}
        self.assertEqual({" ".join(path) for path in by_path}, set(COMMAND_HELP))
        self.assertIn(("workflow", "status"), by_path)
        self.assertIn("next", by_path["workflow", "status"]["aliases"])
        self.assertNotIn(("dry-run",), by_path)
        self.assertNotIn(("workflow", "run-check"), by_path)
        self.assertNotIn(("lessons", "search_lessons"), by_path)
        checks = by_path["checks", "run"]
        flags = {flag for arg in checks["arguments"] for flag in arg["flags"]}
        self.assertTrue({"--request", "--dispatch", "--dry-run"} <= flags)
        self.assertEqual(checks["group_arguments"][0]["path"], ["checks"])
        self.assertIn("configured-check-command", checks["effects"]["may_contact_or_run"])
        self.assertTrue(checks["supports_dry_run"])
        self.assertFalse(by_path["workflow", "explain"]["supports_dry_run"])
        self.assertEqual(
            {path for path, row in by_path.items() if row["supports_dry_run"]},
            {
                ("acpx", "setup"),
                ("checks", "run"),
                ("workflow", "claim"),
                ("workflow", "handoff"),
                ("workflow", "prepare-workspace"),
                ("workflow", "retry"),
            },
        )
        self.assertEqual(
            by_path["workflow", "diagram"]["output"], {"default": "text", "json": "json"}
        )
        self.assertEqual(by_path["workflow", "read-packet"]["output"]["default"], "json")
        self.assertEqual(by_path["telemetry", "journal"]["output"]["default"], "jsonl")
        for path, row in by_path.items():
            self.assertIn(
                "--json", {flag for arg in row["arguments"] for flag in arg["flags"]}, path
            )
            flags = {flag for arg in row["arguments"] for flag in arg["flags"]}
            self.assertEqual(row["supports_dry_run"], "--dry-run" in flags, path)
            self.assertEqual(row["output"]["json"], "json", path)
            if path and path != ("help",):
                self.assertTrue(row["requirements"], path)
                self.assertTrue(row["effects"]["description"], path)
                self.assertTrue(row["examples"], path)
                for example in row["examples"]:
                    with self.subTest(example=example):
                        parser.parse_args(self.example_args(example))

    def test_duplicate_and_missing_help_declarations_name_the_command(self) -> None:
        declaration = ("setup", help_details(("setup",)))
        with self.assertRaisesRegex(ValueError, "Duplicate CLI help declaration for 'setup'"):
            collect_command_help(declaration, declaration)
        with self.assertRaisesRegex(ValueError, "Missing CLI help declaration for 'new leaf'"):
            help_details(("new", "leaf"))

    def test_agent_guide_commands_use_the_project_launcher(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            guide = self.launch(root, "help", "agents", "--json")
            self.assertEqual(guide.returncode, 0, guide.stderr)
            text = json.loads(guide.stdout)["text"]
            self.assertIn(f"{LAUNCHER} workflow status --json", text)
            self.assertIn(f"{LAUNCHER} checks results EXECUTION_ID --json", text)
            self.assertIn(
                f"{LAUNCHER} workflow prepare-report NODE DRAFT_ID RECEIPT_ID --json", text
            )
            for line in text.splitlines():
                if line.startswith(f"  {LAUNCHER} "):
                    build_parser().parse_args(self.example_args(line.strip()))
            self.assertEqual(list(root.iterdir()), [])

    def test_help_forms_match_and_cannot_mutate_checkout(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path in (("checks", "run"), ("workflow",), ("workflow", "status")):
                with self.subTest(path=path):
                    guide = self.launch(root, "help", *path)
                    flag = self.launch(root, *path, "--help")
                    self.assertEqual((guide.returncode, flag.returncode), (0, 0))
                    self.assertEqual(guide.stdout, flag.stdout)
                    self.assertIn("Examples:", guide.stdout)
            self.assertEqual(list(root.iterdir()), [])

    def test_json_help_is_scoped_and_accepts_both_flag_orders(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected = self.launch(root, "help", "workflow", "status", "--json")
            self.assertEqual(expected.returncode, 0, expected.stderr)
            for args in (
                ("--json", "workflow", "next", "--help"),
                ("workflow", "--json", "next", "--help"),
                ("workflow", "next", "--help", "--json"),
                ("workflow", "next", "--json", "--help"),
                ("--json", "help", "workflow", "status"),
                ("help", "workflow", "--json", "status"),
            ):
                with self.subTest(args=args):
                    result = self.launch(root, *args)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout), json.loads(expected.stdout))
                    self.assertEqual(result.stderr, "")
            self.assertEqual(list(root.iterdir()), [])

    def test_json_usage_error_and_option_delimiter(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for args in (("--json", "checks", "run"), ("checks", "run", "--json")):
                with self.subTest(args=args):
                    result = self.launch(root, *args)
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertEqual(result.stderr, "")
                    error = json.loads(result.stdout)["error"]
                    self.assertEqual(error["code"], "usage_error")
                    self.assertIn("--request", error["message"])
                    self.assertIn(f"{LAUNCHER} checks run --help", error["next_action"])
            unknown = self.launch(root, "help", "--", "--json")
            self.assertEqual(unknown.returncode, 2)
            self.assertEqual(unknown.stdout, "")
            self.assertIn("unknown help path: --json", unknown.stderr)
            self.assertEqual(list(root.iterdir()), [])

    def test_json_operation_error_uses_diagnostic_code_and_guidance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.launch(
                root, "workflow", "explain", "missing-node", "--dispatch", "missing", "--json"
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertEqual(result.stderr, "")
            error = json.loads(result.stdout)["error"]
            self.assertEqual(error["code"], "io_error")
            self.assertEqual(error["message"], "No current workflow run")
            self.assertEqual(error["next_action"], ERROR_GUIDANCE["io_error"])
            self.assertEqual(list(root.iterdir()), [])

    def test_json_unexpected_failures_omit_private_exception_details(self) -> None:
        for failure, code in (
            (TypeError("private input value"), "runtime_error"),
            (sqlite3.DatabaseError("private backend value"), "database_error"),
        ):
            with self.subTest(code=code):
                with patch("factory.cli.workflow_cli.run", side_effect=failure):
                    output = StringIO()
                    with redirect_stdout(output):
                        self.assertEqual(main(["workflow", "status", "--json"]), 1)
                    error = json.loads(output.getvalue())["error"]
                    self.assertEqual(error["code"], code)
                    self.assertEqual(error["next_action"], ERROR_GUIDANCE[code])
                    self.assertNotIn("private", error["message"])
                    with self.assertRaises(type(failure)):
                        main(["workflow", "status"])

    def test_json_invalid_pin_omits_raw_validation_inputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pin = root / "config.json"
            pin.write_text(
                '{"ok":true,"result":{"_path":["private input value"]}}', encoding="utf-8"
            )
            result = self.launch(
                root,
                "workflow",
                "read-instructions",
                str(pin),
                "workflow/orchestration.md",
                "--json",
            )
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertNotIn("Traceback", result.stderr)
            self.assertNotIn("private input value", result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)["error"]["code"], "invalid_operation")

    def test_printed_config_pin_and_instruction_examples_run(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config_help = self.launch(root, "help", "workflow", "config", "--json")
            self.assertEqual(config_help.returncode, 0, config_help.stderr)
            config_example = json.loads(config_help.stdout)["commands"][0]["examples"][0]
            config = self.launch(root, *self.example_args(config_example))
            self.assertEqual(config.returncode, 0, config.stderr)
            pin = config.stdout.strip()
            self.assertRegex(pin, r"^[a-f0-9]{64}$")
            instruction_help = self.launch(root, "workflow", "read-instructions", "--help")
            self.assertEqual(instruction_help.returncode, 0, instruction_help.stderr)
            example = next(
                line.strip()
                for line in instruction_help.stdout.splitlines()
                if line.strip().startswith(LAUNCHER)
            )
            instructions = self.launch(
                root, *(pin if arg == "PIN" else arg for arg in self.example_args(example))
            )
            self.assertEqual(instructions.returncode, 0, instructions.stderr)
            document = json.loads(instructions.stdout)["result"][0]
            self.assertTrue(document["path"].endswith("orchestration.md"))
            self.assertTrue(document["content"])

    def test_printed_pr_example_runs_in_pipe_mode(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            help_result = self.launch(root, "pr", "note", "--help")
            self.assertEqual(help_result.returncode, 0, help_result.stderr)
            example = next(
                line.strip()
                for line in help_result.stdout.splitlines()
                if line.strip().startswith(LAUNCHER) and " note issue " in line
            )
            args = self.example_args(example)
            valid = self.launch(root, *args, stdin='[{"id":123,"body":"Example input comment"}]')
            self.assertEqual(valid.returncode, 0, valid.stderr)
            self.assertIn("Example input comment", valid.stdout)
            missing = self.launch(root, *args, stdin="[]")
            self.assertEqual(missing.returncode, 1)
            self.assertIn("comment 123 not found", missing.stderr)

    def test_help_lists_live_error_codes_and_rejects_invalid_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            public_codes = ERRORS | CLI_ERROR_GUIDANCE.keys()
            self.assertFalse(ERRORS & CLI_ERROR_GUIDANCE.keys())
            self.assertEqual(set(ERROR_GUIDANCE), public_codes)
            codes = self.launch(root, "help", "errors")
            self.assertEqual(codes.returncode, 0, codes.stderr)
            self.assertEqual(
                {line.strip() for line in codes.stdout.splitlines() if line.startswith("  ")},
                public_codes,
            )
            data = self.launch(root, "help", "errors", "stale_dispatch", "--json")
            self.assertEqual(data.returncode, 0, data.stderr)
            self.assertIn("current assignment", json.loads(data.stdout)["text"])
            for code in ("usage_error", "setup_failed", "review_checks", "observation_not_found"):
                with self.subTest(code=code):
                    guidance = self.launch(root, "help", "errors", code, "--json")
                    self.assertEqual(guidance.returncode, 0, guidance.stderr)
                    self.assertIn(ERROR_GUIDANCE[code], json.loads(guidance.stdout)["text"])
            for path in (
                ("help", "errors", "never_seen"),
                ("help", "unknown_group"),
                ("-c", "print(1)"),
            ):
                with self.subTest(path=path):
                    result = self.launch(root, *path)
                    self.assertEqual(result.returncode, 2)
                    self.assertFalse(result.stdout)
            self.assertEqual(list(root.iterdir()), [])

    def test_json_pipes_use_utf8_with_a_legacy_locale(self) -> None:
        body = "Ответ 🎨"
        payload = json.dumps(
            [
                {
                    "id": 7,
                    "body": body,
                    "created_at": "2026-11-24T00:00:00Z",
                    "user": {"login": "agent"},
                }
            ],
            ensure_ascii=False,
        ).encode("utf-8")
        args = ["pr", "note", "issue", "7", "--json"]
        for command in (
            [sys.executable, "-E", "-s", "-B", "-X", "utf8=0", "-P", "-m", "factory.cli"],
            CLI,
        ):
            result = subprocess.run(
                [*command, *args],
                input=payload,
                capture_output=True,
                env=dict(os.environ, LC_ALL="C"),
                check=False,
            )
            self.assertEqual(result.returncode, 0, (result.stdout, result.stderr))
            self.assertEqual(json.loads(result.stdout.decode("utf-8"))["target"]["body"], body)

    def test_setup_help_works_before_venv_with_an_explicit_python(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools = root / ".factory/tooling"
            package = tools / "factory"
            package.mkdir(parents=True)
            for name in ("__init__.py", "cli_help.py", "cli_topics.py", "cli_output.py"):
                shutil.copy2(TOOLS / "factory" / name, package / name)
            shutil.copytree(TOOLS / "factory/cli_metadata", package / "cli_metadata")
            shutil.copy2(TOOLS / "bootstrap.py", tools / "bootstrap.py")
            shutil.copytree(TOOLS / "bin", tools / "bin")
            launcher = tools / "bin" / Path(CLI[0]).name
            # A bare interpreter catches accidental third-party imports before setup.
            bare = root / "bare-python"
            venv.EnvBuilder(with_pip=False).create(bare)
            python = bare / ("Scripts/python.exe" if os.name == "nt" else "bin/python")
            for flags in ([], ["--json"]):
                with self.subTest(flags=flags):
                    result = subprocess.run(
                        [str(launcher), "setup", "--help", *flags],
                        cwd=root,
                        env=dict(os.environ, FACTORY_SETUP_PYTHON=str(python)),
                        capture_output=True,
                        text=True,
                        timeout=30,
                        check=False,
                    )
                    rendered = self.launch(root, "help", "setup", *flags)
                    self.assertEqual(
                        (result.returncode, rendered.returncode), (0, 0), result.stderr
                    )
                    self.assertEqual(result.stdout, rendered.stdout)
            self.assertFalse((tools.parent / ".venv").exists())

    def test_encoded_launcher_arguments_are_still_parsed_as_cli_commands(self) -> None:
        def encode(value: object) -> str:
            return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip("=")

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = self.launch(
                root, "--argv-base64", encode(["help", "workflow", "status"]), "--json"
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                json.loads(result.stdout)["commands"][0]["path"], ["workflow", "status"]
            )
            unusual = 'path %EXPANSION% & "quote"'
            invalid_path = self.launch(root, "--argv-base64", encode(["help", unusual]))
            self.assertEqual(invalid_path.returncode, 2)
            self.assertIn(unusual, invalid_path.stderr)
            invalid_payload = self.launch(root, "--argv-base64", encode({"command": "help"}))
            self.assertEqual(invalid_payload.returncode, 1)
            self.assertIn("Invalid encoded launcher arguments", invalid_payload.stderr)
            no_passthrough = self.launch(root, "--argv-base64", encode(["-c", "print(1)"]))
            self.assertEqual(no_passthrough.returncode, 2)
            self.assertFalse(no_passthrough.stdout)
            self.assertEqual(list(root.iterdir()), [])
