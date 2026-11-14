#!/usr/bin/env python3
"""Command entry point; implementation: factory.decompose.generate_task_graph."""

import runpy
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tooling"))

if __name__ == "__main__":
    runpy.run_module("factory.decompose.generate_task_graph", run_name="__main__")
