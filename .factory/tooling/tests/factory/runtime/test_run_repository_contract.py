"""Observable storage guarantees shared by workflow database implementations."""

import unittest
from copy import deepcopy
from pathlib import Path

from factory.database.port import DatabaseBackend
from factory.database.provider import use_database
from factory.database.sqlite.adapter import SQLiteDatabaseBackend
from factory.runtime.history.artifact_ref import Artifact
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class RunRepositoryContractTests(unittest.TestCase):
    def open_backend(self, root: Path) -> DatabaseBackend:
        """Open this checkout’s isolated store, preserving any data from a previous call."""
        return SQLiteDatabaseBackend()

    def setUp(self) -> None:
        self.fixture = WorkflowFixture(self.addCleanup)
        self.root = self.fixture.root
        self.db = self.open_backend(self.root)
        self.enterContext(use_database(self.db))
        self.fixture.ledger = Ledger(self.root)

    def test_state_and_evidence_commit_and_roll_back_together(self) -> None:
        state = self.fixture.init()
        run = state["run_id"]
        self.assertEqual(self.db.runs.get_current(self.root), state)
        saved = deepcopy(state)
        saved["pause_reason"] = "review"
        first = Artifact("first.txt", "attachment", b"first")
        self.db.runs.save_progress(self.root, saved, (first,))
        self.assertEqual(self.db.runs.get_current(self.root), saved)
        self.assertEqual(
            self.db.history.stored_evidence(self.root, run, first.name, allow_loose=False), b"first"
        )

        proposed = deepcopy(saved)
        proposed["pause_reason"] = "different review"
        second = Artifact("second.txt", "attachment", b"second")
        invalid = Artifact("bad.txt", "attachment", b"changed", expected="0" * 64)
        with self.assertRaises(Invalid):
            self.db.runs.save_progress(self.root, proposed, (second, invalid))
        self.assertEqual(self.db.runs.get_current(self.root), saved)
        self.assertIsNone(
            self.db.history.stored_evidence(self.root, run, second.name, allow_loose=True)
        )

    def test_retried_archive_preserves_history_and_one_teacher_job(self) -> None:
        # A worker subprocess would select its own backend outside this contract fixture.
        check = self.fixture.g["tasks"]["label"]["required_checks"][0]
        check["kind"] = "observation"
        del check["execution"]
        state = self.fixture.init()
        self.fixture.complete()
        location = self.fixture.ledger.archive("completed", "accepted")
        reopened_db = self.open_backend(self.root)
        self.enterContext(use_database(reopened_db))
        reopened = Ledger(self.root)
        self.assertEqual(reopened.archive("completed", "accepted"), location)
        archived = reopened_db.history.archived_state(self.root, state["run_id"])
        self.assertEqual(archived["status"], "completed")
        jobs = reopened_db.teacher.pending(
            self.root, False, lambda: archived["lesson_run_checkout"]
        )
        self.assertEqual(jobs, [archived["final_teacher_event"]])
        reopened.clean()
        self.assertFalse(reopened_db.runs.has_current(self.root))
        self.assertEqual(reopened_db.history.archived_state(self.root, state["run_id"]), archived)
