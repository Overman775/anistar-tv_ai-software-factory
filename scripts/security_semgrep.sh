#!/usr/bin/env bash
# Offline source scan. Never print Semgrep's matched source or raw diagnostics.
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo 'Usage: bash scripts/security_semgrep.sh' >&2
  exit 2
fi

security_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$security_root"
if ! command -v semgrep >/dev/null 2>&1; then
  echo 'Semgrep is required. Install it with: brew install semgrep' >&2
  exit 2
fi

umask 077
security_tmp="$(mktemp -d "${TMPDIR:-/tmp}/anistar-semgrep.XXXXXX")"
trap 'rm -rf "$security_tmp"' EXIT
security_status=0
semgrep scan --config "$security_root/.semgrep" --oss-only \
  --metrics=off --disable-version-check --disable-nosem \
  --strict --error --json --quiet --no-rewrite-rule-ids . \
  </dev/null >"$security_tmp/result.json" 2>"$security_tmp/diagnostics" || security_status=$?

# JSON includes snippets and metavariable values. Read only identifiers and
# positions; never echo JSON or diagnostic messages, even after a tool failure.
bash scripts/with_python.sh python3 - "$security_tmp/result.json" "$security_status" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding='utf-8') as result_file:
        result = json.load(result_file)
    status = int(sys.argv[2])
    findings = result['results']
    errors = result['errors']
    scanned = result['paths']['scanned']
    if not isinstance(findings, list) or not isinstance(errors, list) or not isinstance(scanned, list):
        raise ValueError('invalid result structure')
    for finding in findings:
        # JSON encoding also escapes control characters in repository filenames.
        print('Semgrep finding: {}:{} {}'.format(
            json.dumps(finding['path'], ensure_ascii=True),
            int(finding['start']['line']),
            json.dumps(finding['check_id'], ensure_ascii=True),
        ))
    if errors or status not in (0, 1) or not scanned:
        print(f'Semgrep tool error: exit={status}, errors={len(errors)}, scanned={len(scanned)}.', file=sys.stderr)
        sys.exit(status if status not in (0, 1) else 2)
    if findings:
        print(f'Semgrep: {len(findings)} finding(s); {len(scanned)} file(s) scanned.')
        sys.exit(1)
    if status != 0:
        print(f'Semgrep tool error: unexpected exit={status} without findings.', file=sys.stderr)
        sys.exit(2)
    print(f'Semgrep: no findings; {len(scanned)} file(s) scanned.')
except (OSError, ValueError, KeyError, TypeError):
    print('Semgrep tool error: missing or invalid JSON result; raw output withheld.', file=sys.stderr)
    sys.exit(2)
PY
