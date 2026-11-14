"""Pinned test configuration, independent of consumer configuration and project files."""

from __future__ import annotations

import shutil
import tempfile
from pathlib import Path

from factory.diagnostics.dry_run import copy_bundle
from factory.paths import FACTORY_ROOT

# Test-only lifetime: all suites share immutable fixture inputs, never consumer settings.
_directory = tempfile.TemporaryDirectory(prefix="factory-test-fixture-")
ROOT = Path(_directory.name).resolve() / ".factory"
copy_bundle(FACTORY_ROOT, ROOT)
for name in ("factory.yaml", "factory.example.yaml"):
    shutil.copy2(FACTORY_ROOT / "tooling/tests/data" / name, ROOT / name)
shutil.copytree(FACTORY_ROOT / "tooling/tests/data/project", ROOT / "project")
