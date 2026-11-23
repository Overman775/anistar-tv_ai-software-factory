"""Regressions for reconciliation, historical scope and durable command ownership."""

from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import time
from copy import deepcopy
from pathlib import Path
from unittest import TestCase, skipUnless
from unittest.mock import patch

from factory.database.sqlite import workflow_db
from factory.project.profile_io import load_profile
from factory.project.profile_rules import required_checks
from factory.runtime import command_worker
from factory.runtime.history import report_history
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime import workflow_fixture
from tests.factory.runtime.store_fixture import overwrite

CLI = Path(__file__).resolve().parents[3] / "bin/workflow.py"


class RetroTransitionsTests(TestCase):
    def setUp(self) -> None:
        self.f = workflow_fixture.WorkflowFixture(self.addCleanup)

    def test_next_actions_acknowledges_exact_dispatch_and_preserves_pause(self) -> None:
        f = self.f
        f.init()
        first = f.ledger.next_actions()
        self.assertEqual(["write-label"], first["runnable"])
        self.assertTrue(f.ledger.next_actions(first["cursor"])["unchanged"])
        f.ledger.set_paused("User stopped")
        self.assertEqual([], f.ledger.next_actions()["runnable"])
        with self.assertRaisesRegex(Invalid, "paused"):
            f.ledger.claim("write-label")
        resumed = Ledger(f.root)
        self.assertEqual("User stopped", resumed.next_actions()["pause_reason"])
        resumed.set_paused(None)
        f.start("write-label")
        self.assertEqual("running", resumed.next_actions()["dispatches"]["write-label"]["status"])
        f.ledger.unknown("write-label", "lost host response")
        self.assertIn("Reconcile actual", resumed.next_actions()["blockers"]["write-label"])
        f.ledger.resolve("write-label", "running", "host returned")
        f.ledger.finish("write-label", f.report("write-label"))
        returned = Ledger(f.root).next_actions()
        result = returned["results"]["write-label"]
        self.assertEqual("PASS", result["outcome"])
        self.assertEqual(["verify-label"], returned["runnable"])
        with self.assertRaisesRegex(Invalid, "stale"):
            resumed.acknowledge_result("write-label", "old")
        resumed.acknowledge_result("write-label", result["dispatch_id"])
        state = resumed.read()
        resumed.acknowledge_result("write-label", result["dispatch_id"])
        self.assertEqual(state, resumed.read())
        self.assertEqual({}, resumed.next_actions()["results"])
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        self.assertEqual(["accept-label"], resumed.next_actions()["acceptance"])
        resumed.accept("accept-label")
        self.assertTrue(resumed.next_actions()["completion_eligible"])

    def test_next_checks_config_once_and_detects_drift_on_next_call(self) -> None:
        from factory.runtime import workflow_config

        f = self.f
        policy_file = f.root / "policy.yaml"
        policy_file.write_text("policy: before\n")
        from factory.runtime.workflow_core import digest

        f.config["_files"][str(policy_file)] = digest(policy_file.read_bytes())
        f.init()
        with patch(
            "factory.runtime.workflow_query.check_config", wraps=workflow_config.check_config
        ) as check:
            result = f.ledger.next_actions()
            self.assertEqual(1, check.call_count)
        self.assertEqual("Unfinished nodes", result["blockers"]["completion"])
        policy_file.write_text("policy: changed\n")
        result = f.ledger.next_actions()
        self.assertIn("run", result["blockers"])
        self.assertFalse(result["completion_eligible"])

    def test_additive_scope_requires_current_verification_and_keeps_original_report(self) -> None:
        f = self.f
        f.g["agents"]["author"] = {"role": "developer", "profile": "middle-developer"}
        f.require_fixture_review()
        verify = next(node for node in f.g["nodes"] if node["id"] == "verify-label")
        verify["agent"] = "fixture-judge"
        f.g["tasks"]["label"]["required_checks"][0]["execution"]["argv"] = [
            sys.executable,
            "-c",
            "from pathlib import Path; raise SystemExit(0 if Path('behavior-dependency.txt').is_file() else 3)",
        ]
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label", "fixture-judge")
        report = f.report("verify-label", "FAIL", stage_result="FAIL_CODE")
        self.assertEqual(3, report["checks"][0]["exit_code"])
        f.ledger.finish("verify-label", report)
        state = f.ledger.read()
        ref = state["nodes"]["verify-label"]["report_ref"]
        historical = report_history.read(f.root, ref)
        (f.root / "behavior-dependency.txt").write_text("current behavior")
        f.ledger.expand_scope(
            "label", ["behavior-dependency.txt"], "Reproduce with relevant dependency"
        )
        current = f.ledger.read()
        self.assertEqual("pending", current["nodes"]["verify-label"]["status"])
        self.assertEqual({}, current["counters"])
        f.ledger.expand_scope("label", ["behavior-dependency.txt"], "Repeated scope")
        self.assertEqual(current, f.ledger.read())
        correction = {
            "author_dispatch_id": state["nodes"]["write-label"]["dispatch_id"],
            "evidence_node": "verify-label",
            "evidence_dispatch_id": report["dispatch_id"],
            "cause": "tests",
            "kind": "quality",
            "reason": "old failure",
            "terminal_evidence": "terminal",
            "handoff": "replay",
        }
        with self.assertRaisesRegex(Invalid, "Historical failure|current verification"):
            f.ledger.correct("write-label", correction)
        f.start("verify-label", "fixture-judge")
        fresh = f.report("verify-label")
        self.assertEqual(0, fresh["checks"][0]["exit_code"])
        self.assertNotEqual(report["dispatch_id"], fresh["dispatch_id"])
        self.assertEqual(report["source_hash"], fresh["source_hash"])
        receipt = f.ledger.read()["executions"][fresh["checks"][0]["execution_id"]]
        self.assertIn("behavior-dependency.txt", receipt["input_scope"])
        incomplete = deepcopy(fresh)
        incomplete["files"].pop("behavior-dependency.txt")
        with self.assertRaisesRegex(Invalid, "Stale/incomplete"):
            f.ledger.finish("verify-label", incomplete)
        f.ledger.finish("verify-label", fresh)
        self.assertEqual(historical, report_history.read(f.root, ref))
        resolved = f.ledger.read()
        with self.assertRaisesRegex(Invalid, "Historical failure was superseded"):
            f.ledger.correct("write-label", correction)
        self.assertEqual(resolved, f.ledger.read())
        self.assertEqual(state["counters"], resolved["counters"])
        self.assertEqual("middle-developer", resolved["nodes"]["write-label"]["profile"])

        f.start("review-label", "fixture-judge")
        f.ledger.finish("review-label", f.report("review-label", verdict="APPROVE"))
        f.ledger.accept("accept-label")
        f.ledger.archive("completed", "Fresh verification accepted expanded scope")
        f.ledger.clean()
        self.assertFalse((f.root / ref["path"]).exists())
        self.assertEqual(historical, report_history.read(f.root, ref))

    def test_report_history_checks_raw_bytes_before_parsing_shape(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        ref = f.ledger.read()["nodes"]["write-label"]["report_ref"]
        with workflow_db.database(f.root) as db:
            original = db.execute(
                "SELECT body FROM artifact_blobs WHERE sha256=?", (ref["sha256"],)
            ).fetchone()[0]
            db.execute(
                "UPDATE artifact_blobs SET body=? WHERE sha256=?", (original + b" ", ref["sha256"])
            )
        with self.assertRaisesRegex(Invalid, "digest mismatch"):
            report_history.read(f.root, ref)
        with workflow_db.database(f.root) as db:
            db.execute("UPDATE artifact_blobs SET body=? WHERE sha256=?", (original, ref["sha256"]))
        self.assertEqual("PASS", report_history.read(f.root, ref)["report"]["outcome"])

    def ready_check(self, command: str, timeout: int = 10) -> None:
        f = self.f
        f.g["tasks"]["label"]["required_checks"][0]["execution"].update(
            argv=[sys.executable, "-c", command], timeout_seconds=timeout
        )
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")

    def test_unstarted_intent_is_durable_and_requires_explicit_abandonment(self) -> None:
        self.ready_check("raise AssertionError('must not run')")
        f = self.f
        with patch.object(command_worker, "launch", side_effect=OSError("crash before spawn")):
            pending = f.ledger.run_check("verify-label", "behavior", "request")
        self.assertEqual("RUNNING", pending["result"])
        rid = pending["execution_id"]
        self.assertFalse(f.ledger.next_actions()["commands"][rid]["owner_registered"])
        self.assertEqual(pending, Ledger(f.root).run_check("verify-label", "behavior", "request"))
        self.assertEqual("BLOCKED", f.ledger.reconcile_check(rid, abandon_unstarted=True)["result"])
        self.assertNotIn(rid, f.ledger.next_actions()["commands"])

    @skipUnless(os.name == "posix", "POSIX process group fixture")
    def test_timeout_terminates_grandchild_before_releasing_command_resource(self) -> None:
        marker = self.f.root / "survived"
        grandchild = (
            f"import time; from pathlib import Path; time.sleep(2); Path({str(marker)!r}).touch()"
        )
        self.ready_check(
            f"import subprocess, sys, time; subprocess.Popen([sys.executable, '-c', {grandchild!r}]); time.sleep(20)",
            timeout=1,
        )
        f = self.f
        result = f.ledger.run_check("verify-label", "behavior")
        deadline = time.monotonic() + 4
        while result["result"] == "RUNNING" and time.monotonic() < deadline:
            time.sleep(0.02)
            result = f.ledger.reconcile_check(result["execution_id"])
        self.assertEqual("BLOCKED", result["result"])
        assert result["result"] != "RUNNING"
        self.assertIsNone(result["exit_code"])
        self.assertFalse(marker.exists())

    @skipUnless(os.name == "posix", "POSIX process group fixture")
    def test_surviving_child_after_supervisor_death_retains_resource(self) -> None:
        f = self.f
        self.ready_check(
            "import os, time; from pathlib import Path; Path('child.pid').write_text(str(os.getpid())); time.sleep(30)"
        )
        runner = subprocess.Popen(
            [
                sys.executable,
                str(CLI),
                "--workspace",
                str(f.root),
                "run-check",
                "verify-label",
                "behavior",
                "--request",
                "crash",
                "--dispatch",
                f.ledger.read()["nodes"]["verify-label"]["dispatch_id"],
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.addCleanup(runner.communicate, timeout=10)
        pid_path = f.root / "child.pid"
        deadline = time.monotonic() + 10
        while not pid_path.exists() and time.monotonic() < deadline:
            time.sleep(0.03)
        self.assertTrue(pid_path.exists())
        state = f.ledger.read()
        [rid] = state["executions"]
        record = state["executions"][rid]
        owner = json.loads(command_worker.artifact(f.root, record, ".owner.json").read_text())
        group = owner["process_group"]
        self.addCleanup(self.kill_group, group)
        os.kill(group, signal.SIGKILL)
        runner.communicate(timeout=10)
        self.assertEqual("RUNNING", f.ledger.reconcile_check(rid)["result"])
        with self.assertRaisesRegex(Invalid, "Unresolved command"):
            f.ledger.run_check("verify-label", "behavior", "second")
        with self.assertRaisesRegex(Invalid, "Unresolved project commands"):
            f.ledger.archive("cancelled", "attempt")
        self.kill_group(group)
        result = f.ledger.reconcile_check(rid)
        deadline = time.monotonic() + 5
        while result["result"] == "RUNNING" and time.monotonic() < deadline:
            time.sleep(0.03)
            result = f.ledger.reconcile_check(rid)
        self.assertEqual("BLOCKED", result["result"])
        assert result["result"] != "RUNNING"
        self.assertIsNone(result["exit_code"])

    @staticmethod
    def kill_group(group: int) -> None:
        try:
            os.killpg(group, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def test_late_result_is_retained_against_original_dispatch(self) -> None:
        f = self.f
        self.ready_check("print('actual exit')")
        # Interrupt the result transaction while it persists the check output.
        with patch.object(workflow_db, "put", side_effect=OSError("result commit interrupted")):
            with self.assertRaisesRegex(OSError, "result commit interrupted"):
                f.ledger.run_check("verify-label", "behavior")
        state = f.ledger.read()
        [rid] = state["executions"]
        self.assertEqual("RUNNING", state["executions"][rid]["status"])
        old = state["executions"][rid]["dispatch_id"]
        state["nodes"]["verify-label"]["dispatch_id"] = "replacement"
        overwrite(f.ledger, state)
        result = Ledger(f.root).reconcile_check(rid)
        assert result["result"] != "RUNNING"
        self.assertEqual(("BLOCKED", 0), (result["result"], result["exit_code"]))
        self.assertEqual(old, f.ledger.read()["executions"][rid]["dispatch_id"])
        self.assertEqual("replacement", f.ledger.read()["nodes"]["verify-label"]["dispatch_id"])

    def composite_policy(
        self, selection: str, exit_code: int = 0, *, extra_stages: bool = False
    ) -> None:
        f = self.f
        payload = f"print('FACTORY_TEST_SELECTION ' + {selection!r}); raise SystemExit({exit_code})"
        tests = {
            "id": "actual-tests",
            "level": "final",
            "kind": "tests",
            "method": "Full fixture suite",
            "execution": {
                "cwd": ".",
                "argv": [sys.executable, "-c", payload],
                "timeout_seconds": 10,
                "mode": "full",
            },
        }
        aggregate = {
            "id": "aggregate",
            "level": "final",
            "kind": "static",
            "method": "Registered fixture stages",
            "execution": {
                "cwd": ".",
                "argv": [],
                "timeout_seconds": 10,
                "stages": ["preflight", "actual-tests", "skipped"]
                if extra_stages
                else ["actual-tests"],
            },
        }
        checks = [tests, aggregate]
        if extra_stages:
            preflight = {
                **tests,
                "id": "preflight",
                "kind": "static",
                "execution": {
                    "cwd": ".",
                    "argv": [sys.executable, "-c", "pass"],
                    "timeout_seconds": 10,
                    "mode": "full",
                },
            }
            skipped = {**preflight, "id": "skipped"}
            checks = [preflight, tests, skipped, aggregate]
        f.fixture_profile.write_text(
            json.dumps(
                {
                    "id": "fixture",
                    "gates": [
                        {
                            "id": "verification",
                            "at": ["implement.verify"],
                            "checks": checks,
                        }
                    ],
                }
            )
        )
        f.config["_project"] = load_profile(f.fixture_profile)
        f.config["_files"].update(f.config["_project"]["files"])
        task = f.g["tasks"]["label"]
        task["required_checks"] += required_checks(f.config["_project"]["data"], task, final=True)
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")

    def test_composite_receipts_satisfy_full_assignment_without_duplicate_runs(self) -> None:
        f = self.f
        self.composite_policy('{"mode":"full","selected":3,"completed":3}')
        parent = f.ledger.run_check("verify-label", "aggregate", "one-run")
        self.assertEqual("PASS", parent["result"])
        _, child = f.ledger.check_results(parent["execution_id"])
        self.assertEqual("actual-tests", child["id"])
        with self.assertRaisesRegex(Invalid, "actual-tests"):
            f.ledger.finish(
                "verify-label",
                f.report(
                    "verify-label", checks=[f.ledger.run_check("verify-label", "behavior"), parent]
                ),
            )
        report = f.report("verify-label")
        report["checks"].extend([parent, child])
        f.ledger.finish("verify-label", report)
        self.assertEqual(3, len(f.ledger.read()["executions"]))

    def test_prepare_report_expands_composite_with_independent_check(self) -> None:
        f = self.f
        self.composite_policy('{"mode":"full","selected":3,"completed":3}')
        independent = f.ledger.run_check("verify-label", "behavior")
        parent = f.ledger.run_check("verify-label", "aggregate")
        _, child = f.ledger.check_results(parent["execution_id"])
        draft = f.report("verify-label", checks=[])
        draft.pop("files")
        explicit = f.ledger.prepare_report(
            "verify-label",
            draft,
            [independent["execution_id"], parent["execution_id"], child["execution_id"]],
        )
        expanded = f.ledger.prepare_report(
            "verify-label", draft, [independent["execution_id"], parent["execution_id"]]
        )
        self.assertEqual(explicit, expanded)
        self.assertEqual(3, len(expanded["checks"]))
        self.assertEqual(3, len(f.ledger.read()["executions"]))
        original = f.ledger.read()
        missing = deepcopy(original)
        del missing["executions"][child["execution_id"]]
        overwrite(f.ledger, missing)
        with self.assertRaisesRegex(Invalid, "Missing required check results: actual-tests"):
            f.ledger.prepare_report(
                "verify-label", draft, [independent["execution_id"], parent["execution_id"]]
            )
        overwrite(f.ledger, original)
        scope_file = next(iter(original["executions"][child["execution_id"]]["input_scope"]))
        path = f.root / scope_file
        contents = path.read_bytes()
        path.write_bytes(contents + b"changed")
        with self.assertRaisesRegex(Invalid, "invalidated by later write"):
            f.ledger.prepare_report(
                "verify-label", draft, [independent["execution_id"], parent["execution_id"]]
            )
        path.write_bytes(contents)
        f.ledger.finish("verify-label", expanded)

    def test_explicit_later_receipt_overrides_composite_child(self) -> None:
        f = self.f
        self.composite_policy('{"mode":"full","selected":3,"completed":3}')
        independent = f.ledger.run_check("verify-label", "behavior")
        parent = f.ledger.run_check("verify-label", "aggregate")
        later = f.ledger.run_check("verify-label", "actual-tests")
        draft = f.report("verify-label", checks=[])
        draft.pop("files")
        report = f.ledger.prepare_report(
            "verify-label",
            draft,
            [independent["execution_id"], parent["execution_id"], later["execution_id"]],
        )
        self.assertEqual(later["execution_id"], report["checks"][2]["execution_id"])
        f.ledger.finish("verify-label", report)

    def test_failed_composite_includes_earlier_pass_and_skips_later_stage(self) -> None:
        f = self.f
        self.composite_policy(
            '{"mode":"full","selected":3,"completed":3}', exit_code=3, extra_stages=True
        )
        parent = f.ledger.run_check("verify-label", "aggregate")
        results = f.ledger.check_results(parent["execution_id"])
        self.assertEqual(["FAIL", "PASS", "FAIL"], [result["result"] for result in results])
        draft = f.report("verify-label", "FAIL", checks=[], stage_result="FAIL_TEST")
        draft.pop("files")
        expanded = f.ledger.prepare_report("verify-label", draft, [parent["execution_id"]])
        explicit = f.ledger.prepare_report(
            "verify-label", draft, [r["execution_id"] for r in results]
        )
        self.assertEqual(expanded, explicit)
        with self.assertRaises(Invalid):
            f.ledger.finish("verify-label", dict(expanded, outcome="PASS", stage_result="VERIFIED"))
        f.ledger.finish("verify-label", expanded)

    def test_failed_composite_child_report_preserves_and_checks_provenance(self) -> None:
        f = self.f
        self.composite_policy('{"mode":"full","selected":3,"completed":3}', exit_code=3)
        parent = f.ledger.run_check("verify-label", "aggregate")
        assert parent["result"] != "RUNNING"
        self.assertEqual(("FAIL", 3), (parent["result"], parent["exit_code"]))
        _, child = f.ledger.check_results(parent["execution_id"])
        self.assertEqual(("FAIL", 3), (child["result"], child["exit_code"]))
        draft = f.report("verify-label", "FAIL", checks=[], stage_result="FAIL_TEST")
        draft.pop("files")
        ids = [parent["execution_id"], child["execution_id"]]
        prepared = f.ledger.prepare_report("verify-label", draft, [parent["execution_id"]])
        self.assertEqual(prepared, f.ledger.prepare_report("verify-label", draft, ids))
        self.assertEqual(["FAIL", "FAIL"], [check["result"] for check in prepared["checks"]])
        self.assertEqual(child["evidence"], prepared["checks"][1]["evidence"])
        self.assertTrue((f.root / child["evidence"]).is_file())
        with self.assertRaises(Invalid):
            f.ledger.prepare_report(
                "verify-label", dict(draft, outcome="PASS"), [parent["execution_id"]]
            )
        with self.assertRaises(Invalid):
            f.ledger.finish("verify-label", dict(prepared, outcome="PASS", stage_result="VERIFIED"))

        original = f.ledger.read()
        for field in ("dispatch_id", "composite_parent"):
            altered = deepcopy(original)
            receipt = altered["executions"][child["execution_id"]]
            if field == "dispatch_id":
                receipt["dispatch_id"] = "another-attempt"
            else:
                receipt["composite_parent"] = "wrong"
            overwrite(f.ledger, altered)
            with self.assertRaises(Invalid):
                f.ledger.prepare_report("verify-label", draft, [parent["execution_id"]])
            with self.assertRaises(Invalid):
                f.ledger.finish("verify-label", prepared)
        overwrite(f.ledger, original)
        output = f.root / child["evidence"]
        contents = output.read_bytes()
        output.write_bytes(contents + b"modified")
        with self.assertRaisesRegex(Invalid, "output missing or changed"):
            f.ledger.prepare_report("verify-label", draft, [parent["execution_id"]])
        with self.assertRaisesRegex(Invalid, "output missing or changed"):
            f.ledger.finish("verify-label", prepared)
        output.write_bytes(contents)
        f.ledger.finish("verify-label", prepared)
        state = f.ledger.read()
        saved = report_history.read(f.root, state["nodes"]["verify-label"]["report_ref"])
        self.assertEqual(child["evidence"], saved["report"]["checks"][1]["evidence"])

    def test_composite_rejects_filtered_stage_even_with_zero_exit(self) -> None:
        self.composite_policy('{"mode":"filtered","selected":3,"completed":3}')
        result = self.f.ledger.run_check("verify-label", "aggregate")
        assert result["result"] != "RUNNING"
        self.assertEqual(("BLOCKED", 0), (result["result"], result["exit_code"]))
        _, child = self.f.ledger.check_results(result["execution_id"])
        self.assertEqual("BLOCKED", child["result"])
        draft = self.f.report(
            "verify-label", "BLOCKED", checks=[], stage_result="BLOCKED_TOOL_ERROR"
        )
        draft.pop("files")
        prepared = self.f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])
        self.assertEqual(["BLOCKED", "BLOCKED"], [check["result"] for check in prepared["checks"]])
        with self.assertRaises(Invalid):
            self.f.ledger.prepare_report(
                "verify-label", dict(draft, outcome="PASS"), [result["execution_id"]]
            )
        with self.assertRaises(Invalid):
            self.f.ledger.finish(
                "verify-label", dict(prepared, outcome="PASS", stage_result="VERIFIED")
            )
        output = self.f.root / child["evidence"]
        contents = output.read_bytes()
        output.write_bytes(contents + b"modified")
        with self.assertRaisesRegex(Invalid, "output missing or changed"):
            self.f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])
        output.write_bytes(contents)
        self.f.ledger.finish("verify-label", prepared)

    def generator_setup(self, extra_write: bool) -> None:
        f = self.f
        task = f.g["tasks"]["label"]
        task["scope"].append("generated.txt")
        task["required_checks"][0]["execution"].update(
            argv=[
                sys.executable,
                "-c",
                "from pathlib import Path; assert Path('generated.txt').read_text() == 'after'",
            ],
            inputs=["generated.txt"],
        )
        (f.root / "generated.txt").write_text("before")
        (f.root / "generator-input.txt").write_text("input")
        code = "from pathlib import Path; Path('generated.txt').write_text('after')"
        if extra_write:
            code += "; Path('lib/example.dart').write_text('forbidden')"
        task["required_checks"].append(
            {
                "id": "generate",
                "category": "project",
                "kind": "codegen",
                "criteria": [],
                "method": "Generate exact declared file",
                "execution": {
                    "argv": [sys.executable, "-c", code],
                    "cwd": ".",
                    "timeout_seconds": 10,
                    "outputs": ["generated.txt"],
                    "inputs": ["generator-input.txt"],
                },
            }
        )
        f.g["nodes"][0].update(
            owns=["generated.txt"], resources=["project-checks"], required_check_ids=["generate"]
        )
        f.init()
        f.start("write-label")

    def test_codegen_mutates_only_exact_outputs_and_verifies_new_snapshot(self) -> None:
        self.generator_setup(False)
        f = self.f
        result = f.ledger.run_check("write-label", "generate")
        self.assertEqual("PASS", result["result"])
        record = f.ledger.read()["executions"][result["execution_id"]]
        self.assertNotEqual(record["output_before"], record["output_after"])
        f.ledger.finish(
            "write-label", f.report("write-label", checks=[result], stage_result="VERIFIED")
        )
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.ledger.accept("accept-label")
        self.assertTrue(f.ledger.next_actions()["completion_eligible"])

    def test_codegen_rejects_change_to_another_declared_input(self) -> None:
        self.generator_setup(True)
        result = self.f.ledger.run_check("write-label", "generate")
        assert result["result"] != "RUNNING"
        self.assertEqual(("BLOCKED", 0), (result["result"], result["exit_code"]))

    def test_projected_integration_writer_preserves_handoff_and_full_report_scope(self) -> None:
        f = self.f
        f.batch()
        task = f.g["tasks"]["integrated"]
        task["scope"].append("integration.txt")
        f.g["agents"]["explorer"] = {"role": "code-explorer", "profile": "code-explorer"}
        f.g["nodes"].extend(
            [
                {
                    "id": "explore-all",
                    "task": "integrated",
                    "stage": "explore",
                    "agent": "explorer",
                    "depends_on": ["accept-label", "accept-second"],
                    "owns": [],
                    "resources": [],
                },
                {
                    "id": "write-all",
                    "task": "integrated",
                    "stage": "work",
                    "agent": "author",
                    "depends_on": ["explore-all"],
                    "owns": ["integration.txt"],
                    "resources": [],
                },
            ]
        )
        verify = next(n for n in f.g["nodes"] if n["id"] == "verify-all")
        verify["depends_on"] = ["write-all"]
        f.init()
        f.complete()
        f.start("write-second")
        caveat = "Outside the integration writer scope: retries unknown; network NOT_RUN. Keep prior contract."
        f.ledger.finish("write-second", f.report("write-second", summary=caveat))
        f.start("verify-second")
        f.ledger.finish("verify-second", f.report("verify-second"))
        f.ledger.accept("accept-second")
        f.start("explore-all", "explorer")
        self.assertEqual(task["scope"], f.ledger.packet("explore-all")["task"]["scope"])
        f.ledger.finish("explore-all", f.report("explore-all"))
        f.start("write-all")
        packet = f.ledger.packet("write-all")
        self.assertEqual(["integration.txt"], packet["task"]["scope"])
        self.assertFalse(packet["integration_tasks"])
        self.assertEqual(caveat, packet["dependency_results"]["write-second"]["report"]["summary"])
        ref = packet["dependency_results"]["write-second"]["report_ref"]
        retained = report_history.read(f.root, ref)["report"]
        assert isinstance(retained, dict)
        self.assertEqual(caveat, retained["summary"])
        draft = f.report("write-all")
        draft.pop("files")
        prepared = f.ledger.prepare_report("write-all", draft, [])
        self.assertEqual(set(task["scope"]), set(prepared["files"]))
        f.ledger.finish("write-all", prepared)
        f.start("verify-all", "judge")
        judge = f.ledger.packet("verify-all")
        self.assertEqual({"label", "second"}, set(judge["integration_tasks"]))
        self.assertEqual(task["required_checks"], judge["finish_requirements"]["required_checks"])
        self.assertEqual(task["scope"], judge["task"]["scope"])
        f.ledger.finish("verify-all", f.report("verify-all"))
        f.start("review-all", "judge")
        f.ledger.finish("review-all", f.report("review-all", verdict="APPROVE"))
        f.ledger.accept("accept-all")
        f.ledger.archive("completed", "scope and handoff verified")
        f.ledger.clean()
        retained = report_history.read(f.root, ref)["report"]
        assert isinstance(retained, dict)
        self.assertEqual(caveat, retained["summary"])

    def test_acceptance_rejects_stale_generator_input_after_successful_final_check(self) -> None:
        self.generator_setup(False)
        f = self.f
        result = f.ledger.run_check("write-label", "generate")
        f.ledger.finish("write-label", f.report("write-label", checks=[result]))
        (f.root / "generator-input.txt").write_text("changed")
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        with self.assertRaisesRegex(Invalid, "Generated inputs or outputs changed"):
            f.ledger.accept("accept-label")
