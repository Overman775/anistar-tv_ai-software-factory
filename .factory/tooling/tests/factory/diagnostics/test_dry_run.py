"""Dry-run boundaries: disposable state, no transport and actionable failures."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from factory.diagnostics import dry_run as driver
from factory.paths import TOOLS

SCRIPT = TOOLS / "bin/dry_run.py"


def snapshot() -> dict[str, str]:
    return {
        str(p): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in TOOLS.parent.rglob("*")
        if p.is_file()
        and not p.is_symlink()
        and not any(
            part in p.parts for part in ("__pycache__", ".venv", ".mypy_cache", ".ruff_cache")
        )
    }


class DryRunTests(unittest.TestCase):
    def test_repeatable_without_processes_network_or_source_writes(self) -> None:
        before = snapshot()
        real_temp = tempfile.TemporaryDirectory
        paths = []

        def temporary(*args: Any, **kwargs: Any) -> tempfile.TemporaryDirectory[str]:
            value = real_temp(*args, **kwargs)
            paths.append(Path(value.name))
            return value

        with (
            patch("tempfile.TemporaryDirectory", side_effect=temporary),
            patch("subprocess.Popen", side_effect=AssertionError("External process forbidden")),
            patch("os.system", side_effect=AssertionError("Shell forbidden")),
            patch("socket.socket", side_effect=AssertionError("Network forbidden")),
        ):
            first = driver.run()
            self.assertEqual(first, driver.run())
        self.assertEqual(first["status"], "PASS")
        self.assertEqual(len(first["checks"]), 7)
        self.assertEqual(before, snapshot())
        self.assertTrue(paths)
        self.assertTrue(all(not path.exists() for path in paths))

    def test_copy_excludes_local_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            shutil.copytree(
                TOOLS.parent,
                source,
                ignore=shutil.ignore_patterns(
                    ".venv", "__pycache__", ".ruff_cache", ".mypy_cache", ".pytest_cache"
                ),
            )
            for name in (".ruff_cache/cache", ".coverage.tmp", "htmlcov/index.html", "module.pyo"):
                path = source / "tooling" / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("local", encoding="utf-8")
            target = root / "target"
            driver.copy_bundle(source, target)
            for name in (".ruff_cache/cache", ".coverage.tmp", "htmlcov/index.html", "module.pyo"):
                self.assertFalse((target / "tooling" / name).exists())
            self.assertTrue((target / "tooling/factory/runtime/memory.py").is_file())

    def test_missing_role_fails_and_cleans_temporary_bundle(self) -> None:
        original = driver.copy_bundle
        copies = []

        def damaged(source: Path, target: Path) -> None:
            original(source, target)
            copies.append(target)
            (target / "roles/generalist.md").unlink()

        with patch.object(driver, "copy_bundle", side_effect=damaged):
            with self.assertRaisesRegex(Exception, "Missing role"):
                driver.run()
        self.assertTrue(all(not target.exists() for target in copies))

    def test_cli_from_unrelated_directory(self) -> None:
        with tempfile.TemporaryDirectory() as cwd:
            result = subprocess.run(
                [sys.executable, "-B", str(SCRIPT)],
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=30,
            )
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(json.loads(result.stdout)["status"], "PASS")

    def test_missing_dependency_is_nonzero_json(self) -> None:
        # -S plus an empty PYTHONPATH deliberately hides third-party packages.
        environment = dict(os.environ, PYTHONPATH="")
        result = subprocess.run(
            [sys.executable, "-B", "-S", str(SCRIPT)],
            env=environment,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        report = json.loads(result.stdout)
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("PyYAML", report["error"])


if __name__ == "__main__":
    unittest.main()
