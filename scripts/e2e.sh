#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
device=${1:-}
mode=${2:-fixtures}
[[ $# -le 2 && ( -z $device || $device =~ ^emulator-[0-9]+$ ) ]] || { echo 'Usage: bash scripts/e2e.sh [emulator-<port>] [fixtures|fixtures-mobile|live]' >&2; exit 64; }
[[ $mode == fixtures || $mode == fixtures-mobile || $mode == live ]] || { echo 'Unknown E2E mode.' >&2; exit 64; }
seed=${ANISTAR_TEST_SEED:-20261010}
[[ $seed =~ ^[0-9]+$ ]] || { echo 'ANISTAR_TEST_SEED must be a non-negative integer.' >&2; exit 64; }
sdk_dir=${ANISTAR_FLUTTER_SDK:-$project_root/.fvm/flutter_sdk}
flutter_cmd=("$sdk_dir/bin/flutter" --no-version-check)
dart_cmd=("$sdk_dir/bin/dart")
android_sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
expected_profile=tv
if [[ $mode == fixtures-mobile ]]; then expected_profile=mobile; fi
if [[ $expected_profile == mobile ]]; then
  requested_avd=${ANISTAR_MOBILE_AVD:-anistar_mobile_e2e}
else
  requested_avd=${ANISTAR_TV_AVD:-anistar_tv_e2e}
fi
mkdir -p build/e2e
safe_label=$(printf '%s' "${device:-$requested_avd}" | tr -c 'A-Za-z0-9._-' '_')
prefix="$project_root/build/e2e/$expected_profile-$mode-seed-$seed-$safe_label"
if [[ -n ${ANISTAR_E2E_RUN_DIR:-} ]]; then
  run_dir=$ANISTAR_E2E_RUN_DIR
  if [[ -e $run_dir && ! -d $run_dir ]] || { [[ -d $run_dir ]] && [[ -n $(find "$run_dir" -mindepth 1 -maxdepth 1 -print -quit) ]]; }; then
    echo "Refusing to reuse nonempty E2E run directory: $run_dir. Choose a new or empty directory." >&2
    exit 64
  fi
  mkdir -p "$run_dir"
else
  run_dir=$(mktemp -d "$prefix.XXXXXX")
fi
exec > >(tee "$run_dir/runner.log") 2>&1
started_at=$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat())')
avd=''
phase=preflight
adb_cmd=("$android_sdk/platform-tools/adb" -s "$device")
previous_immersive=''
immersive_changed=0
fixture_pid=''
fixture_port=''
lock_owned=0
lock_dir="$project_root/build/e2e/.flutter.lock"
cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n $device ]]; then
    "${adb_cmd[@]}" logcat -d -t 400 > "$run_dir/logcat.log" 2>/dev/null || true
  fi
  if [[ $immersive_changed == 1 ]]; then
    if [[ $previous_immersive == null ]]; then
      "${adb_cmd[@]}" shell settings delete secure immersive_mode_confirmations >/dev/null 2>&1 || true
    else
      "${adb_cmd[@]}" shell settings put secure immersive_mode_confirmations "$previous_immersive" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n $fixture_port ]]; then "${adb_cmd[@]}" reverse --remove "tcp:$fixture_port" >/dev/null 2>&1 || true; fi
  if [[ -n $fixture_pid ]]; then kill "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true; fi
  if [[ $lock_owned == 1 ]]; then rm -f "$lock_dir/owner"; rmdir "$lock_dir" 2>/dev/null || true; fi
  local report_status=0
  python3 tool/e2e/e2e_report.py run --directory "$run_dir" --platform "$expected_profile" \
    --mode "$mode" --seed "$seed" --device "$device" --avd "$avd" --exit-code "$status" \
    --requested-avd "$requested_avd" --phase "$phase" --started-at "$started_at" || report_status=$?
  if [[ $status == 0 && $report_status != 0 ]]; then status=$report_status; fi
  echo "E2E [$expected_profile/$mode] AVD=${avd:-unknown} requestedAVD=$requested_avd device=${device:-unselected} seed=$seed exit=$status"
  echo "Reports and logs: $run_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
