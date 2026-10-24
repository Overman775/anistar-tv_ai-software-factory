#!/usr/bin/env bash
# Run sequentially: both platforms share Flutter/Gradle build output.
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
[[ $# -le 2 ]] || { echo 'Usage: bash scripts/e2e-all.sh [tv-emulator-<port>] [mobile-emulator-<port>]; filtered runs are diagnostics only.' >&2; exit 64; }
if [[ -n ${ANISTAR_TEST_SELECTORS_JSON:-} ]]; then
  echo 'test:e2e runs the full TV and mobile gate; ANISTAR_TEST_SELECTORS_JSON is diagnostic-only for platform E2E runners.' >&2
  exit 64
fi
for argument in "$@"; do
  case $argument in
    --plain-name|--name|--plain-name=*|--name=*)
      echo 'test:e2e runs the full TV and mobile gate; selectors are diagnostic-only and must use a platform E2E runner.' >&2
      exit 64
      ;;
  esac
done
tv_device=${1:-}
mobile_device=${2:-}
for device in "$tv_device" "$mobile_device"; do
  [[ -z $device || $device =~ ^emulator-[0-9]+$ ]] || { echo 'Device overrides must be emulator-<port>.' >&2; exit 64; }
done
tv_avd=${ANISTAR_TV_AVD:-anistar_tv_e2e}
mobile_avd=${ANISTAR_MOBILE_AVD:-anistar_mobile_e2e}
if [[ ( -n $tv_device && $tv_device == "$mobile_device" ) || ( -z $tv_device && -z $mobile_device && $tv_avd == "$mobile_avd" ) ]]; then
  echo 'TV and mobile E2E must use different emulators/AVDs.' >&2
  exit 64
fi
seed=${ANISTAR_TEST_SEED:-20261010}
[[ $seed =~ ^[0-9]+$ ]] || { echo 'ANISTAR_TEST_SEED must be a non-negative integer.' >&2; exit 64; }
android_sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
selection_args=(--adb "$android_sdk/platform-tools/adb" --emulator "$android_sdk/emulator/emulator" --identity-only)
tv_args=(--avd "$tv_avd" --expected tv)
mobile_args=(--avd "$mobile_avd" --expected mobile)
if [[ -n $tv_device ]]; then tv_args+=(--device "$tv_device"); fi
if [[ -n $mobile_device ]]; then mobile_args+=(--device "$mobile_device"); fi
# Each suite still performs its full role preflight. These read-only identities
# catch mixed explicit/default overrides pointing at the same emulator first.
tv_identity=$(python3 tool/e2e/emulator_selection.py "${selection_args[@]}" "${tv_args[@]}" 2>/dev/null) || tv_identity=''
mobile_identity=$(python3 tool/e2e/emulator_selection.py "${selection_args[@]}" "${mobile_args[@]}" 2>/dev/null) || mobile_identity=''
if [[ -n $tv_identity && $tv_identity == "$mobile_identity" ]]; then
  echo 'TV and mobile E2E resolve to the same emulator; choose different AVDs/devices.' >&2
  exit 64
fi
safe_tv=$(printf '%s' "${tv_device:-$tv_avd}" | tr -c 'A-Za-z0-9._-' '_')
safe_mobile=$(printf '%s' "${mobile_device:-$mobile_avd}" | tr -c 'A-Za-z0-9._-' '_')
mkdir -p build/e2e
run_dir=$(mktemp -d "$project_root/build/e2e/all-seed-$seed-tv-$safe_tv-mobile-$safe_mobile.XXXXXX")
tv_status=0
if [[ -n $tv_device ]]; then
  ANISTAR_E2E_RUN_DIR="$run_dir/tv" bash "$project_root/scripts/e2e-tv.sh" "$tv_device" || tv_status=$?
else
  ANISTAR_E2E_RUN_DIR="$run_dir/tv" bash "$project_root/scripts/e2e-tv.sh" || tv_status=$?
fi
mobile_status=0
if [[ -n $mobile_device ]]; then
  ANISTAR_E2E_RUN_DIR="$run_dir/mobile" bash "$project_root/scripts/e2e-mobile.sh" "$mobile_device" || mobile_status=$?
else
  ANISTAR_E2E_RUN_DIR="$run_dir/mobile" bash "$project_root/scripts/e2e-mobile.sh" || mobile_status=$?
fi
report_status=0
python3 "$project_root/tool/e2e/e2e_report.py" aggregate --directory "$run_dir" "$run_dir/tv" "$run_dir/mobile" || report_status=$?
aggregate_status=0
[[ $tv_status == 0 && $mobile_status == 0 && $report_status == 0 ]] || aggregate_status=1
if [[ $aggregate_status == 0 ]]; then
  echo "OK suite=e2e scope=full report=$run_dir"
else
  echo "FAIL suite=e2e scope=full report=$run_dir" >&2
fi
exit "$aggregate_status"
