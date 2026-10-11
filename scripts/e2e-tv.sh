#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
device=''
mode=fixtures
if [[ $# -gt 0 ]]; then
  if [[ $1 == fixtures || $1 == live ]]; then
    mode=$1
    shift
  else
    device=$1
    shift
    if [[ $# -gt 0 ]]; then mode=$1; shift; fi
  fi
fi
[[ $# == 0 && ( $mode == fixtures || $mode == live ) ]] || { echo 'Usage: bash scripts/e2e-tv.sh [emulator-<port>] [fixtures|live]' >&2; exit 64; }
exec bash "$project_root/scripts/e2e.sh" "$device" "$mode"
