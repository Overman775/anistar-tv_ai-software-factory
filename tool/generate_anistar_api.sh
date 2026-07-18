#!/usr/bin/env bash
set -euo pipefail

readonly project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly schema_path="${1:-${project_root}/openapi/anistar.openapi.json}"
readonly output_path="${project_root}/packages/anistar_api"
readonly required_version="7.23.0"

if ! command -v openapi-generator >/dev/null 2>&1; then
  echo "openapi-generator ${required_version} is required" >&2
  exit 1
fi

actual_version="$(openapi-generator version)"
if [[ "${actual_version}" != "${required_version}" ]]; then
  echo "Expected openapi-generator ${required_version}, found ${actual_version}" >&2
  exit 1
fi

openapi-generator generate \
  --input-spec "${schema_path}" \
  --generator-name dart-dio \
  --output "${output_path}" \
  --additional-properties pubName=anistar_api,pubVersion=1.0.0,useEnumExtension=true

patch --directory "${output_path}" --strip=1 < "${project_root}/openapi/dart-dio-7.23.0.patch"
fvm dart pub get --directory "${output_path}"
(
  cd "${output_path}"
  fvm dart run build_runner build
  fvm dart format lib
)
