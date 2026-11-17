from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

from factory.paths import BIN
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid
from factory.runtime.workspace import check_workspace
from tests.fixture_bundle import ROOT


class WorkspaceTests(unittest.TestCase):
    def setUp(self) -> None:
        temp = tempfile.TemporaryDirectory(prefix="factory-workspace-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name).resolve() / "source checkout"
        self.config = self.root / ".factory/factory.yaml"
        shutil.copytree(ROOT, self.config.parent)
        self.graph = self.root.parent / "graph.json"
        self.graph.write_text("{}", encoding="utf-8")

    def mode(self, mode: str) -> None:
        raw = yaml.safe_load(self.config.read_text(encoding="utf-8"))
        raw["execution"]["workspace"] = mode
        self.config.write_text(yaml.safe_dump(raw), encoding="utf-8")

    def invoke(self, *args: str, workspace: Path | None = None) -> subprocess.CompletedProcess[str]:
        root = workspace or self.root
        return subprocess.run(
            [
                sys.executable,
                str(BIN / "workflow.py"),
                "--workspace",
                str(root),
                "--config",
                str(root / ".factory/factory.yaml"),
                *args,
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def git(self, *args: str, workspace: Path | None = None) -> str:
        return subprocess.check_output(
            [
                "git",
                "-C",
                str(workspace or self.root),
                "-c",
                "user.name=Factory Test",
                "-c",
                "user.email=factory@example.invalid",
                "-c",
                "commit.gpgSign=false",
                *args,
            ],
            text=True,
        ).strip()

    def test_omitted_workspace_preserves_current_checkout(self) -> None:
        result = self.invoke("prepare-workspace")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(result.stdout)["result"],
            {"mode": "shared", "workspace": str(self.root), "config": str(self.config)},
        )

    def test_container_blocks_preparation_and_direct_intake(self) -> None:
        self.mode("container")
        for args in (("prepare-workspace",), ("init", str(self.graph))):
            result = self.invoke(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Container workspace is not implemented", result.stderr)
        self.assertFalse((self.root / ".factory/memory/state/workflow.json").exists())

    def test_worktree_uses_committed_checkout_and_reuses_prepared_directory(self) -> None:
        self.mode("worktree")
        self.git("init", "-q")
        (self.root / ".gitignore").write_text(
            "local-data\n/.factory/diagnostics/\n", encoding="utf-8"
        )
        (self.root / "local-data").write_text("local", encoding="utf-8")
        source = self.root / "tracked.txt"
        source.write_text("before", encoding="utf-8")
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture")
        original = self.git("rev-parse", "HEAD")
        original_branch = self.git("rev-parse", "--abbrev-ref", "HEAD")

        refused = self.invoke("init", str(self.graph))
        self.assertIn("use the returned worktree", refused.stderr)
        source.write_text("uncommitted", encoding="utf-8")
        dirty = self.invoke("prepare-workspace")
        self.assertNotEqual(dirty.returncode, 0)
        self.assertIn("requires a clean checkout", dirty.stderr)
        source.write_text("before", encoding="utf-8")

        result = self.invoke("prepare-workspace")
        self.assertEqual(result.returncode, 0, result.stderr)
        selected = json.loads(result.stdout)["result"]
        target = Path(selected["workspace"])
        self.assertEqual(target.parent, self.root.parent)
        self.assertRegex(
            self.git("rev-parse", "--abbrev-ref", "HEAD", workspace=target),
            r"^worktree/factory-[0-9a-f]{12}$",
        )
        self.assertEqual(self.git("rev-parse", "HEAD", workspace=target), original)
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD"), original_branch)
        self.assertFalse((target / "local-data").exists())
        check_workspace(target, load_config(selected["config"]))
        with self.assertRaisesRegex(Invalid, "config in the selected checkout"):
            check_workspace(target, load_config(self.config))
        (target / "tracked.txt").write_text("agent edit", encoding="utf-8")
        self.assertEqual(source.read_text(encoding="utf-8"), "before")
        again = self.invoke("prepare-workspace", workspace=target)
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(json.loads(again.stdout)["result"], selected)

    def test_unknown_workspace_is_rejected_at_config_boundary(self) -> None:
        self.mode("sandbox")
        with self.assertRaisesRegex(Invalid, r"execution.workspace"):
            load_config(self.config)
