"""Regression coverage for lossless selector transport."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from selector_args import ENVIRONMENT_VARIABLE, SelectorError, load_selectors


class SelectorArgsTest(unittest.TestCase):
    def test_exec_preserves_exact_selector_argv_and_consumes_only_selector_environment(self):
        selectors = ['test/with  spaces.dart', '--name', r'^one  "quoted" \| \$$']
        with tempfile.TemporaryDirectory() as temporary:
            capture = Path(temporary) / 'capture.py'
            capture.write_text(
                'import json, os, sys\n'
                'print(json.dumps({"argv": sys.argv[1:], "selectors": os.getenv("ANISTAR_TEST_SELECTORS_JSON"), '
                '"kept": os.getenv("ANISTAR_SELECTOR_KEEP")}))\n',
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(Path(__file__).with_name('selector_args.py')),
                    '--profile',
                    'host',
                    'exec',
                    '--',
                    sys.executable,
                    str(capture),
                    'fixed argument',
                ],
                check=False,
                capture_output=True,
                text=True,
                env={
                    **os.environ,
                    ENVIRONMENT_VARIABLE: json.dumps(selectors),
                    'ANISTAR_SELECTOR_KEEP': 'preserved',
                },
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        captured = json.loads(result.stdout)
        self.assertEqual(captured['argv'], ['fixed argument', *selectors])
        self.assertIsNone(captured['selectors'])
        self.assertEqual(captured['kept'], 'preserved')

    def test_nul_selector_is_rejected_before_exec(self):
        with self.assertRaisesRegex(SelectorError, 'NUL'):
            load_selectors('["test\\u0000broken.dart"]')


if __name__ == '__main__':
    unittest.main()
