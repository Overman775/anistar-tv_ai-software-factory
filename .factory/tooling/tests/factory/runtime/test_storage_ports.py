"""Exercise application commands against alternate inputs and workflow persistence."""

import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from contextlib import closing, redirect_stdout
from copy import deepcopy
from io import StringIO
from pathlib import Path
from unittest.mock import Mock, patch

import bootstrap
from factory import file_reader
from factory.database.port import DatabaseBackend
from factory.database.provider import current_database, use_database
from factory.decompose.graph.task_data import load_source_lock
from factory.diagnostics.diagnostic_journal import DiagnosticJournal
from factory.environment import settings, use_environment
from factory.runtime import lessons, teacher, workflow_cli
from factory.runtime.contracts import PacketRef, State
from factory.runtime.history import task_records as memory
from factory.runtime.knowledge import case_search
from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
from factory.runtime.observability import export_policy, otlp_bridge
from factory.runtime.observability.otlp_bridge import Receiver
from factory.runtime.packets import content as packet_io
from factory.runtime.run_repository import ArchiveReference, RunRepository
from factory.runtime.workflow import Ledger
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class DatabaseAndInputPortTests(unittest.TestCase):
    def test_run_lifecycle_through_cli_with_injected_store(self) -> None:
        fixture = WorkflowFixture(self.addCleanup)
        runs = Mock(spec_set=RunRepository)
        diagnostics = Mock(spec_set=DiagnosticJournal)
        saved: list[State] = []

        def write(root: Path, state: State, *args: object) -> None:
            self.assertEqual(root, fixture.root.resolve())
            saved.append(deepcopy(state))

        runs.has_current.side_effect = lambda root: bool(saved)
        runs.get_current.side_effect = lambda root: deepcopy(saved[-1])
        runs.create_run.side_effect = write
        runs.save_progress.side_effect = write
        runs.commit_archive.side_effect = write
        runs.reference.return_value = ArchiveReference("run-store:example", "history/example")
        runs.cleanup_paths.return_value = []

        def cli(*args: str) -> object:
            output = StringIO()
            with (
                patch.object(sys, "argv", ["workflow", "--workspace", str(fixture.root), *args]),
                redirect_stdout(output),
            ):
                workflow_cli.main()
            return json.loads(output.getvalue())["result"]

        original = current_database()
        backend = Mock(spec_set=DatabaseBackend)
        backend.runs = runs
        backend.diagnostics = diagnostics
        jobs = Mock(spec_set=TeacherJobRepository)
        jobs.pending.return_value = ["from-selected-queue"]
        backend.teacher = jobs
        with use_database(backend):
            run = Ledger(fixture.root).init(fixture.g, fixture.config)["run_id"]
            with patch("factory.runtime.teacher.current_database", side_effect=AssertionError):
                status = cli("status")
                assert isinstance(status, dict)
                self.assertEqual(status["pending_teacher_events"], ["from-selected-queue"])
            cli("pause", "owner requested")
            paused = cli("status")
            assert isinstance(paused, dict)
            self.assertEqual(paused["pause_reason"], saved[-1]["pause_reason"])
            self.assertEqual(saved[-1]["pause_reason"], "owner requested")
            cli("resume")
            self.assertEqual(cli("archive", "cancelled", "finished"), "history/example")
            self.assertEqual(cli("archive", "cancelled", "finished"), "history/example")
            cli("clean")

        runs.create_run.assert_called_once()
        self.assertEqual(runs.save_progress.call_count, 2)
        runs.commit_archive.assert_called_once()
        runs.release_current.assert_called_once_with(fixture.root.resolve(), run)
        self.assertEqual(saved[-1]["archive_path"], "run-store:example")
        self.assertTrue(diagnostics.append.called)
        self.assertFalse(list(fixture.root.rglob("*.sqlite3")))
        self.assertIs(current_database(), original)

    def test_remaining_database_sections_follow_the_invocation_backend(self) -> None:
        backend = Mock(spec_set=DatabaseBackend)
        backend.history.stored_evidence.return_value = b"stored"
        backend.packets.delivery_state.return_value = {"served": 1, "acknowledged": 1}
        backend.teacher.pending.return_value = ["job"]
        backend.cases.search_cases.return_value = ([], ["skipped"])
        backend.lessons.search.return_value = ([], {})
        backend.exports.exists.return_value = False
        backend.has_active_workflow.return_value = True
        packet: PacketRef = {
            "run_id": "run-1",
            "node_id": "node",
            "dispatch_id": "dispatch",
            "source_hash": "original",
            "path": "packet.json",
            "sha256": "digest",
            "revision": "1",
        }
        with tempfile.TemporaryDirectory() as directory, use_database(backend):
            root = Path(directory).resolve()
            path = ".factory/memory/history/run-1/output"
            self.assertEqual(memory.read_evidence(root, path, run_id="run-1"), b"stored")
            self.assertEqual(packet_io.delivery_state(root, packet, 1)["acknowledged"], 1)
            self.assertEqual(teacher.pending(root), ["job"])
            self.assertEqual(case_search.search_cases(root, "example"), ([], ["skipped"]))
            self.assertEqual(lessons.search_lessons(root, "example"), [])
            backend.traces.record_search.assert_called_once()
            with patch.object(export_policy, "enabled", return_value=True):
                self.assertEqual(otlp_bridge.drain(root, Receiver("http://unused", {}), "test"), 0)
            backend.exports.exists.assert_called_once_with(root)
            with (
                patch.object(bootstrap, "AGENTS", root / ".factory"),
                self.assertRaisesRegex(RuntimeError, "active workflow"),
            ):
                bootstrap.setup()
            backend.has_active_workflow.assert_called_once_with(root / ".factory")
            self.assertFalse(list(root.rglob("*.sqlite3")))

    def test_sqlite_preflight_before_dependencies_are_installed(self) -> None:
        fixture = WorkflowFixture(self.addCleanup)
        factory_root = fixture.root / ".factory"
        script = (
            "from pathlib import Path; import sys; "
            "from factory.database.provider import current_database; "
            "print(current_database().has_active_workflow(Path(sys.argv[1])))"
        )

        def active() -> str:
            return subprocess.check_output(
                [sys.executable, "-E", "-S", "-B", "-c", script, str(factory_root)],
                cwd=Path(bootstrap.__file__).parent,
                text=True,
            ).strip()

        self.assertEqual(active(), "False")
        self.assertFalse((factory_root / "memory/workflow.sqlite3").exists())
        fixture.init()
        self.assertEqual(active(), "True")
        fixture.ledger.archive("cancelled", "done")
        self.assertEqual(active(), "False")

    def test_setup_reports_unsupported_database_without_changes(self) -> None:
        fixture = WorkflowFixture(self.addCleanup)
        factory_root = fixture.root / ".factory"
        path = factory_root / "memory/workflow.sqlite3"
        path.parent.mkdir(parents=True, exist_ok=True)
        with closing(sqlite3.connect(path)) as db, db:
            db.execute("CREATE TABLE old_state(payload TEXT)")
        before = path.read_bytes()
        with patch.object(bootstrap, "AGENTS", factory_root), redirect_stdout(StringIO()) as output:
            self.assertEqual(bootstrap.main(["setup", "--json"]), 1)
        failure = json.loads(output.getvalue())["error"]
        self.assertEqual(failure["code"], "setup_failed")
        self.assertIn("Unsupported workflow database", failure["message"])
        self.assertEqual(path.read_bytes(), before)

    def test_scoped_inputs_agree_on_source_lock_and_environment(self) -> None:
        fixture = WorkflowFixture(self.addCleanup)
        path = fixture.root / ".env"
        path.write_text("physical", encoding="utf-8")
        reader = Mock(spec_set=file_reader.FileReader)
        reader.read_text.return_value = (
            '# Receiver credential\nTEST_TOKEN="file"\nEXAMPLE="literal ${HOME} # suffix"\n'
        )
        with file_reader.use_reader(reader), use_environment({"TEST_TOKEN": "process"}):
            config = settings(path)
            self.assertEqual(config["TEST_TOKEN"], "process")
            self.assertEqual(config["EXAMPLE"], "literal ${HOME} # suffix")
            reader.read_text.return_value = "INVALID secret-value"
            with self.assertRaisesRegex(ValueError, "^Invalid environment assignment on line 1$"):
                settings(path)
            reader.read_text.return_value = '{"plan_id": "overlay"}'
            _, errors = load_source_lock(path)
            self.assertIn("Invalid source lock", errors[0])
        self.assertEqual(file_reader.read_text(path, encoding="utf-8"), "physical")
