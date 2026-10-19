#!/usr/bin/env bash
set -euo pipefail

# Lefthook 2.2.2 also uses this flag to disable its automatic partial-file stash.
# Check the current worktree without hiding unstaged changes or staging files.
if [[ ${1:-} == run && ${2:-} == pre-commit ]]; then
  exec lefthook "$@" --no-stage-fixed
fi
exec lefthook "$@"
