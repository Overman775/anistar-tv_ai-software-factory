#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[[ $# -le 1 ]] || { echo 'Usage: e2e_live.sh [emulator-<port>]' >&2; exit 64; }
exec bash "$project_root/scripts/e2e-tv.sh" "${1:-}" live
