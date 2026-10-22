#!/usr/bin/env python3
"""Run each Factory suite in its own interpreter; reject empty test collection."""
from __future__ import annotations
import argparse
import subprocess
import sys
from pathlib import Path

CHILD = '''import sys, unittest
suite = unittest.defaultTestLoader.discover(sys.argv[1], pattern=sys.argv[2])
count = suite.countTestCases()
if count == 0:
    sys.stderr.write("ERROR: zero tests collected\\n")
    sys.exit(2)
result = unittest.TextTestRunner(verbosity=1).run(suite)
sys.exit(0 if result.wasSuccessful() else 1)
'''

def run_suite(directory, pattern='test_*.py'):
    return subprocess.run([sys.executable, '-c', CHILD, str(Path(directory).resolve()), pattern], check=False).returncode

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', help='Checkout root; defaults to this script checkout')
    parser.add_argument('--suite', action='append', help='Explicit suite directory; default all Factory skill scripts and tool/factory')
    parser.add_argument('--pattern', default='test_*.py')
    args = parser.parse_args()
    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[2]
    if args.suite:
        suites = [(Path(path), args.pattern) for path in args.suite]
    else:
        required = ('factory-code-review', 'factory-implement', 'factory-planning', 'factory-decompose', 'factory-pr')
        suites = [(root / '.agents/skills' / name / 'scripts', 'test_*.py') for name in required]
        suites.append((root / 'tool/factory', '*_test.py'))
    failed = False
    for directory, pattern in suites:
        sys.stderr.write(f'Factory suite: {directory.relative_to(root) if directory.is_relative_to(root) else directory}\n')
        if run_suite(directory, pattern) != 0:
            failed = True
    return 1 if failed else 0

if __name__ == '__main__':
    sys.exit(main())
