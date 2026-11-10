"""Decision definitions remain pinned policy, independent of answer providers."""

from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any

import yaml

from factory_tooling.project.profile_io import (
    check_frozen,
    fingerprint,
    load_profile,
    snapshot,
    validate_snapshot,
)
from factory_tooling.project.profile_rules import required_checks
from factory_tooling.project.project import review_snapshot
from tests.factory_tooling.project.test_gates import policy


class DecisionFileTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.data: dict[str, Any] = dict(policy())
        self.data["gates"][0]["checks"][0]["decision"] = "needs-static"
        self.definitions: list[dict[str, Any]] = [
            {"id": "needs-static", "question": "Are static checks required?"}
        ]
        self.data["decision_files"] = ["decisions/verification.yaml"]
        self.file = self.root / "project.yaml"
        self.bundle = self.root / "decisions/verification.yaml"
        self.bundle.parent.mkdir()
        self.write()

    def write(self) -> None:
        self.file.write_text(yaml.safe_dump(self.data))
        self.bundle.write_text(yaml.safe_dump({"decisions": self.definitions}))

    def test_loaded_decisions_drive_checks_and_unknown_does_not_skip(self) -> None:
        reads = []

        def read(path: Path) -> bytes:
            reads.append(path)
            return path.read_bytes()

        loaded = load_profile(self.file, read_bytes=read)
        self.assertEqual(2, len(reads))
        task: dict[str, Any] = {"scope": ["src/main.py"]}
        with self.assertRaisesRegex(ValueError, "UNKNOWN"):
            required_checks(loaded["data"], task)
        for answer, expected in [(True, 1), (False, 0)]:
            task["policy_decisions"] = {
                "needs-static": {
                    "probability": 0.9 if answer else 0.1,
                    "source": "agent:fixture",
                    "reason": "Scope evidence",
                }
            }
            self.assertEqual(expected, len(required_checks(loaded["data"], task)))
        task["policy_decisions"]["needs-static"]["probability"] = 0.5
        with self.assertRaisesRegex(ValueError, "UNKNOWN"):
            required_checks(loaded["data"], task)

    def test_combined_files_validate_ids_references_and_modes(self) -> None:
        second = self.root / "decisions/second.yaml"
        second.write_text(yaml.safe_dump({"decisions": self.definitions}))
        self.data["decision_files"].append("decisions/second.yaml")
        self.write()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            load_profile(self.file)
        self.data["decision_files"] = ["decisions/verification.yaml"]
        self.data["decisions"] = []
        self.write()
        with self.assertRaisesRegex(ValueError, "choose"):
            load_profile(self.file)
        del self.data["decisions"]
        self.data["decision_files"] = []
        self.write()
        with self.assertRaisesRegex(ValueError, "unknown check decision"):
            load_profile(self.file)

    def test_paths_and_bundle_schema_fail_closed(self) -> None:
        for paths in [
            ["../outside.yaml"],
            ["decisions/*.yaml"],
            ["missing.yaml"],
            ["decisions/verification.yaml"] * 2,
        ]:
            self.data["decision_files"] = paths
            self.write()
            with self.subTest(paths=paths), self.assertRaises(ValueError):
                load_profile(self.file)
        self.data["decision_files"] = ["decisions/verification.yaml"]
        self.write()
        for value in [
            {"decisions": []},
            {"decision_files": ["other.yaml"]},
            {"decisions": self.definitions, "gates": []},
            {"decisions": [{"id": "needs-static", "question": "Q", "provider": "jev"}]},
        ]:
            self.bundle.write_text(yaml.safe_dump(value))
            with self.subTest(value=value), self.assertRaises(ValueError):
                load_profile(self.file)
        self.bundle.unlink()
        self.bundle.symlink_to(self.file)
        with self.assertRaisesRegex(ValueError, "symlink"):
            load_profile(self.file)

    def test_drift_portable_hash_and_snapshot_reconstruction(self) -> None:
        loaded = load_profile(self.file)
        pinned = snapshot(loaded, source="accepted")
        shutil.copytree(self.root, self.root / "copy", ignore=shutil.ignore_patterns("copy"))
        self.assertEqual(loaded["hash"], load_profile(self.root / "copy/project.yaml")["hash"])
        self.definitions[0]["question"] = "Changed policy"
        self.write()
        with self.assertRaisesRegex(ValueError, "drift"):
            check_frozen(loaded["files"])
        self.assertEqual(loaded["data"], validate_snapshot(pinned))
        pinned["profile"]["decisions"][0]["question"] = "Forged normalized question"
        pinned["sha256"] = fingerprint({k: v for k, v in pinned.items() if k != "sha256"})
        with self.assertRaisesRegex(ValueError, "differs"):
            validate_snapshot(pinned)

    def test_git_baseline_includes_both_bundle_types_without_candidate_reads(self) -> None:
        gates = self.data.pop("gates")
        self.data["gate_files"] = ["gates/work.yaml"]
        (self.root / "gates").mkdir()
        (self.root / "gates/work.yaml").write_text(yaml.safe_dump({"gates": gates}))
        self.write()
        expected = load_profile(self.file)["data"]
        (self.root / "AGENTS.md").write_text("Accepted instructions")

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
        (self.root / "gates/work.yaml").unlink()
        pinned = review_snapshot(self.root, revision, "project.yaml")
        self.assertEqual(expected, validate_snapshot(pinned))
        self.assertIn("decisions/verification.yaml", pinned["files"])
        self.assertIn("gates/work.yaml", pinned["files"])
