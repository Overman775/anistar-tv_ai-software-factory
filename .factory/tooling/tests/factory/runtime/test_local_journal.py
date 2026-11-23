from __future__ import annotations

import argparse
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

from factory.database.sqlite import sqlite_diagnostic_journal as journal
from factory.diagnostics.events import event
from factory.diagnostics.records import OPERATIONS
from factory.logging_config import diagnostic_operation
from factory.paths import BIN, TOOLING_ROOT
from factory.runtime import command_worker
from factory.runtime.knowledge.cli import command_parser
from factory.runtime.workflow_cli import build_parser
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime import workflow_fixture
from tests.factory.runtime.store_fixture import overwrite

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

    def test_parsed_workflow_and_lesson_actions_have_diagnostic_names(self) -> None:
        for parser, prefix in ((build_parser(), ""), (command_parser(), "lessons.")):
            actions = next(a for a in parser._actions if isinstance(a, argparse._SubParsersAction))
            names = {prefix + name for name in actions.choices if name != "diagnostics"}
            self.assertLessEqual(names, OPERATIONS)

    def test_lesson_index_failure_can_be_traced_without_search_text(self) -> None:
        index = self.root / ".factory/memory/cache/lessons.sqlite3"
        index.parent.mkdir(exist_ok=True, parents=True)
        index.write_bytes(b"unreadable index" * 100)
        result = subprocess.run(
            [
                sys.executable,
                str(BIN / "lessons.py"),
                "--workspace",
                str(self.root),
                "search_lessons",
                "private-search-canary",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "")
        invocation = re.search(r"invocation: ([a-f0-9]+)", result.stderr)
        assert invocation is not None, result.stderr
        page = self.cli("diagnostics", "--invocation", invocation.group(1))
        records = json.loads(page.stdout)["records"]
        self.assertEqual(records[0]["error_code"], "database_corrupt")
        self.assertIn(
            ("database_failed", "lesson_index", "database_corrupt"),
            [(r["event"], r.get("component"), r.get("error_code")) for r in records],
        )
        self.assertNotIn("private-search-canary", page.stdout)
        self.assertNotIn(str(self.root), page.stdout)
        recent = self.cli("diagnostics", "--operation", "lessons.search_lessons", "--limit", "1")
        first = json.loads(recent.stdout)
        self.assertEqual(first["records"], records[:1])
        next_page = self.cli(
            "diagnostics",
            "--operation",
            "lessons.search_lessons",
            "--cursor",
            str(first["next_cursor"]),
        )
        self.assertEqual(json.loads(next_page.stdout)["records"], records[1:])

    def test_search_keeps_result_when_workflow_store_cannot_record_evidence(self) -> None:
        (self.root / ".factory/memory/workflow.sqlite3").write_bytes(b"bad store" * 100)
        result = subprocess.run(
            [
                sys.executable,
                str(BIN / "lessons.py"),
                "--workspace",
                str(self.root),
                "search_lessons",
                "nothing-matches-this-word",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), [])
        records = json.loads(
            self.cli("diagnostics", "--operation", "lessons.search_lessons").stdout
        )["records"]
        self.assertEqual(
            [r["event"] for r in records],
            ["operation_completed", "lesson_trace_unavailable", "database_failed"],
        )
        self.assertEqual(records[-1]["component"], "workflow_store")
        self.assertEqual(len({r["invocation_id"] for r in records}), 1)

    def test_nested_invocations_restore_the_outer_workspace(self) -> None:
        other = self.root / "nested"
        other.mkdir()
        with diagnostic_operation(self.root, "context"):
            with diagnostic_operation(other, "project.checks"):
                pass
            event("operation_completed")
        outer = self.cli("diagnostics", "--operation", "context")
        inner = self.cli("diagnostics", "--operation", "project.checks", workspace=other)
        self.assertEqual(len(json.loads(outer.stdout)["records"]), 2)
        self.assertEqual(len(json.loads(inner.stdout)["records"]), 1)
        self.assertEqual(
            json.loads(self.cli("diagnostics", "--operation", "project.checks").stdout)["records"],
            [],
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

    def test_journal_baseline_preserves_existing_records(self) -> None:
        for version in (0, 1):
            with self.subTest(version=version):
                workspace = self.root / f"legacy-{version}"
                path = journal.database_path(workspace)
                path.parent.mkdir(parents=True)
                with closing(sqlite3.connect(path)) as db, db:
                    db.execute(journal.JOURNAL_TABLE)
                    db.execute("INSERT INTO records VALUES (17,'old',NULL,NULL,'{}')")
                    db.execute(f"PRAGMA user_version={version}")
                self.assertEqual(journal.snapshot(workspace), ["{}"])
                journal.prepare(workspace)
                with closing(sqlite3.connect(path)) as db:
                    self.assertEqual(db.execute("PRAGMA user_version").fetchone(), (2,))
                    self.assertEqual(
                        db.execute("SELECT * FROM records").fetchone(),
                        (17, "old", None, None, "{}", None),
                    )
                self.assertEqual(journal.delivery_window(workspace, "test"), (0, 0))

    def test_pause_and_resume_are_recorded(self) -> None:
        pause = self.cli("pause", "user request")
        paused_state = self.fixture.ledger.read()
        resume = self.cli("resume")
        resumed_state = self.fixture.ledger.read()
        page = self.cli("diagnostics", "--run", self.run_id)
        self.assertEqual(pause.returncode, 0, pause.stderr)
        self.assertEqual(resume.returncode, 0, resume.stderr)
        for action, result in (("pause", pause), ("resume", resume)):
            with self.subTest(action=action):
                self.assertEqual(result.stderr, "")
        self.assertTrue(json.loads(pause.stdout)["ok"])
        self.assertTrue(json.loads(resume.stdout)["ok"])
        self.assertEqual(paused_state["pause_reason"], "user request")
        self.assertNotIn("pause_reason", resumed_state)
        self.assertEqual(page.returncode, 0, page.stderr)
        records = json.loads(page.stdout)["records"]
        self.assertEqual(
            [(record["operation"], record["event"]) for record in records],
            [("resume", "resumed"), ("pause", "paused")],
        )

    def test_pause_and_resume_report_unavailable_journal(self) -> None:
        (self.root / ".factory/diagnostics").write_text("unavailable")
        for action in (("pause", "user request"), ("resume",)):
            with self.subTest(action=action[0]):
                result = self.cli(*action)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(json.loads(result.stdout)["ok"])
                self.assertIn("Factory diagnostics unavailable", result.stderr)
                state = self.fixture.ledger.read()
                expected = "user request" if action[0] == "pause" else None
                self.assertEqual(state.get("pause_reason"), expected)

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
        state = fixture.ledger.read()
        state["graph"]["sources"]["request"]["snapshot"] = "changed secret-canary"
        overwrite(fixture.ledger, state)
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
        state = fixture.ledger.read()
        state["graph"]["sources"]["request"]["snapshot"] = "corrupt"
        overwrite(fixture.ledger, state)

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
        from factory.runtime.workflow import Ledger

        ledger = Ledger(self.root)
        lock_path = self.root / ".factory/memory/state/workflow.lock"
        code = "\n".join(
            [
                "import sys",
                "sys.path.insert(0, sys.argv[1])",
                "from factory.runtime import workflow_cli",
                "original = workflow_cli.initialize",
                "def initialize(workspace, operation, *, store):",
                "    handler = original(workspace, operation, store=store)",
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
                    state = ledger.read()
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

    def test_otlp_snapshot_reads_validated_logs_and_links_the_existing_attempt(self) -> None:
        def telemetry(*args: str) -> str:
            return subprocess.check_output(
                [sys.executable, str(BIN / "telemetry.py"), "--workspace", str(self.root), *args],
                text=True,
                env={**os.environ, "OTEL_SDK_DISABLED": "true"},
            )

        self.assertEqual(telemetry("journal"), "")
        path = self.root / ".factory/diagnostics/journal.sqlite3"
        self.assertFalse(path.exists())
        self.assertEqual(self.cli("claim", "write-label").returncode, 0)
        self.assertEqual(self.cli("claim", "missing").returncode, 1)
        with closing(sqlite3.connect(path)) as db, db:
            records = [
                json.loads(raw) for (raw,) in db.execute("SELECT payload FROM records ORDER BY id")
            ]
            db.execute(
                "INSERT INTO records (payload) VALUES (?)",
                (json.dumps({**records[0], "prompt": "private-canary"}),),
            )
        output = telemetry("journal")
        self.assertNotIn("private-canary", output)
        self.assertEqual(output, telemetry("journal"))
        logs = [
            json.loads(line)["resourceLogs"][0]["scopeLogs"][0]["logRecords"][0]
            for line in output.splitlines()
        ]
        self.assertEqual([log["eventName"] for log in logs], [r["event"] for r in records])
        timeline = json.loads(telemetry("show", "--run", self.run_id))["observations"]
        attempt = next(item for item in timeline if item["name"] == "factory.attempt")
        claim = next(log for log in logs if log["eventName"] == "reserved")
        self.assertEqual(
            (claim["traceId"], claim["spanId"]), (attempt["trace_id"], attempt["span_id"])
        )
        self.assertEqual(claim["severityNumber"], 9)
        self.assertEqual(logs[-1]["severityNumber"], 17)
        self.assertTrue(int(claim["timeUnixNano"]) > 0)

    def test_retention_and_interrupted_transaction(self) -> None:
        self.cli("claim", "missing")
        path = self.root / ".factory/diagnostics/journal.sqlite3"
        with closing(sqlite3.connect(path)) as db, db:
            db.executemany(
                "INSERT INTO records (invocation_id, payload) VALUES (?, ?)",
                [("old", "{}") for _ in range(5_001)],
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
            self.assertEqual(db.execute("SELECT count(*) FROM records").fetchone()[0], 5_000)
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
            for i in range(5_000):
                payload["node_id"] = f"node-{i}"
                db.execute(
                    "INSERT INTO records (run_id, payload) VALUES (?, ?)",
                    (self.run_id, json.dumps(payload)),
                )
        first = json.loads(self.cli("diagnostics", "--run", self.run_id).stdout)
        self.assertEqual(first["records"][-1]["node_id"], "node-4970")
        for _ in range(20):
            self.cli("claim", "missing")
        second = json.loads(
            self.cli(
                "diagnostics", "--run", self.run_id, "--cursor", str(first["next_cursor"])
            ).stdout
        )
        self.assertEqual(second["records"][0]["node_id"], "node-4969")

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
