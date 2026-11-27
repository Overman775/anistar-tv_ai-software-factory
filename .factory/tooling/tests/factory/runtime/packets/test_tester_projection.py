from __future__ import annotations

import json
import time
import unittest
from datetime import UTC, datetime

from factory.runtime.commands.verification import capture
from factory.runtime.contracts import agent_key
from factory.runtime.scheduling.assignment import delivered_findings, implement_packet
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class TesterProjectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = WorkflowFixture(self.addCleanup)
        self.f.require_fixture_review()
        self.f.init()
        self.f.start("write-label")
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        self.f.start("verify-label")
        self.f.ledger.finish("verify-label", self.f.report("verify-label"))
        self.f.start("review-label", "reviewer")
        self.state = self.f.ledger.read()
        predecessor = next(n for n in self.state["graph"]["nodes"] if n["id"] == "verify-label")
        self.state["graph"]["agents"][agent_key(predecessor)]["role"] = "tester"

    def test_mixed_verification_counts_stay_with_their_scope(self) -> None:
        report = self.state["nodes"]["verify-label"]["report"]
        receipt = self.state["executions"][report["checks"][0]["execution_id"]]
        receipt["verification"] = [
            {
                "suite": scope,
                "phase": "verify",
                "result": "PASS",
                "scope": scope,
                "counts": {"selected": count, "completed": count},
                "failures": [],
                "diagnostics": ["passing-name"],
            }
            for scope, count in [("filtered", 1), ("full", 2)]
        ]
        delivered = implement_packet(self.state, "review-label")["dependency_results"][
            "verify-label"
        ]
        facts = delivered["report"]["verification"]
        self.assertEqual(
            {"filtered": {"selected": 1, "completed": 1}, "full": {"selected": 2, "completed": 2}},
            {item["scope"]: item["counts"] for item in facts},
        )
        self.assertTrue(all(item["failures"] == [] and item["diagnostics"] == [] for item in facts))
        self.assertIn("report_ref", delivered)

    def test_delivered_packets(self) -> None:
        for suite, failed, infra in (
            ("unit", 2, False),
            ("unit", 0, False),
            ("prepare", 0, True),
            ("analyze", 1, False),
        ):
            with self.subTest(suite=suite, failed=failed, infra=infra):
                directory = self.f.root / "build/quality" / f"{suite}-{failed}"
                directory.mkdir(parents=True, exist_ok=True)
                data = {
                    "suite": suite,
                    "scope": "filtered",
                    "phase": suite,
                    "exit_code": int(bool(failed)),
                    "started_at": datetime.now(UTC).isoformat(),
                    "completed_test_count": 50,
                    "skipped_test_count": 3,
                    "passed": 50 - failed,
                    "failures": failed,
                    "errors": 0,
                    "event_stream_complete": True,
                    "completed_tests": [f"passing-case-{i}" for i in range(48)],
                }
                (directory / "summary.json").write_text(json.dumps(data))
                cases = "".join(
                    f'<testcase name="broken-{i}"><failure>Expected true\ntest/widget_test.dart:42:9</failure></testcase>'
                    for i in range(failed)
                )
                (directory / "junit.xml").write_text("<testsuite>" + cases + "</testsuite>")
                if suite == "analyze":
                    (directory / "stage.log").write_text(
                        "error • Invalid assignment • lib/main.dart:9:2\n"
                    )
                log = self.f.root / "current.log"
                log.write_text(f"FAIL suite={suite} scope=filtered report={directory}\n")
                check = self.state["nodes"]["verify-label"]["report"]["checks"][0]
                receipt = self.state["executions"][check["execution_id"]]
                receipt["verification"] = capture(
                    log, self.f.root, time.time() - 10, result_format="anistar-quality"
                )
                receipt["status"] = "BLOCKED" if infra else "FAIL" if failed else "PASS"
                receipt["error"] = "TimeoutExpired: setup interrupted" if infra else None
                original = json.dumps(self.state["nodes"]["verify-label"]["report"], sort_keys=True)
                packet = implement_packet(self.state, "review-label")
                self.assertEqual(
                    original,
                    json.dumps(self.state["nodes"]["verify-label"]["report"], sort_keys=True),
                )
                predecessor = packet["dependency_results"]["verify-label"]
                self.assertIn("report_ref", predecessor)
                delivered = json.dumps(predecessor)
                self.assertNotIn("passing-case", delivered)
                details = predecessor["report"]["verification"][0]
                self.assertEqual(details["counts"]["passed"], 50 - failed)
                if failed:
                    self.assertIn("broken-0", delivered)
                    self.assertIn("test/widget_test.dart:42:9", delivered)
                if infra:
                    self.assertIn("TimeoutExpired", delivered)
                if suite == "analyze":
                    self.assertIn("lib/main.dart:9:2", delivered)
                self.assertEqual(
                    capture(log, self.f.root, time.time() + 10, result_format="anistar-quality")[0][
                        "result"
                    ],
                    "BLOCKED",
                )

    def test_historical_record_does_not_read_current_build_artifacts(self) -> None:
        check = self.state["nodes"]["verify-label"]["report"]["checks"][0]
        del self.state["executions"][check["execution_id"]]
        packet = implement_packet(self.state, "review-label")
        delivered = packet["dependency_results"]["verify-label"]["report"]
        self.assertIn("unavailable", delivered["verification"][0]["diagnostics"][0])

    def test_pre_execution_blocker_keeps_observation_without_structured_receipt(self) -> None:
        report = self.state["nodes"]["verify-label"]["report"]
        report["outcome"] = "BLOCKED"
        report["summary"] = "Device unavailable before execution"
        report["evidence"] = "Emulator transport refused the connection before tests started"
        self.state["executions"] = {}
        packet = implement_packet(self.state, "review-label")
        delivered = packet["dependency_results"]["verify-label"]
        self.assertIn("report_ref", delivered)
        self.assertEqual("BLOCKED", delivered["report"]["outcome"])
        self.assertIn(
            "Emulator transport refused the connection before tests started",
            "\n".join(delivered["report"]["verification"][0]["diagnostics"]),
        )

    def test_generic_unittest_counts_and_failure_names(self) -> None:
        log = self.f.root / "unittest.log"
        log.write_text(
            "FAIL: test_widget (WidgetTests)\nRan 50 tests in 1.2s\nFAILED (failures=2)\n"
        )
        result = capture(log, self.f.root, time.time(), 1)[0]
        self.assertEqual(result["counts"]["passed"], 48)
        self.assertEqual(result["failures"][0]["name"], "test_widget (WidgetTests)")

    def test_anistar_reports_with_spaces_and_static_success(self) -> None:
        directory = self.f.root / "build/quality/analyze with spaces"
        directory.mkdir(parents=True)
        (directory / "summary.json").write_text(
            json.dumps(
                {
                    "suite": "analyze",
                    "scope": "full",
                    "phase": "analyze",
                    "exit_code": 0,
                    "started_at": datetime.now(UTC).isoformat(),
                }
            )
        )
        log = self.f.root / "current.log"
        log.write_text(f"OK suite=analyze scope=full report={directory}\n")
        result = capture(log, self.f.root, time.time() - 10, 0, result_format="anistar-quality")[0]
        self.assertEqual(result["result"], "PASS")
        self.assertEqual(result["counts"], {})
        self.assertEqual(result["diagnostics"], [])

    def test_non_tester_handoff_is_unchanged(self) -> None:
        predecessor = next(n for n in self.state["graph"]["nodes"] if n["id"] == "verify-label")
        self.state["graph"]["agents"][agent_key(predecessor)]["role"] = "generalist"
        packet = implement_packet(self.state, "review-label")
        report = packet["dependency_results"]["verify-label"]["report"]
        self.assertEqual(report["summary"], "Fixture result")
        self.assertTrue(report["checks"])
        self.assertNotIn("verification", report)

    def test_expected_incomplete_report_blocks_canonical_receipt(self) -> None:
        import sys

        fixture = WorkflowFixture(self.addCleanup)
        execution = fixture.g["tasks"]["label"]["required_checks"][0]["execution"]
        execution["result_format"] = "anistar-quality"
        script = (
            "import json; from pathlib import Path; from datetime import datetime, UTC; "
            "p=Path('build/quality/current-unique'); p.mkdir(parents=True); "
            "data=dict(suite='unit', scope='full', phase='flutter-tests', exit_code=0, "
            "started_at=datetime.now(UTC).isoformat(), completed_test_count=0, "
            "passed=0, failures=0, errors=0, event_stream_complete=False); "
            "(p/'summary.json').write_text(json.dumps(data)); "
            "print(f'OK suite=unit scope=full report={p}')"
        )
        execution["argv"] = [sys.executable, "-c", script]
        fixture.init()
        fixture.start("write-label")
        fixture.ledger.finish("write-label", fixture.report("write-label"))
        fixture.start("verify-label")
        result = fixture.ledger.run_check("verify-label", "behavior")
        self.assertEqual(result["result"], "BLOCKED")
        state = fixture.ledger.read()
        receipt = state["executions"][result["execution_id"]]
        self.assertEqual(receipt["status"], "BLOCKED")
        self.assertIn("evidence", receipt["error"] or "")

    def test_correct_delivers_failed_verifier_to_author(self) -> None:
        import sys

        fixture = WorkflowFixture(self.addCleanup)
        fixture.config["_defaults"]["implementer"] = "middle-implementer"
        fixture.g["agents"]["author"]["profile"] = "middle-implementer"
        fixture.require_fixture_review()
        execution = fixture.g["tasks"]["label"]["required_checks"][0]["execution"]
        execution["argv"] = [
            sys.executable,
            "-c",
            "print('FAIL: test_widget (WidgetTests)\\n  File \"test/widget_test.py\", line 42\\nAssertionError: expected true\\nRan 50 tests in 1.2s\\nFAILED (failures=2)'); raise SystemExit(1)",
        ]
        fixture.init()
        fixture.start("write-label")
        fixture.ledger.finish("write-label", fixture.report("write-label"))
        fixture.start("verify-label")
        result = fixture.ledger.run_check("verify-label", "behavior")
        fixture.ledger.finish(
            "verify-label",
            fixture.report("verify-label", "FAIL", stage_result="FAIL_TEST", checks=[result]),
        )
        state = fixture.ledger.read()
        reference = state["nodes"]["verify-label"]["report_ref"]
        fixture.ledger.correct(
            "write-label",
            {
                "author_dispatch_id": state["nodes"]["write-label"]["dispatch_id"],
                "evidence_node": "verify-label",
                "evidence_dispatch_id": state["nodes"]["verify-label"]["dispatch_id"],
                "cause": "tests",
                "kind": "quality",
                "reason": "Confirmed regression",
                "terminal_evidence": "Both turns terminal",
                "handoff": "Fix failed behavior",
            },
        )
        fixture.start("write-label", "corrected-author")
        packet = fixture.ledger.packet("write-label")
        history = packet["correction"]["history"][0]
        self.assertEqual(history["report_ref"], reference)
        self.assertEqual(history["evidence"]["stage_result"], "FAIL_TEST")
        self.assertEqual(history["evidence"]["checks"][0]["id"], "behavior")
        failure = history["evidence"]["verification"][0]["failures"][0]
        self.assertEqual(failure["name"], "test_widget (WidgetTests)")
        self.assertEqual(failure["location"], "test/widget_test.py:42")
        self.assertEqual(failure["check_id"], "behavior")
        self.assertIn("expected true", failure["diagnostic"])
        self.assertNotIn("files", history["evidence"])

    def test_assigned_failed_observation_reaches_author_beside_passing_command(self) -> None:
        fixture = WorkflowFixture(self.addCleanup)
        fixture.g["agents"]["author"]["profile"] = "middle-implementer"
        fixture.config["_defaults"]["implementer"] = "middle-implementer"
        observation = {
            "id": "visible-unit",
            "kind": "observation",
            "assessor": "tester",
            "category": "acceptance",
            "criteria": ["AC-01"],
            "method": "Inspect the output unit",
        }
        fixture.g["tasks"]["label"]["required_checks"].append(observation)
        fixture.init()
        fixture.start("write-label")
        fixture.ledger.finish("write-label", fixture.report("write-label"))
        fixture.start("verify-label")
        passed = fixture.ledger.run_check("verify-label", "behavior")
        detail = "Rendered total on line 1 uses USD; expected EUR."
        failed = {**observation, "result": "FAIL", "evidence": detail}
        report = fixture.report(
            "verify-label", "FAIL", stage_result="FAIL_CODE", checks=[passed, failed]
        )
        report.pop("evidence")  # The assigned observation carries the only failure evidence.
        fixture.ledger.finish("verify-label", report)
        state = fixture.ledger.read()
        record = fixture.ledger.correct(
            "write-label",
            {
                "author_dispatch_id": state["nodes"]["write-label"]["dispatch_id"],
                "evidence_node": "verify-label",
                "evidence_dispatch_id": report["dispatch_id"],
                "kind": "quality",
                "cause": "tests",
                "reason": "Assigned observation failed",
                "terminal_evidence": "Tester has finished",
                "handoff": "Correct the displayed unit",
            },
        )
        self.assertIn(record["decision"], {"retry", "escalate"})
        fixture.claim("write-label")
        item = fixture.ledger.packet("write-label")["correction"]["history"][-1]
        self.assertEqual(item["report_ref"], state["nodes"]["verify-label"]["report_ref"])
        self.assertEqual(
            item["evidence"]["checks"],
            [
                {
                    "kind": "observation",
                    "id": "visible-unit",
                    "result": "FAIL",
                    "evidence": detail,
                }
            ],
        )

    def test_generic_zero_incomplete_and_skipped_counts(self) -> None:
        log = self.f.root / "unittest.log"
        for text in ("No tests found\n", "Ran 0 tests in 0s\nOK\n", "Ran 3 tests in 1s\n"):
            with self.subTest(text=text):
                log.write_text(text)
                self.assertEqual(capture(log, self.f.root, time.time(), 0)[0]["result"], "BLOCKED")
        log.write_text("Ran 5 tests in 1s\nOK (skipped=2)\n")
        result = capture(log, self.f.root, time.time(), 0)[0]
        self.assertEqual(
            result["counts"],
            {"selected": 5, "completed_test_count": 3, "skipped_test_count": 2, "passed": 3},
        )

    def test_e2e_aggregate_does_not_double_count_child_suites(self) -> None:
        base = {
            "scope": "full",
            "phase": "flutter-tests",
            "exit_code": 0,
            "started_at": datetime.now(UTC).isoformat(),
            "completed_test_count": 2,
            "skipped_test_count": 0,
            "passed": 2,
            "failures": 0,
            "errors": 0,
            "event_stream_complete": True,
            "event_stream_issues": [],
        }
        root = self.f.root / "build/e2e"
        root.mkdir(parents=True)
        for name, data in (
            ("tv", {**base, "suite": "e2e:tv"}),
            ("mobile", {**base, "suite": "e2e:mobile"}),
            (
                "all",
                {
                    "scope": "full",
                    "status": "passed",
                    "runs": [{**base, "suite": "e2e:tv"}, {**base, "suite": "e2e:mobile"}],
                },
            ),
        ):
            directory = root / name
            directory.mkdir()
            (directory / "summary.json").write_text(json.dumps(data))
        log = self.f.root / "e2e.log"
        log.write_text(
            "".join(
                f"OK suite=e2e:{name} scope=full report={root / name}\n"
                for name in ("tv", "mobile", "all")
            )
        )
        results = capture(log, self.f.root, time.time() - 10, 0, result_format="anistar-quality")
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["counts"]["passed"], 4)

    def test_opted_in_missing_or_false_green_report_is_blocked(self) -> None:
        log = self.f.root / "missing.log"
        log.write_text("command exited successfully\n")
        self.assertEqual(
            capture(log, self.f.root, time.time(), 0, result_format="anistar-quality")[0]["result"],
            "BLOCKED",
        )
        self.assertEqual(capture(log, self.f.root, time.time(), 0)[0]["result"], "PASS")
        directory = self.f.root / "build/quality/contradictory"
        directory.mkdir(parents=True)
        base = {
            "suite": "unit",
            "scope": "full",
            "phase": "flutter-tests",
            "exit_code": 0,
            "started_at": datetime.now(UTC).isoformat(),
            "completed_test_count": 2,
            "passed": 1,
            "failures": 1,
            "errors": 0,
            "event_stream_complete": True,
        }
        for changes in (
            {},
            {"exit_code": "0"},
            {"completed_test_count": None},
            {"event_stream_complete": False},
        ):
            with self.subTest(changes=changes):
                (directory / "summary.json").write_text(json.dumps({**base, **changes}))
                log.write_text(f"OK suite=unit scope=full report={directory}\n")
                self.assertEqual(
                    capture(log, self.f.root, time.time() - 10, 0, result_format="anistar-quality")[
                        0
                    ]["result"],
                    "BLOCKED",
                )

    def test_non_escalating_retry_delivers_failed_verifier_to_author(self) -> None:
        import sys

        fixture = WorkflowFixture(self.addCleanup)
        fixture.g["tasks"]["label"]["required_checks"][0]["execution"]["argv"] = [
            sys.executable,
            "-c",
            "print('FAIL: test_retry (Tests)\\nRan 1 test in 1s\\nFAILED (failures=1)'); raise SystemExit(1)",
        ]
        fixture.init()
        fixture.start("write-label")
        fixture.ledger.finish("write-label", fixture.report("write-label"))
        fixture.start("verify-label")
        failed = fixture.ledger.run_check("verify-label", "behavior")
        fixture.ledger.finish(
            "verify-label",
            fixture.report(
                "verify-label",
                "FAIL",
                checks=[failed],
                stage_result="FAIL_CODE",
                summary="test_passing_case passed; test_retry failed",
                findings=[
                    dict(
                        id="REV-1",
                        status="open",
                        blocking=True,
                        owner_role="implementer",
                        summary="test_passing_case passed; repair the failed behavior",
                        evidence="test_passing_case passed; test_retry failed",
                    )
                ],
            ),
        )
        reference = fixture.ledger.read()["nodes"]["verify-label"]["report_ref"]
        fixture.ledger.retry("write-label", "tests", "Fix verified defect", "Turns terminal")
        fixture.start("write-label")
        packet = fixture.ledger.packet("write-label")
        previous = packet["correction"]["verification_failures"][0]
        self.assertNotIn("test_passing_case", json.dumps(packet))
        self.assertNotIn("gate_results", previous["report"])
        self.assertNotIn("findings", previous["report"])
        finding = packet["review_findings"]["REV-1"]
        self.assertEqual("implementer", finding["owner_role"])
        self.assertIn("test_retry", finding["evidence"])
        self.assertIn("test_retry", finding["reviewed"]["evidence"])
        canonical = fixture.ledger.read()["review_findings"]["label"]["REV-1"]
        self.assertIn("test_passing_case", canonical["summary"])
        self.assertIn("test_passing_case", canonical["evidence"])
        state = fixture.ledger.read()
        for receipt in state["executions"].values():
            receipt.pop("verification", None)
        legacy = delivered_findings(state, "label", include_dependencies=False)["REV-1"]
        self.assertEqual(canonical["evidence"], legacy["evidence"])
        origin_node = next(n for n in state["graph"]["nodes"] if n["id"] == "verify-label")
        state["graph"]["agents"][agent_key(origin_node)]["role"] = "judge"
        judge = delivered_findings(state, "label", include_dependencies=False)["REV-1"]
        self.assertEqual(canonical["summary"], judge["summary"])
        self.assertEqual(canonical["evidence"], judge["evidence"])
        state["graph"]["nodes"].remove(origin_node)
        self.assertEqual(
            judge, delivered_findings(state, "label", include_dependencies=False)["REV-1"]
        )
        state["review_findings"]["label"]["REV-1"]["history"] = []
        self.assertEqual(
            judge, delivered_findings(state, "label", include_dependencies=False)["REV-1"]
        )
        self.assertEqual(previous["report_ref"], reference)
        self.assertTrue(previous["historical"])
        self.assertEqual(previous["report"]["outcome"], "FAIL")
        self.assertEqual(previous["report"]["checks"][0]["id"], "behavior")
        self.assertEqual(
            previous["report"]["verification"][0]["failures"][0]["name"], "test_retry (Tests)"
        )

    def test_real_flutter_failure_protocol_supplies_assertion_and_location(self) -> None:
        directory = self.f.root / "build/quality/goldens-protocol"
        directory.mkdir(parents=True)
        data = {
            "suite": "goldens",
            "scope": "full",
            "phase": "flutter-tests",
            "exit_code": 1,
            "started_at": datetime.now(UTC).isoformat(),
            "completed_test_count": 50,
            "passed": 48,
            "failures": 2,
            "errors": 0,
            "event_stream_complete": True,
        }
        (directory / "summary.json").write_text(json.dumps(data))
        (directory / "junit.xml").write_text(
            '<testsuite><testcase name="broken"><error>Test failed. See exception logs above.</error></testcase></testsuite>'
        )
        events = [
            {"type": "suite", "suite": {"id": 0, "path": "/project/test/widget_test.dart"}},
            {"type": "testStart", "test": {"id": 5, "name": "passing-name", "suiteID": 0}},
            {"type": "print", "testID": 5, "message": "Do not deliver this passing case"},
            {
                "type": "testStart",
                "test": {
                    "id": 7,
                    "name": "broken",
                    "suiteID": 0,
                    "root_line": 24,
                    "root_url": "file:///project/test/widget_test.dart",
                    "url": "package:flutter_test/src/widget_tester.dart",
                    "line": 174,
                },
            },
            {
                "type": "print",
                "testID": 7,
                "message": "The following TestFailure was thrown:\nExpected: exactly one matching candidate\nActual: Found 0 widgets\n#4 main (file:///project/test/widget_test.dart:36:5)",
            },
            {
                "type": "error",
                "testID": 7,
                "error": "Test failed. See exception logs above.",
                "stackTrace": "",
            },
        ]
        (directory / "flutter-events.jsonl").write_text(
            "".join(json.dumps(event) + "\n" for event in events)
        )
        log = self.f.root / "current.log"
        log.write_text(f"FAIL suite=goldens scope=full report={directory}\n")
        result = capture(log, self.f.root, time.time() - 10, 1, result_format="anistar-quality")[0]
        failure = result["failures"][0]
        self.assertEqual(failure["location"], "/project/test/widget_test.dart:36:5")
        self.assertEqual(failure["path"], "/project/test/widget_test.dart")
        self.assertIn("Expected: exactly one", failure["diagnostic"])
        self.assertNotIn("passing-name", json.dumps(result))

    def test_failed_analyzer_info_and_format_paths_are_preserved(self) -> None:
        directory = self.f.root / "build/quality/static-diagnostics"
        directory.mkdir(parents=True)
        log = self.f.root / "current.log"
        for suite, message in (
            ("analyze", "info • Sort directives • lib/main.dart:24:1 • directives_ordering"),
            ("format-check", "Changed lib/widget.dart"),
        ):
            (directory / "summary.json").write_text(
                json.dumps(
                    {
                        "suite": suite,
                        "scope": "full",
                        "phase": suite,
                        "exit_code": 1,
                        "started_at": datetime.now(UTC).isoformat(),
                    }
                )
            )
            (directory / "stage.log").write_text(message + "\n")
            log.write_text(f"FAIL suite={suite} scope=full report={directory}\n")
            result = capture(
                log, self.f.root, time.time() - 10, 1, result_format="anistar-quality"
            )[0]
            self.assertEqual(result["diagnostics"], [message])

    def test_duplicate_flutter_names_bind_only_to_failing_execution_ids(self) -> None:
        from factory.runtime.commands.verification import Failure, _enrich_failures

        directory = self.f.root / "duplicate-events"
        directory.mkdir()
        events = []
        for test_id, path, failed, line in (
            (1, "passing", False, 11),
            (2, "failure_a", True, 22),
            (3, "failure_b", True, 33),
        ):
            events.extend(
                [
                    {
                        "type": "testStart",
                        "test": {
                            "id": test_id,
                            "name": "shared name",
                            "root_url": f"file:///project/test/{path}.dart",
                            "root_line": 1,
                        },
                    },
                    {
                        "type": "print",
                        "testID": test_id,
                        "message": f"Expected: {path}\nActual: mismatch\n#4 main (file:///project/test/{path}.dart:{line}:5)",
                    },
                    {
                        "type": "testDone",
                        "testID": test_id,
                        "result": "failure" if failed else "success",
                        "skipped": False,
                    },
                ]
            )
        # A passing execution can finish last; it must not overwrite either failed location.
        events.append(
            {
                "type": "print",
                "testID": 1,
                "message": "Expected: passing late\n#4 main (file:///project/test/passing.dart:99:5)",
            }
        )
        (directory / "flutter-events.jsonl").write_text(
            "".join(json.dumps(event) + "\n" for event in events)
        )
        failures: list[Failure] = [
            {"name": "shared name", "diagnostic": "JUnit failure"},
            {"name": "shared name", "diagnostic": "JUnit failure"},
        ]
        _enrich_failures(directory, failures, time.time() - 10)
        self.assertEqual(
            [failure["location"] for failure in failures],
            ["/project/test/failure_a.dart:22:5", "/project/test/failure_b.dart:33:5"],
        )
        self.assertNotIn("passing", json.dumps(failures))
        ambiguous: list[Failure] = [
            {"name": "shared name", "diagnostic": "Unmatched JUnit identity"}
        ]
        _enrich_failures(directory, ambiguous, time.time() - 10)
        self.assertEqual(
            ambiguous, [{"name": "shared name", "diagnostic": "Unmatched JUnit identity"}]
        )

    def test_filtered_marker_selection_is_persisted_and_invalid_runs_block(self) -> None:
        import sys

        cases = (
            ({"mode": "filtered", "selected": 3, "completed": 2, "skipped": 1}, "PASS"),
            ({"mode": "filtered", "selected": 2, "completed": 2}, "PASS"),
            ({"mode": "full", "selected": 2, "completed": 2}, "BLOCKED"),
            ({"mode": "filtered", "selected": 0, "completed": 0}, "BLOCKED"),
            ({"mode": "filtered", "selected": 2, "completed": 0, "skipped": 2}, "BLOCKED"),
            ({"mode": "filtered", "selected": 3, "completed": 2}, "BLOCKED"),
            (None, "BLOCKED"),
        )
        for marker, expected in cases:
            with self.subTest(marker=marker):
                fixture = WorkflowFixture(self.addCleanup)
                execution = fixture.g["tasks"]["label"]["required_checks"][0]["execution"]
                execution["mode"] = "filtered"
                text = (
                    "FACTORY_TEST_SELECTION " + json.dumps(marker)
                    if marker is not None
                    else "generic command output"
                )
                execution["argv"] = [sys.executable, "-c", f"print({text!r})"]
                fixture.init()
                fixture.start("write-label")
                fixture.ledger.finish("write-label", fixture.report("write-label"))
                fixture.start("verify-label")
                result = fixture.ledger.run_check("verify-label", "behavior")
                self.assertEqual(result["result"], expected)
                receipt = fixture.ledger.read()["executions"][result["execution_id"]]
                if expected == "PASS":
                    self.assertEqual(receipt["selection"], marker)
                    assert marker is not None
                    counts = receipt["verification"][0]["counts"]
                    self.assertEqual(counts["completed_test_count"], marker["completed"])
                    self.assertEqual(counts["skipped_test_count"], marker.get("skipped", 0))
                else:
                    self.assertNotIn("selection", receipt)

    def test_filtered_opted_in_summary_selection_preserves_skips_and_scope(self) -> None:
        import sys

        for scope, completed, skipped, expected in (
            ("filtered", 2, 1, "PASS"),
            ("full", 2, 1, "BLOCKED"),
            ("filtered", 0, 3, "BLOCKED"),
        ):
            with self.subTest(scope=scope, completed=completed):
                fixture = WorkflowFixture(self.addCleanup)
                execution = fixture.g["tasks"]["label"]["required_checks"][0]["execution"]
                execution.update(mode="filtered", result_format="anistar-quality")
                data = {
                    "suite": "unit",
                    "scope": scope,
                    "phase": "flutter-tests",
                    "exit_code": 0,
                    "completed_test_count": completed,
                    "skipped_test_count": skipped,
                    "passed": completed,
                    "failures": 0,
                    "errors": 0,
                    "event_stream_complete": True,
                    "event_stream_issues": [],
                }
                script = (
                    "import json; from pathlib import Path; from datetime import datetime, UTC; p=Path('build/quality/focused'); p.mkdir(parents=True); data="
                    + repr(data)
                    + "; data['started_at']=datetime.now(UTC).isoformat(); (p/'summary.json').write_text(json.dumps(data)); print(f'OK suite=unit scope="
                    + scope
                    + " report={p}')"
                )
                execution["argv"] = [sys.executable, "-c", script]
                fixture.init()
                fixture.start("write-label")
                fixture.ledger.finish("write-label", fixture.report("write-label"))
                fixture.start("verify-label")
                result = fixture.ledger.run_check("verify-label", "behavior")
                self.assertEqual(result["result"], expected)
                receipt = fixture.ledger.read()["executions"][result["execution_id"]]
                if expected == "PASS":
                    self.assertEqual(
                        receipt["selection"],
                        {"mode": "filtered", "selected": 3, "completed": 2, "skipped": 1},
                    )
                else:
                    self.assertNotIn("selection", receipt)
