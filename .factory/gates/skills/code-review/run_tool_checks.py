#!/usr/bin/env python3
"""Command entry point; implementation: factory_tooling.review.run_tool_checks."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

if __name__ == "__main__":
    from factory_tooling.review.run_tool_checks import main

    sys.exit(main())
