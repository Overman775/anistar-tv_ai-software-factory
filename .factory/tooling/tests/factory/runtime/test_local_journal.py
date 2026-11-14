from __future__ import annotations

import concurrent.futures
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import unittest
from contextlib import closing
from pathlib import Path

from factory.paths import BIN, TOOLING_ROOT
from factory.runtime import command_worker
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime import workflow_fixture

CLI = BIN / "workflow.py"
ACP = BIN / "acpx_adapter.py"


class JournalCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fixture = workflow_fixture.WorkflowFixture(self.addCleanup)
        self.fixture.init()
        self.root = self.fixture.root
        self.run_id = self.fixture.ledger.read()["run_id"]

    def cli(self, *args: str, workspace: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CLI), "--workspace", str(workspace or self.root), *args],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_success_failure_and_secret_exclusion(self) -> None:
        result = self.cli("claim", "write-label")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertNotIn("diagnostic", result.stdout)
        dispatch = json.loads(result.stdout)["result"]["dispatch"]["dispatch_id"]
        failure = self.cli(
            "retry", "write-label", "secret-canary", "secret-canary", "secret-canary"
        )
        self.assertEqual(failure.returncode, 1)
        invocation = re.search(r"Factory diagnostic invocation: ([a-f0-9]+)", failure.stderr)
        self.assertIsNotNone(invocation)
        assert invocation is not None
        page = self.cli("diagnostics", "--invocation", invocation.group(1))
        records = json.loads(page.stdout)["records"]
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["event"], "operation_failed")
        self.assertEqual(records[0]["run_id"], self.run_id)
        self.assertNotIn("dispatch_id", records[0])
        self.assertEqual(records[0]["level"], "ERROR")
        self.assertNotIn("secret-canary", page.stdout)
        by_dispatch = self.cli("diagnostics", "--dispatch", dispatch)
        self.assertEqual(len(json.loads(by_dispatch.stdout)["records"]), 1)

    def test_acp_rejection_is_retrievable(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ACP), "--workspace", str(self.root), "prepare", "missing"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        match = re.search(r"invocation: ([a-f0-9]+)", result.stderr)
        self.assertIsNotNone(match)
        assert match is not None
        page = self.cli("diagnostics", "--invocation", match.group(1))
        record = json.loads(page.stdout)["records"][0]
        self.assertEqual(record["operation"], "acp_prepare")
        self.assertEqual(record["run_id"], self.run_id)

    def test_retry_keeps_prior_dispatch_in_journal(self) -> None:
        self.fixture.start("write-label")
        dispatch = self.fixture.ledger.read()["nodes"]["write-label"]["dispatch_id"]
        self.fixture.ledger.unknown("write-label", "fixture interrupted")
        result = self.cli("retry", "write-label", "recovery", "retry", "terminal")
        self.assertEqual(result.returncode, 0, result.stderr)
        page = self.cli("diagnostics", "--dispatch", dispatch)
        records = json.loads(page.stdout)["records"]
        self.assertEqual([record["event"] for record in records], ["retry"])

    def test_source_drift_has_safe_error_code(self) -> None:
        fixture = workflow_fixture.WorkflowFixture(self.addCleanup)
        (fixture.root / "request.md").write_text("source")
        fixture.g["sources"]["request"] = {
            "path": "request.md",
            "acceptance": fixture.g["sources"]["request"]["acceptance"],
        }
        fixture.init()
        (fixture.root / "request.md").write_text("changed secret-canary")
        result = subprocess.run(
            [sys.executable, str(CLI), "--workspace", str(fixture.root), "claim", "write-label"],
            capture_output=True,
            text=True,
            check=False,
        )
        match = re.search(r"invocation: ([a-f0-9]+)", result.stderr)
        assert match is not None
        page = subprocess.run(
            [
                sys.executable,
                str(CLI),
                "--workspace",
                str(fixture.root),
                "diagnostics",
                "--invocation",
                match.group(1),
            ],
            capture_output=True,
            text=True,
            check=True,
        )
        record = json.loads(page.stdout)["records"][0]
        self.assertEqual(record["error_code"], "SOURCE_DRIFT")
        self.assertNotIn("secret-canary", page.stdout)

    def test_finish_failure_identifies_only_a_validated_dispatch(self) -> None:
        fixture = workflow_fixture.WorkflowFixture(self.addCleanup)
        source = fixture.root / "request.md"
        source.write_text("source")
        fixture.g["sources"]["request"] = {
            "path": source.name,
            "acceptance": fixture.g["sources"]["request"]["acceptance"],
        }
        fixture.init()
        node = "write-label"
        fixture.start(node)
        report = fixture.report(node)
        report_path = fixture.root / "report.json"
        source.write_text("changed source")

        report_path.write_text(json.dumps({**report, "dispatch_id": "0" * 32}))
        stale = self.cli("finish", node, str(report_path), workspace=fixture.root)
        self.assertEqual(stale.returncode, 1)
        self.assertIn("Stale report identity", stale.stderr)
        invocation = re.search(r"invocation: ([a-f0-9]+)", stale.stderr)
        assert invocation is not None
        stale_page = self.cli(
            "diagnostics", "--invocation", invocation.group(1), workspace=fixture.root
        )
        self.assertEqual(stale_page.returncode, 0, stale_page.stderr)
        self.assertNotIn("dispatch_id", json.loads(stale_page.stdout)["records"][0])

        report_path.write_text(json.dumps(report))
        drift = self.cli("finish", node, str(report_path), workspace=fixture.root)
        self.assertEqual(drift.returncode, 1)
        self.assertIn("SOURCE_DRIFT", drift.stderr)

        dispatch = report["dispatch_id"]
        page = self.cli("diagnostics", "--dispatch", dispatch, workspace=fixture.root)
        self.assertEqual(page.returncode, 0, page.stderr)
        records = json.loads(page.stdout)["records"]
        self.assertEqual(
            [(record["event"], record["error_code"], record["dispatch_id"]) for record in records],
            [("operation_failed", "SOURCE_DRIFT", dispatch)],
        )
        self.assertEqual(fixture.ledger.read()["nodes"][node]["status"], "running")

    def test_bind_rejection_identifies_selected_dispatch(self) -> None:
        claim = self.cli("claim", "write-label")
        dispatch = json.loads(claim.stdout)["result"]["dispatch"]["dispatch_id"]
        failure = self.cli("bind", "write-label", "fixture-handle", "wrong-model")
        self.assertEqual(failure.returncode, 1, failure.stdout)
        match = re.search(r"invocation: ([a-f0-9]+)", failure.stderr)
        assert match is not None
        page = self.cli("diagnostics", "--invocation", match.group(1))
        record = json.loads(page.stdout)["records"][0]
        self.assertEqual(record["dispatch_id"], dispatch)

    def test_failed_init_does_not_claim_existing_run(self) -> None:
        result = self.cli("init", "missing-graph.json")
        match = re.search(r"invocation: ([a-f0-9]+)", result.stderr)
        assert match is not None
        page = self.cli("diagnostics", "--invocation", match.group(1))
        record = json.loads(page.stdout)["records"][0]
        self.assertNotIn("run_id", record)
        self.assertNotIn("dispatch_id", record)

    def test_acp_doctor_failure_has_reference(self) -> None:
        config = self.fixture.config_file(
            lambda raw: raw["acpx"].update(command="/not-a-real-acpx-executable")
        )
        result = subprocess.run(
            [
                sys.executable,
                str(ACP),
                "--workspace",
                str(self.root),
                "--config",
                str(config),
                "doctor",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        match = re.search(r"invocation: ([a-f0-9]+)", result.stderr)
        self.assertIsNotNone(match)
        assert match is not None
        page = self.cli("diagnostics", "--invocation", match.group(1))
        record = json.loads(page.stdout)["records"][0]
        self.assertEqual(record["error_code"], "executable_unavailable")
        self.assertEqual(record["level"], "ERROR")

    def test_parallel_calls_and_page_bound(self) -> None:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            failures = list(pool.map(lambda _: self.cli("claim", "missing"), range(40)))
        ids = [re.search(r"invocation: ([a-f0-9]+)", r.stderr) for r in failures]
        self.assertTrue(all(r.returncode == 1 for r in failures))
        for result, match in zip(failures, ids, strict=True):
            self.assertTrue(match is not None or "diagnostics unavailable" in result.stderr)
        self.assertEqual(len({match.group(1) for match in ids if match}), sum(bool(m) for m in ids))
        for _ in range(40):
            self.cli("claim", "missing")
        page = self.cli("diagnostics", "--run", self.run_id)
        self.assertLessEqual(len(page.stdout.encode()), 8192)
        result = json.loads(page.stdout)
        self.assertEqual(len(result["records"]), 30)
        self.assertGreater(result["next_cursor"], 0)
        second = self.cli(
            "diagnostics", "--run", self.run_id, "--cursor", str(result["next_cursor"])
        )
        self.assertGreaterEqual(len(json.loads(second.stdout)["records"]), 10)

    def test_unavailable_does_not_change_outcome(self) -> None:
        (self.root / ".factory/diagnostics").write_text("unavailable")
        success = self.cli("claim", "write-label")
        self.assertEqual(success.returncode, 0, success.stderr)
        self.assertTrue(json.loads(success.stdout)["ok"])
        self.assertIn("diagnostics unavailable", success.stderr)
        failure = self.cli("claim", "missing")
        self.assertEqual(failure.returncode, 1)
        self.assertIn("BLOCKED:", failure.stderr)
        self.assertIn("diagnostics unavailable", failure.stderr)

    def test_busy_journal_flushes_after_workflow_unlock(self) -> None:
        self.cli("claim", "missing")
        path = self.root / ".factory/diagnostics/journal.sqlite3"
        state_path = self.root / ".factory/memory/state/workflow.json"
        lock_path = self.root / ".factory/memory/state/workflow.lock"
        code = "\n".join(
            [
                "import sys",
                "sys.path.insert(0, sys.argv[1])",
                "from factory.runtime import workflow_cli",
                "original = workflow_cli.initialize",
                "def initialize(workspace, operation):",
                "    handler = original(workspace, operation)",
                "    print('READY', flush=True)",
                "    sys.stdin.readline()",
                "    return handler",
                "workflow_cli.initialize = initialize",
                "sys.argv = ['workflow.py', '--workspace', sys.argv[2], 'claim', 'write-label']",
                "workflow_cli.main()",
            ]
        )
        with subprocess.Popen(
            [sys.executable, "-c", code, str(TOOLING_ROOT), str(self.root)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        ) as process:
            assert process.stdout is not None and process.stdin is not None
            self.assertEqual(process.stdout.readline().strip(), "READY")
            with closing(sqlite3.connect(path)) as db:
                db.execute("BEGIN IMMEDIATE")
                process.stdin.write("go\n")
                process.stdin.flush()
                deadline = time.monotonic() + 0.8
                unlocked = False
                while time.monotonic() < deadline:
                    state = json.loads(state_path.read_text())
                    if state["nodes"]["write-label"]["status"] == "reserved":
                        try:
                            with command_worker.lock(lock_path):
                                unlocked = True
                                break
                        except Invalid:
                            pass
                    time.sleep(0.005)
                db.rollback()
                self.assertTrue(unlocked, "workflow lock held by diagnostic contention")
            stdout, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertTrue(json.loads(stdout)["ok"])
            self.assertNotIn("diagnostics unavailable", stderr)
        records = json.loads(self.cli("diagnostics", "--run", self.run_id).stdout)["records"]
        self.assertIn("reserved", [record["event"] for record in records])

    def test_retention_and_interrupted_transaction(self) -> None:
        self.cli("claim", "missing")
        path = self.root / ".factory/diagnostics/journal.sqlite3"
        with closing(sqlite3.connect(path)) as db, db:
            db.executemany(
                "INSERT INTO records (invocation_id, payload) VALUES (?, ?)",
                [("old", "{}") for _ in range(501)],
            )
        code = (
            "import os,sqlite3,sys; c=sqlite3.connect(sys.argv[1]); "
            "c.execute('BEGIN IMMEDIATE'); "
            "c.execute(\"INSERT INTO records (invocation_id,payload) VALUES ('dead','{}')\"); "
            "os._exit(17)"
        )
        child = subprocess.run([sys.executable, "-c", code, str(path)], check=False)
        self.assertEqual(child.returncode, 17)
        failure = self.cli("claim", "missing")
        self.assertEqual(failure.returncode, 1)
        self.assertNotIn("diagnostics unavailable", failure.stderr)
        with closing(sqlite3.connect(path)) as db, db:
            self.assertEqual(db.execute("SELECT count(*) FROM records").fetchone()[0], 500)
            self.assertEqual(
                db.execute("SELECT count(*) FROM records WHERE invocation_id='dead'").fetchone()[0],
                0,
            )

    def test_cursor_survives_retention_between_pages(self) -> None:
        self.cli("claim", "missing")
        path = self.root / ".factory/diagnostics/journal.sqlite3"
        with closing(sqlite3.connect(path)) as db, db:
            payload = json.loads(db.execute("SELECT payload FROM records").fetchone()[0])
            db.execute("DELETE FROM records")
            for i in range(500):
                payload["node_id"] = f"node-{i}"
                db.execute(
                    "INSERT INTO records (run_id, payload) VALUES (?, ?)",
                    (self.run_id, json.dumps(payload)),
                )
        first = json.loads(self.cli("diagnostics", "--run", self.run_id).stdout)
        self.assertEqual(first["records"][-1]["node_id"], "node-470")
        for _ in range(20):
            self.cli("claim", "missing")
        second = json.loads(
            self.cli(
                "diagnostics", "--run", self.run_id, "--cursor", str(first["next_cursor"])
            ).stdout
        )
        self.assertEqual(second["records"][0]["node_id"], "node-469")

    def test_untrusted_read_fields_are_rejected(self) -> None:
        result = self.cli("claim", "missing")
        match = re.search(r"invocation: ([a-f0-9]+)", result.stderr)
        assert match is not None
        path = self.root / ".factory/diagnostics/journal.sqlite3"
        with closing(sqlite3.connect(path)) as db, db:
            payload = json.loads(db.execute("SELECT payload FROM records").fetchone()[0])
            payload["prompt"] = "secret-canary"
            db.execute("UPDATE records SET payload = ?", (json.dumps(payload),))
        page = self.cli("diagnostics", "--invocation", match.group(1))
        self.assertEqual(json.loads(page.stdout)["records"], [])
        self.assertNotIn("secret-canary", page.stdout)

    def test_hardlink_diagnostics_does_not_touch_target(self) -> None:
        source = self.root / "external.sqlite3"
        source.write_bytes(b"untouched")
        directory = self.root / ".factory/diagnostics"
        directory.mkdir(parents=True)
        try:
            os.link(source, directory / "journal.sqlite3")
        except OSError:
            self.skipTest("hardlinks unavailable")
        result = self.cli("claim", "missing")
        self.assertEqual(result.returncode, 1)
        self.assertIn("diagnostics unavailable", result.stderr)
        self.assertEqual(source.read_bytes(), b"untouched")

    def test_hardlinked_sidecar_does_not_touch_target(self) -> None:
        self.cli("claim", "missing")
        source = self.root / "external-sidecar"
        source.write_bytes(b"untouched")
        sidecar = self.root / ".factory/diagnostics/journal.sqlite3-wal"
        try:
            os.link(source, sidecar)
        except OSError:
            self.skipTest("hardlinks unavailable")
        result = self.cli("claim", "missing")
        self.assertEqual(result.returncode, 1)
        self.assertIn("diagnostics unavailable", result.stderr)
        self.assertEqual(source.read_bytes(), b"untouched")

    def test_control_field_canary_is_rejected(self) -> None:
        result = self.cli("claim", "missing")
        match = re.search(r"invocation: ([a-f0-9]+)", result.stderr)
        assert match is not None
        path = self.root / ".factory/diagnostics/journal.sqlite3"
        with closing(sqlite3.connect(path)) as db, db:
            payload = json.loads(db.execute("SELECT payload FROM records").fetchone()[0])
            payload["event"] = "SECRET_CANARY"
            db.execute("UPDATE records SET payload = ?", (json.dumps(payload),))
        page = self.cli("diagnostics", "--invocation", match.group(1))
        self.assertEqual(json.loads(page.stdout)["records"], [])
        self.assertNotIn("SECRET_CANARY", page.stdout)

    def test_symlink_diagnostics_does_not_touch_target(self) -> None:
        target = self.root / "outside"
        target.mkdir()
        marker = target / "journal.sqlite3"
        marker.write_text("untouched")
        try:
            (self.root / ".factory/diagnostics").symlink_to(target, target_is_directory=True)
        except OSError:
            self.skipTest("symlinks unavailable")
        result = self.cli("claim", "missing")
        self.assertEqual(result.returncode, 1)
        self.assertIn("diagnostics unavailable", result.stderr)
        self.assertEqual(marker.read_text(), "untouched")


if __name__ == "__main__":
    unittest.main()
