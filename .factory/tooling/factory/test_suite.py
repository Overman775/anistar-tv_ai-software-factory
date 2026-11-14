"""Discover every factory suite; an empty or missing suite is an error."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from typing import Any

from factory.paths import FACTORY_ROOT

SUITES = (
    "adapters",
    "context",
    "decisions",
    "diagnostics",
    "gates",
    "project",
    "../infrastructure/python_runtime",
    "runtime",
    "planning",
    "decompose",
    "review",
    "github",
)


class FactoryLoader(unittest.TestLoader):
    def _find_test_path(self, full_path: str, pattern: str, *args: Any) -> Any:
        if {
            ".venv",
            "__pycache__",
            ".mypy_cache",
            ".ruff_cache",
            ".pytest_cache",
            "htmlcov",
        }.intersection(Path(full_path).parts):
            return None, False
        return super()._find_test_path(full_path, pattern, *args)  # type: ignore[misc]


def main() -> int:
    loader = FactoryLoader()
    for name in SUITES:
        discovered = loader.discover(
            str(FACTORY_ROOT / "tooling/tests/factory" / name),
            top_level_dir=str(FACTORY_ROOT / "tooling"),
        )
        count = discovered.countTestCases()
        if not count:
            print(f"BLOCKED: no tests discovered in {name}", file=sys.stderr)
            return 2
        print(f"{name}: {count} tests", flush=True)
    tests = FACTORY_ROOT / "tooling/tests"
    for file in tests.rglob("test*.py"):
        if {
            ".venv",
            "__pycache__",
            ".mypy_cache",
            ".ruff_cache",
            ".pytest_cache",
            "htmlcov",
        }.intersection(file.parts):
            continue
        for directory in file.relative_to(tests).parents:
            if not (tests / directory / "__init__.py").is_file():
                print(f"BLOCKED: test package missing __init__.py: {file}", file=sys.stderr)
                return 2
    suite = loader.discover(str(tests), top_level_dir=str(FACTORY_ROOT / "tooling"))
    return 0 if unittest.TextTestRunner(verbosity=1).run(suite).wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
