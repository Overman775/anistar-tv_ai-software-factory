"""Failure diagnostics survive subsequent successful coverage commands."""

import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from factory import quality
from factory.paths import FACTORY_ROOT, TOOLS


class QualityFailureTests(unittest.TestCase):
    def test_checker_discovers_sources_once_only_when_needed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            result = quality.StageResult("stage", "PASS", 0, [], "log", [])
            with (
                patch.object(
                    quality, "source_files", return_value=[root / "source.py"]
                ) as discover,
                patch.object(quality, "source_digest", return_value="unchanged"),
                patch.object(quality, "run_stage", return_value=result) as run,
                contextlib.redirect_stdout(io.StringIO()),
            ):
                self.assertEqual(0, quality.check(["lint", "format", "types", "imports"], root))
                self.assertEqual(1, discover.call_count)
                self.assertTrue(
                    all(call.args[2] == [str(root / "source.py")] for call in run.call_args_list)
                )
                discover.reset_mock()
                self.assertEqual(0, quality.check(["imports"], root))
                discover.assert_not_called()

    def test_source_discovery_matches_original_and_refreshes(self) -> None:
        roots = [
            TOOLS,
            FACTORY_ROOT / "tooling/factory",
            FACTORY_ROOT / "tooling/tests",
            FACTORY_ROOT / "gates",
            FACTORY_ROOT / "project/gates",
            FACTORY_ROOT / "project/examples/gates",
        ]
        roots += sorted((FACTORY_ROOT / "skills").glob("factory-*/scripts"))
        roots += sorted((FACTORY_ROOT / "skills").glob("factory-*/tests"))
        excluded = {
            ".venv",
            ".python",
            "__pycache__",
            ".mypy_cache",
            ".ruff_cache",
            ".pytest_cache",
            "htmlcov",
        }
        original = {
            p for root in roots for p in root.rglob("*.py") if not excluded.intersection(p.parts)
        }
        self.assertEqual(original, set(quality.source_files()))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(quality, "TOOLS", root), patch.object(quality, "FACTORY_ROOT", root):
                self.assertEqual([], quality.source_files())
                added = root / "new.py"
                added.touch()
                self.assertEqual([added], quality.source_files())

    def test_single_discovery_validates_and_runs_all_tests_once(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tests = root / "tooling/tests"
            group = tests / "factory/group"
            group.mkdir(parents=True)
            for package in (tests, tests / "factory", group):
                (package / "__init__.py").touch()
            marker = root / "runs"
            body = (
                "import unittest\nfrom pathlib import Path\nclass Example(unittest.TestCase):\n    def test_one(self):\n"
                f"        with Path({str(marker)!r}).open('a') as f: f.write('x')\n"
            )
            (group / "test_group.py").write_text(body, encoding="utf-8")
            (tests / "test_extra.py").write_text(body, encoding="utf-8")
            script = "import sys; from pathlib import Path; from factory import test_suite; sys.path.insert(0, sys.argv[1] + '/tooling'); test_suite.FACTORY_ROOT = Path(sys.argv[1]); test_suite.SUITES = ('group',); sys.exit(test_suite.main())"

            def run() -> subprocess.CompletedProcess[str]:
                return subprocess.run(
                    [sys.executable, "-c", script, str(root)],
                    capture_output=True,
                    text=True,
                    check=False,
                )

            self.assertEqual(0, run().returncode)
            self.assertEqual("xx", marker.read_text(encoding="utf-8"))
            (tests / "test_added.py").write_text(body, encoding="utf-8")
            marker.unlink()
            self.assertEqual(0, run().returncode)
            self.assertEqual("xxx", marker.read_text(encoding="utf-8"))
            (group / "test_group.py").unlink()
            self.assertIn("no tests discovered in group", run().stderr)
            (group / "test_group.py").write_text(body, encoding="utf-8")
            (group / "__init__.py").unlink()
            self.assertIn("test package missing __init__.py", run().stderr)

    def test_source_digest_ignores_local_diagnostics_but_tracks_module(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            module = root / "tooling/factory/diagnostics/dry_run.py"
            module.parent.mkdir(parents=True)
            module.write_text("original", encoding="utf-8")
            with patch.object(quality, "FACTORY_ROOT", root):
                before = quality.source_digest()
                journal = root / "diagnostics/journal.sqlite3"
                journal.parent.mkdir()
                journal.write_text("record", encoding="utf-8")
                self.assertEqual(before, quality.source_digest())
                module.write_text("changed", encoding="utf-8")
                self.assertNotEqual(before, quality.source_digest())

    def test_failed_test_is_reported_after_verbose_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            failing_test = root / "test_failure.py"
            failing_test.write_text(
                "import unittest\n"
                "class Example(unittest.TestCase):\n"
                "    def test_failure(self):\n"
                "        self.fail('distinct test failure')\n"
                "unittest.main()\n",
                encoding="utf-8",
            )
            commands = [
                [sys.executable, str(failing_test)],
                [sys.executable, "-c", "print('coverage row\\n' * 200)"],
            ]
            output = io.StringIO()
            with (
                patch.object(quality, "commands", return_value=commands),
                patch.object(quality, "source_digest", return_value="unchanged"),
                contextlib.redirect_stdout(output),
            ):
                result = quality.check(["tests"], root / "reports")
            self.assertEqual(result, 1)
            self.assertIn("distinct test failure", output.getvalue())
            self.assertIn(str(failing_test), output.getvalue())
            self.assertIn("coverage row", (root / "reports/tests.log").read_text())
            summary = json.loads((root / "reports/result.json").read_text())
            self.assertEqual(
                set(summary["stages"][0]), {"stage", "status", "exit_code", "commands", "log"}
            )


if __name__ == "__main__":
    unittest.main()
