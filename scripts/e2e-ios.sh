#!/usr/bin/env bash
# Explicit optional native fixture run; never part of the Android gate.
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
device=${1:-}
flavor=${2:-}
profile=${3:-mobile}
[[ ( $# == 2 || $# == 3 ) && $device =~ ^[A-Fa-f0-9-]{36}$ && ( $flavor == dev || $flavor == prod ) && ( $profile == mobile || $profile == tv ) ]] || {
  echo 'Usage: test:e2e:ios -- <booted-simulator-UDID> <dev|prod> [mobile|tv]; tv is an iPad layout diagnostic only' >&2; exit 64;
}
[[ $(uname -s) == Darwin ]] || { echo 'iOS E2E requires macOS and Xcode.' >&2; exit 1; }
command -v xcrun >/dev/null || { echo 'iOS E2E requires Xcode tools.' >&2; exit 1; }
xcrun simctl list devices booted -j | python3 -c '
import json,sys
devices=json.load(sys.stdin)["devices"]
selected=next((d for group in devices.values() for d in group if d["udid"]==sys.argv[1] and d.get("isAvailable")),None)
if selected is None:
    raise SystemExit("Requested available simulator must already be booted")
if sys.argv[2]=="tv" and ".iPad" not in selected.get("deviceTypeIdentifier", ""):
    raise SystemExit("TV layout diagnostic requires an iPad Simulator")
' "$device" "$profile"
bash scripts/with_python.sh python3 tool/environment/prepare.py
[[ -f integration_test/ios_e2e_test.dart ]] || { echo 'Missing iOS fixture test entry point.' >&2; exit 1; }
sdk_dir=${ANISTAR_FLUTTER_SDK:-$project_root/.fvm/flutter_sdk}
flutter_cmd=("$sdk_dir/bin/flutter" --no-version-check)
seed=${ANISTAR_TEST_SEED:-20261010}
[[ $seed =~ ^[0-9]+$ ]] || { echo 'Invalid test seed' >&2; exit 64; }
mkdir -p build/e2e
run_dir=$(mktemp -d "$project_root/build/e2e/ios-$flavor.XXXXXX")
fixture_pid=''
lock_dir="$project_root/build/e2e/.flutter.lock"
lock_owned=0
cleanup() {
  status=$?
  trap - EXIT INT TERM
  if [[ -n $fixture_pid ]]; then kill "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true; fi
  if [[ $lock_owned == 1 ]]; then rm -f "$lock_dir/owner"; rmdir "$lock_dir" 2>/dev/null || true; fi
  python3 - "$run_dir" "$device" "$flavor" "$profile" "$status" <<'PY'
import json,sys
from pathlib import Path
directory,device,flavor,profile,status=sys.argv[1:]
Path(directory,'result.json').write_text(json.dumps(dict(platform='ios',device=device,flavor=flavor,profile=profile,exit_code=int(status),status='PASS' if status=='0' else 'FAIL',fixture_trust='retained in selected simulator'),indent=2)+'\n')
PY
  echo "iOS E2E flavor=$flavor simulator=$device exit=$status; reports: $run_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$lock_dir" 2>/dev/null || { echo 'Another E2E runner owns Flutter build lock.' >&2; exit 1; }
lock_owned=1
printf 'pid=%s platform=ios device=%s\n' "$$" "$device" > "$lock_dir/owner"
"${flutter_cmd[@]}" --version --machine | "$sdk_dir/bin/dart" tool/quality/verify_sdk.dart
"${flutter_cmd[@]}" pub get --enforce-lockfile
# simctl cannot remove a single root certificate. Preserve all existing data;
# this public fixture trust remains installed only in the selected simulator.
echo 'Installing public localhost fixture trust in selected simulator; trust remains after this run.'
xcrun simctl keychain "$device" add-root-cert android/app/src/debug/res/raw/e2e_localhost.pem
python3 tool/e2e/fixture_server.py --ready-file "$run_dir/port" --event-log "$run_dir/requests.jsonl" > "$run_dir/server.log" 2>&1 &
fixture_pid=$!
for attempt in {1..100}; do
  [[ -s $run_dir/port ]] && break
  kill -0 "$fixture_pid" 2>/dev/null || { echo 'Fixture server failed.' >&2; exit 1; }
  sleep 0.1
done
[[ -s $run_dir/port ]] || { echo 'Fixture startup timed out.' >&2; exit 1; }
fixture_port=$(cat "$run_dir/port")
export ANISTAR_ANDROID_SIGNING_MODE=unsigned
export ANISTAR_IOS_FIXTURE_TARGET=integration_test/ios_e2e_test.dart
"${flutter_cmd[@]}" test integration_test/ios_e2e_test.dart -d "$device" --debug --flavor "$flavor" \
  --dart-define-from-file="env/$flavor.json" \
  --dart-define="ANISTAR_MIRROR_URL=https://localhost:$fixture_port" \
  --dart-define="ANISTAR_IOS_DIAGNOSTIC_PROFILE=$profile" \
  --timeout=10m --reporter=expanded --file-reporter="json:$run_dir/flutter-events.jsonl" \
  --test-randomize-ordering-seed="$seed" 2>&1 | tee "$run_dir/flutter.log"
