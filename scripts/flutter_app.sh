#!/usr/bin/env bash
# Shared flavor/entry point/defines for Melos run and Android builds.
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
action=${1:-}
flavor=${2:-}
mode=${3:-}
[[ $# -ge 3 ]] || { echo 'Usage: flutter_app.sh run|apk|bundle dev|prod debug|profile|release [Flutter arguments]' >&2; exit 64; }
shift 3
[[ $action == run || $action == apk || $action == bundle ]] || exit 64
[[ $flavor == dev || $flavor == prod ]] || exit 64
[[ $mode == debug || $mode == profile || $mode == release ]] || exit 64
if [[ $flavor == prod && $mode == release ]]; then
  export ANISTAR_ANDROID_SIGNING_MODE=${ANISTAR_ANDROID_SIGNING_MODE:-local}
  [[ $ANISTAR_ANDROID_SIGNING_MODE == local || $ANISTAR_ANDROID_SIGNING_MODE == unsigned ]] || {
    echo 'Invalid Android signing mode' >&2; exit 64;
  }
else
  # Dev/debug commands must never load production credentials.
  export ANISTAR_ANDROID_SIGNING_MODE=unsigned
fi
sdk_dir=${ANISTAR_FLUTTER_SDK:-$project_root/.fvm/flutter_sdk}
flutter_cmd=("$sdk_dir/bin/flutter" --no-version-check)
"${flutter_cmd[@]}" --version --machine | "$sdk_dir/bin/dart" tool/quality/verify_sdk.dart
arguments=("--$mode" --flavor "$flavor" --target "lib/main_$flavor.dart")
if [[ -f env/$flavor.json ]]; then arguments+=("--dart-define-from-file=env/$flavor.json"); fi
if [[ $action == run ]]; then
  exec "${flutter_cmd[@]}" run "${arguments[@]}" "$@"
fi
# Keep normal pub lifecycle after integration tests (plugin registrar freshness).
if [[ $action == apk ]]; then
  "${flutter_cmd[@]}" build apk "${arguments[@]}" "$@"
  if [[ $mode == release ]]; then
    python3 tool/quality/verify_android_apk.py --variant "${flavor}Release" \
      --apk "build/app/outputs/flutter-apk/app-$flavor-release.apk"
    if [[ $flavor == prod ]]; then
      python3 tool/signing/android_signing.py verify \
        --apk "build/app/outputs/flutter-apk/app-$flavor-release.apk" \
        --mode "$ANISTAR_ANDROID_SIGNING_MODE"
    fi
  fi
else
  "${flutter_cmd[@]}" build appbundle "${arguments[@]}" "$@"
fi
