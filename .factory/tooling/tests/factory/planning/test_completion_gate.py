from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from factory.paths import FACTORY_ROOT
from tests.factory.planning.fixture_plan import PLAN

SCRIPT = FACTORY_ROOT / "gates/skills/planning/validate_plan.py"


class CompletionGateTest(unittest.TestCase):
    def test_previous_and_current_invalid_revisions_return_structured_errors(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            plan, previous = Path(tmp) / "plan.md", Path(tmp) / "previous.md"
            for current_revision, previous_revision in (
                ("bad", "1"),
                ("1", "bad"),
                ("0", "1"),
                ("1", "0"),
            ):
                with self.subTest(current=current_revision, previous=previous_revision):
                    plan.write_text(PLAN.replace("revision: 1", "revision: " + current_revision))
                    previous.write_text(
                        PLAN.replace("revision: 1", "revision: " + previous_revision)
                    )
                    result = subprocess.run(
                        [
                            sys.executable,
                            str(SCRIPT),
                            "--plan",
                            str(plan),
                            "--previous",
                            str(previous),
                        ],
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(1, result.returncode, result.stderr)
                    self.assertNotIn("Traceback", result.stderr)
                    data = json.loads(result.stdout)
                    self.assertIn(
                        "TRANSITION_METADATA_INVALID", {item["code"] for item in data["errors"]}
                    )

    def test_machine_pass_is_not_completion_and_stale_review_blocks(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            plan = Path(tmp) / "plan.md"
            plan.write_text(
                PLAN.replace("status: draft", "status: approved").replace(
                    "approved_revision: none", "approved_revision: 1"
                )
            )
            command = [sys.executable, str(SCRIPT), "--plan", str(plan), "--phase", "approved"]
            preflight = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(0, preflight.returncode, preflight.stderr)
            result = json.loads(preflight.stdout)
            self.assertEqual("BLOCKED", result["gate_result"]["status"])
            report = Path(tmp) / "review.json"
            report.write_text(
                json.dumps(
                    {
                        "plan_hash": result["plan_hash"],
                        "policy_hash": result["gate_result"]["policy_hash"],
                        "coordinator_id": "coordinator",
                        "verdict": "APPROVE",
                        "evidence": ["checked plan.md"],
                        "approval_evidence": ["user explicitly approved revision 1"],
                    }
                )
            )
            final = subprocess.run(
                command + ["--completion-review", str(report)], capture_output=True, text=True
            )
            self.assertEqual(0, final.returncode, final.stderr)
            self.assertEqual("PASS", json.loads(final.stdout)["gate_result"]["status"])
            plan.write_text(plan.read_text() + "\n")
            stale = subprocess.run(
                command + ["--completion-review", str(report)], capture_output=True, text=True
            )
            self.assertEqual(2, stale.returncode)
            self.assertEqual("BLOCKED", json.loads(stale.stdout)["gate_result"]["status"])
