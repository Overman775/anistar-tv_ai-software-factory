#!/usr/bin/env bash
# Ensure nested E2E tools also resolve python3 to a supported interpreter.
set -euo pipefail
[[ $# -gt 0 ]] || { echo 'Usage: with_python.sh command [arguments]' >&2; exit 64; }
selected_python=''
if [[ -n ${ANISTAR_PYTHON:-} ]]; then
  candidates=("$ANISTAR_PYTHON")
else
  candidates=(python3 python3.14 python3.13 python3.12 python3.11 python3.10)
fi
for candidate in "${candidates[@]}"; do
  if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
    selected_python=$("$candidate" -c 'import sys; print(sys.executable)')
    break
  fi
done
[[ -n $selected_python ]] || { echo 'Python 3.10+ required. Install it or set ANISTAR_PYTHON to its executable.' >&2; exit 1; }
shim_dir=$(mktemp -d "${TMPDIR:-/tmp}/anistar-python.XXXXXX")
trap 'rm -f "$shim_dir/python3"; rmdir "$shim_dir"' EXIT
ln -s "$selected_python" "$shim_dir/python3"
export PATH="$shim_dir:$PATH"
"$@"
