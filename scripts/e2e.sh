#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
device=${1:-}
mode=${2:-fixtures}
[[ $device == emulator-* ]] || { echo 'Usage: bash scripts/e2e.sh emulator-<port> [fixtures|live]' >&2; exit 64; }
[[ $mode == fixtures || $mode == live ]] || { echo 'Unknown E2E mode.' >&2; exit 64; }
seed=${ANISTAR_TEST_SEED:-20261010}
[[ $seed =~ ^[0-9]+$ ]] || { echo 'ANISTAR_TEST_SEED must be a non-negative integer.' >&2; exit 64; }
sdk_dir=${ANISTAR_FLUTTER_SDK:-$project_root/.fvm/flutter_sdk}
flutter_cmd=("$sdk_dir/bin/flutter" --no-version-check)
dart_cmd=("$sdk_dir/bin/dart")
android_sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
adb_cmd=("$android_sdk/platform-tools/adb" -s "$device")
[[ $("${adb_cmd[@]}" get-state) == device ]] || { echo 'Android emulator is not ready.' >&2; exit 1; }
python3 tool/e2e/emulator_input.py --adb "${adb_cmd[0]}" --device "$device"
"${flutter_cmd[@]}" --version --machine | "${dart_cmd[@]}" tool/quality/verify_sdk.dart
"${flutter_cmd[@]}" pub get --enforce-lockfile
mkdir -p build/e2e
run_dir=$(mktemp -d "$project_root/build/e2e/run.XXXXXX")
previous_immersive=$("${adb_cmd[@]}" shell settings get secure immersive_mode_confirmations | tr -d '\r')
"${adb_cmd[@]}" shell settings put secure immersive_mode_confirmations confirmed
fixture_pid=''
fixture_port=''
cleanup() {
  local status=$?
  "${adb_cmd[@]}" logcat -d -t 400 > "$run_dir/logcat.log" 2>/dev/null || true
  if [[ $previous_immersive == null ]]; then
    "${adb_cmd[@]}" shell settings delete secure immersive_mode_confirmations >/dev/null 2>&1 || true
  else
    "${adb_cmd[@]}" shell settings put secure immersive_mode_confirmations "$previous_immersive" >/dev/null 2>&1 || true
  fi
  if [[ -n $fixture_port ]]; then "${adb_cmd[@]}" reverse --remove "tcp:$fixture_port" >/dev/null 2>&1 || true; fi
  if [[ -n $fixture_pid ]]; then kill "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true; fi
  exit "$status"
}
trap cleanup EXIT
if [[ $mode == live ]]; then
  credentials_file=${ANISTAR_LIVE_CREDENTIALS_FILE:-$project_root/env/live-test.local.json}
  python3 - "$credentials_file" <<'PYCONFIG'
import json, sys
from pathlib import Path
try:
    config = json.loads(Path(sys.argv[1]).read_text())
    assert all(isinstance(config.get(key), str) and config[key] for key in ('ANISTAR_TEST_USERNAME', 'ANISTAR_TEST_PASSWORD'))
except (OSError, ValueError, AssertionError, AttributeError):
    raise SystemExit('Missing/invalid local live credentials. See docs/05_development_and_testing.md section 9.')
PYCONFIG
  "${flutter_cmd[@]}" test integration_test/direct_android_test.dart -d "$device" --flavor dev \
    --dart-define-from-file="$credentials_file" \
    --timeout=10m --reporter=expanded --test-randomize-ordering-seed="$seed" 2>&1 | tee "$run_dir/flutter.log"
else
  python3 -m unittest discover -s tool/e2e -p '*_test.py'
  python3 tool/e2e/fixture_server.py --ready-file "$run_dir/port" --event-log "$run_dir/requests.jsonl" > "$run_dir/server.log" 2>&1 &
  fixture_pid=$!
  for attempt in {1..100}; do
    [[ -s $run_dir/port ]] && break
    kill -0 "$fixture_pid" 2>/dev/null || { cat "$run_dir/server.log" >&2; exit 1; }
    sleep 0.1
  done
  [[ -s $run_dir/port ]] || { echo 'Fixture startup timed out.' >&2; exit 1; }
  fixture_port=$(cat "$run_dir/port")
  "${adb_cmd[@]}" reverse "tcp:$fixture_port" "tcp:$fixture_port"
  "${flutter_cmd[@]}" test integration_test/app_e2e_test.dart -d "$device" --flavor dev \
    --dart-define="ANISTAR_MIRROR_URL=https://localhost:$fixture_port" \
    --timeout=10m --reporter=expanded --test-randomize-ordering-seed="$seed" 2>&1 | tee "$run_dir/flutter.log"
fi
