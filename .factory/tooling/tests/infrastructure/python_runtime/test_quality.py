"""Real checker failures must remain failures when a later stage passes."""

from __future__ import annotations

import contextlib
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from factory import quality, yaml_checks
from factory.paths import TOOLS
from factory.test_suite import FactoryLoader


class QualityTests(unittest.TestCase):
    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory(prefix="factory quality ")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name).resolve()
        self.tools = self.root / ".factory/tooling"
        self.tools.mkdir(parents=True)
        shutil.copy2(TOOLS / "pyproject.toml", self.tools / "pyproject.toml")
        shutil.copy2(TOOLS / "yamllint.yaml", self.tools / "yamllint.yaml")
        self.source = self.tools / "probe.py"
        self.reports = self.root / "reports"
        locations = patch.multiple(quality, TOOLS=self.tools, FACTORY_ROOT=self.tools.parent)
        locations.start()
        self.addCleanup(locations.stop)

    def test_discovery_ignores_cached_python_yaml_and_tests(self) -> None:
        cache = self.tools / ".pytest_cache"
        cache.mkdir()
        (cache / "cache.py").write_text("invalid ???", encoding="utf-8")
        (cache / "cache.yaml").write_text("invalid: [", encoding="utf-8")
        (cache / "test_cache.py").write_text("invalid ???", encoding="utf-8")
        self.assertNotIn(cache / "cache.py", quality.source_files())
        self.assertNotIn(cache / "cache.yaml", yaml_checks.source_files(self.tools.parent))
        self.assertEqual((None, False), FactoryLoader()._find_test_path(str(cache), "test*.py"))

    def test_source_digest_tracks_package_but_not_memory(self) -> None:
        package = self.tools / "factory"
        package.mkdir()
        module = package / "example.py"
        module.write_text("before\n", encoding="utf-8")
        before = quality.source_digest()
        memory = self.tools.parent / "memory"
        memory.mkdir()
        (memory / "run.json").write_text("state\n", encoding="utf-8")
        self.assertEqual(before, quality.source_digest())
        module.write_text("after\n", encoding="utf-8")
        self.assertNotEqual(before, quality.source_digest())
        module.write_text("before\n", encoding="utf-8")
        package_memory = package / "memory"
        package_memory.mkdir()
        (package_memory / "module.py").write_text("owned\n", encoding="utf-8")
        self.assertNotEqual(before, quality.source_digest())

    def test_real_lint_failure_survives_a_passing_formatter(self) -> None:
        self.source.write_text("def broken() -> int:\n    return missing\n", encoding="utf-8")
        before = self.source.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            code = quality.check(["lint", "format"], self.reports)
        self.assertNotEqual(0, code)
        result = json.loads((self.reports / "result.json").read_text())
        self.assertEqual(["FAIL", "PASS"], [stage["status"] for stage in result["stages"]])
        self.assertIn("F821", (self.reports / "lint.log").read_text())
        self.assertEqual(before, self.source.read_bytes())
        self.assertTrue(result["source_unchanged"])

    def test_real_type_error_and_corrected_source_are_checked_afresh(self) -> None:
        self.source.write_text('def broken() -> int:\n    return "wrong"\n', encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertNotEqual(0, quality.check(["types"], self.reports))
        self.assertIn("[return-value]", (self.reports / "types.log").read_text())
        self.source.write_text("def broken() -> int:\n    return 1\n", encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(0, quality.check(["types"], self.reports))
        self.assertEqual("PASS", json.loads((self.reports / "result.json").read_text())["status"])

    def test_yaml_failure_survives_a_passing_python_formatter(self) -> None:
        profile = self.tools.parent / "project/project.yaml"
        profile.parent.mkdir()
        profile.write_text("id: sample\nid: duplicate\n", encoding="utf-8")
        self.source.write_text("answer = 1\n", encoding="utf-8")
        before = profile.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertNotEqual(0, quality.check(["yaml-lint", "format"], self.reports))
        result = json.loads((self.reports / "result.json").read_text())
        self.assertEqual(["FAIL", "PASS"], [stage["status"] for stage in result["stages"]])
        self.assertIn("key-duplicates", (self.reports / "yaml-lint.log").read_text())
        self.assertEqual(before, profile.read_bytes())

    def test_yaml_discovery_failure_is_reported_and_later_stage_still_runs(self) -> None:
        project = self.tools.parent / "project"
        project.mkdir()
        (project / "project.yaml").write_text("id: fixture\n", encoding="utf-8")
        external = self.root / "external"
        external.mkdir()
        (external / "invalid.yaml").write_text("invalid: [", encoding="utf-8")
        (project / "gates").symlink_to(external, target_is_directory=True)
        self.source.write_text("answer = 1\n", encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertNotEqual(0, quality.check(["yaml-lint", "format"], self.reports))
        result = json.loads((self.reports / "result.json").read_text())
        self.assertEqual(["FAIL", "PASS"], [stage["status"] for stage in result["stages"]])
        self.assertIn("symlink", (self.reports / "yaml-lint.log").read_text())
