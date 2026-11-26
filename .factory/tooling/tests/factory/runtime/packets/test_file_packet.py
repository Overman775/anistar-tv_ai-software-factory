from __future__ import annotations

import json
import shlex
import subprocess
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import Mock, patch

from factory.database.port import DatabaseBackend
from factory.database.provider import current_database, use_database
from factory.database.sqlite import sqlite_history_repository, workflow_db
from factory.diagnostics.query import read_journal
from factory.logging_config import diagnostic_operation
from factory.runtime.contracts import PacketRef
from factory.runtime.history.task_records import read_evidence
from factory.runtime.packets.content import (
    PACKET_CONTENT_LIMIT,
    PACKET_REFERENCE,
    PACKET_RESPONSE_LIMIT,
    delivery_state,
    packet_chunks,
    packet_confirmed,
    packet_response,
)
from factory.runtime.packets.delivery import PacketDelivery
from factory.runtime.workflow import Ledger
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from tests import CLI
from tests.factory.runtime import workflow_fixture
from tests.factory.runtime.store_fixture import has_current, overwrite, record_bytes


class FilePacketTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = workflow_fixture.WorkflowFixture(self.addCleanup)
        self.f.init()
        self.f.claim("write-label")

    def prepare(self) -> dict[str, Any]:
        return self.f.ledger.prepare_packet("write-label")

    def bind(self, f: workflow_fixture.WorkflowFixture | None = None) -> None:
        f = f or self.f
        config = f.ledger.read()["config"]
        profile = f.ledger.read()["nodes"]["write-label"]["profile"]
        model = config["models"][config["profiles"][profile]["model"]]["id"] or "fixture-default"
        f.ledger.bind("write-label", "handle-author", model)

    def meta(self, bootstrap: dict[str, Any]) -> PacketRef:
        return PACKET_REFERENCE.validate_python(
            {
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
        )

    def test_packet_checks_dependency_report_in_ledger_history(self) -> None:
        self.bind()
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        self.f.start("verify-label")
        other = Mock(spec_set=DatabaseBackend)
        other.history.stored_evidence.side_effect = AssertionError("read from another backend")
        with use_database(other):
            prepared = self.f.ledger.prepare_packet("verify-label", with_diagnostics=True)
            bootstrap = self.f.ledger.prepare_packet("verify-label")
            self.assertEqual(prepared["bootstrap"], bootstrap)
            chunk = self.f.ledger.read_packet("verify-label", self.meta(bootstrap), 1)
        self.assertEqual(chunk["ordinal"], 1)
        other.history.stored_evidence.assert_not_called()

    def test_complete_unicode_chunks_and_reserved_then_bound(self) -> None:
        # A large project instruction exercises chunking at non-ASCII boundaries.
        f = workflow_fixture.WorkflowFixture(self.addCleanup)
        (f.root / "AGENTS.md").write_text(('Ж🙂"\\' + "\n") * 8000)
        f.init()
        f.claim("write-label")
        self.f = f
        b = self.prepare()
        self.assertEqual(b, self.prepare())
        diagnostics = self.f.ledger.prepare_packet("write-label", with_diagnostics=True)
        last = diagnostics["diagnostics"]["chunks"]
        self.assertGreater(last, 1)
        with self.assertRaisesRegex(Invalid, "Bind actual recipient"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)
        with self.assertRaisesRegex(Invalid, "unbound"):
            self.f.ledger.finish("write-label", self.f.report("write-label"))
        with self.assertRaisesRegex(Invalid, "bound running"):
            self.f.ledger.run_check("write-label", "irrelevant")
        self.bind()
        bound = self.prepare()
        self.assertEqual(self.meta(b), self.meta(bound))
        self.assertEqual("handle-author", bound["recipient"])
        with self.assertRaisesRegex(Invalid, "recipient mismatch"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1, recipient="different")
        with self.assertRaisesRegex(Invalid, "preceding chunk"):
            self.f.ledger.read_packet("write-label", self.meta(b), last)
        self.assertEqual(
            {"served": 0, "acknowledged": 0}, delivery_state(self.f.root, self.meta(b), last)
        )
        first = self.f.ledger.read_packet("write-label", self.meta(b), 1)
        self.assertEqual(first, self.f.ledger.read_packet("write-label", self.meta(b), 1))
        parts = []
        ordinal = 1
        ack = None
        while ordinal is not None:
            result = self.f.ledger.read_packet("write-label", self.meta(b), ordinal, ack)
            ack = result["acknowledgement"]
            self.assertEqual(result["ordinal"], ordinal)
            self.assertLessEqual(len(result["content"].encode("utf-8")), PACKET_CONTENT_LIMIT)
            self.assertLessEqual(len(packet_response(result)), PACKET_RESPONSE_LIMIT)
            parts.append(result["content"])
            ordinal = result["next"]
        raw = read_evidence(self.f.root, b["path"], run_id=b["run_id"]).decode()
        self.assertEqual(raw, "".join(parts))
        self.assertEqual(len(parts), result["total"])
        self.assertIn(
            "- dispatch_id = " + b["dispatch_id"], raw.decode() if isinstance(raw, bytes) else raw
        )
        with self.assertRaisesRegex(Invalid, "Invalid packet chunk"):
            self.f.ledger.read_packet("write-label", self.meta(b), len(parts) + 1)
        self.f.ledger.confirm_packet(
            "write-label", self.meta(b), result["acknowledgement"], result["materials"]
        )
        self.assertTrue(packet_confirmed(self.f.ledger.read()["nodes"]["write-label"]))

    def test_lost_output_and_lost_receipt_replay_without_ledger_writes(self) -> None:
        b = self.prepare()
        self.bind()
        meta = self.meta(b)
        saved = record_bytes(self.f.ledger)
        first = self.f.ledger.read_packet("write-label", meta, 1)
        self.assertEqual(
            {"served": 1, "acknowledged": 0}, delivery_state(self.f.root, meta, first["total"])
        )
        restarted = Ledger(self.f.root)
        self.assertEqual(first, restarted.read_packet("write-label", meta, 1))
        self.assertEqual(saved, record_bytes(self.f.ledger))
        with workflow_db.database(self.f.root) as db:
            db.execute(
                "DELETE FROM packet_deliveries WHERE artifact_id=(SELECT artifact_id FROM artifacts WHERE run_id=? AND path=?)",
                (meta["run_id"], meta["path"]),
            )
        with self.assertRaisesRegex(Invalid, "restart at chunk 1"):
            restarted.read_packet("write-label", meta, 2, first["acknowledgement"])
        self.assertEqual(first, restarted.read_packet("write-label", meta, 1))

    def test_legacy_ack_and_receipt_cannot_advance_delivery(self) -> None:
        meta = self.meta(self.prepare())
        self.bind()
        first = self.f.ledger.read_packet("write-label", meta, 1)
        with workflow_db.database(self.f.root) as db:
            db.execute("DELETE FROM packet_deliveries")
        state: dict[str, Any] = dict(self.f.ledger.read())
        state["nodes"]["write-label"]["packet_confirmed"] = True
        overwrite(self.f.ledger, state)
        with self.assertRaisesRegex(Invalid, "Invalid persisted state"):
            self.f.ledger.next_actions()
        del state["nodes"]["write-label"]["packet_confirmed"]
        state["nodes"]["write-label"]["confirmed_packet_sha256"] = "0" * 64
        overwrite(self.f.ledger, state)
        self.assertEqual(
            ["write-label"], self.f.ledger.next_actions()["pending_packet_confirmations"]
        )
        obsolete = first["acknowledgement"].replace("chunk:", "v2:")
        with self.assertRaisesRegex(Invalid, "preceding chunk"):
            self.f.ledger.read_packet("write-label", meta, 2, obsolete)
        with self.assertRaisesRegex(Invalid, "restart at chunk 1"):
            self.f.ledger.read_packet("write-label", meta, 2, first["acknowledgement"])
        self.assertEqual(first, self.f.ledger.read_packet("write-label", meta, 1))

    def test_relational_receipt_identity_counters_and_ownership(self) -> None:
        meta = self.meta(self.prepare())
        self.bind()
        self.f.ledger.read_packet("write-label", meta, 1)
        with self.assertRaisesRegex(Invalid, "Invalid packet delivery receipt"):
            delivery_state(self.f.root, {**meta, "source_hash": "other"}, 2, "handle-author")
        orphan: PacketRef = {**meta, "path": meta["path"] + "missing"}
        with self.assertRaisesRegex(Invalid, "Invalid packet delivery receipt"):
            current_database().packets.save_receipt(
                self.f.root, orphan, "handle-author", PacketDelivery(1, 0)
            )
        with self.assertRaisesRegex(Invalid, "CHECK constraint"):
            with workflow_db.database(self.f.root) as db:
                db.execute("UPDATE packet_deliveries SET acknowledged=served+1")
        with workflow_db.database(self.f.root) as db:
            db.execute(
                "DELETE FROM artifacts WHERE run_id=? AND path=?", (meta["run_id"], meta["path"])
            )
            self.assertEqual([], db.execute("SELECT * FROM packet_deliveries").fetchall())
            self.assertEqual([], db.execute("PRAGMA foreign_key_check").fetchall())

    def test_interrupted_confirmation_retries_exact_delivery(self) -> None:
        meta = self.meta(self.prepare())
        self.bind()
        first = self.f.ledger.read_packet("write-label", meta, 1)
        chunk = first
        while chunk["next"] is not None:
            chunk = self.f.ledger.read_packet(
                "write-label", meta, chunk["next"], chunk["acknowledgement"]
            )
        with patch.object(self.f.ledger, "save", side_effect=OSError("interrupt")):
            with self.assertRaises(OSError):
                self.f.ledger.confirm_packet(
                    "write-label", meta, chunk["acknowledgement"], chunk["materials"]
                )
        self.assertFalse(packet_confirmed(self.f.ledger.read()["nodes"]["write-label"]))
        with diagnostic_operation(self.f.root, "confirm-packet"):
            for _ in range(2):
                self.f.ledger.confirm_packet(
                    "write-label", meta, chunk["acknowledgement"], chunk["materials"]
                )
        records = read_journal(self.f.root, "dispatch_id", meta["dispatch_id"], 0, 30)["records"]
        self.assertEqual([record["event"] for record in records], ["packet_confirmed"])
        self.assertTrue(packet_confirmed(self.f.ledger.read()["nodes"]["write-label"]))

    def test_rejects_bootstrap_digest_content_and_symlink_tampering(self) -> None:
        self.bind()
        b = self.prepare()
        for key, value in (
            ("run_id", "foreign"),
            ("dispatch_id", "old"),
            ("source_hash", "wrong"),
            ("sha256", "wrong"),
            ("path", "../foreign"),
            ("revision", "9"),
        ):
            bad = dict(self.meta(b))
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(Invalid):
                self.f.ledger.read_packet("write-label", bad, 1)
        p = self.f.root / b["path"]
        original = read_evidence(self.f.root, b["path"], run_id=b["run_id"])
        p.write_bytes(original + b" ")
        with self.assertRaisesRegex(Invalid, "digest"):
            self.prepare()
        p.unlink()
        foreign = self.f.root / "foreign.json"
        foreign.write_bytes(original)
        p.symlink_to(foreign)
        with self.assertRaisesRegex(Invalid, "Symlink"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)

    def test_cli_returns_complete_first_chunk_and_bound_status(self) -> None:
        self.bind()
        b = self.prepare()
        argv = [
            *CLI,
            "workflow",
            "--workspace",
            str(self.f.root),
            "read-packet",
            b["node_id"],
            b["path"],
            b["sha256"],
            b["run_id"],
            b["dispatch_id"],
            b["source_hash"],
            b["revision"],
            "--recipient",
            b["recipient"],
            "--chunk",
            "1",
        ]
        run = subprocess.run(argv, capture_output=True, check=True)
        chunk = json.loads(run.stdout)["result"]
        self.assertEqual(chunk["ordinal"], 1)
        self.assertEqual(chunk["binding"], "running")
        self.assertFalse(chunk["ready_for_work"])
        data = read_evidence(self.f.root, b["path"], run_id=b["run_id"])
        self.assertEqual(chunk["content"], packet_chunks(data)[0])
        read_command = (
            shlex.split(b["read_command"])
            if b["read_shell"] == "POSIX shell"
            else [*argv, "--json"]
        )
        replay = subprocess.run(read_command, capture_output=True, check=True)
        self.assertEqual(run.stdout, replay.stdout)
        self.assertEqual(
            read_journal(self.f.root, "operation", "read-packet", 0, 30)["records"], []
        )
        argv[-1] = "2"
        denied = subprocess.run(
            argv + ["--ack", "private-token", "--json"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(denied.returncode, 1)
        response = json.loads(denied.stdout)
        self.assertFalse(response["ok"])
        self.assertEqual(response["error"]["code"], "packet_ack_mismatch")
        (error,) = read_journal(self.f.root, "operation", "read-packet", 0, 30)["records"]
        self.assertEqual(
            (error["error_code"], error["dispatch_id"]), ("packet_ack_mismatch", b["dispatch_id"])
        )
        self.assertNotIn("private-token", json.dumps(error))
        self.assertEqual(
            delivery_state(self.f.root, self.meta(b), chunk["total"]),
            {"served": 1, "acknowledged": 0},
        )
        self.assertIn("read-packet", b["read_command"])
        self.assertIn("--json", b["read_command"])
        self.assertIn("--json", b["confirm_command"])

    def test_workspace_instruction_edit_preserves_read_and_reprepare(self) -> None:
        self.bind()
        b = self.prepare()
        (self.f.root / "AGENTS.md").write_text("Changed instructions")
        chunk = self.f.ledger.read_packet("write-label", self.meta(b), 1)
        self.assertNotIn("Changed instructions", chunk["content"])
        self.assertEqual(b, self.prepare())

    def test_windows_bootstrap_uses_powershell_and_native_launcher(self) -> None:
        with patch("factory.runtime.agent_commands.platform.system", return_value="Windows"):
            result = self.prepare()
        self.assertEqual(result["read_shell"], "PowerShell")
        self.assertIn(".factory\\tooling\\bin\\cli.cmd", result["read_command"])
        self.assertIn("'workflow'", result["read_command"])
        self.assertIn("'--json' 'read-packet'", result["read_command"])
        self.assertTrue(result["read_command"].startswith("& "))

    def test_external_source_edit_preserves_packet(self) -> None:
        f = workflow_fixture.WorkflowFixture(self.addCleanup)
        f.g["sources"]["request"] = f.external_source()
        f.init()
        f.claim("write-label")
        self.bind(f)
        b = f.ledger.prepare_packet("write-label")
        (f.root / "external.md").write_text("Changed after approval")
        chunk = f.ledger.read_packet("write-label", self.meta(b), 1)
        self.assertNotIn("Changed after approval", chunk["content"])

    def test_rejects_conflicting_ledger_role_and_workspace(self) -> None:
        self.bind()
        b = self.prepare()
        original = self.f.ledger.read()
        state = self.f.ledger.read()
        state["nodes"]["write-label"]["role"] = "judge"
        overwrite(self.f.ledger, state)
        with self.assertRaisesRegex(Invalid, "profile mismatch"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)
        state = original
        state["workspace"] = str(self.f.root / "foreign")
        overwrite(self.f.ledger, state)
        with self.assertRaisesRegex(Invalid, "workspace mismatch"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)

    def test_unregistered_preexisting_file_is_never_overwritten(self) -> None:
        s = self.f.ledger.read()
        rel = f"{s['run_id']}-write-label-{s['nodes']['write-label']['dispatch_id']}.packet.md"
        p = self.f.ledger.dir / rel
        p.write_text("foreign")
        with self.assertRaisesRegex(Invalid, "already exists"):
            self.prepare()
        self.assertEqual("foreign", p.read_text())

    def test_executable_config_drift_rejects_read(self) -> None:
        f = workflow_fixture.WorkflowFixture(self.addCleanup)
        config_file = f.config_file(lambda config: None)
        f.config = load_config(config_file)
        f.init()
        f.claim("write-label")
        self.bind(f)
        b = f.ledger.prepare_packet("write-label")
        original = config_file.read_text()
        config_file.write_text(original + "# drift\n")
        with self.assertRaisesRegex(Invalid, "drift"):
            f.ledger.read_packet("write-label", self.meta(b), 1)
        config_file.write_text(original)
        f.ledger.read_packet("write-label", self.meta(b), 1)

    def test_cleanup_removes_only_owned_packet_after_saved_history(self) -> None:
        b = self.prepare()
        state = self.f.ledger.read()
        profile = state["config"]["profiles"][state["nodes"]["write-label"]["profile"]]
        model = state["config"]["models"][profile["model"]]["id"] or "fixture-default"
        self.f.ledger.bind("write-label", "handle-author", model)
        with self.assertRaisesRegex(Invalid, "Confirm native packet"):
            self.f.ledger.finish("write-label", self.f.report("write-label"))
        chunk = self.f.ledger.read_packet("write-label", self.meta(b), 1)
        while chunk["next"] is not None:
            chunk = self.f.ledger.read_packet(
                "write-label", self.meta(b), chunk["next"], chunk["acknowledgement"]
            )
        self.f.ledger.confirm_packet(
            "write-label", self.meta(b), chunk["acknowledgement"], chunk["materials"]
        )
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        self.f.start("verify-label")
        self.f.ledger.finish("verify-label", self.f.report("verify-label"))
        self.f.ledger.accept("accept-label")
        foreign = self.f.ledger.dir / "foreign.packet.json"
        foreign.write_text("preserve")
        history = Path(self.f.ledger.archive("completed", "done"))
        self.assertEqual(self.f.root.resolve() / sqlite_history_repository.DATABASE, history)
        self.assertEqual(
            sqlite_history_repository.inventory(self.f.root, b["run_id"]).state["nodes"][
                "write-label"
            ]["packet_file"],
            self.meta(b),
        )
        self.f.ledger.clean()
        self.assertFalse((self.f.root / b["path"]).exists())
        self.assertEqual(
            chunk["total"],
            delivery_state(self.f.root, self.meta(b), chunk["total"], "handle-author")[
                "acknowledged"
            ],
        )
        self.assertEqual(foreign.read_text(), "preserve")

    def test_old_dispatch_cannot_read_after_retry(self) -> None:
        b = self.prepare()
        state = self.f.ledger.read()
        profile = state["config"]["profiles"][state["nodes"]["write-label"]["profile"]]
        model = state["config"]["models"][profile["model"]]["id"] or "fixture-default"
        self.f.ledger.bind("write-label", "handle-author", model)
        self.f.ledger.finish("write-label", self.f.report("write-label", "FAIL"))
        self.f.ledger.retry("write-label", "tests", "fix", "terminal")
        self.f.claim("write-label")
        new = self.prepare()
        self.bind()
        self.assertNotEqual(new["dispatch_id"], b["dispatch_id"])
        with self.assertRaisesRegex(Invalid, "bootstrap mismatch"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)


class PacketCleanupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = workflow_fixture.WorkflowFixture(self.addCleanup)
        self.f.init()
        self.f.claim("write-label")
        self.first = self.transport_copy()

    def transport_copy(self) -> dict[str, Any]:
        packet = self.f.ledger.prepare_packet("write-label")
        data = read_evidence(self.f.root, packet["path"], run_id=packet["run_id"])
        (self.f.root / packet["path"]).write_bytes(data)
        return packet

    def bind(self) -> None:
        s = self.f.ledger.read()
        p = s["config"]["profiles"][s["nodes"]["write-label"]["profile"]]
        model = s["config"]["models"][p["model"]]["id"] or "fixture-default"
        self.f.ledger.bind("write-label", "handle-author", model)

    def blocked(self) -> None:
        self.bind()
        self.f.ledger.finish("write-label", self.f.report("write-label", "FAIL"))

    def archived_with_retry(self) -> tuple[dict[str, Any], str]:
        self.blocked()
        self.f.ledger.retry("write-label", "tests", "fix", "terminal")
        self.f.claim("write-label")
        second = self.transport_copy()
        self.blocked()
        history = self.f.ledger.archive("cancelled", "explicit cancellation")
        return second, history

    def test_active_reserved_running_and_unknown_runs_keep_packet(self) -> None:
        for status in ("reserved", "running", "unknown"):
            if status == "running":
                self.bind()
            elif status == "unknown":
                self.f.ledger.unknown("write-label", "unresolved transport")
            with self.subTest(status=status), self.assertRaisesRegex(Invalid, "resumable"):
                self.f.ledger.clean()
            self.assertTrue((self.f.root / self.first["path"]).is_file())
            self.assertTrue(has_current(self.f.ledger))

    def test_blocked_active_run_keeps_packet(self) -> None:
        self.blocked()
        with self.assertRaisesRegex(Invalid, "resumable"):
            self.f.ledger.clean()
        self.assertTrue((self.f.root / self.first["path"]).is_file())

    def test_missing_or_mismatched_terminal_history_keeps_all_packets(self) -> None:
        second, history = self.archived_with_retry()
        run = second["run_id"]
        with workflow_db.database(self.f.root) as db:
            original = db.execute("SELECT sha256 FROM runs WHERE run_id=?", (run,)).fetchone()[0]
            db.execute("UPDATE runs SET sha256='wrong' WHERE run_id=?", (run,))
        with self.assertRaisesRegex(Invalid, "journal digest mismatch"):
            self.f.ledger.clean()
        self.assertTrue(has_current(self.f.ledger))
        for b in (self.first, second):
            self.assertTrue((self.f.root / b["path"]).is_file())
        with workflow_db.database(self.f.root) as db:
            db.execute("UPDATE runs SET sha256=? WHERE run_id=?", (original, run))
        self.f.ledger.clean()
        self.assertTrue(Path(history).is_file())

    def test_all_current_and_retired_owned_packets_removed_foreign_preserved(self) -> None:
        second, history = self.archived_with_retry()
        unregistered = self.f.ledger.dir / f"{self.first['run_id']}-foreign.packet.json"
        unregistered.write_text("foreign")
        self.assertNotEqual(self.first["dispatch_id"], second["dispatch_id"])
        bodies = [(self.f.root / b["path"]).read_bytes() for b in (self.first, second)]
        self.f.ledger.clean()
        for b, body in zip((self.first, second), bodies, strict=True):
            self.assertFalse((self.f.root / b["path"]).exists())
            self.assertEqual(read_evidence(self.f.root, b["path"], run_id=b["run_id"]), body)
        self.assertFalse(has_current(self.f.ledger))
        self.assertEqual(unregistered.read_text(), "foreign")
        self.assertTrue((self.f.root / history).is_file())

    def test_foreign_registered_path_rejected_before_any_deletion(self) -> None:
        second, _history = self.archived_with_retry()
        foreign = self.f.ledger.dir / "foreign.packet.json"
        foreign.write_text("preserve")
        run = second["run_id"]
        from factory.database.sqlite import graph_state

        state = self.f.ledger.read()
        state["transport_artifacts"].append(str(foreign.relative_to(self.f.ledger.root)))
        with workflow_db.database(self.f.root) as db:
            graph_state.write(db, state)
            db.execute("UPDATE runs SET sha256=? WHERE run_id=?", (graph_state.seal(db, run), run))
        with self.assertRaisesRegex(Invalid, "ownership"):
            self.f.ledger.clean()
        for b in (self.first, second):
            self.assertTrue((self.f.root / b["path"]).is_file())
        self.assertTrue(has_current(self.f.ledger))
        self.assertEqual(foreign.read_text(), "preserve")

    def test_symlink_rejection_preflights_all_before_deleting_any(self) -> None:
        second, _history = self.archived_with_retry()
        target = self.f.root / "foreign.txt"
        target.write_text("preserve")
        second_path = self.f.root / second["path"]
        second_path.unlink()
        second_path.symlink_to(target)
        with self.assertRaisesRegex(Invalid, "Symlink"):
            self.f.ledger.clean()
        self.assertTrue((self.f.root / self.first["path"]).is_file())
        self.assertTrue(second_path.is_symlink())
        self.assertTrue(has_current(self.f.ledger))
        self.assertEqual(target.read_text(), "preserve")
