from __future__ import annotations

import json
import subprocess
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch

from factory_tooling.runtime import telemetry
from factory_tooling.runtime.run_archive import read_member
from tests.factory_tooling.runtime import test_workflow


class TelemetryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = test_workflow.WorkflowTests()
        self.f.setUp()
        self.addCleanup(self.f.doCleanups)
        self.f.init()
        self.f.ledger.claim("write-label")
        self.state = self.f.ledger.read()
        self.dispatch = self.state["nodes"]["write-label"]
        self.cwd = self.state["workspace"]
        self.state["config"]["acpx"] = {
            "command": "acpx",
            "connections": {"sessions": {"command": "fake", "max_parallel_agents": 1}},
        }
        self.name = f"{self.state['run_id']}-author-e0"
        self.argv = [
            "acpx",
            "--cwd",
            self.cwd,
            "--format",
            "json",
            "sessions",
            "sessions",
            "new",
            "--name",
            self.name,
        ]
        self.state["events"].append(
            {
                "at": 1.0,
                "event": "transport_requested",
                "node": "write-label",
                "operation": "create",
                "argv": self.argv,
            }
        )

    def record(self, name: str) -> dict[str, object]:
        return {
            "name": name,
            "cwd": self.cwd,
            "acpxRecordId": "record",
            "acpSessionId": "acp",
            "messages": ["secret"],
            "request_token_usage": {
                "r1": {"input_tokens": 10, "output_tokens": 0},
                "r2": {"input_tokens": 20, "cache_read_input_tokens": 0},
            },
            "cumulative_cost": {"amount": 0.02, "currency": "USD"},
        }

    def test_usage_allowlist_and_zero(self) -> None:
        self.state["events"].append(
            {
                "at": 2.0,
                "event": "bound",
                "node": "write-label",
                "handle": self.name,
                "model": "confirmed-model",
            }
        )
        output = subprocess.CompletedProcess([], 0, stdout=json.dumps(self.record(self.name)))
        with patch("factory_tooling.runtime.telemetry._show", return_value=output) as run:
            result = telemetry.collect(self.state)
        sessions = result["sessions"]
        assert isinstance(sessions, list)
        session = sessions[0]
        self.assertEqual(
            session["request_token_usage"],
            self.record(self.name)["request_token_usage"],
        )
        self.assertEqual(session["cumulative_cost"], {"amount": 0.02, "currency": "USD"})
        self.assertNotIn("messages", str(result))
        self.assertEqual(session["attempts"][0]["dispatch_id"], self.dispatch["dispatch_id"])
        self.assertEqual(session["attempts"][0]["transport"], "acp")
        self.assertEqual(session["attempts"][0]["effective_model"], "confirmed-model")
        self.assertEqual(run.call_args.args[0][-4:], ["sessions", "sessions", "show", self.name])

    def test_replaced_timeout_and_missing_cost(self) -> None:
        old = self.state["events"][-1]
        name = self.name[:-1] + "1"
        previous = deepcopy(self.dispatch)
        previous["handle"] = self.name
        current = deepcopy(self.dispatch)
        current["dispatch_id"] = "second-dispatch"
        current["handle"] = name
        self.state["nodes"]["write-label"] = current
        self.state["events"].extend(
            [
                {"at": 2.0, "event": "invalidated", "node": "write-label", "previous": previous},
                {
                    "at": 3.0,
                    "event": "reserved",
                    "node": "write-label",
                    "dispatch_id": "second-dispatch",
                },
                {**old, "argv": [*self.argv[:-1], name]},
            ]
        )
        record = self.record(name)
        del record["cumulative_cost"]
        responses = [
            subprocess.TimeoutExpired("acpx", 2),
            subprocess.CompletedProcess([], 0, stdout=json.dumps(record)),
        ]
        with patch("factory_tooling.runtime.telemetry._show", side_effect=responses) as run:
            result = telemetry.collect(self.state)
        sessions = result["sessions"]
        assert isinstance(sessions, list)
        self.assertEqual([s["collection"] for s in sessions], ["unavailable", "ok"])
        self.assertNotIn("cumulative_cost", sessions[1])
        self.assertEqual(run.call_count, 2)
        self.assertEqual(sessions[0]["attempts"][0]["dispatch_id"], previous["dispatch_id"])
        self.assertEqual(sessions[1]["attempts"][0]["dispatch_id"], "second-dispatch")

    def test_malformed_and_identity_mismatch(self) -> None:
        for output in ("{}", json.dumps(self.record("wrong")), "not json"):
            with (
                self.subTest(output=output),
                patch(
                    "factory_tooling.runtime.telemetry._show",
                    return_value=subprocess.CompletedProcess([], 0, stdout=output),
                ),
            ):
                sessions = telemetry.collect(self.state)["sessions"]
                assert isinstance(sessions, list)
                self.assertEqual(sessions[0]["collection"], "unavailable")

    def test_archive_retry_and_cleanup(self) -> None:
        profile = self.f.config["profiles"][self.dispatch["profile"]]
        model = self.f.config["models"][profile["model"]]["id"] or "fixture"
        self.f.ledger.bind("write-label", "handle", model)
        # Fresh fixture avoids active dispatch and checks committed archive recovery.
        self.f.ledger.finish("write-label", self.f.report("write-label", "BLOCKED"))
        with (
            patch(
                "factory_tooling.runtime.telemetry.collect",
                return_value={"run_id": self.state["run_id"], "sessions": []},
            ) as collect,
            patch(
                "factory_tooling.runtime.workflow.atomic_json",
                side_effect=OSError("interrupted"),
            ),
            self.assertRaises(OSError),
        ):
            self.f.ledger.archive("cancelled", "done")
        with patch(
            "factory_tooling.runtime.telemetry.collect",
            side_effect=AssertionError("requery"),
        ):
            archive = Path(self.f.ledger.archive("cancelled", "done"))
        self.assertEqual(collect.call_count, 1)
        self.assertEqual(json.loads(read_member(archive, "usage.acpx.json"))["sessions"], [])
        self.f.ledger.clean()
        self.assertTrue(archive.is_file())
