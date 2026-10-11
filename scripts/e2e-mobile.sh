#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[[ $# -le 1 ]] || { echo 'Usage: bash scripts/e2e-mobile.sh [emulator-<port>]' >&2; exit 64; }
exec bash "$project_root/scripts/e2e.sh" "${1:-}" fixtures-mobile
