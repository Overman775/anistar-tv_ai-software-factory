"""Real subprocess regressions: no models, Flutter or network calls."""

from __future__ import annotations

import json
import subprocess
import sys
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory_tooling.runtime.workflow import Ledger
from factory_tooling.runtime.workflow_core import Invalid, atomic_json
from tests.factory_tooling.runtime import test_workflow

_TOOLS = Path(__file__).resolve().parents[3] / "tools"


class CheckRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = test_workflow.WorkflowTests()
        self.f.setUp()
        self.addCleanup(self.f.doCleanups)

    def ready(
        self, code: str = "print('real output')", **execution: Any
    ) -> test_workflow.WorkflowTests:
        f = self.f
        f.g["tasks"]["label"]["required_checks"][0]["execution"].update(
            argv=[sys.executable, "-c", code], **execution
        )
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        return f

    def report(self, result: object) -> dict[str, Any]:
        f = self.f
        # Construct the role report without implicitly running another command.
        with patch.object(f.ledger, "run_check", return_value=result):
            return f.report("verify-label")

    def test_author_report_binds_dispatch_receipt_and_handoff_snapshot(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        draft = self.report(result)
        draft.pop("files")
        draft.pop("task_id")
        draft.pop("slice_id")
        draft["checks"] = []
        stale = dict(draft, dispatch_id="old")
        with self.assertRaisesRegex(Invalid, "Stale report identity"):
            f.ledger.prepare_report("verify-label", stale, [result["execution_id"]])
        prepared = f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])
        self.assertEqual([result], prepared["checks"])
        self.assertEqual("label", prepared["task_id"])
        with self.assertRaisesRegex(Invalid, "cannot be refreshed"):
            f.ledger.prepare_report("verify-label", prepared, [])
        path = f.root / next(iter(prepared["files"]))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("changed after handoff")
        with self.assertRaisesRegex(Invalid, "Stale/incomplete file evidence"):
            f.ledger.finish("verify-label", prepared)

    def test_selected_receipt_cannot_hide_behind_matching_draft_check(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        draft = self.report(result)
        draft.pop("files")
        foreign = f.ledger.read()
        receipt = deepcopy(foreign["executions"][result["execution_id"]])
        receipt["node_id"] = "write-label"
        receipt_result = receipt["result"]
        receipt_result["execution_id"] = "foreign-receipt"
        foreign["executions"]["foreign-receipt"] = receipt
        atomic_json(f.ledger.path, foreign)
        with self.assertRaisesRegex(Invalid, "Stale or mismatched runner receipt"):
            f.ledger.prepare_report("verify-label", draft, ["foreign-receipt"])

    def test_prepare_report_rejects_invalid_and_duplicate_drafts(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        draft = self.report(result)
        draft.pop("files")
        with self.assertRaisesRegex(Invalid, "duplicates a draft check"):
            f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])
        draft["checks"] = [None]
        with self.assertRaisesRegex(Invalid, "Invalid checks"):
            f.ledger.prepare_report("verify-label", draft, [])
        with self.assertRaisesRegex(Invalid, "Unknown report node"):
            f.ledger.prepare_report("missing", {}, [])

    def test_prepare_report_cli_accepts_stdin_and_rejects_non_object(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        draft = self.report(result)
        draft.pop("files")
        draft["checks"] = []
        command = [
            sys.executable,
            "-m",
            "factory_tooling.runtime.workflow",
            "--workspace",
            str(f.root),
            "prepare-report",
            "verify-label",
            "-",
            result["execution_id"],
        ]
        run = subprocess.run(command, input=json.dumps(draft), capture_output=True, text=True)
        self.assertEqual(0, run.returncode, run.stderr)
        self.assertEqual([result], json.loads(run.stdout)["result"]["checks"])
        run = subprocess.run(command, input="[]", capture_output=True, text=True)
        self.assertNotEqual(0, run.returncode)
        self.assertIn("BLOCKED: Report draft must be an object", run.stderr)

    def test_failed_receipt_is_evidence_for_nonpassing_handoff_only(self) -> None:
        f = self.ready("raise SystemExit(7)")
        result = f.ledger.run_check("verify-label", "behavior")
        draft = self.report(result)
        draft.pop("files")
        draft["checks"] = []
        draft["outcome"] = "FAIL"
        prepared = f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])
        self.assertEqual("FAIL", prepared["checks"][0]["result"])
        f.ledger.finish("verify-label", prepared)
        self.assertEqual("blocked", f.ledger.read()["nodes"]["verify-label"]["status"])

    def test_timeout_receipt_can_be_reported_blocked(self) -> None:
        f = self.ready("import time; time.sleep(30)", timeout_seconds=1)
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("BLOCKED", result["result"])
        draft = self.report(result)
        draft.pop("files")
        draft["checks"] = []
        draft["outcome"] = "BLOCKED"
        prepared = f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])
        self.assertEqual([result], prepared["checks"])
        f.ledger.finish("verify-label", prepared)
        self.assertEqual("blocked", f.ledger.read()["nodes"]["verify-label"]["status"])

    def test_blocked_receipt_retains_modified_inputs_and_detects_later_write(self) -> None:
        f = self.ready("from pathlib import Path; Path('lib/example.dart').write_text('changed')")
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("BLOCKED", result["result"])
        draft = self.report(result)
        draft.pop("files")
        draft["checks"] = []
        draft["outcome"] = "BLOCKED"
        prepared = f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])
        self.assertEqual([result], prepared["checks"])
        (f.root / "lib/example.dart").write_text("later edit")
        with self.assertRaisesRegex(Invalid, "invalidated by later write"):
            f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])

    def test_failed_receipt_cannot_be_used_for_pass(self) -> None:
        f = self.ready("raise SystemExit(7)")
        result = f.ledger.run_check("verify-label", "behavior")
        draft = self.report(result)
        draft.pop("files")
        draft["checks"] = []
        with self.assertRaisesRegex(Invalid, "not passed"):
            f.ledger.prepare_report("verify-label", draft, [result["execution_id"]])

    def test_actual_output_is_preserved_through_archive_and_cleanup(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("real output\n", (f.root / result["evidence"]).read_text())
        f.ledger.finish("verify-label", self.report(result))
        f.ledger.accept("accept-label")
        f.ledger.archive("completed", "done")
        f.ledger.clean()
        self.assertTrue((f.root / result["evidence"]).is_file())

    def test_claimed_green_without_execution_is_rejected(self) -> None:
        f = self.ready()
        spec = f.g["tasks"]["label"]["required_checks"][0]
        fake = dict(spec, command="true", cwd=".", exit_code=0, evidence="imaginary.log")
        with self.assertRaisesRegex(Invalid, "no runner receipt"):
            f.ledger.finish("verify-label", self.report(fake))

    def test_real_nonzero_cannot_be_relabelled_green(self) -> None:
        f = self.ready("print('failure'); raise SystemExit(7)")
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual(("FAIL", 7), (result["result"], result["exit_code"]))
        forged = dict(result, result="PASS", exit_code=0)
        with self.assertRaisesRegex(Invalid, "not passed"):
            f.ledger.finish("verify-label", self.report(forged))

    def test_timeout_is_blocked_and_log_survives(self) -> None:
        f = self.ready(
            "import time; print('started', flush=True); time.sleep(30)", timeout_seconds=1
        )
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("BLOCKED", result["result"])
        self.assertIsNone(result["exit_code"])
        self.assertIn("started", (f.root / result["evidence"]).read_text())
        self.assertFalse((f.ledger.dir / "workflow.lock").exists())

    def test_missing_binary_is_blocked(self) -> None:
        f = self.f
        f.g["tasks"]["label"]["required_checks"][0]["execution"]["argv"] = [
            "missing-ofl-test-executable"
        ]
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        f.start("verify-label")
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("BLOCKED", result["result"])
        self.assertIsNone(result["exit_code"])

    def test_modified_result_or_log_rejected(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        for key, value in [("command", ["true"]), ("cwd", "lib"), ("evidence", "other.log")]:
            with self.subTest(key=key), self.assertRaises(Invalid):
                f.ledger.finish("verify-label", self.report(dict(result, **{key: value})))
        (f.root / result["evidence"]).write_text("rewritten")
        with self.assertRaisesRegex(Invalid, "output missing or changed"):
            f.ledger.finish("verify-label", self.report(result))

    def test_accept_rechecks_log_after_finish(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        f.ledger.finish("verify-label", self.report(result))
        (f.root / result["evidence"]).unlink()
        with self.assertRaisesRegex(Invalid, "output missing or changed"):
            f.ledger.accept("accept-label")

    def test_latest_attempt_cannot_be_hidden_by_earlier_pass(self) -> None:
        f = self.ready(
            "from pathlib import Path; raise SystemExit(int(Path('fail.flag').exists()))"
        )
        first = f.ledger.run_check("verify-label", "behavior")
        (f.root / "fail.flag").touch()
        latest = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("FAIL", latest["result"])
        with self.assertRaisesRegex(Invalid, "superseded"):
            f.ledger.finish("verify-label", self.report(first))

    def test_command_that_changes_inputs_cannot_pass(self) -> None:
        f = self.ready("from pathlib import Path; Path('lib/example.dart').write_text('changed')")
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("BLOCKED", result["result"])
        self.assertEqual(0, result["exit_code"])

    def test_additional_input_drift_invalidates_result(self) -> None:
        (self.f.root / "tooling.json").write_text("v1")
        f = self.ready(inputs=["tooling.json"])
        result = f.ledger.run_check("verify-label", "behavior")
        (f.root / "tooling.json").write_text("v2")
        with self.assertRaisesRegex(Invalid, "invalidated"):
            f.ledger.finish("verify-label", self.report(result))

    def test_unreserved_writer_cannot_launch_command(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        with self.assertRaisesRegex(Invalid, "reservation"):
            f.ledger.run_check("write-label", "behavior")

    def test_in_progress_receipt_blocks_repeat_and_success(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        s = f.ledger.read()
        s["executions"][result["execution_id"]]["status"] = "RUNNING"
        atomic_json(f.ledger.path, s)
        with self.assertRaisesRegex(Invalid, "Unresolved command"):
            f.ledger.run_check("verify-label", "behavior")
        with self.assertRaisesRegex(Invalid, "not passed"):
            f.ledger.finish("verify-label", self.report(result))

    def test_stale_dispatch_receipt_rejected(self) -> None:
        f = self.ready()
        result = f.ledger.run_check("verify-label", "behavior")
        f.ledger.finish("verify-label", self.report(result))
        f.ledger.retry("verify-label", "tests", "repeat required", "terminal confirmed")
        f.start("verify-label")
        with self.assertRaisesRegex(Invalid, "mismatched"):
            f.ledger.finish("verify-label", self.report(result))

    def test_ledger_lock_prevents_overlapping_mutations(self) -> None:
        f = self.ready()
        with f.ledger.locked(), self.assertRaisesRegex(Invalid, "Ledger locked"):
            Ledger(f.root).run_check("verify-label", "behavior")

    def test_keyboard_interrupt_is_recorded_without_success(self) -> None:
        f = self.ready("import time; time.sleep(30)")
        original_wait = subprocess.Popen.wait
        calls = []

        def interrupted_once(process: subprocess.Popen[bytes], *args: Any, **kwargs: Any) -> int:
            calls.append(True)
            if len(calls) == 1:
                raise KeyboardInterrupt()
            return original_wait(process, *args, **kwargs)

        with patch.object(subprocess.Popen, "wait", interrupted_once):
            result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("BLOCKED", result["result"])
        record = f.ledger.read()["executions"][result["execution_id"]]
        self.assertEqual("KeyboardInterrupt", record["error"])

    def test_source_change_during_command_is_blocked(self) -> None:
        (self.f.root / "request.md").write_text("original request")
        self.f.g["sources"]["request"]["path"] = "request.md"
        f = self.ready("from pathlib import Path; Path('request.md').write_text('changed')")
        result = f.ledger.run_check("verify-label", "behavior")
        self.assertEqual("BLOCKED", result["result"])
        self.assertEqual(
            "SOURCE_DRIFT", f.ledger.read()["executions"][result["execution_id"]]["error"]
        )

    def test_unsafe_cwd_rejected_before_command(self) -> None:
        self.f.g["tasks"]["label"]["required_checks"][0]["execution"]["cwd"] = "../outside"
        with self.assertRaisesRegex(Invalid, "Unsafe path"):
            self.f.init()


if __name__ == "__main__":
    unittest.main()
