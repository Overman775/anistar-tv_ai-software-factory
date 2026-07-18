#!/usr/bin/env bash
set -euo pipefail

readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly api_root="${project_root}/api"

cd "${api_root}"
fvm dart pub get
fvm dart run swagger_parser
fvm dart run build_runner build
fvm dart format lib
