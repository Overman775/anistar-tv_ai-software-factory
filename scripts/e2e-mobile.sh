#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
device=''
if [[ ${1:-} =~ ^emulator-[0-9]+$ ]]; then
  device=$1
  shift
fi
arguments=(fixtures-mobile)
[[ -z $device ]] || arguments=("$device" "${arguments[@]}")
for argument in "$@"; do
  [[ -n $argument ]] || continue
  arguments+=("$argument")
done
exec bash "$project_root/scripts/e2e.sh" "${arguments[@]}"
