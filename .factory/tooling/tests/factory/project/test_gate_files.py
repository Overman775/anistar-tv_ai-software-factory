"""External gates preserve policy composition, trust boundary and selective context."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from typing import Any

import yaml

from factory.project.profile_io import (
    check_frozen,
    fingerprint,
    load_profile,
    snapshot,
    validate_snapshot,
)
from factory.project.project import review_snapshot
from tests.factory.project.fixture_policy import policy


class GateFileTests(unittest.TestCase):
    def setUp(self) -> None:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.data: dict[str, Any] = dict(policy())
        self.gates = self.data.pop("gates")
        self.data["gate_files"] = ["gates/work.yaml"]
        (self.root / "gates").mkdir()
        self.file = self.root / "project.yaml"
        self.bundle = self.root / "gates/work.yaml"
        self.write()

    def write(self) -> None:
        self.file.write_text(yaml.safe_dump(self.data))
        self.bundle.write_text(yaml.safe_dump({"gates": self.gates}))

    def test_composition_one_read_relocation_and_unlisted_files(self) -> None:
        reads = []

        def read(p: Path) -> bytes:
            reads.append(p)
            return p.read_bytes()

        result = load_profile(self.file, read_bytes=read)
        self.assertEqual(policy(), result["data"])
        self.assertEqual(2, len(reads))
        self.assertEqual(2, len(set(reads)))
        (self.root / "gates/unused.yaml").write_text("invalid: [")
        self.assertEqual(result["hash"], load_profile(self.file)["hash"])
        shutil.copytree(self.root, self.root / "moved", ignore=shutil.ignore_patterns("moved"))
        self.assertEqual(result["hash"], load_profile(self.root / "moved/project.yaml")["hash"])

    def test_gate_files_fail_closed_and_no_recursive_import(self) -> None:
        for paths in [
            ["../outside.yaml"],
            ["/tmp/gate.yaml"],
            ["gates/*.yaml"],
            ["gates/missing.yaml"],
            ["gates/work.yaml", "gates/work.yaml"],
            "gates/work.yaml",
        ]:
            self.data["gate_files"] = paths
            self.write()
            with self.subTest(paths=paths), self.assertRaises(ValueError):
                load_profile(self.file)
        self.data["gate_files"] = ["gates/work.yaml"]
        self.write()
        for contents in [
            {"gate_files": ["gates/work.yaml"]},
            {"gates": []},
            {"gates": self.gates, "id": "override"},
        ]:
            self.bundle.write_text(yaml.safe_dump(contents))
            with self.subTest(contents=contents), self.assertRaises(ValueError):
                load_profile(self.file)
        self.write()
        self.bundle.unlink()
        self.bundle.symlink_to(self.file)
        with self.assertRaisesRegex(ValueError, "symlink"):
            load_profile(self.file)

    def test_duplicate_ids_across_files_and_mixed_modes_rejected(self) -> None:
        (self.root / "gates/second.yaml").write_text(yaml.safe_dump({"gates": self.gates}))
        self.data["gate_files"].append("gates/second.yaml")
        self.write()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            load_profile(self.file)
        other = deepcopy(self.gates)
        other[0]["id"] = "other"
        (self.root / "gates/second.yaml").write_text(yaml.safe_dump({"gates": other}))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            load_profile(self.file)
        self.data["gates"] = []
        self.write()
        with self.assertRaisesRegex(ValueError, "choose"):
            load_profile(self.file)

    def test_snapshot_reconstructs_gates_and_drift_blocks(self) -> None:
        loaded = load_profile(self.file)
        pinned = snapshot(loaded, source="accepted")
        self.gates[0]["checks"][0]["method"] = "weakened"
        self.write()
        with self.assertRaisesRegex(ValueError, "drift"):
            check_frozen(loaded["files"])
        self.assertEqual(policy(), validate_snapshot(pinned))
        self.assertNotEqual(loaded["hash"], load_profile(self.file)["hash"])
        # Rehashing a changed normalized object must not bypass the pinned bytes.
        pinned["profile"]["gates"] = []
        pinned["sha256"] = fingerprint({k: v for k, v in pinned.items() if k != "sha256"})
        with self.assertRaisesRegex(ValueError, "differs"):
            validate_snapshot(pinned)

    def test_git_snapshot_uses_baseline_even_if_candidate_deletes_gate(self) -> None:
        (self.root / "AGENTS.md").write_text("Accepted project instructions")

        def git(*args: str) -> str:
            return subprocess.run(
                ["git", "-C", str(self.root), *args], check=True, capture_output=True, text=True
            ).stdout.strip()

        git("init", "-q")
        git("add", ".")
        git(
            "-c",
            "user.name=Fixture",
            "-c",
            "user.email=fixture@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "commit",
            "-qm",
            "accepted",
        )
        revision = git("rev-parse", "HEAD")
        self.bundle.unlink()
        result = review_snapshot(self.root, revision, "project.yaml")
        self.assertEqual(policy(), validate_snapshot(result))
        self.assertIn("gates/work.yaml", result["files"])

    def test_gate_files_optional_but_declared_files_required_in_snapshot(self) -> None:
        self.data["gate_files"] = []
        self.write()
        self.assertEqual([], load_profile(self.file)["data"]["gates"])
        self.data["gate_files"] = ["gates/work.yaml"]
        self.write()
        pinned = snapshot(load_profile(self.file), source="accepted")
        del pinned["contents"]["gates/work.yaml"]
        del pinned["files"]["gates/work.yaml"]
        pinned["sha256"] = fingerprint({k: v for k, v in pinned.items() if k != "sha256"})
        with self.assertRaisesRegex(ValueError, "missing pinned gate"):
            validate_snapshot(pinned)
