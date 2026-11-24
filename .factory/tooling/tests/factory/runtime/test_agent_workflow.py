"""Agent-facing runtime planning, evidence navigation and lost-response recovery."""

import base64
import json
import re
import shlex
import subprocess
import unittest
from pathlib import Path, PureWindowsPath
from typing import Any
from unittest.mock import patch

from bootstrap import _cli_args
from factory.runtime import agent_commands
from factory.runtime.workflow_core import digest
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class WorkflowAgentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = WorkflowFixture(self.addCleanup)
        self.check_marker = self.f.root / "check-executions"
        execution = self.f.g["tasks"]["label"]["required_checks"][0]["execution"]
        execution["argv"][-1] = (
            "from pathlib import Path, PureWindowsPath\n"
            "with Path('check-executions').open('a') as marker:\n"
            "    marker.write('ran\\n')\n"
            "print('fixture check')"
        )
        self.run_id = self.f.init()["run_id"]

    def invoke(self, family: str, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [*CLI, family, "--workspace", str(self.f.root), *args],
            text=True,
            capture_output=True,
            check=False,
        )

    def result(self, family: str, *args: str) -> Any:
        call = self.invoke(family, *args)
        self.assertEqual(call.returncode, 0, call.stderr)
        return json.loads(call.stdout)["result"]

    def memory(self) -> dict[Path, str | None]:
        return {
            path.relative_to(self.f.root): digest(path.read_bytes()) if path.is_file() else None
            for path in (self.f.root / ".factory/memory").rglob("*")
        }

    def test_claim_and_retry_plan_without_writes(self) -> None:
        before = self.memory()
        claim = self.result("workflow", "claim", "write-label", "--dry-run")
        self.assertEqual(
            ("pending", "reserved", 1),
            (
                claim["current_status"],
                claim["planned_status"],
                claim["attempt"],
            ),
        )
        self.assertEqual(self.memory(), before)
        self.f.start("write-label")
        before = self.memory()
        retry = ("retry", "write-label", "tests", "fix test failure", "writer terminal")
        rejected = self.invoke("workflow", *retry, "--dry-run")
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn("Cannot retry a live writer", rejected.stderr)
        self.assertEqual(self.memory(), before)

        self.f.ledger.finish("write-label", self.f.report("write-label", "FAIL"))
        before = self.memory()
        plan = self.result("workflow", *retry, "--dry-run")
        self.assertEqual(plan["budget"]["used"], 0)
        self.assertEqual(plan["budget"]["planned_used"], 1)
        affected = plan["affected"]
        self.assertEqual(set(affected), {"write-label", "verify-label", "accept-label"})
        self.assertEqual(self.memory(), before)
        self.result("workflow", *retry)
        state = self.f.ledger.read()
        self.assertEqual(state["counters"][plan["budget"]["key"]], 1)
        self.assertTrue(all(state["nodes"][node]["status"] == "pending" for node in affected))

    def test_status_leads_to_same_report_after_retry_and_archive_cleanup(self) -> None:
        self.f.start("write-label")
        report = self.f.report("write-label", "FAIL")
        self.f.ledger.finish("write-label", report)
        dispatch = report["dispatch_id"]
        status = self.result("workflow", "status")
        cmd = status["read_commands"]["write-label"]
        self.assertIn("--json", cmd)
        self.assertIn("explain write-label", cmd.replace("'", ""))
        self.assertIn(dispatch, cmd)
        self.assertIn(self.run_id, cmd)
        selector = ("explain", "write-label", "--dispatch", dispatch, "--run", self.run_id)
        if status["command_shell"] == "POSIX shell":
            issued = subprocess.run(shlex.split(cmd), text=True, capture_output=True, check=True)
            active = json.loads(issued.stdout)["result"]
        else:
            active = self.result("workflow", *selector)
        self.assertTrue(active["current"])
        self.assertEqual(active["report"]["report"]["dispatch_id"], dispatch)
        self.assertEqual(active["report"]["report"]["outcome"], "FAIL")
        self.f.ledger.retry("write-label", "tests", "fix test failure", "writer terminal")
        superseded = self.result("workflow", *selector)
        self.assertFalse(superseded["current"])
        self.assertEqual(superseded["report"], active["report"])
        self.f.ledger.archive("cancelled", "Fixture finished")
        self.f.ledger.clean()
        after = self.result("workflow", *selector)
        self.assertEqual(after["report_ref"], active["report_ref"])
        self.assertIn(active["report_ref"]["path"], [item["path"] for item in after["artifacts"]])
        self.assertFalse(after["current"])
        self.assertEqual(after["run_status"], "cancelled")

    def test_check_preview_and_lost_response_replay(self) -> None:
        self.f.start("write-label")
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        self.f.start("verify-label")
        attempt = self.f.ledger.packet("verify-label")["check_commands"][0]
        for key in ("run_command", "results_command", "reconcile_command"):
            self.assertIn("--json", attempt[key])
        args = (
            "run",
            "verify-label",
            attempt["check_id"],
            "--request",
            attempt["request_id"],
            "--dispatch",
            attempt["dispatch_id"],
        )
        before = self.memory()
        planned = self.result("checks", *args, "--dry-run")
        self.assertEqual(planned["execution_id"], attempt["execution_id"])
        self.assertIn("print('fixture check')", planned["stages"][0]["argv"][-1])
        self.assertFalse(self.check_marker.exists())
        self.assertEqual(self.memory(), before)
        # Submit the exact issued command, then recover without its stdout.
        if attempt["shell"] == "POSIX shell":
            subprocess.run(
                shlex.split(attempt["run_command"]),
                capture_output=True,
                check=True,
            )
            response = subprocess.run(
                shlex.split(attempt["results_command"]),
                capture_output=True,
                check=True,
            )
            recovered = json.loads(response.stdout)["result"]
        else:
            self.result("checks", *args, "--json")
            recovered = self.result("checks", "results", attempt["execution_id"], "--json")
        self.assertEqual(recovered[0]["result"], "PASS")
        self.assertEqual(recovered[0], self.result("checks", *args))
        self.assertEqual(recovered[0], self.result("checks", "reconcile", attempt["execution_id"]))
        state = self.f.ledger.read()
        self.assertEqual(list(state["executions"]), [attempt["execution_id"]])
        starts = [event for event in state["events"] if event["event"] == "check_started"]
        self.assertEqual(len(starts), 1)
        self.assertEqual(self.check_marker.read_text(encoding="utf-8"), "ran\n")
        after = self.memory()
        repeated = self.result("checks", *args, "--dry-run")
        self.assertEqual(repeated["existing_result"], "PASS")
        self.assertEqual(after, self.memory())


