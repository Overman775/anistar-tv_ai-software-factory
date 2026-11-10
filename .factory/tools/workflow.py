#!/usr/bin/env python3
"""Command entry point; implementation: factory_tooling.runtime.workflow_cli."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

if __name__ == "__main__":
    from factory_tooling.runtime.workflow_cli import main

    main()
