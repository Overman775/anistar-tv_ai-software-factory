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

from factory_tooling.project.profile_io import load_profile
from factory_tooling.project.profile_rules import required_checks
from factory_tooling.runtime.memory import read_evidence
from factory_tooling.runtime.workflow import Ledger
from factory_tooling.runtime.workflow_core import Invalid, atomic_json, digest
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
        run_id = f.ledger.read()["run_id"]
        f.ledger.archive("completed", "done")
        f.ledger.clean()
        self.assertFalse((f.root / result["evidence"]).exists())
        self.assertEqual(b"real output\n", read_evidence(f.root, result["evidence"], run_id=run_id))

    def test_check_waits_for_native_delivery_and_valid_confirmation(self) -> None:
        f = self.ready()
        node = "verify-label"
        prepared = f.ledger.prepare_packet(node, with_diagnostics=True)
        bootstrap = prepared["bootstrap"]
        meta = {
            key: bootstrap[key]
            for key in (
                "node_id",
                "path",
                "sha256",
                "run_id",
                "dispatch_id",
                "source_hash",
                "revision",
            )
        }
        with self.assertRaisesRegex(Invalid, "outstanding native packet"):
            f.ledger.run_check(node, "behavior", "superseding-attempt")
        with self.assertRaisesRegex(Invalid, "Confirm final chunk"):
            f.ledger.confirm_packet(node, meta)
        chunk = f.ledger.read_packet(node, meta, 1)
        self.assertEqual(chunk["total"], prepared["diagnostics"]["chunks"])
        self.assertEqual((f.root / meta["path"]).stat().st_size, prepared["diagnostics"]["bytes"])
        for ordinal in range(2, chunk["total"] + 1):
            chunk = f.ledger.read_packet(node, meta, ordinal, chunk["acknowledgement"])
        with self.assertRaisesRegex(Invalid, "bootstrap mismatch"):
            f.ledger.confirm_packet(node, {**meta, "dispatch_id": "old"})
        with self.assertRaisesRegex(Invalid, "outstanding native packet"):
            f.ledger.run_check(node, "behavior")
        f.ledger.confirm_packet(node, meta, chunk["acknowledgement"], chunk["materials"])
        self.assertEqual("PASS", f.ledger.run_check(node, "behavior")["result"])
        self.assertEqual(1, len(f.ledger.read()["executions"]))

    def test_pending_delivery_on_another_node_blocks_check_until_confirmed(self) -> None:
        f = self.f
        (f.root / "AGENTS.md").write_text("Ж🙂" * 6000)
        f.g["agents"]["explorer"] = {"role": "code-explorer", "profile": "code-explorer"}
        f.g["nodes"].append(
            {
                "id": "inspect-label",
                "task": "label",
                "stage": "explore",
                "agent": "explorer",
                "depends_on": ["write-label"],
                "owns": [],
                "resources": [],
            }
        )
        f.g["nodes"][2]["depends_on"].append("inspect-label")
        self.ready()
        node = "inspect-label"
        f.ledger.claim(node)
        bootstrap = f.ledger.prepare_packet(node)
        meta = {
            key: bootstrap[key]
            for key in (
                "node_id",
                "path",
                "sha256",
                "run_id",
                "dispatch_id",
                "source_hash",
                "revision",
            )
        }
        chunk = f.ledger.read_packet(node, meta, 1)
        self.assertGreater(chunk["total"], 1)
        with self.assertRaisesRegex(Invalid, "outstanding native packet"):
            f.ledger.run_check("verify-label", "behavior")
        model = (
            f.ledger.read()["config"]["models"][
                f.ledger.read()["config"]["profiles"]["code-explorer"]["model"]
            ]["id"]
            or "fixture-default"
        )
        f.ledger.bind(node, "explorer", model)
        for ordinal in range(2, chunk["total"] + 1):
            chunk = f.ledger.read_packet(node, meta, ordinal, chunk["acknowledgement"])
        with self.assertRaisesRegex(Invalid, "outstanding native packet"):
            f.ledger.run_check("verify-label", "behavior")
        self.assertFalse(f.ledger.read().get("executions"))
        f.ledger.confirm_packet(node, meta, chunk["acknowledgement"], chunk["materials"])
        self.assertEqual("PASS", f.ledger.run_check("verify-label", "behavior")["result"])
        self.assertEqual(1, len(f.ledger.read()["executions"]))

    def approval_fixture(
        self, *, sibling: bool = False, downstream: bool = False
    ) -> tuple[Path, Path]:
        f = self.f
        gate_path = f.root / "fixture-gate.yaml"
        gate_path.write_text(
            json.dumps(
                {
                    "gates": [
                        {
                            "id": "verify-fixture",
                            "at": ["implement.verify"],
                            "checks": [
                                {
                                    "id": "baseline",
                                    "level": "final",
                                    "kind": "tests",
                                    "method": "fixture baseline",
                                    "approval_action": "update-baseline",
                                    "approval_path_regex": r"test/goldens/[^/]+[.]txt",
                                    "execution": {
                                        "argv": [
                                            sys.executable,
                                            "-c",
                                            "from pathlib import Path; "
                                            "raise SystemExit(Path('test/goldens/label.txt').read_bytes() "
                                            "!= Path('candidate.txt').read_bytes())",
                                        ],
                                        "cwd": ".",
                                        "timeout_seconds": 10,
                                        "inputs": ["candidate.txt", "test/goldens/label.txt"],
                                    },
                                }
                            ],
                        }
                    ]
                }
            )
        )
        if downstream:
            gate_data = json.loads(gate_path.read_text())
            checks = gate_data["gates"][0]["checks"]
            for name, dependency in (
                ("post-baseline", "baseline"),
                ("post-final", "post-baseline"),
            ):
                checks.append(
                    {
                        "id": name,
                        "level": "final",
                        "kind": "tests",
                        "method": "Later fixture check",
                        "execution": checks[0]["execution"],
                        "after": [dependency],
                    }
                )
            gate_path.write_text(json.dumps(gate_data))
        f.fixture_profile.write_text(f.fixture_policy + "gate_files: [fixture-gate.yaml]\n")
        f.config["_project"] = load_profile(f.fixture_profile)
        f.config["_files"].update(f.config["_project"]["files"])
        task = f.g["tasks"]["label"]
        task["required_checks"].extend(
            required_checks(f.config["_project"]["data"], task, final=True)
        )
        f.require_fixture_review()
        f.g["nodes"][1]["agent"] = "fixture-judge"
        path = "test/goldens/label.txt"
        target = f.root / path
        target.parent.mkdir(parents=True)
        target.write_text("old")
        candidate = f.root / "candidate.txt"
        candidate.write_text("old" if sibling else "approved")
        (f.root / "ordinary-input.txt").write_text("current")
        task["required_checks"][0]["execution"]["inputs"] = ["ordinary-input.txt"]
        if sibling:
            f.g["nodes"].append({**f.g["nodes"][1], "id": "verify-sibling"})
            review = next(n for n in f.g["nodes"] if n["id"] == "review-label")
            review["depends_on"].append("verify-sibling")
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        return target, candidate

    def test_approval_rejects_missing_or_stale_ordinary_receipt_even_when_omitted(self) -> None:
        f = self.f
        self.approval_fixture(downstream=True)
        node = "verify-label"
        f.start(node, "judge")
        failed = f.ledger.run_check(node, "baseline")
        report = {
            **self.report(failed),
            "outcome": "BLOCKED",
            "stage_result": "APPROVAL_REQUIRED",
            "approval_request": {
                "action": "update-baseline",
                "evidence": "independent candidate comparison",
                "files": {"test/goldens/label.txt": digest(b"approved")},
                "execution_id": failed["execution_id"],
            },
        }
        with self.assertRaisesRegex(Invalid, "Missing required check before approval"):
            f.ledger.finish(node, report)
        ordinary = f.ledger.run_check(node, "behavior")
        self.assertEqual("PASS", ordinary["result"])
        (f.root / "ordinary-input.txt").write_text("changed")
        with self.assertRaisesRegex(Invalid, "Runner evidence invalidated"):
            f.ledger.finish(node, report)
        f.ledger.run_check(node, "behavior", "fresh-input")
        f.ledger.finish(node, report)
        self.assertEqual("blocked", f.ledger.read()["nodes"][node]["status"])

    def test_approval_resumes_only_exact_candidate_at_exhausted_budget(self) -> None:
        f = self.f
        target, candidate = self.approval_fixture(sibling=True)
        path = target.relative_to(f.root).as_posix()
        sibling = "verify-sibling"
        f.start(sibling, "judge")
        old_checks = [f.ledger.run_check(sibling, name) for name in ("behavior", "baseline")]
        with patch.object(f.ledger, "run_check", return_value=old_checks[0]):
            f.ledger.finish(sibling, f.report(sibling, checks=old_checks))
        candidate.write_text("approved")
        node = "verify-label"
        budget = f.ledger.read()["config"]["execution"]["retry_budgets"]["tests"]
        for _ in range(budget):
            f.start(node, "judge")
            failure = f.ledger.run_check(node, "baseline")
            f.ledger.finish(node, {**self.report(failure), "outcome": "FAIL"})
            f.ledger.retry(node, "tests", "diagnosed and stopped", "terminal test fixture")
        f.start(node, "judge")
        ok = f.ledger.run_check(node, "behavior")
        failed = f.ledger.run_check(node, "baseline")
        report = self.report(ok)
        request = {
            "action": "update-baseline",
            "evidence": "independent candidate comparison",
            "files": {path: digest(b"approved")},
            "execution_id": failed["execution_id"],
        }
        report.update(outcome="BLOCKED", stage_result="APPROVAL_REQUIRED", checks=[ok, failed])
        with self.assertRaisesRegex(Invalid, "Invalid approval request"):
            f.ledger.finish(node, report)
        with self.assertRaisesRegex(Invalid, "does not allow"):
            f.ledger.finish(
                node, {**report, "approval_request": {**request, "action": "unrelated"}}
            )
        with self.assertRaisesRegex(Invalid, "outside allowed scope"):
            f.ledger.finish(
                node,
                {
                    **report,
                    "approval_request": {
                        **request,
                        "files": {"lib/example.dart": digest(b"wrong scope")},
                    },
                },
            )
        f.ledger.finish(node, {**report, "approval_request": request})
        state = f.ledger.read()
        request_id = state["nodes"][node]["report"]["approval_request"]["id"]
        self.assertEqual(budget, state["counters"]["label:tests"])
        self.assertNotIn(path, state["graph"]["tasks"]["label"]["scope"])
        with self.assertRaisesRegex(Invalid, "RETRY_BUDGET_EXHAUSTED"):
            f.ledger.retry(node, "tests", "no retry left", "terminal")
        target.write_text("wrong")
        with self.assertRaisesRegex(Invalid, "do not match"):
            f.ledger.resume_approved(node, request_id, "user approval")
        target.write_text("approved")
        with self.assertRaisesRegex(Invalid, "Need current approval"):
            f.ledger.resume_approved(node, "stale", "user approval")
        f.ledger.resume_approved(node, request_id, "user approval")
        with self.assertRaisesRegex(Invalid, "Need current approval"):
            f.ledger.resume_approved(node, request_id, "replay")
        resumed = f.ledger.read()
        self.assertEqual(budget, resumed["counters"]["label:tests"])
        self.assertEqual("pending", resumed["nodes"][node]["status"])
        self.assertEqual("pending", resumed["nodes"]["accept-label"]["status"])
        self.assertEqual("pending", resumed["nodes"][sibling]["status"])
        self.assertEqual(state["revision"] + 1, resumed["revision"])
        self.assertIn(path, resumed["graph"]["tasks"]["label"]["scope"])
        f.start(node, "judge")
        fresh = [f.ledger.run_check(node, name) for name in ("behavior", "baseline")]
        self.assertTrue(all(check["result"] == "PASS" for check in fresh))
        self.assertNotEqual(failed["execution_id"], fresh[1]["execution_id"])
        f.ledger.finish(node, {**self.report(fresh[0]), "checks": fresh})
        f.start(sibling, "judge")
        peer = [f.ledger.run_check(sibling, name) for name in ("behavior", "baseline")]
        self.assertTrue(all(check["result"] == "PASS" for check in peer))
        self.assertNotEqual(old_checks[1]["execution_id"], peer[1]["execution_id"])
        with patch.object(f.ledger, "run_check", return_value=peer[0]):
            f.ledger.finish(sibling, f.report(sibling, checks=peer))
        f.start("review-label", "judge")
        f.ledger.finish("review-label", f.report("review-label", verdict="APPROVE"))
        f.ledger.accept("accept-label")
        self.assertEqual("done", f.ledger.read()["nodes"]["accept-label"]["status"])

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
        with f.ledger.locked():
            self.assertTrue((f.ledger.dir / "workflow.lock").exists())

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
        latest = f.ledger.run_check("verify-label", "behavior", "intentional-rerun")
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
        (f.root / (result["evidence"] + ".owner.json")).unlink()
        atomic_json(f.ledger.path, s)
        self.assertEqual("RUNNING", f.ledger.run_check("verify-label", "behavior")["result"])
        with self.assertRaisesRegex(Invalid, "Unresolved command"):
            f.ledger.run_check("verify-label", "behavior", "new-request")
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

    def test_interrupted_coordinator_leaves_reconcilable_actual_result(self) -> None:
        f = self.ready()
        original_wait = subprocess.Popen.wait

        def wait_then_interrupt(process: subprocess.Popen[bytes], *args: Any, **kwargs: Any) -> int:
            original_wait(process, *args, **kwargs)
            raise KeyboardInterrupt()

        with (
            patch.object(subprocess.Popen, "wait", wait_then_interrupt),
            self.assertRaises(KeyboardInterrupt),
        ):
            f.ledger.run_check("verify-label", "behavior", "interrupted")
        state = f.ledger.read()
        [execution_id] = state["executions"]
        self.assertEqual("RUNNING", state["executions"][execution_id]["status"])
        with self.assertRaisesRegex(Invalid, "Unresolved project commands"):
            f.ledger.archive("cancelled", "test")
        result = f.ledger.run_check("verify-label", "behavior", "interrupted")
        self.assertEqual(("PASS", 0), (result["result"], result["exit_code"]))
        self.assertEqual(result, f.ledger.run_check("verify-label", "behavior", "interrupted"))

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
