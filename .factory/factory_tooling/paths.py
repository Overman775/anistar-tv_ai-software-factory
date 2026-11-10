"""Locations owned by this installed factory bundle."""

from pathlib import Path

FACTORY_ROOT = Path(__file__).resolve().parents[1]
TOOLS = FACTORY_ROOT / "tools"
