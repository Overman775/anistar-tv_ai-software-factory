#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
# DCM fix requires an absolute normalized SDK path (analyze also accepts relative).
sdk_dir=$(CDPATH= cd -- "${ANISTAR_FLUTTER_SDK:-$project_root/.fvm/flutter_sdk}" && pwd -P)
"$sdk_dir/bin/flutter" --no-version-check --version --machine | "$sdk_dir/bin/dart" tool/quality/verify_sdk.dart
exec dcm fix lib infrastructure test integration_test tool/quality \
  --sdk-path "$sdk_dir/bin/cache/dart-sdk" --no-analytics "$@"
