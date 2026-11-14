"""Failure diagnostics survive subsequent successful coverage commands."""

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from factory import quality


class QualityFailureTests(unittest.TestCase):
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
