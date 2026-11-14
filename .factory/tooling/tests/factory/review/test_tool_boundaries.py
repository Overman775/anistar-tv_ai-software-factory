"""Review execution and rendering stay usable without global I/O patching."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory.review.render_review_report import render_report_text
from factory.review.review_evidence import validate_tool_results
from factory.review.review_plan import review_checks
from factory.review.run_tool_checks import EXCERPT_BYTES, collect_results, run_command


class ReviewBoundaryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = dict(
            schema_version="4",
            review_id="r",
            mode="branch",
            base_sha="a" * 40,
            head_sha="b" * 40,
            scope_hash="c" * 64,
            checks=[{"id": "tests", "execution": {"argv": ["check"], "cwd": "."}}],
        )

    def test_invalid_later_command_cannot_execute_earlier_command(self) -> None:
        calls: list[tuple[object, ...]] = []

        def record_call(*args: object) -> Any:
            calls.append(args)
            return {}

        with self.assertRaisesRegex(ValueError, "argv"):
            collect_results(
                self.manifest,
                "tests",
                [json.dumps({"argv": ["valid"]}), json.dumps({"argv": []})],
                run=record_call,
            )
        self.assertEqual([], calls)

    def test_injected_runner_failure_cannot_be_reported_as_pass(self) -> None:
        def run(argv: list[str], cwd: Any, timeout_seconds: int) -> Any:
            return dict(
                argv=argv,
                cwd=cwd,
                exit_code=3,
                stdout_excerpt="",
                stderr_excerpt="failure",
                stdout_truncated=False,
                stderr_truncated=False,
            )

        result = collect_results(self.manifest, "tests", ['{"argv": ["check"]}'], run=run)
        self.assertEqual("FAIL", result["status"])
        self.assertEqual(self.manifest["scope_hash"], result["scope_hash"])
        self.assertEqual(3, result["commands"][0]["exit_code"])

    def test_not_applicable_never_invokes_runner(self) -> None:
        result = collect_results(
            self.manifest,
            "deps",
            [],
            not_applicable_reason="No dependency changes",
            run=lambda *args: self.fail("Must not run"),
        )
        self.assertEqual("NOT_APPLICABLE", result["status"])
        self.assertEqual([], result["commands"])

    def test_inconsistent_runner_result_is_rejected_before_publication(self) -> None:
        def run(argv: list[str], cwd: str, timeout_seconds: int) -> Any:
            return dict(
                argv=argv,
                cwd=cwd,
                exit_code=exit_code,
                error=error,
                stdout_excerpt="",
                stderr_excerpt="",
                stdout_truncated=False,
                stderr_truncated=False,
            )

        for exit_code, error in ((None, None), (0, "unavailable")):
            with (
                self.subTest(exit_code=exit_code, error=error),
                self.assertRaisesRegex(ValueError, "Invalid review command result"),
            ):
                collect_results(self.manifest, "tests", ['{"argv": ["check"]}'], run=run)

    def test_composite_review_check_is_rejected_when_building_plan(self) -> None:
        profile = {
            "gates": [
                {
                    "at": ["code-review.complete"],
                    "checks": [{"id": "composite", "execution": {"argv": [], "stages": ["unit"]}}],
                }
            ]
        }
        manifest: dict[str, Any] = {
            "project_policy": {},
            "scope_files": [],
            "additional_checks": [],
        }
        with (
            patch("factory.review.review_plan.validate_snapshot", return_value=profile),
            self.assertRaisesRegex(ValueError, "composite execution is not supported in review"),
        ):
            review_checks(manifest)

    def test_runner_cannot_report_a_different_command(self) -> None:
        def run(argv: list[str], cwd: str, timeout_seconds: int) -> Any:
            return dict(
                argv=["other"],
                cwd=cwd,
                exit_code=0,
                stdout_excerpt="",
                stderr_excerpt="",
                stdout_truncated=False,
                stderr_truncated=False,
            )

        with self.assertRaisesRegex(ValueError, "command differs from request"):
            collect_results(self.manifest, "tests", ['{"argv": ["check"]}'], run=run)

    def test_missing_command_is_blocked_and_cannot_complete_review(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = collect_results(
                self.manifest,
                "tests",
                [json.dumps({"argv": [str(Path(tmp) / "missing")], "cwd": tmp})],
            )
            self.assertEqual("BLOCKED", result["status"])
            self.assertIsNone(result["commands"][0]["exit_code"])
            self.assertTrue(Path(result["commands"][0]["stderr_path"]).is_file())
            report = Path(tmp) / "result.json"
            report.write_text(json.dumps(result))
            _, counts, errors, failures = validate_tool_results([report], self.manifest)
            self.assertNotIn("tests", counts)
            self.assertTrue(any("unavailable" in e for e in errors))
            self.assertEqual([], failures)

    def test_failed_command_and_timeout_retain_both_causes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            commands = [
                json.dumps({"argv": [sys.executable, "-c", code], "cwd": tmp, "timeout_seconds": 1})
                for code in ["raise SystemExit(3)", "import time; time.sleep(20)"]
            ]
            result = collect_results(self.manifest, "tests", commands)
            self.assertEqual("FAIL", result["status"])
            self.assertEqual(3, result["commands"][0]["exit_code"])
            self.assertIn("TimeoutExpired", result["commands"][1]["error"])
            report = Path(tmp) / "result.json"
            report.write_text(json.dumps(result))
            _, _, errors, failures = validate_tool_results([report], self.manifest)
            self.assertIn("tests", failures)
            self.assertTrue(any("unavailable" in e for e in errors))

    def test_full_output_persists_beyond_report_excerpt(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = run_command([sys.executable, "-c", 'print("x"*50000)'], tmp)
            self.assertIsNone(result["error"])
            self.assertTrue(result["stdout_truncated"])
            self.assertEqual(EXCERPT_BYTES, len(result["stdout_excerpt"]))
            self.assertEqual(50001, Path(result["stdout_path"]).stat().st_size)

    def test_invalid_timeout_in_later_command_prevents_all_execution(self) -> None:
        calls: list[tuple[object, ...]] = []

        def record_call(*args: object) -> Any:
            calls.append(args)
            return {}

        for invalid in (
            {"argv": ["bad"], "timeout_seconds": 0},
            {"argv": ["bad"], "cwd": "bad\0path"},
        ):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                collect_results(
                    self.manifest,
                    "tests",
                    ['{"argv":["ok"]}', json.dumps(invalid)],
                    run=record_call,
                )
        self.assertEqual([], calls)

    def test_report_text_has_no_filesystem_effect(self) -> None:
        with patch.object(Path, "write_text", side_effect=AssertionError("Unexpected write")):
            text = render_report_text(
                {
                    "pipeline_status": "INCOMPLETE",
                    "code_verdict": "NEEDS_WORK",
                    "errors": ["missing evidence"],
                }
            )
        self.assertIn("missing evidence", text)


if __name__ == "__main__":
    unittest.main()
