#!/bin/sh
# No PATH lookup, activation, installation or network on ordinary execution.
set -eu
TOOLS=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PYTHON="$TOOLS/../.venv/bin/python"
if [ ! -x "$PYTHON" ]; then
    echo 'Factory Python is not ready. Follow Python setup in .factory/tools/README.md.' >&2
    exit 1
fi
exec "$PYTHON" -E -s -B "$TOOLS/python_runtime.py" run "$@"
