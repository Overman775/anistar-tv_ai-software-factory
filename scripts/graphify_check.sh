#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
[[ -f graphify-out/.graphify_python ]] || { echo 'Configure graphify first; see tool/graphify/README.md.' >&2; exit 1; }
graphify_python=$(cat graphify-out/.graphify_python)
"$graphify_python" tool/graphify/patch_graphify.py --check
"$graphify_python" -m unittest discover -s tool/graphify -p 'test_*.py'
