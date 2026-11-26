"""Differential checks using real dispatch, receipt, acceptance and Teacher entry points."""

import json
import shutil
import sqlite3
import subprocess
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path
from unittest.mock import Mock, patch

from factory.database.port import DatabaseBackend
from factory.database.provider import current_database, use_database
from factory.database.sqlite import artifacts, sqlite_history_repository
from factory.runtime import teacher
from factory.runtime.history import report_history
from factory.runtime.history import task_records as memory
from factory.runtime.knowledge import case_search
from factory.runtime.lessons import Lesson, catalog
from factory.runtime.packets.content import PACKET_REFERENCE, delivery_state
from factory.runtime.workflow_core import Invalid
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture, bound_teacher


class HistoryStoreTests(unittest.TestCase):
    def test_journal_lifecycle(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        subprocess.run(["git", "-C", str(f.root), "init", "-q", "-b", "pilot"], check=True)
        f.require_fixture_review()
        node = "write-label"
        state = f.ledger.init(f.g, f.config)
        run = state["run_id"]
        f.start(node)
        packet = f.ledger.prepare_packet(node)
        meta = PACKET_REFERENCE.validate_python(
            {
                k: packet[k]
                for k in (
                    "path",
                    "sha256",
                    "run_id",
                    "node_id",
                    "dispatch_id",
                    "source_hash",
                    "revision",
                )
            }
        )
        chunk = f.ledger.read_packet(node, meta, 1)
        while chunk["next"] is not None:
            chunk = f.ledger.read_packet(node, meta, chunk["next"], chunk["acknowledgement"])
        f.ledger.confirm_packet(node, meta, chunk["acknowledgement"], chunk["materials"])
        transport = {meta["path"]: memory.read_evidence(f.root, meta["path"], run_id=run)}
        self.assertFalse((f.root / meta["path"]).exists())
        failed = f.report(node, "FAIL", evidence="tungsten")
        with patch("factory.database.sqlite.workflow_db.put", side_effect=OSError("injected")):
            with self.assertRaisesRegex(OSError, "injected"):
                f.ledger.finish(node, failed)
        self.assertFalse(f.ledger.read().get("report_index"))
        f.ledger.finish(node, failed)
        failed_ref = f.ledger.read()["nodes"][node]["report_ref"]
        raw = memory.read_evidence(f.root, failed_ref["path"], run_id=run)
        self.assertFalse((f.root / failed_ref["path"]).exists())
        f.ledger.retry(node, "tests", "replace shims", "author stopped")
        f.start(node)
        with self.assertRaises(Invalid):
            f.ledger.confirm_packet(node, meta, chunk["acknowledgement"], chunk["materials"])
        f.ledger.finish(node, f.report(node, evidence="verified iridium"))
        accepted_ref = f.ledger.read()["nodes"][node]["report_ref"]
        f.start("verify-label")
        dependency = f.ledger.packet("verify-label")["dependency_results"][node]["report_ref"]
        self.assertEqual(accepted_ref, dependency)
        self.assertEqual(
            report_history.read(f.root, dependency)["report"]["evidence"], "verified iridium"
        )
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.start("review-label", "independent-judge")
        f.ledger.finish("review-label", f.report("review-label", verdict="APPROVE", findings=[]))
        f.ledger.accept("accept-label")
        self.assertEqual(([], []), case_search.search_cases(f.root, "iridium"))
        self.assertEqual([], teacher.pending(f.root))
        name = f".factory/memory/history/{run}/proof.png"
        (f.root / name).parent.mkdir(parents=True, exist_ok=True)
        (f.root / name).write_bytes(b"attachment\x00\xff")
        failure = "factory.database.sqlite.sqlite_teacher_job_repository.insert_event"
        with patch(failure, side_effect=OSError("after seal")):
            with self.assertRaisesRegex(OSError, "after seal"):
                f.ledger.archive("completed", "verified")
        self.assertEqual("active", f.ledger.read()["status"])
        self.assertFalse(teacher.pending(f.root))
        with sqlite_history_repository.database(f.root) as db:
            self.assertEqual(0, db.execute("SELECT count(*) FROM closed_runs").fetchone()[0])
        self.assertFalse((f.root / ".factory/memory/history/seals").exists())
        self.assertFalse((f.root / ".factory/memory/state/workflow.json").exists())
        self.assertFalse(list((f.root / ".factory/memory").rglob("*.delivery.json")))
        f.ledger.archive("completed", "verified")
        [key] = teacher.pending(f.root)
        event = teacher.read_event(f.root, key)
        assert event.incidents is not None
        [incident] = event.incidents
        self.assertIn(failed_ref, event.incidents[incident].reports)
        with sqlite_history_repository.database(f.root) as db:
            self.assertEqual(
                [(run, "completed", "verified")],
                db.execute("SELECT run_id,status,summary FROM closed_runs").fetchall(),
            )
            self.assertEqual(
                (2, accepted_ref["path"]),
                db.execute(
                    "SELECT attempt,report_path FROM closed_steps WHERE node_id=?", (node,)
                ).fetchone(),
            )
            self.assertNotIn("record", [row[1] for row in db.execute("PRAGMA table_info(runs)")])
            self.assertEqual(
                db.execute("SELECT count(*) FROM graph_edges WHERE run_id=?", (run,)).fetchone()[0],
                sum(len(n["depends_on"]) for n in f.g["nodes"]),
            )
            paths = db.execute(
                "SELECT report_path FROM closed_attempts WHERE run_id=? AND node_id=?",
                (run, node),
            ).fetchall()
            self.assertEqual({failed_ref["path"], accepted_ref["path"]}, {row[0] for row in paths})
        self.assertFalse((f.root / ".factory/memory/history/snapshots" / (run + ".json")).exists())
        f.ledger.clean()
        for name_in_state, content in transport.items():
            self.assertFalse((f.root / name_in_state).exists())
            self.assertEqual(content, memory.read_evidence(f.root, name_in_state, run_id=run))
        self.assertEqual(raw, memory.read_evidence(f.root, failed_ref["path"], run_id=run))
        self.assertEqual("completed", memory.read_task(f.root, "label", run_id=run)["run_status"])
        self.assertEqual(([], []), case_search.search_cases(f.root, "tungsten"))
        with ThreadPoolExecutor(max_workers=3) as pool:
            self.assertEqual(
                [1, 1, 1],
                list(
                    pool.map(
                        lambda _: len(case_search.search_cases(f.root, "iridium")[0]), range(3)
                    )
                ),
            )
        sqlite = current_database()
        with use_database(Mock(spec_set=DatabaseBackend)):
            # An explicitly selected index must verify evidence in its own backend.
            [hit], skipped = sqlite.cases.search_cases(f.root, "iridium")
        self.assertEqual((2, []), (hit.ordinal, skipped))
        card = Lesson(
            id="shims",
            scope="project",
            title="Shims",
            observed="Old shim",
            applies_when="Testing",
            action="Measure the shim",
        )
        original = teacher.apply(
            f.root, key, card, None, incident=incident, dispatch_id=bound_teacher(f.root, key)
        )
        restored = f.root / "restored"
        restored_db = restored / sqlite_history_repository.DATABASE
        restored_db.parent.mkdir(parents=True)
        shutil.copyfile(f.root / sqlite_history_repository.DATABASE, restored_db)
        shutil.rmtree(f.root / ".factory/memory")  # The restore must stand on its own.
        self.assertEqual(([], []), case_search.search_cases(restored, "iridium"))
        for cmd in ("verify-history", "rebind-history"):
            args = [
                *CLI,
                "workflow",
                "--workspace",
                str(restored),
                cmd,
                run,
            ]
            self.assertTrue(json.loads(subprocess.check_output(args))["ok"])
        self.assertEqual([hit], case_search.search_cases(restored, "iridium")[0])
        subprocess.run(["git", "-C", str(restored), "init", "-q", "-b", "other"], check=True)
        self.assertEqual(([], []), case_search.search_cases(restored, "iridium"))
        subprocess.run(
            ["git", "-C", str(restored), "symbolic-ref", "HEAD", "refs/heads/pilot"], check=True
        )
        self.assertEqual(
            chunk["total"],
            delivery_state(restored, meta, chunk["total"], "handle-author")["acknowledged"],
        )
        self.assertEqual([key], teacher.pending(restored))
        self.assertEqual(
            original,
            teacher.apply(
                restored,
                key,
                card,
                None,
                incident=incident,
                dispatch_id=bound_teacher(restored, key),
            ),
        )
        self.assertEqual([incident], list(catalog(restored)[0].lesson.sources))
        teacher.complete(restored, key, dispatch_id=bound_teacher(restored, key))
        self.assertEqual([], teacher.pending(restored))
        subprocess.run(
            [
                *CLI,
                "workflow",
                "--workspace",
                str(restored),
                "reset-history-index",
            ],
            check=True,
            capture_output=True,
        )
        self.assertEqual([hit], case_search.search_cases(restored, "iridium")[0])
        cli = [*CLI, "workflow", "--workspace", str(restored)]
        listing = json.loads(subprocess.check_output([*cli, "list-artifacts", run]))["result"]
        self.assertTrue(
            {"packet", "report", "usage", "attachment"} <= {item["kind"] for item in listing}
        )
        for logical, body in {**transport, name: b"attachment\x00\xff"}.items():
            output = restored / "export.bin"
            subprocess.run(
                [*cli, "export-artifact", run, logical, str(output)],
                check=True,
                capture_output=True,
            )
            self.assertEqual(body, output.read_bytes())
            with self.assertRaises(FileExistsError):
                sqlite_history_repository.export(restored, run, logical, output)
            output.unlink()
        with sqlite_history_repository.database(restored) as db:
            db.execute("DELETE FROM artifacts WHERE run_id=? AND path=?", (run, name))
        with self.assertRaisesRegex(Invalid, "Missing or changed artifact"):
            sqlite_history_repository.check_inventory(
                restored, sqlite_history_repository.inventory(restored, run)
            )
        self.assertEqual(raw, memory.read_evidence(restored, failed_ref["path"], run_id=run))
        with sqlite_history_repository.database(restored) as db:
            db.execute("UPDATE artifact_blobs SET body=? WHERE sha256=?", (b"wrong", hit.sha256))
        self.assertEqual(([], [run]), case_search.search_cases(restored, "iridium"))

    def test_large_attachments_share_bytes_and_rollback_with_closure(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        run = f.init()["run_id"]
        f.complete()
        folder = f.root / f".factory/memory/history/{run}"
        folder.mkdir(parents=True, exist_ok=True)
        body = bytes(range(256)) * 10000
        first, second = folder / "a.bin", folder / "b.bin"
        for path in (first, second):
            path.write_bytes(body)
        with patch(
            "factory.database.sqlite.sqlite_teacher_job_repository.insert_event",
            side_effect=OSError("interrupted"),
        ):
            with self.assertRaises(OSError):
                f.ledger.archive("completed", "finished")
        with sqlite_history_repository.database(f.root) as db:
            self.assertEqual(
                0,
                db.execute(
                    "SELECT count(*) FROM artifact_blobs WHERE length(body)=?", (len(body),)
                ).fetchone()[0],
            )
        self.assertEqual("active", f.ledger.read()["status"])
        f.ledger.archive("completed", "finished")
        with sqlite_history_repository.database(f.root) as db:
            self.assertEqual(
                1,
                db.execute(
                    "SELECT count(*) FROM artifact_blobs WHERE length(body)=?", (len(body),)
                ).fetchone()[0],
            )
            self.assertEqual(
                2,
                db.execute(
                    "SELECT count(*) FROM artifacts WHERE kind='attachment' AND path LIKE '%.bin'"
                ).fetchone()[0],
            )
        late = folder / "after.txt"
        late.write_text("keep")
        second.write_bytes(b"changed")
        with self.assertRaisesRegex(Invalid, "Working artifact changed"):
            f.ledger.clean()
        self.assertTrue(first.is_file())
        second.write_bytes(body)
        f.ledger.clean()
        self.assertFalse(first.exists())
        self.assertEqual("keep", late.read_text())
        self.assertEqual(
            body,
            sqlite_history_repository.member(f.root, run, first.relative_to(f.root).as_posix()),
        )

    def test_full_verification_checks_each_binding_and_each_distinct_body(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        run = f.init()["run_id"]
        with sqlite_history_repository.database(f.root) as db:
            manifest = {
                name: artifacts.put(db, run, artifacts.Artifact(name, "attachment", b"shared"))
                for name in ("first", "second")
            }
            with patch.object(artifacts, "_blob_chunks", wraps=artifacts._blob_chunks) as scan:
                artifacts.verify_manifest(db, run, manifest)
                self.assertEqual(1, scan.call_count)
            with self.assertRaisesRegex(Invalid, "Immutable artifact differs"):
                artifacts.put(db, run, artifacts.Artifact("first", "report", b"shared"))
            with self.assertRaisesRegex(Invalid, "Missing or changed artifact"):
                artifacts.verify_manifest(
                    db, run, {"first": manifest["first"], "wrong": manifest["second"]}
                )
            with self.assertRaisesRegex(Invalid, "Missing or changed artifact"):
                artifacts.verify_manifest(db, run, {"first": manifest["first"]})
            db.execute("UPDATE artifact_blobs SET body=?", (b"wrong",))
            with self.assertRaisesRegex(Invalid, "digest mismatch"):
                artifacts.verify_manifest(db, run, manifest)

    def test_completed_and_partially_accepted_cancelled_runs(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        f.init()
        f.complete()
        accepted = f.ledger.read()["nodes"]["write-label"]["report_ref"]
        raw = memory.read_evidence(f.root, accepted["path"], run_id=accepted["run_id"])
        f.ledger.archive("completed", "old")
        f.ledger.clean()
        [old_key] = teacher.pending(f.root)
        f.batch()
        run = f.ledger.init(f.g, f.config)["run_id"]
        f.complete()
        f.start("write-second")
        f.ledger.finish("write-second", f.report("write-second", evidence="unaccepted zircon"))
        f.ledger.archive("cancelled", "stopped before second acceptance")
        f.ledger.clean()
        self.assertEqual([old_key], teacher.pending(f.root))
        self.assertEqual(([], []), case_search.search_cases(f.root, "zircon"))
        hits, skipped = case_search.search_cases(f.root, "fixture")
        self.assertEqual({run, accepted["run_id"]}, {item.run_id for item in hits})
        self.assertEqual([], skipped)
        self.assertEqual(
            raw, memory.read_evidence(f.root, accepted["path"], run_id=accepted["run_id"])
        )
        self.assertEqual("PASS", report_history.read(f.root, accepted)["report"]["outcome"])

    def test_old_files_do_not_publish_state_jobs_or_cases(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        folder = f.root / ".factory/memory"
        self.assertEqual([], teacher.pending(f.root))
        self.assertEqual(([], []), case_search.search_cases(f.root, "obsolete"))
        for name in (
            "state/workflow.json",
            "teacher/old.json",
            "history/seals/obsolete.json",
            "history/snapshots/obsolete.json",
            "history/archive/2000-01-01_obsolete.tar.gz",
            "history/obsolete/reports/orphan.json",
        ):
            path = folder / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('{"summary":"obsolete"}')
        with self.assertRaisesRegex(Invalid, "Run not found"):
            memory.read_task(f.root, "label", run_id=None)
        f.init()
        self.assertEqual([], teacher.pending(f.root))
        self.assertEqual(([], []), case_search.search_cases(f.root, "obsolete"))
        with self.assertRaisesRegex(Invalid, "Run not found"):
            memory.read_task(f.root, "label", run_id="obsolete")
        with self.assertRaisesRegex(Invalid, "Run not found"):
            memory.read_evidence(
                f.root, ".factory/memory/history/obsolete/reports/orphan.json", run_id="obsolete"
            )

        first = f.ledger.read()["run_id"]
        f.complete()
        f.ledger.archive("completed", "first clean-install run")
        f.ledger.clean()
        self.assertNotEqual(first, "obsolete")
        self.assertIn(first, {hit.run_id for hit in case_search.search_cases(f.root, "fixture")[0]})
        self.assertNotIn("obsolete", str(teacher.pending(f.root)))
        self.assertEqual(([], []), case_search.search_cases(f.root, "obsolete"))

    def test_rejecting_incompatible_wal_preserves_payload_and_pending_writes(self) -> None:
        fixture = WorkflowFixture(self.addCleanup)
        path = fixture.root / sqlite_history_repository.DATABASE
        path.parent.mkdir(parents=True, exist_ok=True)
        with closing(sqlite3.connect(path)) as db, db:
            db.setconfig(sqlite3.SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE, True)
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("CREATE TABLE old_state(value TEXT)")
            db.execute("INSERT INTO old_state VALUES ('pending')")
        wal = Path(str(path) + "-wal")
        before = path.read_bytes(), wal.read_bytes()
        with self.assertRaisesRegex(Invalid, "Unsupported workflow database"):
            fixture.init()
        self.assertEqual((path.read_bytes(), wal.read_bytes()), before)

    def test_unsupported_databases_are_left_intact(self) -> None:
        for version in (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10):
            with self.subTest(version=version):
                f = WorkflowFixture(self.addCleanup)
                path = f.root / sqlite_history_repository.DATABASE
                path.parent.mkdir(parents=True, exist_ok=True)
                db = sqlite3.connect(path)
                try:
                    db.execute("CREATE TABLE existing(value)")
                    db.execute("INSERT INTO existing VALUES ('original')")
                    db.execute(f"PRAGMA user_version={version}")
                    db.commit()
                    before = path.read_bytes()
                    with self.assertRaisesRegex(Invalid, "Unsupported workflow database"):
                        f.init()
                    self.assertEqual(before, path.read_bytes())
                finally:
                    db.close()
