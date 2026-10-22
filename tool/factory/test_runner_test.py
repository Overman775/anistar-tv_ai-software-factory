import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
import run_tests


class IsolatedRunnerTest(unittest.TestCase):
    def test_empty_suite_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(Path(run_tests.__file__)), '--suite', directory], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('zero tests collected', result.stderr)

    def test_missing_or_empty_required_default_suite_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('factory-code-review', 'factory-implement', 'factory-planning', 'factory-decompose', 'factory-pr'):
                path = root / '.agents/skills' / name / 'scripts'
                path.mkdir(parents=True)
                (path / 'test_skill_contract.py').write_text('import unittest\nclass Contract(unittest.TestCase):\n def test_ok(self): pass\n')
            factory = root / 'tool/factory'
            factory.mkdir(parents=True)
            (factory / 'runner_test.py').write_text('import unittest\nclass Contract(unittest.TestCase):\n def test_ok(self): pass\n')
            argv = [sys.executable, str(Path(run_tests.__file__)), '--root', str(root)]
            self.assertEqual(0, subprocess.run(argv, capture_output=True).returncode)
            missing = root / '.agents/skills/factory-planning/scripts/test_skill_contract.py'
            missing.unlink()
            self.assertNotEqual(0, subprocess.run(argv, capture_output=True).returncode)
            missing.parent.rename(missing.parent.with_name('saved-scripts'))
            self.assertNotEqual(0, subprocess.run(argv, capture_output=True).returncode)

    def test_colliding_module_names_run_in_distinct_subprocesses(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = [root / 'a', root / 'b']
            for index, path in enumerate(paths):
                path.mkdir()
                (path / 'test_skill_contract.py').write_text(f'import unittest\nclass Contract(unittest.TestCase):\n def test_identity(self):\n  self.assertEqual({index}, {index})\n')
            result = subprocess.run([sys.executable, str(Path(run_tests.__file__)), '--suite', str(paths[0]), '--suite', str(paths[1])], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(2, result.stderr.count('Ran 1 test'))

    def test_import_failure_and_test_failure_propagate(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test_skill_contract.py'
            for source in ('raise RuntimeError("broken import")', 'import unittest\nclass Contract(unittest.TestCase):\n def test_failure(self):\n  self.fail("failed assertion")\n'):
                path.write_text(source)
                result = subprocess.run([sys.executable, str(Path(run_tests.__file__)), '--suite', directory], capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)

if __name__ == '__main__':
    unittest.main()
