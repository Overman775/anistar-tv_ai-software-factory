#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else "Python 3.10+ required in PATH; see docs/melos_tooling.md")'
python3 -m unittest discover -s tool/quality -p '*_test.py'
python3 -m unittest discover -s tool/security -p '*_test.py'
python3 -m unittest discover -s tool/e2e -p '*_test.py'
python3 -m unittest discover -s tool/version -p '*_test.py'
python3 -m unittest discover -s tool/signing -p '*_test.py'
# Factory suites use separate processes because test_skill_contract module names collide.
python3 tool/factory/run_tests.py
# Graphify is optional, but a broken installed/configured tool must fail.
python3 tool/graphify/prepare.py --optional --check
