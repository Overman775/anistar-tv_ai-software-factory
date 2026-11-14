"""Shared protection for Decompose inputs and output paths."""

import os
import tempfile
from pathlib import Path

from factory.decompose.task_data import load_source_lock
from factory.paths import FACTORY_ROOT
from factory.project.contracts import Policy
from factory.project.profile_io import safe_path


def atomic_write_text(path: str | Path, content: str) -> None:
    """Replace a final path without following a late file alias."""
    target = Path(path)
    fd, temporary = tempfile.mkstemp(prefix=".decompose-output-", dir=target.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(content)
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)


def reject_symlink_ancestors(path: Path) -> None:
    """Check all user-controlled components, excluding the host temp prefix."""
    absolute = path if path.is_absolute() else Path.cwd() / path
    if ".." in absolute.parts:
        raise ValueError("Parent traversal in projection path")
    temp_root = Path(tempfile.gettempdir())
    if absolute.is_relative_to(temp_root):
        base, parts = temp_root.resolve(), absolute.relative_to(temp_root).parts
    else:
        base, parts = Path(absolute.anchor), absolute.parts[1:]
    for part in parts:
        base = base / part
        if base.is_symlink():
            raise ValueError("Symlink in projection path")


def factory_inputs() -> set[Path]:
    """Files bound into the review identity and protected from outputs."""
    # Freeze the gate's actual code, common contract and role instructions as well as project policy.
    required_modules = [
        FACTORY_ROOT / "tooling/factory/runtime/check_process.py",
        FACTORY_ROOT / "tooling/factory/checks/command.py",
    ]
    for module in required_modules:
        safe_path(FACTORY_ROOT, module.relative_to(FACTORY_ROOT).as_posix())
    files: list[Path] = []
    files += list((FACTORY_ROOT / "gates/skills/decompose").glob("*.md")) + list(
        (FACTORY_ROOT / "skills/factory-decompose").rglob("*.md")
    )
    files += [
        FACTORY_ROOT / name
        for name in [
            "roles/task-reviewer.md",
            "contracts/task-reviewer.md",
            "roles/task-decomposer.md",
            "contracts/task-decomposer.md",
            "contracts/common/implementation-detail.md",
        ]
    ]
    files += list((FACTORY_ROOT / "tooling/factory").rglob("*.py"))
    files += list((FACTORY_ROOT / "gates/skills/decompose").glob("*.py"))
    files += list((FACTORY_ROOT / "gates/skills/planning").glob("*.py"))
    return {safe_path(FACTORY_ROOT, p.relative_to(FACTORY_ROOT).as_posix()) for p in files}


def protected_inputs(
    config: str | Path, staging: str | Path, source: str | Path, policy: Policy
) -> set[Path]:
    """Inventory all source, policy and project materials before any output write."""
    protected = {Path(config).resolve(), Path(staging).resolve(), Path(source).resolve()}
    protected.update(Path(path).resolve() for path in policy["files"])
    protected.update(path.resolve() for path in factory_inputs())
    protected.add((Path(policy["workspace"]) / "AGENTS.md").resolve())
    lock, _ = load_source_lock(source)
    if lock and isinstance(lock.get("plan_path"), str):
        protected.add(Path(lock["plan_path"]).resolve())
    for document in policy["data"].get("documents", {}).values():
        protected.add((Path(policy["workspace"]) / document["path"]).resolve())
    for rules in policy["data"].get("rules", {}).values():
        for rule in rules:
            if rule.get("project_file"):
                protected.add((Path(policy["workspace"]) / rule["project_file"]).resolve())
    return protected


def guard_output(output: str | Path, protected: set[Path]) -> None:
    path = Path(output)
    reject_symlink_ancestors(path)
    if path.is_file() and path.stat().st_nlink != 1:
        raise ValueError("Output must not use a hardlink")
    target = path.resolve()
    if any(
        target == item or target.is_relative_to(item) or item.is_relative_to(target)
        for item in protected
    ):
        raise ValueError("Output must not overwrite or overlap protected inputs")


def guard_evidence_aliases(output_dir: str | Path) -> None:
    """Reject existing aliases before commands or logs can follow them."""
    root = Path(output_dir)
    if root.is_symlink():
        raise ValueError("Evidence directory contains a symlink")
    if not root.exists():
        return
    if not root.is_dir():
        raise ValueError("Evidence directory is not a directory")
    for path in root.rglob("*"):
        if path.is_symlink() or (path.is_file() and path.stat().st_nlink != 1):
            raise ValueError("Evidence directory contains a symlink or hardlink")
