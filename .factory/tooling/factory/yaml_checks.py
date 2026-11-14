"""Validate owned YAML through its runtime contracts without executing project commands."""

from __future__ import annotations

import shutil
import sys
import tempfile
from pathlib import Path

import yaml

from factory.diagnostics.dry_run import copy_bundle
from factory.paths import FACTORY_ROOT
from factory.project.profile_io import load_profile, parse_yaml
from factory.runtime.workflow_config import load_config
from factory.runtime.workflow_core import Invalid


def source_files(agents: Path = FACTORY_ROOT) -> list[Path]:
    if agents.is_symlink() or (agents / "skills").is_symlink():
        raise ValueError(f"symlink YAML discovery root: {agents}")
    roots = [agents / name for name in ("tooling", "project", "gates")]
    roots += sorted((agents / "skills").glob("factory-*"))
    candidates = [file for file in agents.glob("*") if file.suffix in {".yaml", ".yml"}]
    for root in roots:
        if root.is_symlink():
            raise ValueError(f"symlink YAML discovery root: {root}")
        candidates.extend(root.rglob("*"))
    files = set()
    for file in candidates:
        if {
            ".venv",
            "__pycache__",
            ".mypy_cache",
            ".ruff_cache",
            ".pytest_cache",
            "htmlcov",
        }.intersection(file.parts) or file.name.startswith(".coverage"):
            continue
        # rglob does not descend into directory links: reject them before suffix filtering.
        if file.is_symlink() and (
            file.is_dir() or not file.exists() or file.suffix in {".yaml", ".yml"}
        ):
            raise ValueError(f"symlink in owned YAML discovery: {file}")
        if file.suffix in {".yaml", ".yml"} and file.is_file():
            files.add(file)
    return sorted(files)


def _check_files(files: list[Path], agents: Path) -> int:
    if not files:
        print("YAML_CONTRACT: no owned YAML files discovered")
        return 1
    covered: set[Path] = set()
    definitions: list[Path] = []
    failed = False
    for file in files:
        try:
            if file.is_symlink() or any(parent.is_symlink() for parent in file.parents):
                raise ValueError("symlink YAML path")
            data = parse_yaml(file.read_bytes())
            if not isinstance(data, dict):
                raise ValueError("document must be a mapping")
            if file.stem in {"factory", "factory.example"}:
                load_config(file)
            elif file == agents / "tooling/yamllint.yaml":
                # The yamllint stage owns validation of its own configuration.
                continue
            elif (
                file.parent.name == "agents"
                and file.parent.parent.name.startswith("factory-")
                and file.parent.parent.parent == agents / "skills"
                and file.stem == "openai"
            ):
                # Harness metadata has no factory-owned semantic contract.
                print(f"{file}: YAML_SYNTAX: PASS (harness metadata)")
                continue
            elif "id" in data or file.stem in {"project", "project.example"}:
                load_profile(file)
                # Provenance also includes opaque rule files and executable inputs.
                # Only explicitly composed definitions establish semantic coverage.
                covered.update(
                    (file.parent / name).resolve()
                    for field in ("gate_files", "decision_files")
                    for name in data.get(field, [])
                )
            elif set(data) in ({"gates"}, {"decisions"}):
                definitions.append(file)
                continue
            else:
                raise ValueError("unknown YAML contract; associate this file with its owner")
            print(f"{file}: YAML_CONTRACT: PASS")
        except (OSError, ValueError, Invalid, yaml.YAMLError, TypeError, KeyError) as exc:
            failed = True
            print(f"{file}: YAML_CONTRACT: {exc}")
    for file in definitions:
        if file.resolve() not in covered:
            failed = True
            print(f"{file}: YAML_CONTRACT: definition needs a checked owning project profile")
        else:
            print(f"{file}: YAML_CONTRACT: PASS (composed project policy)")
    return int(failed)


def _copy_fixtures(source: Path, target: Path) -> None:
    if source.is_symlink():
        raise ValueError(f"symlink fixture source: {source}")
    # Preflight every path, including non-YAML files, before overlaying anything.
    for file in [source, *source.rglob("*")]:
        if file.is_symlink():
            raise ValueError(f"symlink fixture source: {file}")
        destination = target / file.relative_to(source)
        if any(
            parent.is_symlink()
            for parent in (destination, *destination.parents)
            if parent.is_relative_to(target)
        ):
            raise ValueError(f"symlink fixture destination: {destination}")
        if not destination.resolve().is_relative_to(target.resolve()):
            raise ValueError(f"fixture destination escapes temporary root: {destination}")
    shutil.copytree(source, target, dirs_exist_ok=True, symlinks=True)


def _check(agents: Path) -> int:
    fixtures = agents / "tooling/tests/data"
    files = source_files(agents)
    code = _check_files([file for file in files if not file.is_relative_to(fixtures)], agents)
    fixture_files = [file for file in files if file.is_relative_to(fixtures)]
    if fixture_files:
        # Fixture paths target an installed .factory/project layout, not tests/data.
        with tempfile.TemporaryDirectory(prefix="factory-yaml-fixtures-") as directory:
            target = Path(directory).resolve() / ".factory"
            copy_bundle(agents, target)
            _copy_fixtures(fixtures, target)
            print("Checking pinned YAML fixtures in a disposable installed layout")
            code |= _check_files(
                [target / file.relative_to(fixtures) for file in fixture_files], target
            )
    return code


def check(agents: Path = FACTORY_ROOT) -> int:
    try:
        return _check(agents)
    except (OSError, ValueError, shutil.Error) as exc:
        print(f"{agents}: YAML_CONTRACT: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(check())