selection_args=(--adb "${adb_cmd[0]}" --avd "$requested_avd" --expected "$expected_profile" --emulator "$android_sdk/emulator/emulator" --json)
if [[ -n $device ]]; then selection_args+=(--device "$device"); fi
python3 tool/e2e/emulator_selection.py "${selection_args[@]}" > "$run_dir/selection.json"
device=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["device"])' "$run_dir/selection.json")
avd=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["avd"])' "$run_dir/selection.json")
adb_cmd=("$android_sdk/platform-tools/adb" -s "$device")
if [[ -z ${ANISTAR_E2E_RUN_DIR:-} && $avd != "$safe_label" ]]; then
  safe_avd=$(printf '%s' "$avd" | tr -c 'A-Za-z0-9._-' '_')
  actual_dir=$(mktemp -d "$project_root/build/e2e/$expected_profile-$mode-seed-$seed-$safe_avd.XXXXXX")
  rmdir "$actual_dir"
  mv "$run_dir" "$actual_dir"
  run_dir=$actual_dir
fi
echo "E2E [$expected_profile/$mode] AVD=$avd device=$device seed=$seed"
echo "Reports and logs: $run_dir"
if [[ $expected_profile == tv ]]; then
  python3 tool/e2e/emulator_input.py --adb "${adb_cmd[0]}" --device "$device"
fi
if ! mkdir "$lock_dir" 2>/dev/null; then
  echo 'Another E2E runner owns the Flutter build lock. Wait for it to finish.' >&2
  [[ ! -f $lock_dir/owner ]] || cat "$lock_dir/owner" >&2
  exit 1
fi
lock_owned=1
printf 'pid=%s platform=%s device=%s avd=%s\n' "$$" "$expected_profile" "$device" "$avd" > "$lock_dir/owner"
phase=sdk-and-dependencies
"${flutter_cmd[@]}" --version --machine | "${dart_cmd[@]}" tool/quality/verify_sdk.dart
"${flutter_cmd[@]}" pub get --enforce-lockfile
previous_immersive=$("${adb_cmd[@]}" shell settings get secure immersive_mode_confirmations | tr -d '\r')
"${adb_cmd[@]}" shell settings put secure immersive_mode_confirmations confirmed
immersive_changed=1
if [[ $mode == live ]]; then
  phase=live-credentials
  credentials_file=${ANISTAR_LIVE_CREDENTIALS_FILE:-$project_root/.private/credentials/live-test.json}
  python3 - "$credentials_file" <<'PYCONFIG'
import json, sys
from pathlib import Path
try:
    config = json.loads(Path(sys.argv[1]).read_text())
    assert all(isinstance(config.get(key), str) and config[key] for key in ('ANISTAR_TEST_USERNAME', 'ANISTAR_TEST_PASSWORD'))
except (OSError, ValueError, AssertionError, AttributeError):
    raise SystemExit('Missing/invalid local live credentials. See docs/05_development_and_testing.md section 9.')
PYCONFIG
  phase=flutter-tests
  "${flutter_cmd[@]}" test integration_test/direct_android_test.dart -d "$device" --flavor dev \
    --dart-define-from-file="$credentials_file" \
    --timeout=10m --reporter=expanded --file-reporter="json:$run_dir/flutter-events.jsonl" \
    --test-randomize-ordering-seed="$seed" 2>&1 | tee "$run_dir/flutter.log"
else
  phase=fixture-tool-tests
  python3 -m unittest discover -s tool/e2e -p '*_test.py'
  phase=fixture-startup
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
  test_file=integration_test/app_e2e_test.dart
  if [[ $mode == fixtures-mobile ]]; then
    test_file=integration_test/mobile_e2e_test.dart
  fi
  phase=flutter-tests
  "${flutter_cmd[@]}" test "$test_file" -d "$device" --flavor dev \
    --dart-define="ANISTAR_MIRROR_URL=https://localhost:$fixture_port" \
    --timeout=10m --reporter=expanded --file-reporter="json:$run_dir/flutter-events.jsonl" \
    --test-randomize-ordering-seed="$seed" 2>&1 | tee "$run_dir/flutter.log"
fi
phase=complete
