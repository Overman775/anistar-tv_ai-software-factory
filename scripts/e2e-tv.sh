#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
forward=()
forward_count=0
for argument in "$@"; do
  [[ -n $argument ]] || continue
  [[ $argument != fixtures-mobile ]] || { echo 'TV runner does not accept fixtures-mobile mode.' >&2; exit 64; }
  forward+=("$argument")
  forward_count=$((forward_count + 1))
done
# Bash 3.2 treats an empty array expansion as an unset variable under `set -u`.
# Keep the no-argument full-suite invocation truly argument-free.
if [[ $forward_count == 0 ]]; then
  exec bash "$project_root/scripts/e2e.sh"
fi
exec bash "$project_root/scripts/e2e.sh" "${forward[@]}"
