#!/usr/bin/env bash
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$project_root"

if [[ $# -ne 0 ]]; then
  echo 'Usage: bash scripts/security_osv.sh (scans the root pubspec.lock)' >&2
  exit 2
fi

if ! command -v osv-scanner >/dev/null 2>&1; then
  echo 'OSV-Scanner is required. Install it with: brew install osv-scanner' >&2
  exit 127
fi

if [[ ! -f "$project_root/pubspec.lock" ]]; then
  echo 'Root pubspec.lock is missing. Restore the workspace lockfile before scanning.' >&2
  exit 128
fi

# The shared lockfile includes direct and transitive workspace dependencies.
# Query OSV with package metadata only; do not walk source, SDK or cache trees.
# Native exit codes distinguish findings (1) from scanner/network failures.
exec osv-scanner scan source --no-resolve --lockfile "$project_root/pubspec.lock"
