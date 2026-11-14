"""Locations owned by this installed factory bundle."""

from pathlib import Path

TOOLING_ROOT = Path(__file__).resolve().parents[1]
FACTORY_ROOT = TOOLING_ROOT.parent
TOOLS = TOOLING_ROOT
BIN = TOOLING_ROOT / "bin"
PACKAGE = TOOLING_ROOT / "factory"
TESTS = TOOLING_ROOT / "tests"
