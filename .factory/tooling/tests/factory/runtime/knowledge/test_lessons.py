"""Teacher and retrieval checks through disposable checkouts and workflow acceptance."""

import json
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from pathlib import Path
from threading import Barrier
from unittest.mock import Mock, patch

from factory.adapters.acpx_adapter import prepare_prompt
from factory.database.port import DatabaseBackend
from factory.database.provider import current_database, use_database
from factory.database.sqlite import workflow_db
from factory.paths import BIN, FACTORY_ROOT
from factory.runtime import lessons, teacher
from factory.runtime.history import report_history
from factory.runtime.knowledge.case_search import search_cases
from factory.runtime.knowledge.teacher_job_repository import TeacherJobRepository
from factory.runtime.lessons import BASE, Lesson, catalog, lookup, search_lessons
from factory.runtime.observability import lesson_telemetry
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class LessonTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name).resolve()
        self.card = Lesson(
            id="packet",
            scope="factory",
            title="Packet receipt",
            observed="Wrong receipt",
            applies_when="Multipart delivery",
            action="Bind receipt to assignment and digest.",
            tags=["квитанция", "пакет"],
        )
        self.incident = "run-01/accept/4"
        self.event = teacher.Event(
            kind="retro", incident=self.incident, source="retro-1", observation="Verified"
        )
        self.key = teacher.enqueue(self.root, self.event)

    def test_cache_upgrade_and_incremental_edits_are_atomic(self) -> None:
        cache = self.root / BASE / "cache/lessons.sqlite3"
        cache.parent.mkdir(parents=True)
        with closing(sqlite3.connect(cache)) as db, db:
            db.execute("CREATE TABLE version(signature TEXT)")
            db.execute("CREATE VIRTUAL TABLE lessons USING fts5(id,content)")
            db.execute("INSERT INTO lessons VALUES ('orphan','legacy')")
        for key in ("first", "middle", "third"):
            teacher.apply(self.root, self.key, self.card.model_copy(update={"id": key}), None)
        self.assertEqual(search_lessons(self.root, "legacy"), [])
        folder = self.root / BASE / "lessons/factory"
        first = folder / "first.md"
        original = first.read_bytes()
        self.assertIn(b"receipt", original)
        first.write_bytes(original.replace(b"receipt", b"beacon"))
        with patch.object(lessons, "_entry", wraps=lessons._entry) as parse:
            self.assertEqual([m.id for m in search_lessons(self.root, "beacon")], ["first"])
            self.assertEqual({Path(c.args[0]).stem for c in parse.call_args_list}, {"first"})
        with closing(sqlite3.connect(cache)) as db:
            before = db.execute("SELECT path,revision FROM lesson_files ORDER BY path").fetchall()
        first.unlink()
        bad = folder / "zzz.md"
        bad.write_bytes(b"bad front matter")
        with self.assertRaisesRegex(ValueError, "front matter"):
            search_lessons(self.root, "receipt")
        with closing(sqlite3.connect(cache)) as db:
            self.assertEqual(
                db.execute("SELECT path,revision FROM lesson_files ORDER BY path").fetchall(),
                before,
            )
        bad.unlink()
        self.assertEqual({m.id for m in search_lessons(self.root, "receipt")}, {"middle", "third"})
        with closing(sqlite3.connect(cache)) as db:
            db.execute("VACUUM")
        self.assertEqual({m.id for m in search_lessons(self.root, "receipt")}, {"middle", "third"})

    def test_typed_telemetry_preserves_unlimited_totals_and_wire_shape(self) -> None:
        with workflow_db.database(self.root) as db:
            db.execute(
                """INSERT INTO runs(run_id,record,current) VALUES ('run','{"status":"active"}',1)"""
            )
            for i in range(4):
                raw = json.dumps(
                    {
                        "report": {
                            "outcome": "PASS",
                            "applied_lessons": [
                                {"id": "lesson", "revision": "a" * 64, "result": str(i)}
                            ],
                        }
                    }
                ).encode()
                db.execute("INSERT INTO artifact_blobs(sha256,body) VALUES (?,?)", (str(i), raw))
                db.execute(
                    """INSERT INTO artifacts(run_id,path,kind,sha256,node_id,dispatch_id)
                           VALUES ('run',?,'report',?,'node','dispatch')""",
                    (str(i), str(i)),
                )
        trace = lesson_telemetry.read_trace(self.root, "run", 1)
        self.assertEqual(trace.reported_applications, 4)
        self.assertEqual([a.result for a in trace.applications], ["3"])
        self.assertEqual(lesson_telemetry.report(self.root, "run", 1), trace.model_dump())

    def test_lesson_trace_survives_clean_and_restore(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        seed = teacher.enqueue(f.root, self.event)
        original = teacher.apply(f.root, seed, self.card, None)
        teacher.complete(f.root, seed)
        run = f.init()["run_id"]
        f.start("write-label")
        dispatch = f.ledger.read()["nodes"]["write-label"]["dispatch_id"]

        def cli(*args: str) -> str:
            return subprocess.check_output(
                [sys.executable, str(BIN / "lessons.py"), "--workspace", str(f.root), *args],
                text=True,
            )

        def search(query: str) -> list[dict[str, str]]:
            matches: list[dict[str, str]] = json.loads(
                cli("search_lessons", query, "--run", run, "--dispatch", dispatch)
            )
            return matches

        self.assertEqual([], search("private-miss-phrase"))
        (hit,) = search("квитанция")
        self.assertEqual(original["revision"], hit["revision"])
        use = {"id": hit["id"], "revision": hit["revision"], "result": "Receipt verified by test"}
        f.ledger.finish("write-label", f.report("write-label", applied_lessons=[use]))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.ledger.accept("accept-label")
        f.ledger.archive("completed", "trace review")
        f.ledger.clean()
        (key,) = teacher.pending(f.root)
        evidence = teacher.read_event(f.root, key).incidents
        assert evidence is not None
        self.assertEqual(next(iter(evidence.values())).applied_lessons, [use])
        teacher.apply(f.root, key, self.card, hit["revision"])
        teacher.apply(f.root, key, self.card, hit["revision"])
        teacher.complete(f.root, key, reason="Confirmed in this run")
        teacher.complete(f.root, key)
        # A search outside an assignment remains visible only in workspace totals.
        self.assertEqual([], json.loads(cli("search_lessons", "standalone")))
        restored = self.root / "restored"
        target = restored / workflow_db.DATABASE
        target.parent.mkdir(parents=True)
        shutil.copyfile(f.root / workflow_db.DATABASE, target)
        report = lesson_telemetry.report(restored, run, 10)
        self.assertEqual(report, json.loads(cli("telemetry", "--run", run, "--json")))
        self.assertEqual(report["search_counts"], {"hit": 1, "miss": 1, "error": 0})
        self.assertNotIn("private-miss-phrase", json.dumps(report))
        self.assertEqual(report["reported_applications"], 1)
        self.assertEqual(report["applications"][0]["search_id"], report["searches"][0]["id"])
        self.assertEqual(report["applications"][0]["report_outcome"], "PASS")
        self.assertEqual(report["teacher_counts"], {"completed": 1})
        (change,) = report["teacher"][0]["changes"]
        self.assertEqual((change["action"], change["confirmed"]), ("updated", True))
        self.assertEqual(report["teacher"][0]["reason"], "Confirmed in this run")
        self.assertEqual(report, json.loads(cli("telemetry", "--run", run)))
        self.assertEqual(lesson_telemetry.report(restored, None, 1)["search_counts"]["miss"], 2)

    def test_search_error_and_best_effort_telemetry(self) -> None:
        with patch("factory.runtime.lessons._search", side_effect=ValueError("private details")):
            with self.assertRaisesRegex(ValueError, "private details"):
                search_lessons(self.root, "private query")
        trace = lesson_telemetry.report(self.root, None, 3)
        self.assertEqual(trace["search_counts"]["error"], 1)
        self.assertEqual(trace["searches"][0]["error_type"], "ValueError")
        self.assertNotIn("private", json.dumps(trace))
        with (
            patch("factory.database.sqlite.workflow_db.database", side_effect=OSError("locked")),
            patch("sys.stderr"),
        ):
            self.assertEqual(search_lessons(self.root, "nothing"), [])

    def test_teacher_recovers_trace_after_card_write(self) -> None:
        update = teacher.update_event

        def interrupt(
            root: Path, key: str, event: teacher.Event, *, jobs: TeacherJobRepository
        ) -> None:
            if event.changes and event.changes[0].confirmed:
                raise OSError("interrupted after rename")
            update(root, key, event, jobs=jobs)

        with (
            patch.object(teacher, "update_event", side_effect=interrupt),
            self.assertRaises(OSError),
        ):
            teacher.apply(self.root, self.key, self.card, None)
        teacher.complete(self.root, self.key)
        (change,) = teacher.read_event(self.root, self.key).changes
        self.assertEqual((change.action, change.confirmed), ("created", True))
        deletion = teacher.enqueue(
            self.root,
            teacher.Event(
                kind="user", incident="remove", source="owner", delete_target=self.card.id
            ),
        )
        teacher.delete(self.root, deletion, change.revision)
        teacher.delete(self.root, deletion, change.revision)
        teacher.complete(self.root, deletion)
        changes = teacher.read_event(self.root, deletion).changes
        self.assertEqual([c.action for c in changes], ["deleted"])

    def test_publish_retry_update_conflict_and_skip(self) -> None:
        card = self.card.model_copy(update={"action": self.card.action + "\n"})
        first = teacher.apply(self.root, self.key, card, None)
        self.assertEqual(first, teacher.apply(self.root, self.key, card, None))
        teacher.complete(self.root, self.key)
        self.assertEqual(self.key, teacher.enqueue(self.root, self.event))
        self.assertEqual([], teacher.pending(self.root))
        next_key = teacher.enqueue(self.root, self.event.model_copy(update={"source": "retro-2"}))
        with self.assertRaisesRegex(Invalid, "reread catalog"):
            teacher.apply(self.root, next_key, self.card, None)
        old = catalog(self.root)[0]
        teacher.apply(self.root, next_key, self.card, old.revision)
        current = catalog(self.root)[0]
        self.assertEqual([self.incident], list(current.lesson.sources))
        self.assertEqual(2, len(current.lesson.sources[self.incident]))
        skip = teacher.enqueue(self.root, self.event.model_copy(update={"source": "unconfirmed"}))
        teacher.complete(self.root, skip)
        self.assertEqual([current], catalog(self.root))

    def test_ready_queue_preserves_operation_and_waiting_owner(self) -> None:
        def cli(*args: str) -> object:
            out = subprocess.check_output(
                [sys.executable, str(BIN / "lessons.py"), "--workspace", str(self.root), *args]
            )
            return json.loads(out)

        old = teacher.apply(self.root, self.key, self.card, None)
        teacher.complete(self.root, self.key)
        audit = str(cli("user", "audit-01", "msg1", "Review our catalog", "--audit"))
        retro = str(cli("retro", "--confirmed", "incident-02", "retro2", "New observation"))
        self.assertEqual("audit", teacher.route(self.root, audit)["operation"])
        self.assertEqual("capture", teacher.route(self.root, retro)["operation"])
        self.assertEqual("user", teacher.route(self.root, audit)["kind"])
        updated = teacher.apply(self.root, audit, self.card, str(old["revision"]))
        self.assertEqual([self.incident], list(catalog(self.root)[0].lesson.sources))
        self.assertEqual(1, len(catalog(self.root)[0].lesson.edits))
        teacher.complete(self.root, audit)
        teacher.apply(self.root, retro, self.card, str(updated["revision"]))
        self.assertIn("incident-02", catalog(self.root)[0].lesson.sources)
        teacher.complete(self.root, retro)

        deletion = str(cli("user", "request", "msg2", "Delete packet", "--delete", "packet"))
        cli("wait-owner", deletion, "Confirm the current version?")
        for index in range(2):
            ready = str(cli("retro", "--confirmed", f"case-{index}", f"retro-{index}", "Review"))
            self.assertEqual([ready], cli("pending"))
            teacher.complete(self.root, ready)
        self.assertEqual([deletion], cli("waiting"))
        self.assertEqual("delete", teacher.route(self.root, deletion)["operation"])
        with self.assertRaisesRegex(Invalid, "Awaiting owner reply"):
            teacher.delete(self.root, deletion, catalog(self.root)[0].revision)
        with self.assertRaisesRegex(ValueError, "Awaiting owner reply"):
            teacher.complete(self.root, deletion)
        cli("complete", deletion, "--cancelled-by", "msg3")
        self.assertEqual([], cli("waiting"))

    def test_named_edit_packet_stays_bounded_as_catalog_grows(self) -> None:
        teacher.apply(self.root, self.key, self.card, None)
        event = teacher.Event(
            kind="user", operation="edit", edit_target="packet", source="msg", incident="edit"
        )
        key = teacher.enqueue(self.root, event)
        path = self.root / catalog(self.root)[0].path
        raw = path.read_text()
        packets = []
        for index in range(1, 300):
            name = f"extra-{index}"
            path.with_name(name + ".md").write_text(raw.replace("id: packet", f"id: {name}"))
            if index in (9, 299):
                packets.append(teacher.packet(self.root, key))
        self.assertEqual(packets[0], packets[1])
        self.assertEqual(1, len(lookup(self.root, "packet")))
        self.assertEqual(300, len(catalog(self.root)))
        with self.assertRaisesRegex(Invalid, "existing target"):
            teacher.apply(self.root, key, self.card.model_copy(update={"id": "extra-1"}), None)

    def test_user_creation_edit_delete_through_cli(self) -> None:
        def cli(*args: str, payload: Lesson | None = None) -> str:
            result = subprocess.run(
                [sys.executable, str(BIN / "lessons.py"), "--workspace", str(self.root), *args],
                input=payload.model_dump_json(exclude={"sources"}) if payload else None,
                capture_output=True,
                text=True,
                check=True,
            )
            return result.stdout

        created = json.loads(cli("user", "case", "chat/msg1", "Observed a stale packet"))
        entry = json.loads(cli("publish", created, "-", payload=self.card))
        cli("complete", created)
        edited = json.loads(cli("user", "msg2", "chat/msg2", "Clarify the lookup tag"))
        card = self.card.model_copy(update={"tags": ["передача", "item-count"]})
        updated = json.loads(
            cli("publish", edited, "-", "--revision", entry["revision"], payload=card)
        )
        cli("complete", edited)
        self.assertEqual(entry["lesson"]["sources"], updated["lesson"]["sources"])
        self.assertEqual([f"user:chat/msg2#{edited}"], updated["lesson"]["edits"])
        self.assertTrue(
            all(s.startswith("user:chat/") for s in updated["lesson"]["sources"]["case"])
        )
        self.assertEqual(
            ["packet"], [r["id"] for r in json.loads(cli("search_lessons", "передача"))]
        )
        deletion = json.loads(
            cli("user", "case", "chat/msg3", "Delete packet", "--delete", "packet")
        )
        with self.assertRaisesRegex(Invalid, "Lesson changed"):
            teacher.delete(self.root, deletion, entry["revision"])
        cli("delete", deletion, "--revision", updated["revision"])
        cli("delete", deletion, "--revision", updated["revision"])
        cli("complete", deletion)
        self.assertEqual([], json.loads(cli("search_lessons", "передача")))
        self.assertFalse((self.root / updated["path"]).exists())

    def test_deletion_requires_target_request_and_no_inbound_links(self) -> None:
        item = teacher.apply(self.root, self.key, self.card, None)
        revision = str(item["revision"])
        with self.assertRaisesRegex(Invalid, "Explicit user deletion"):
            teacher.delete(self.root, self.key, revision)
        old = self.card.model_copy(update={"id": "old", "replaced_by": self.card.id})
        teacher.apply(self.root, self.key, old, None)
        deletion = teacher.enqueue(
            self.root,
            teacher.Event(
                kind="user",
                incident="case",
                source="msg3",
                observation="Delete packet",
                delete_target=self.card.id,
            ),
        )
        with self.assertRaisesRegex(Invalid, "replaced_by: old"):
            teacher.delete(self.root, deletion, revision)
        self.assertEqual(2, len(catalog(self.root)))

    def test_delayed_delete_cannot_repin_or_disappear_on_retry(self) -> None:
        first = teacher.apply(self.root, self.key, self.card, None)
        request = teacher.Event(kind="user", incident="q", source="msg", delete_target="packet")
        key = teacher.enqueue(self.root, request)
        update = teacher.enqueue(self.root, self.event.model_copy(update={"source": "second"}))
        current = teacher.apply(
            self.root,
            update,
            self.card.model_copy(update={"action": "New"}),
            str(first["revision"]),
        )
        self.assertEqual(key, teacher.enqueue(self.root, request))
        for revision in (first["revision"], current["revision"]):
            with self.assertRaisesRegex(Invalid, "Lesson changed"):
                teacher.delete(self.root, key, str(revision))
        with self.assertRaisesRegex(Invalid, "Unresolved deletion"):
            teacher.complete(self.root, key)
        self.assertIn(key, teacher.pending(self.root))
        teacher.complete(self.root, key, "chat/owner-reply")
        self.assertEqual("chat/owner-reply", teacher.read_event(self.root, key).cancelled_by)
        self.assertEqual(current["revision"], catalog(self.root)[0].revision)
        confirmed = teacher.enqueue(
            self.root, request.model_copy(update={"source": "chat/confirmed"})
        )
        teacher.delete(self.root, confirmed, str(current["revision"]))
        teacher.complete(self.root, confirmed)
        self.assertEqual([], catalog(self.root))

    def test_owner_reports_new_independent_observation(self) -> None:
        initial = teacher.apply(self.root, self.key, self.card, None)
        event = teacher.Event(
            kind="user", incident="another", source="chat/observed", new_observation=True
        )
        key = teacher.enqueue(self.root, event)
        teacher.apply(self.root, key, self.card, str(initial["revision"]))
        saved = catalog(self.root)[0].lesson
        self.assertEqual({self.incident, "another"}, set(saved.sources))
        self.assertEqual([], saved.edits)

    def test_old_terms_are_searchable_and_edit_writes_obsidian_tags(self) -> None:
        teacher.apply(self.root, self.key, self.card, None)
        old = catalog(self.root)[0]
        path = self.root / old.path
        raw = path.read_bytes().replace(b"tags:", b"terms:")
        path.write_bytes(raw)
        self.assertEqual(["packet"], [m.id for m in search_lessons(self.root, "квитанция")])
        self.assertEqual(raw, path.read_bytes())
        update = teacher.enqueue(self.root, self.event.model_copy(update={"source": "next"}))
        revision = catalog(self.root)[0].revision
        for tag in ("item count", "#item", "123"):
            with self.assertRaisesRegex(Invalid, "Invalid lesson tag"):
                teacher.apply(
                    self.root, update, self.card.model_copy(update={"tags": [tag]}), revision
                )
        teacher.apply(self.root, update, self.card, revision)
        self.assertIn(b"tags:", path.read_bytes())
        self.assertNotIn(b"terms:", path.read_bytes())

    def test_rebuild_limit_retirement_and_manual_transfer(self) -> None:
        for n in range(4):
            c = self.card.model_copy(
                update={"id": f"packet-{n}", "scope": "project" if n == 0 else "factory"}
            )
            teacher.apply(self.root, self.key, c, None)
        self.assertEqual(3, len(search_lessons(self.root, "квитанция")))
        self.assertEqual([], search_lessons(self.root, "absent"))
        old = catalog(self.root)[0]
        other = next(e.lesson.id for e in catalog(self.root) if e.lesson.id != old.lesson.id)
        retire = teacher.enqueue(self.root, self.event.model_copy(update={"source": "refresh"}))
        teacher.apply(
            self.root,
            retire,
            old.lesson.model_copy(update={"sources": {}, "replaced_by": other}),
            old.revision,
        )
        self.assertNotIn(old.lesson.id, {m.id for m in search_lessons(self.root, "packet")})
        (self.root / BASE / "cache/lessons.sqlite3").unlink()
        matches = search_lessons(self.root, "packet")
        self.assertEqual(3, len(matches))
        installed = self.root / "other"
        portable = next(
            e
            for e in catalog(self.root)
            if e.lesson.scope == "factory" and not e.lesson.replaced_by
        )
        target = installed / portable.path
        target.parent.mkdir(parents=True)
        shutil.copyfile(self.root / portable.path, target)
        self.assertEqual(
            [portable.lesson.id], [m.id for m in search_lessons(installed, "квитанция")]
        )
        target.unlink()
        self.assertEqual([], search_lessons(installed, "квитанция"))

    def test_git_merge_and_switch_rebuild_current_catalog(self) -> None:
        def git(*args: str) -> None:
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(self.root),
                    "-c",
                    "user.name=Fixture",
                    "-c",
                    "user.email=fixture@example.invalid",
                    "-c",
                    "commit.gpgsign=false",
                    "-c",
                    "core.hooksPath=/dev/null",
                    *args,
                ],
                check=True,
                capture_output=True,
            )

        git("init", "-q", "-b", "base")
        store = self.root / ".factory"
        shutil.copyfile(FACTORY_ROOT / ".gitignore", store / ".gitignore")
        (self.root / BASE / "USER.md").touch()
        git("add", ".")
        git("commit", "-qm", "base")
        for branch in ("left", "right"):
            git("switch", "-qc", branch, "base")
            teacher.apply(self.root, self.key, self.card.model_copy(update={"id": branch}), None)
            git("add", ".")
            git("commit", "-qm", branch)
            self.assertEqual([branch], [m.id for m in search_lessons(self.root, "packet")])
        git("merge", "--no-edit", "left")
        self.assertEqual({"left", "right"}, {m.id for m in search_lessons(self.root, "packet")})
        git("switch", "-q", "base")
        self.assertEqual([], search_lessons(self.root, "packet"))

    def test_bad_markdown_and_paths_report_error(self) -> None:
        path = self.root / BASE / "lessons/project/wrong.md"
        path.parent.mkdir(parents=True)
        path.write_text("corrupt", encoding="utf-8")
        run = subprocess.run(
            [
                sys.executable,
                str(BIN / "lessons.py"),
                "--workspace",
                str(self.root),
                "search_lessons",
                "wrong",
            ],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(0, run.returncode)
        self.assertIn("front matter", run.stderr)
        self.assertEqual("", run.stdout)
        with self.assertRaises(Invalid):
            teacher.read_event(self.root, "../USER.md")

    def test_invalid_catalog_directory_does_not_look_empty(self) -> None:
        path = self.root / BASE / "lessons/project"
        path.parent.mkdir(parents=True)
        path.write_text("not a directory", encoding="utf-8")
        with self.assertRaises((ValueError, OSError)):
            search_lessons(self.root, "packet")

    def test_event_checks_pinned_owner_text_and_rejects_old_queue_format(self) -> None:
        raw = teacher.read_event(self.root, self.key).model_dump()
        raw["user_instructions"] = "Changed after capture"
        with workflow_db.database(self.root) as db:
            db.execute("UPDATE teacher_jobs SET record=? WHERE id=?", (json.dumps(raw), self.key))
        with self.assertRaisesRegex(Invalid, "instructions digest"):
            teacher.packet(self.root, self.key)
        legacy = self.event.model_dump(exclude={"checkout", "user_sha256"})
        with workflow_db.database(self.root) as db:
            db.execute(
                "UPDATE teacher_jobs SET record=? WHERE id=?", (json.dumps(legacy), self.key)
            )
        with self.assertRaisesRegex(Invalid, "instructions digest"):
            teacher.read_event(self.root, self.key)
        legacy = self.event.model_dump(exclude={"operation"})
        with workflow_db.database(self.root) as db:
            db.execute(
                "UPDATE teacher_jobs SET record=? WHERE id=?", (json.dumps(legacy), self.key)
            )
        with self.assertRaisesRegex(Invalid, "Missing Teacher operation"):
            teacher.pending(self.root)

    def test_teacher_poll_validates_only_the_requested_checkout_and_queue(self) -> None:
        subprocess.run(["git", "init", "-q", "-b", "current", str(self.root)], check=True)
        current = teacher.enqueue(
            self.root, self.event.model_copy(update={"checkout": "refs/heads/current"})
        )
        foreign = teacher.enqueue(
            self.root, self.event.model_copy(update={"checkout": "refs/heads/other"})
        )
        parked = teacher.enqueue(
            self.root,
            self.event.model_copy(update={"checkout": "refs/heads/current", "source": "parked"}),
        )
        teacher.park(self.root, parked, "Which change?")
        with workflow_db.database(self.root) as db:
            db.execute(
                """UPDATE teacher_jobs SET record=json_set(record, '$.user_instructions', 'changed')
                   WHERE id IN (?, ?)""",
                (foreign, parked),
            )
        self.assertEqual(sorted([self.key, current]), teacher.pending(self.root))
        with self.assertRaisesRegex(Invalid, "instructions digest"):
            teacher.pending(self.root, waiting=True)
        subprocess.run(
            ["git", "-C", str(self.root), "switch", "--orphan", "other"],
            check=True,
            capture_output=True,
        )
        with self.assertRaisesRegex(Invalid, "instructions digest"):
            teacher.pending(self.root)

    def test_simultaneous_searches_find_the_observed_symptom(self) -> None:
        card = self.card.model_copy(update={"observed": "Navigation flickered"})
        teacher.apply(self.root, self.key, card, None)
        ready = Barrier(4)

        def lookup(_: int) -> list[str]:
            ready.wait(timeout=10)
            return [m.id for m in search_lessons(self.root, "flicker")]

        with ThreadPoolExecutor(max_workers=4) as workers:
            self.assertEqual([["packet"]] * 4, list(workers.map(lookup, range(4))))

    def test_retro_event_stays_on_its_git_branch(self) -> None:
        def cli(*args: str) -> subprocess.CompletedProcess[str]:
            return subprocess.run(
                [sys.executable, str(BIN / "lessons.py"), "--workspace", str(self.root), *args],
                capture_output=True,
                text=True,
                check=False,
            )

        subprocess.run(["git", "init", "-q", "-b", "original", str(self.root)], check=True)
        proposal = (self.incident, "branch-review", "Label flickered")
        initial = teacher.pending(self.root)
        refused = cli("retro", *proposal)
        self.assertNotEqual(0, refused.returncode)
        self.assertIn("--confirmed", refused.stderr)
        self.assertEqual(initial, teacher.pending(self.root))
        event = cli("retro", "--confirmed", *proposal)
        self.assertEqual(0, event.returncode, event.stderr)
        key = json.loads(event.stdout)
        subprocess.run(
            ["git", "-C", str(self.root), "switch", "--orphan", "other"],
            check=True,
            capture_output=True,
        )
        self.assertNotIn(key, teacher.pending(self.root))
        for args in [("packet", key), ("complete", key)]:
            blocked = cli(*args)
            self.assertNotEqual(0, blocked.returncode)
            self.assertIn("refs/heads/original", blocked.stderr)
        with self.assertRaisesRegex(Invalid, "refs/heads/original"):
            teacher.apply(self.root, key, self.card, None)
        subprocess.run(
            ["git", "-C", str(self.root), "switch", "--orphan", "original"],
            check=True,
            capture_output=True,
        )
        self.assertIn(key, teacher.pending(self.root))
        self.assertEqual(0, cli("complete", key).returncode)
        self.assertNotIn(key, teacher.pending(self.root))

    def test_git_distributes_only_durable_memory(self) -> None:
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        store = self.root / ".factory"
        shutil.copyfile(FACTORY_ROOT / ".gitignore", store / ".gitignore")
        user = store / "memory/USER.md"
        user.touch()
        teacher.apply(self.root, self.key, self.card, None)
        search_lessons(self.root, "receipt")
        folder = store / "memory/lessons/factory"
        (folder / "partial-write").write_bytes(b"temporary")
        (folder / "backup").mkdir()
        (folder / "backup/copy.md").touch()
        listing = subprocess.check_output(
            ["git", "-C", str(self.root), "ls-files", "--others", "--exclude-standard"], text=True
        ).splitlines()
        self.assertEqual(
            [".factory/.gitignore", f"{BASE}/USER.md", f"{BASE}/lessons/factory/packet.md"], listing
        )


class TeacherWorkflowTests(unittest.TestCase):
    def test_final_feedback_scopes_queries_to_reported_attempts_and_tracks_catalog(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        run = f.init()["run_id"]
        f.start("write-label")
        dispatch = f.ledger.read()["nodes"]["write-label"]["dispatch_id"]
        search_lessons(f.root, "unbound-secret")
        search_lessons(f.root, "wrong-owner", run_id=run, dispatch_id="stale")
        search_lessons(f.root, "early symptom", run_id=run, dispatch_id=dispatch)
        search_lessons(f.root, "x" * 513, run_id=run, dispatch_id=dispatch)
        with (
            patch.object(lessons, "_search", side_effect=ValueError("invalid card")),
            self.assertRaises(ValueError),
        ):
            search_lessons(f.root, "failed search", run_id=run, dispatch_id=dispatch)
        f.ledger.finish("write-label", f.report("write-label", "FAIL"))
        f.ledger.retry("write-label", "tests", "apply correction", "author stopped")
        f.complete()
        f.ledger.archive("completed", "verified")
        f.ledger.clean()
        [key] = teacher.pending(f.root)
        incidents = teacher.read_event(f.root, key).incidents
        assert incidents is not None
        [incident] = incidents
        rows = teacher.search_feedback(f.root, key, incident)
        self.assertEqual(
            [(r.status, r.query, r.same_catalog) for r in rows],
            [("miss", "early symptom", True), ("miss", None, None), ("error", None, None)],
        )
        self.assertTrue(all(r.dispatch_id == dispatch for r in rows))
        self.assertNotIn("early symptom", json.dumps(lesson_telemetry.report(f.root, run, 20)))
        with workflow_db.database(f.root) as db:
            self.assertEqual(
                db.execute("SELECT query FROM lesson_search_evidence").fetchall(),
                [("early symptom",)],
            )
        card = Lesson(
            id="new", scope="factory", title="New", observed="New", applies_when="New", action="New"
        )
        teacher.apply(f.root, key, card, None)
        self.assertIs(teacher.search_feedback(f.root, key, incident)[0].same_catalog, False)
        with self.assertRaisesRegex(Invalid, "accepted incident"):
            teacher.search_feedback(f.root, key, "different")
        with (
            patch.object(teacher, "checkout_ref", return_value="new-branch"),
            patch.object(
                teacher,
                "read_event",
                return_value=teacher.read_event(f.root, key).model_copy(
                    update={"checkout": "old-branch"}
                ),
            ),
            self.assertRaisesRegex(Invalid, "belongs to"),
        ):
            teacher.search_feedback(f.root, key, incident)

    def test_current_schema_records_unbound_search_without_wording(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            search_lessons(root, "original")
            with workflow_db.database(root) as db:
                self.assertEqual(db.execute("PRAGMA user_version").fetchone(), (2,))
                self.assertEqual(
                    db.execute("SELECT count(*) FROM lesson_searches").fetchone(), (1,)
                )
                self.assertEqual(
                    db.execute("SELECT count(*) FROM lesson_search_evidence").fetchone(), (0,)
                )

    def test_acceptance_recovery_archive_and_retro(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        self.assertEqual("teacher", f.init()["graph"]["after_archive"])
        self.assertEqual(
            {"role": "teacher", "status": "planned"}, f.ledger.next_actions()["after_archive"]
        )
        f.complete()
        self.assertEqual([], f.ledger.next_actions()["pending_teacher_events"])
        f.ledger.archive("completed", "verified")
        [key] = teacher.pending(f.root)
        self.assertIn(key, f.ledger.next_actions()["pending_teacher_events"])
        event = teacher.read_event(f.root, key)
        assert event.incidents is not None
        [(incident, evidence)] = event.incidents.items()
        self.assertEqual({"write-label", "verify-label"}, {r["node_id"] for r in evidence.reports})
        self.assertEqual([key], f.ledger.next_actions()["pending_teacher_events"])
        f.ledger.archive("completed", "verified")
        f.ledger.clean()
        self.assertEqual([key], teacher.pending(f.root))
        for ref in evidence.reports:
            self.assertEqual(
                ref["dispatch_id"], report_history.read(f.root, ref)["report"]["dispatch_id"]
            )
        c = Lesson(
            id="label",
            scope="project",
            title="Label",
            observed="Old label",
            action="Check the label",
            applies_when="Renaming label",
        )
        teacher.apply(f.root, key, c, None)
        teacher.complete(f.root, key)
        retro = teacher.enqueue(
            f.root,
            teacher.Event(
                kind="retro",
                incident=incident,
                source="retro/label",
                observation="Confirmed same issue",
            ),
        )
        teacher.apply(f.root, retro, c, catalog(f.root)[0].revision)
        self.assertEqual(1, len(catalog(f.root)[0].lesson.sources))
        self.assertEqual("label", search_lessons(f.root, "label")[0].id)

    def test_reaccepted_task_keeps_incident_and_failed_evidence(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        f.init()
        f.complete()
        self.assertEqual([], teacher.pending(f.root))
        incident = f.ledger.read()["events"][-1]["lesson_incident"]
        f.ledger.retry("write-label", "tests", "label regression", "author stopped")
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label", "FAIL"))
        f.ledger.retry("write-label", "tests", "correct label", "author stopped")
        f.complete()
        self.assertEqual([], teacher.pending(f.root))
        f.ledger.archive("completed", "Final corrected label")
        [key] = teacher.pending(f.root)
        incidents = teacher.read_event(f.root, key).incidents
        assert incidents is not None
        self.assertEqual([incident], list(incidents))
        outcomes = [
            report_history.read(f.root, ref)["report"]["outcome"]
            for ref in incidents[incident].reports
        ]
        self.assertIn("FAIL", outcomes)

    def test_one_review_for_batch_includes_linked_retro_and_requires_named_provenance(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        f.batch()
        run_id = f.init()["run_id"]
        f.complete()
        incident = f"{run_id}/accept-label"
        command = [
            sys.executable,
            str(BIN / "workflow.py"),
            "--workspace",
            str(f.root),
            "record-retro",
            run_id,
            incident,
            "retro/label",
            "Measured the corrected result",
        ]
        for _ in range(2):
            subprocess.run(command, check=True, capture_output=True)
        with self.assertRaisesRegex(Invalid, "Unfinished nodes"):
            f.ledger.archive("completed", "Premature finalization")
        self.assertEqual([], teacher.pending(f.root))
        for node in ("write-second", "verify-second"):
            f.start(node)
            dispatch = f.ledger.read()["nodes"][node]["dispatch_id"]
            search_lessons(f.root, node, run_id=run_id, dispatch_id=dispatch)
            f.ledger.finish(node, f.report(node))
        f.ledger.accept("accept-second")
        self.assertEqual([], f.ledger.next_actions()["pending_teacher_events"])
        f.start("verify-all", "integration-judge")
        f.ledger.finish("verify-all", f.report("verify-all"))
        f.start("review-all", "integration-judge")
        f.ledger.finish("review-all", f.report("review-all", verdict="APPROVE", findings=[]))
        f.ledger.accept("accept-all")
        self.assertEqual([], teacher.pending(f.root))
        f.ledger.archive("completed", "Integrated checks passed")
        [key] = teacher.pending(f.root)
        f.ledger.clean()
        self.assertEqual([key], teacher.pending(f.root))
        event = teacher.read_event(f.root, key)
        assert event.incidents is not None
        self.assertEqual(
            {incident, f"{run_id}/accept-second", f"{run_id}/accept-all"}, set(event.incidents)
        )
        self.assertEqual([], teacher.search_feedback(f.root, key, incident))
        self.assertEqual(
            [row.query for row in teacher.search_feedback(f.root, key, f"{run_id}/accept-second")],
            ["write-second", "verify-second"],
        )
        self.assertEqual(1, len(event.incidents[incident].retro))
        self.assertEqual("retro/label", event.incidents[incident].retro[0]["source"])
        self.assertTrue(all(item.reports for item in event.incidents.values()))
        card = Lesson(
            id="label",
            scope="project",
            title="Label",
            observed="Old label",
            applies_when="Renaming",
            action="Verify label",
        )
        with self.assertRaisesRegex(Invalid, "Select a packet incident"):
            teacher.apply(f.root, key, card, None)
        teacher.apply(f.root, key, card, None, incident)
        self.assertEqual([incident], list(catalog(f.root)[0].lesson.sources))
        teacher.complete(f.root, key)
        self.assertEqual([], teacher.pending(f.root))

    def test_archive_failure_and_retry_publish_one_job(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        f.init()
        f.complete()
        with patch(
            "factory.database.sqlite.sqlite_teacher_job_repository.insert_event",
            side_effect=OSError("archive failed"),
        ):
            with self.assertRaisesRegex(OSError, "archive failed"):
                f.ledger.archive("completed", "verified")
        self.assertEqual([], teacher.pending(f.root))
        self.assertEqual("active", f.ledger.read()["status"])
        f.ledger.archive("completed", "verified")
        [key] = teacher.pending(f.root)
        self.assertEqual(
            {"role": "teacher", "status": "ready", "event_id": key},
            f.ledger.next_actions()["after_archive"],
        )
        teacher.complete(f.root, key)
        self.assertEqual("done", f.ledger.next_actions()["after_archive"]["status"])
        f.ledger.archive("completed", "verified")
        f.ledger.clean()
        self.assertEqual([], teacher.pending(f.root))

    def test_cancelled_run_keeps_evidence_without_automatic_teacher(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        f.init()
        f.complete()
        f.ledger.archive("cancelled", "Owner cancelled before finalization")
        self.assertEqual(
            {"role": "teacher", "status": "skipped"}, f.ledger.next_actions()["after_archive"]
        )
        f.ledger.clean()
        self.assertEqual([], teacher.pending(f.root))

    def test_user_document_reaches_native_and_acpx_from_snapshot(self) -> None:
        for runner in ["native", "acpx"]:
            with self.subTest(runner=runner):
                f = WorkflowFixture(self.addCleanup)
                config_path = f.config_file(lambda _: None)
                user = config_path.parent / "memory/USER.md"
                user.parent.mkdir(exist_ok=True)
                user.write_bytes("Сохрани  пробелы.\r\n".encode())
                f.config = load_config(config_path)
                if runner == "acpx":
                    f.fake_acp()
                f.init()
                user.write_text("Unaccepted replacement", encoding="utf-8")
                f.ledger.claim("write-label")
                if runner == "acpx":
                    packet = json.loads(
                        Path(prepare_prompt(f.ledger, "write-label")["prompt"]).read_bytes()
                    )
                else:
                    packet = f.ledger.packet("write-label")
                [item] = [
                    doc for doc in packet["instructions"] if doc["path"] == str(user.resolve())
                ]
                self.assertEqual("Сохрани  пробелы.\r\n", item["content"])
                self.assertFalse(
                    any("/memory/lessons/" in doc["path"] for doc in packet["instructions"])
                )


class ArchivedCaseSearchTests(unittest.TestCase):
    def test_explicit_history_uses_current_accepted_attempt_and_exact_report(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        node = "write-label"
        f.init()
        f.start(node)
        f.ledger.finish(node, f.report(node, evidence="obsolete telescopic setting"))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.ledger.accept("accept-label")
        f.ledger.retry(node, "tests", "The setting failed", "The author stopped")
        f.start(node)
        f.ledger.finish(node, f.report(node, "FAIL", evidence="abandoned ultraviolet setting"))
        failed = f.ledger.read()["nodes"][node]["report_ref"]
        f.ledger.retry(node, "tests", "A second setting failed", "The author stopped again")
        f.start(node)
        evidence = "Use the invar shuttle after preloading the stop"
        f.ledger.finish(node, f.report(node, evidence=evidence))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.ledger.accept("accept-label")
        f.ledger.archive("completed", "Fixture verified")
        f.ledger.clean()
        before = teacher.pending(f.root)

        command = [sys.executable, str(BIN / "lessons.py"), "--workspace", str(f.root)]
        query = "invar shuttle"
        plain = subprocess.check_output([*command, "search_lessons", query])
        self.assertEqual([], json.loads(plain))
        self.assertEqual(([], []), search_cases(f.root, "telescopic"))
        self.assertEqual(([], []), search_cases(f.root, "ultraviolet"))
        self.assertEqual(before, teacher.pending(f.root))

        lesson = Lesson(
            id="invar",
            scope="project",
            title="Inspect the invar plate",
            observed="The plate warps",
            applies_when="Before measuring the plate",
            action="Check the plate after it cools",
        )
        teacher.apply(f.root, before[0], lesson, None)
        hits = json.loads(
            subprocess.check_output([*command, "search_lessons", query, "--include-history"])
        )
        self.assertEqual(["lesson", "case"], [hit["source_type"] for hit in hits])
        _, case = hits
        self.assertEqual((node, 3), (case["node"], case["ordinal"]))
        self.assertEqual(case["report_ref"]["sha256"], case["sha256"])

        reference = f.root / "ref.json"
        reference.write_text(json.dumps(case["report_ref"]), encoding="utf-8")
        payload = json.loads(
            subprocess.check_output(
                [
                    sys.executable,
                    str(BIN / "workflow.py"),
                    "--workspace",
                    str(f.root),
                    "read-report",
                    str(reference),
                ]
            )
        )
        self.assertEqual(evidence, payload["result"]["report"]["evidence"])
        self.assertEqual(case["dispatch_id"], payload["result"]["report"]["dispatch_id"])

        capture = [*command, "capture-case", str(reference), "Reused on fixture occurrence two"]
        key = json.loads(subprocess.check_output(capture))
        event = teacher.read_event(f.root, key)
        self.assertEqual("capture", event.route())
        self.assertEqual([case["report_ref"]], event.reports)
        selected = current_database()
        with use_database(Mock(spec_set=DatabaseBackend)):
            self.assertEqual(
                key,
                teacher.capture_case(
                    f.root,
                    case["report_ref"],
                    capture[-1],
                    history=selected.history,
                    jobs=selected.teacher,
                ),
            )
        self.assertEqual(key, json.loads(subprocess.check_output(capture)))
        self.assertEqual(["invar"], [entry.lesson.id for entry in catalog(f.root)])
        reference.write_text(json.dumps(failed), encoding="utf-8")
        blocked = subprocess.run(capture, capture_output=True, text=True, check=False)
        self.assertNotEqual(0, blocked.returncode)
        self.assertIn("not current accepted evidence", blocked.stderr)

    def test_verified_reuse_reaches_teacher_only_with_the_accepted_task(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        author, verifier, gate = "write-label", "verify-label", "accept-label"
        f.init()
        f.start(author)
        f.ledger.finish(author, f.report(author, evidence="Calibrate the invar shuttle"))
        f.start(verifier)
        f.ledger.finish(verifier, f.report(verifier))
        f.ledger.accept(gate)
        f.ledger.archive("completed", "Original accepted case")
        f.ledger.clean()
        for key in teacher.pending(f.root):
            teacher.complete(f.root, key)

        state = f.init()
        cases, _ = search_cases(f.root, "invar shuttle")
        ref = cases[0].report_ref
        use = {"report_ref": ref, "result": "Calibration brought the second shuttle into tolerance"}
        f.start(author)
        forged = {**use, "report_ref": {**ref, "sha256": "0" * 64}}
        with self.assertRaisesRegex(Invalid, "not current accepted evidence"):
            f.ledger.finish(author, f.report(author, applied_cases=[forged]))
        with use_database(Mock(spec_set=DatabaseBackend)):
            f.ledger.finish(author, f.report(author, "FAIL", applied_cases=[use]))
        f.ledger.retry(author, "tests", "Tolerance exceeded", "The author stopped")
        f.start(author)
        f.ledger.finish(author, f.report(author))
        f.start(verifier)
        actual = {**use, "result": "Verified both shuttles within 0.05 mm after calibration"}
        f.ledger.finish(verifier, f.report(verifier, applied_cases=[actual]))
        self.assertEqual([], teacher.pending(f.root))
        f.ledger.accept(gate)
        self.assertEqual([], teacher.pending(f.root))
        f.ledger.archive("completed", "Second shuttle verified")
        [event_id] = teacher.pending(f.root)
        event = teacher.read_event(f.root, event_id)
        assert event.incidents is not None
        [(incident, evidence)] = event.incidents.items()
        self.assertEqual([actual], evidence.applied_cases)
        self.assertEqual(f"{state['run_id']}/{gate}", incident)
        self.assertIn(f.ledger.read()["nodes"][verifier]["report_ref"], evidence.reports)
        self.assertEqual([event_id], teacher.pending(f.root))
        card = Lesson(
            id="calibrate-shuttle",
            scope="project",
            title="Calibrate the shuttle",
            observed="Drift outside tolerance",
            applies_when="Calibrating a replacement shuttle",
            action="Verify clearance after calibration.",
        )
        teacher.apply(f.root, event_id, card, None)
        teacher.complete(f.root, event_id)
        self.assertEqual([incident], list(catalog(f.root)[0].lesson.sources))
        self.assertEqual([], teacher.pending(f.root))

    def test_ignores_unaccepted_reports_and_archives_of_another_branch(self) -> None:
        f = WorkflowFixture(self.addCleanup)
        command = ["git", "-C", str(f.root)]
        subprocess.run([*command, "init", "-qb", "archive-source"], check=True)
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label", evidence="unaccepted quartz"))
        f.ledger.archive("cancelled", "Cancelled before acceptance")
        f.ledger.clean()
        self.assertEqual(([], []), search_cases(f.root, "quartz"))

        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label", evidence="accepted hematite"))
        f.start("verify-label")
        f.ledger.finish("verify-label", f.report("verify-label"))
        f.ledger.accept("accept-label")
        run = f.ledger.read()["run_id"]
        f.ledger.archive("completed", "Fixture verified")
        f.ledger.clean()
        self.assertEqual(1, len(search_cases(f.root, "hematite")[0]))
        subprocess.run([*command, "symbolic-ref", "HEAD", "refs/heads/other"], check=True)
        self.assertEqual(([], []), search_cases(f.root, "hematite"))

        subprocess.run([*command, "symbolic-ref", "HEAD", "refs/heads/archive-source"], check=True)
        with workflow_db.database(f.root) as db:
            db.execute(
                "UPDATE runs SET record=json_set(record,'$.state.summary','changed') WHERE run_id=?",
                (run,),
            )
        self.assertEqual(([], [run]), search_cases(f.root, "hematite"))
        with workflow_db.database(f.root) as db:
            db.execute("DELETE FROM runs WHERE run_id=?", (run,))
        self.assertEqual(([], []), search_cases(f.root, "hematite"))


class TeacherDispatchTests(unittest.TestCase):
    def test_launch_cli_tracks_default_variant_and_model_settings(self) -> None:
        import yaml

        f = WorkflowFixture(self.addCleanup)
        path = f.config_file(lambda _: None)
        bundle = f.root / ".factory"
        path.parent.rename(bundle)
        path = bundle / "factory.yaml"
        config = yaml.safe_load(path.read_text())
        command = [
            sys.executable,
            str(BIN / "lessons.py"),
            "--workspace",
            str(f.root),
            "teacher-launch",
        ]

        def launch() -> subprocess.CompletedProcess[str]:
            return subprocess.run(command, text=True, capture_output=True, check=False)

        initial = launch()
        self.assertEqual(0, initial.returncode, initial.stderr)
        route = json.loads(initial.stdout)
        self.assertEqual("teacher", route["profile_name"])
        self.assertEqual({"id": "gpt-6.2-sol", "effort": "medium"}, route["model"])
        self.assertEqual("roles/teacher.md", route["profile"]["role"])
        self.assertEqual("contracts/teacher.md", route["profile"]["contract"])
        self.assertEqual("native", route["adapter"]["runner"])

        group = config["profiles"]["teacher"]
        group["default"] = "alternate-teacher"
        group["variants"]["alternate-teacher"] = {"model": "alternate", "adapter": "claude"}
        config["models"]["alternate"] = {"id": "configured-model", "effort": "high"}
        path.write_text(yaml.safe_dump(config))
        changed = launch()
        self.assertEqual(0, changed.returncode, changed.stderr)
        route = json.loads(changed.stdout)
        self.assertEqual("alternate-teacher", route["profile_name"])
        self.assertEqual(config["models"]["alternate"], route["model"])
        self.assertEqual("claude", route["adapter"]["harness"])

        for incomplete in ({"id": "configured-model"}, {"id": None, "effort": "high"}):
            config["models"]["alternate"] = incomplete
            path.write_text(yaml.safe_dump(config))
            blocked = launch()
            self.assertNotEqual(0, blocked.returncode)
            self.assertIn("explicit model ID and effort", blocked.stderr)

        del config["profiles"]["teacher"]
        path.write_text(yaml.safe_dump(config))
        blocked = launch()
        self.assertNotEqual(0, blocked.returncode)
        self.assertIn("Configure profiles.teacher", blocked.stderr)
