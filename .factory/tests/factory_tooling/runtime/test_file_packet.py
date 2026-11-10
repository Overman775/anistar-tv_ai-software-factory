from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory_tooling.runtime.memory import read_evidence
from factory_tooling.runtime.run_archive import read_member
from factory_tooling.runtime.workflow_core import Invalid, atomic_json
from tests.factory_tooling.runtime import test_workflow


class FilePacketTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = test_workflow.WorkflowTests()
        self.f.setUp()
        self.addCleanup(self.f.doCleanups)
        self.f.init()
        self.f.ledger.claim("write-label")

    def prepare(self) -> dict[str, Any]:
        return self.f.ledger.prepare_packet("write-label")

    def meta(self, bootstrap: dict[str, Any]) -> dict[str, str]:
        return {
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

    def test_complete_unicode_chunks_and_reserved_then_bound(self) -> None:
        # A large project instruction exercises chunking at non-ASCII boundaries.
        (self.f.root / "AGENTS.md").write_text("Ж🙂" * 12000)
        b = self.prepare()
        self.assertEqual(b, self.prepare())
        diagnostics = self.f.ledger.prepare_packet("write-label", with_diagnostics=True)
        last = diagnostics["diagnostics"]["chunks"]
        self.assertGreater(last, 1)
        self.f.ledger.read_packet("write-label", self.meta(b), last)
        self.assertEqual(0, self.f.ledger.read()["nodes"]["write-label"]["packet_chunks_read"])
        parts = []
        ordinal = 1
        while ordinal is not None:
            result = self.f.ledger.read_packet("write-label", self.meta(b), ordinal)
            self.assertEqual(result["ordinal"], ordinal)
            self.assertLessEqual(len(result["content"].encode("utf-8")), 12000)
            parts.append(result["content"])
            ordinal = result["next"]
        raw = (self.f.root / b["path"]).read_text()
        self.assertEqual(raw, "".join(parts))
        self.assertEqual(len(parts), result["total"])
        self.assertEqual(json.loads(raw)["dispatch_id"], b["dispatch_id"])
        with self.assertRaisesRegex(Invalid, "Invalid packet chunk"):
            self.f.ledger.read_packet("write-label", self.meta(b), len(parts) + 1)
        # Read-only bootstrap succeeds while reserved, but completion cannot.
        with self.assertRaisesRegex(Invalid, "unbound"):
            self.f.ledger.finish("write-label", {})
        with self.assertRaisesRegex(Invalid, "bound running"):
            self.f.ledger.run_check("write-label", "irrelevant")
        state = self.f.ledger.read()
        profile = state["config"]["profiles"][state["nodes"]["write-label"]["profile"]]
        model = state["config"]["models"][profile["model"]]["id"] or "fixture-default"
        self.f.ledger.bind("write-label", "handle-author", model)
        self.assertEqual(b, self.prepare())
        self.f.ledger.read_packet("write-label", self.meta(b), 1)
        self.f.ledger.confirm_packet("write-label", self.meta(b))
        self.assertTrue(self.f.ledger.read()["nodes"]["write-label"]["packet_confirmed"])

    def test_rejects_bootstrap_digest_content_and_symlink_tampering(self) -> None:
        b = self.prepare()
        for key, value in (
            ("run_id", "foreign"),
            ("dispatch_id", "old"),
            ("source_hash", "wrong"),
            ("sha256", "wrong"),
            ("path", "../foreign"),
            ("revision", "9"),
        ):
            bad = self.meta(b)
            bad[key] = value
            with self.subTest(key=key), self.assertRaises(Invalid):
                self.f.ledger.read_packet("write-label", bad, 1)
        p = self.f.root / b["path"]
        original = p.read_bytes()
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
        b = self.prepare()
        module = "factory_tooling.runtime.workflow"
        argv = [
            sys.executable,
            "-m",
            module,
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
            "--chunk",
            "1",
        ]
        run = subprocess.run(argv, capture_output=True, text=True, check=True)
        chunk = json.loads(run.stdout)["result"]
        self.assertEqual(chunk["ordinal"], 1)
        self.assertEqual(chunk["binding"], "reserved")
        self.assertFalse(chunk["ready_for_work"])
        self.assertTrue(chunk["content"].startswith("{"))
        self.assertIn("read-packet", b["read_command"])

    def test_mandatory_workspace_instruction_drift_blocks_read_and_reprepare(self) -> None:
        b = self.prepare()
        (self.f.root / "AGENTS.md").write_text("Changed instructions")
        with self.assertRaisesRegex(Invalid, "instruction drift"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)
        with self.assertRaisesRegex(Invalid, "instruction drift"):
            self.prepare()

    def test_windows_bootstrap_uses_powershell_and_native_launcher(self) -> None:
        b = self.prepare()
        state = self.f.ledger.read()
        node = next(n for n in state["graph"]["nodes"] if n["id"] == "write-label")
        with patch("factory_tooling.runtime.workflow.platform.system", return_value="Windows"):
            result = self.f.ledger._packet_bootstrap(state, node, self.meta(b))
        self.assertEqual(result["read_shell"], "PowerShell")
        self.assertIn(".factory\\.venv\\Scripts\\python.exe", result["read_command"])
        self.assertIn("python_runtime.py", result["read_command"])
        self.assertTrue(result["read_command"].startswith("& "))

    def test_external_source_drift_blocks_read(self) -> None:
        f = test_workflow.WorkflowTests()
        f.setUp()
        self.addCleanup(f.doCleanups)
        f.g["sources"]["request"] = f.external_source()
        f.init()
        f.ledger.claim("write-label")
        b = f.ledger.prepare_packet("write-label")
        (f.root / "external.md").write_text("Changed after approval")
        with self.assertRaisesRegex(Invalid, "SOURCE_DRIFT"):
            f.ledger.read_packet("write-label", self.meta(b), 1)

    def test_rejects_conflicting_ledger_role_and_workspace(self) -> None:
        b = self.prepare()
        original = self.f.ledger.read()
        state = self.f.ledger.read()
        state["nodes"]["write-label"]["role"] = "judge"
        atomic_json(self.f.ledger.path, state)
        with self.assertRaisesRegex(Invalid, "profile mismatch"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)
        state = original
        state["workspace"] = str(self.f.root / "foreign")
        atomic_json(self.f.ledger.path, state)
        with self.assertRaisesRegex(Invalid, "workspace mismatch"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)

    def test_unregistered_preexisting_file_is_never_overwritten(self) -> None:
        s = self.f.ledger.read()
        rel = f"{s['run_id']}-write-label-{s['nodes']['write-label']['dispatch_id']}.packet.json"
        p = self.f.ledger.dir / rel
        p.write_text("foreign")
        with self.assertRaisesRegex(Invalid, "already exists"):
            self.prepare()
        self.assertEqual("foreign", p.read_text())

    def test_config_and_source_drift_reject_reads(self) -> None:
        b = self.prepare()
        # Avoid mutating the actual shared fixture: use a local profile file.
        config_file = self.f.fixture_profile
        original = config_file.read_text()
        config_file.write_text(original + "# drift\n")
        with self.assertRaisesRegex(Invalid, "drift"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)
        config_file.write_text(original)
        self.f.ledger.read_packet("write-label", self.meta(b), 1)

    def test_cleanup_removes_only_owned_packet_after_saved_history(self) -> None:
        b = self.prepare()
        state = self.f.ledger.read()
        profile = state["config"]["profiles"][state["nodes"]["write-label"]["profile"]]
        model = state["config"]["models"][profile["model"]]["id"] or "fixture-default"
        self.f.ledger.bind("write-label", "handle-author", model)
        with self.assertRaisesRegex(Invalid, "Confirm native packet"):
            self.f.ledger.finish("write-label", self.f.report("write-label"))
        ordinal: int | None = 1
        while ordinal is not None:
            ordinal = self.f.ledger.read_packet("write-label", self.meta(b), ordinal)["next"]
        self.f.ledger.confirm_packet("write-label", self.meta(b))
        self.f.ledger.finish("write-label", self.f.report("write-label"))
        self.f.start("verify-label")
        self.f.ledger.finish("verify-label", self.f.report("verify-label"))
        self.f.ledger.accept("accept-label")
        foreign = self.f.ledger.dir / "foreign.packet.json"
        foreign.write_text("preserve")
        history = Path(self.f.ledger.archive("completed", "done"))
        self.assertRegex(history.name, rf"^\d{{4}}-\d{{2}}-\d{{2}}_{b['run_id']}\.tar\.gz$")
        self.assertEqual(history.parent.name, "archive")
        self.assertEqual(
            json.loads(read_member(history, "run.json"))["nodes"]["write-label"]["packet_file"],
            self.meta(b),
        )
        self.f.ledger.clean()
        self.assertFalse((self.f.root / b["path"]).exists())
        self.assertEqual(foreign.read_text(), "preserve")

    def test_old_dispatch_cannot_read_after_retry(self) -> None:
        b = self.prepare()
        state = self.f.ledger.read()
        profile = state["config"]["profiles"][state["nodes"]["write-label"]["profile"]]
        model = state["config"]["models"][profile["model"]]["id"] or "fixture-default"
        self.f.ledger.bind("write-label", "handle-author", model)
        self.f.ledger.finish("write-label", self.f.report("write-label", "FAIL"))
        self.f.ledger.retry("write-label", "tests", "fix", "terminal")
        self.f.ledger.claim("write-label")
        new = self.prepare()
        self.assertNotEqual(new["dispatch_id"], b["dispatch_id"])
        with self.assertRaisesRegex(Invalid, "bootstrap mismatch"):
            self.f.ledger.read_packet("write-label", self.meta(b), 1)


class PacketCleanupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.f = test_workflow.WorkflowTests()
        self.f.setUp()
        self.addCleanup(self.f.doCleanups)
        self.f.init()
        self.f.ledger.claim("write-label")
        self.first = self.f.ledger.prepare_packet("write-label")

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
        self.f.ledger.claim("write-label")
        second = self.f.ledger.prepare_packet("write-label")
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
            self.assertTrue(self.f.ledger.path.is_file())

    def test_blocked_active_run_keeps_packet(self) -> None:
        self.blocked()
        with self.assertRaisesRegex(Invalid, "resumable"):
            self.f.ledger.clean()
        self.assertTrue((self.f.root / self.first["path"]).is_file())

    def test_missing_or_mismatched_terminal_history_keeps_all_packets(self) -> None:
        second, history = self.archived_with_retry()
        hist = self.f.root / history
        original = hist.read_bytes()
        hist.unlink()
        with self.assertRaisesRegex(Invalid, "History"):
            self.f.ledger.clean()
        hist.write_text('{"status": "different"}')
        with self.assertRaisesRegex(Invalid, "Cannot verify archive"):
            self.f.ledger.clean()
        hist.write_bytes(original[:-4])
        with self.assertRaisesRegex(Invalid, "Cannot verify archive"):
            self.f.ledger.clean()
        self.assertTrue(self.f.ledger.path.is_file())
        for b in (self.first, second):
            self.assertTrue((self.f.root / b["path"]).is_file())
        hist.write_bytes(original)
        self.f.ledger.clean()
        self.assertTrue(hist.is_file())

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
        self.assertFalse(self.f.ledger.path.exists())
        self.assertEqual(unregistered.read_text(), "foreign")
        self.assertTrue((self.f.root / history).is_file())

    def test_legacy_terminal_migrates_packets_and_log_before_cleanup(self) -> None:
        self.blocked()
        state = self.f.ledger.read()
        state["status"] = "cancelled"
        state["summary"] = "legacy terminal"
        run_id = state["run_id"]
        legacy = self.f.root / ".factory/memory/history" / run_id / "run.json"
        atomic_json(legacy, state)
        atomic_json(self.f.ledger.path, state)
        log = legacy.parent / "checks" / "legacy.log"
        log.parent.mkdir()
        log.write_text("legacy output")
        packet = self.f.root / self.first["path"]
        before = packet.read_bytes()
        with self.assertRaisesRegex(Invalid, "Archive legacy terminal"):
            self.f.ledger.clean()
        self.assertTrue(packet.exists())
        archive = Path(self.f.ledger.archive("cancelled", "legacy terminal"))
        self.assertEqual(archive, Path(self.f.ledger.archive("cancelled", "legacy terminal")))
        self.f.ledger.clean()
        self.assertFalse(packet.exists())
        self.assertFalse(log.exists())
        self.assertEqual(before, read_evidence(self.f.root, self.first["path"], run_id=run_id))
        self.assertEqual(
            b"legacy output",
            read_evidence(self.f.root, log.relative_to(self.f.root).as_posix(), run_id=run_id),
        )

    def test_foreign_registered_path_rejected_before_any_deletion(self) -> None:
        second, _history = self.archived_with_retry()
        foreign = self.f.ledger.dir / "foreign.packet.json"
        foreign.write_text("preserve")
        state = self.f.ledger.read()
        state["transport_artifacts"].append(str(foreign.relative_to(self.f.ledger.root)))
        atomic_json(self.f.ledger.path, state)
        with self.assertRaisesRegex(Invalid, "ownership"):
            self.f.ledger.clean()
        for b in (self.first, second):
            self.assertTrue((self.f.root / b["path"]).is_file())
        self.assertTrue(self.f.ledger.path.is_file())
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
        self.assertTrue(self.f.ledger.path.is_file())
        self.assertEqual(target.read_text(), "preserve")
