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
# graphify is optional, isolated tooling with its own Python environment.
if [[ -f graphify-out/.graphify_python ]]; then
  graphify_python=$(cat graphify-out/.graphify_python)
  "$graphify_python" -m unittest discover -s tool/graphify -p 'test_*.py'
else
  echo 'Graphify regression tests not run: local graphify interpreter is not configured.'
fi
