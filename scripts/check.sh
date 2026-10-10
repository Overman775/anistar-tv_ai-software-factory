#!/usr/bin/env bash
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
mode=${1:-check}
case "$mode" in
  check|ci|format|format:check|analyze|dcm|test:unit|test:goldens|test:goldens:update|test:coverage) ;;
  *) echo "Usage: bash scripts/check.sh [check|ci|format|format:check|analyze|dcm|test:unit|test:goldens|test:goldens:update|test:coverage]" >&2; exit 64 ;;
esac

# Use pinned FVM or an explicit SDK path, verified against the same pin.
sdk_dir=${ANISTAR_FLUTTER_SDK:-$project_root/.fvm/flutter_sdk}
if [[ -n ${ANISTAR_FLUTTER_SDK:-} ]]; then
  flutter_cmd=("$sdk_dir/bin/flutter" --no-version-check)
  dart_cmd=("$sdk_dir/bin/dart")
else
  command -v fvm >/dev/null || { echo "Install FVM or set ANISTAR_FLUTTER_SDK." >&2; exit 1; }
  flutter_cmd=(fvm flutter --no-version-check)
  dart_cmd=(fvm dart)
fi
seed=${ANISTAR_TEST_SEED:-20261010}
[[ $seed =~ ^[0-9]+$ ]] || { echo "ANISTAR_TEST_SEED must be a non-negative integer." >&2; exit 64; }

"${flutter_cmd[@]}" --version --machine | "${dart_cmd[@]}" tool/quality/verify_sdk.dart
"${flutter_cmd[@]}" pub get --enforce-lockfile

dart_files=()
while IFS= read -r -d '' file; do
  dart_files+=("$file")
done < <(find lib infrastructure test integration_test tool/quality \
  -type d \( -name build -o -name .dart_tool \) -prune -o \
  -type f -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' \
  ! -name generated_plugin_registrant.dart -print0)
[[ ${#dart_files[@]} -gt 0 ]] || { echo "No maintained Dart sources found." >&2; exit 1; }

format_check() { "${dart_cmd[@]}" format --output=none --set-exit-if-changed "${dart_files[@]}"; }
analyze() { "${flutter_cmd[@]}" analyze --no-pub --fatal-infos; }
dcm_check() {
  command -v dcm >/dev/null || { echo "DCM is required for the full check; see dcm_global.yaml." >&2; exit 1; }
  dcm analyze lib infrastructure test integration_test tool/quality \
    --sdk-path "$sdk_dir/bin/cache/dart-sdk" --fatal-style --fatal-warnings --no-analytics
}
unit_tests() {
  "${flutter_cmd[@]}" test --no-pub --exclude-tags=golden --concurrency=4 \
    --test-randomize-ordering-seed="$seed" --coverage \
    --coverage-package=anistar_tv --coverage-package=core --coverage-package=networking \
    --coverage-package=storage --coverage-package=app_logging --coverage-package=anistar --coverage-package=ui_kit
}
golden_tests() {
  "${flutter_cmd[@]}" test --no-pub --tags=golden --concurrency=1 \
    --test-randomize-ordering-seed="$seed" "$@"
}

case "$mode" in
  check) format_check; analyze; dcm_check; unit_tests; golden_tests ;;
  # Flutter-only profile; the full local check additionally requires DCM.
  ci) format_check; analyze; unit_tests; golden_tests ;;
  format) "${dart_cmd[@]}" format "${dart_files[@]}" ;;
  format:check) format_check ;;
  analyze) analyze ;;
  dcm) dcm_check ;;
  test:unit|test:coverage) unit_tests ;;
  test:goldens) golden_tests ;;
  test:goldens:update) golden_tests --update-goldens ;;
esac
