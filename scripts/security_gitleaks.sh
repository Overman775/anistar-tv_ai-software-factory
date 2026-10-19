#!/usr/bin/env bash
set -euo pipefail

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"

if [[ $# != 1 || ( $1 != staged && $1 != history ) ]]; then
  echo 'Usage: bash scripts/security_gitleaks.sh staged|history' >&2
  exit 64
fi
if ! command -v gitleaks >/dev/null 2>&1; then
  echo 'Gitleaks is required. Install with: brew install gitleaks' >&2
  exit 127
fi

scan_args=()
if [[ $1 == staged ]]; then
  # NUL-delimited paths also handle spaces/newlines. Never stash or change index.
  staged_paths=$(mktemp)
  trap 'rm -f "$staged_paths"' EXIT
  git diff --cached --name-only --no-renames --diff-filter=ACMRT -z > "$staged_paths"
  while IFS= read -r -d '' staged_path; do
    case "$staged_path" in
      env/*.local.json|env/prod.json|*.jks|*.keystore|*.p12|*.pfx|\
      key.properties|*/key.properties|signing.properties|*/signing.properties|\
      keystore.properties|*/keystore.properties)
        echo 'Sensitive local credentials or Android signing file is staged. Remove it from the index; use public env/*.example.json templates.' >&2
        exit 1
        ;;
    esac
  done < "$staged_paths"
  scan_args=(--pre-commit --staged)
else
  if [[ $(git rev-parse --is-shallow-repository) != false ]]; then
    echo 'Full secrets history scan requires a complete local clone. Fetch the missing history before retrying.' >&2
    exit 2
  fi
  scan_args=(--log-opts='--all --full-history')
fi

# Ignore inline suppression comments; no baseline or extra local ignore file.
# Default non-verbose output omits source lines, commit messages and secret values.
if gitleaks git --config .gitleaks.toml --redact=100 --no-banner --no-color \
  --ignore-gitleaks-allow --gitleaks-ignore-path /dev/null --exit-code 3 \
  "${scan_args[@]}" . 2>&1; then
  exit 0
else
  scan_status=$?
  if [[ $scan_status == 3 ]]; then
    echo 'Gitleaks found secrets. Review the findings locally with redaction enabled; do not commit or share secret values.' >&2
    exit 1
  else
    echo 'Gitleaks could not complete the scan. Check the installed tool and repository configuration.' >&2
    exit 2
  fi
fi
