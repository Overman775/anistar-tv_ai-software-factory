#!/usr/bin/env python3
"""Command entry point; implementation: factory.review.run_tool_checks."""

import sys

if __name__ == "__main__":
    from factory.review.run_tool_checks import main

    sys.exit(main())