class WindowsAgentCommandTests(unittest.TestCase):
    def test_powershell_quotes_plain_paths_and_exposes_cli_argv(self) -> None:
        with patch.object(
            agent_commands, "FACTORY_ROOT", PureWindowsPath("C:/John's Lab/.factory")
        ):
            command = agent_commands.factory_command(
                Path("C:/John's Lab"),
                "C:/John's Lab/factory.yaml",
                "workflow",
                "status",
                shell="PowerShell",
            )
        self.assertTrue(command.startswith("& 'C:\\John''s Lab\\"))
        self.assertIn("cli.cmd' 'workflow' '--workspace'", command)
        self.assertIn("'C:", command)
        self.assertIn("John''s Lab", command)
        self.assertTrue(command.endswith("'--json' 'status'"))

    def test_encoded_argv_keeps_special_values_and_editable_packet_flags(self) -> None:
        config = "C:/P%ATH% & son's/factory.yaml"
        recipient = 'role "echo | not a command"'
        root = Path("C:/project space")
        with patch.object(agent_commands, "FACTORY_ROOT", PureWindowsPath("C:/factory/.factory")):
            command = agent_commands.factory_command(
                root,
                config,
                "workflow",
                "read-packet",
                "node",
                "--recipient",
                recipient,
                shell="PowerShell",
                trailing=("--chunk", "1"),
            )
        self.assertIn("cli.cmd' '--argv-base64'", command)
        self.assertNotIn("%ATH%", command)
        args = _cli_args(shlex.split(command)[2:] + ["--ack", "receipt"])
        self.assertEqual(
            args,
            [
                "workflow",
                "--workspace",
                str(root),
                "--config",
                config,
                "--json",
                "read-packet",
                "node",
                "--recipient",
                recipient,
                "--chunk",
                "1",
                "--ack",
                "receipt",
            ],
        )

    def test_tricky_launcher_path_uses_single_expansion_and_restores_environment(self) -> None:
        bundle = PureWindowsPath("C:/Owner%PATH% & Team’s/.factory")
        expected = str(bundle / "tooling/bin/cli.cmd")
        with patch.object(agent_commands, "FACTORY_ROOT", bundle):
            command = agent_commands.factory_command(
                Path("C:/project"),
                "project.yaml",
                "workflow",
                "read-packet",
                shell="PowerShell",
                trailing=("--chunk", "1"),
            )
        launcher, args = re.findall(r"FromBase64String\('([^']+)'\)", command)
        self.assertEqual(base64.b64decode(launcher).decode(), expected)
        self.assertEqual(_cli_args(["--argv-base64", args])[-2:], ["--json", "read-packet"])
        self.assertIn('%OVERFACTORY_COMMAND_LAUNCHER%" --argv-base64', command)
        self.assertIn("$env:ComSpec /d /s /v:off /c", command)
        self.assertIn("finally { $env:OVERFACTORY_COMMAND_LAUNCHER = $previous }", command)
        self.assertNotIn("%PATH%", command)
        self.assertTrue(command.endswith("'--chunk' '1'"))
