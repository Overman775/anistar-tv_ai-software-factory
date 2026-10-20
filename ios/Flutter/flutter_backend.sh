#!/bin/sh
# Flavor settings take precedence over a previous scheme's Generated.xcconfig.
set -eu
cd "$SRCROOT/.."
case "$ANISTAR_FLAVOR" in dev|prod) ;; *) echo 'Invalid iOS flavor' >&2; exit 64;; esac
bash scripts/with_python.sh python3 tool/environment/prepare.py
if [ -n "${ANISTAR_IOS_FIXTURE_TARGET:-}" ]; then
  case "$CONFIGURATION:$ANISTAR_IOS_FIXTURE_TARGET" in
    Debug-*:integration_test/ios_e2e_test.dart) ;;
    *) echo 'iOS fixtures require debug and the explicit fixture entry point' >&2; exit 64;;
  esac
  export FLUTTER_TARGET="$ANISTAR_IOS_FIXTURE_TARGET"
else
  export FLUTTER_TARGET="lib/main_$ANISTAR_FLAVOR.dart"
  # Keep other Flutter/tool defines, but never inherit another flavor's mirror.
  DART_DEFINES=$(bash scripts/with_python.sh python3 tool/environment/ios_defines.py)
  export DART_DEFINES
fi
exec /bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@"
