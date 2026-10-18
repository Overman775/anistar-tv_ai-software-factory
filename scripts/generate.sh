#!/usr/bin/env bash
set -euo pipefail
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
dart run build_runner build --workspace "$@"
# Router generator uses its own width; keep the established project format.
dart format lib/app/app_routes.g.dart
