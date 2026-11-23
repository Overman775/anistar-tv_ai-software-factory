"""Shared protection for Decompose inputs and output paths."""

import os
import tempfile
from pathlib import Path

from factory import file_reader
from factory.context.context import WORKER_PROFILE_FIELDS, factory_materials
from factory.decompose.graph.task_data import load_source_lock
from factory.paths import FACTORY_ROOT
from factory.project.contracts import Policy
from factory.project.profile_io import parse_yaml, safe_path, sha
from factory.runtime.workflow_config import expand_profiles


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
    """Factory files protected from outputs, including unrelated tools."""
    # Freeze the gate's actual code, common contract and role instructions as well as project policy.
    required_modules = [
        FACTORY_ROOT / "tooling/factory/runtime/commands/process.py",
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
            "contracts/common/communication.md",
            "contracts/common/agent-checkpoint.md",
            "contracts/common/worker-rules.md",
            "contracts/common/project-policy.md",
            "adapters/worker/common.md",
            "gates/common/verification-rules.md",
        ]
    ]
    files += list((FACTORY_ROOT / "tooling/factory").rglob("*.py"))
    files += list((FACTORY_ROOT / "contracts/common").rglob("*.md"))
    files += list((FACTORY_ROOT / "adapters/worker").rglob("*.md"))
    files += list((FACTORY_ROOT / "gates/skills/decompose").glob("*.py"))
    files += list((FACTORY_ROOT / "gates/skills/planning").glob("*.py"))
    return {safe_path(FACTORY_ROOT, p.relative_to(FACTORY_ROOT).as_posix()) for p in files}


def configured_worker_inputs(config: str | Path) -> set[Path]:
    """Resolve explicitly configured worker instructions, including custom paths."""
    config = Path(config).absolute()
    data = parse_yaml(file_reader.read_bytes(config))
    adapters = data.get("adapters", {})
    if not isinstance(adapters, dict):
        raise ValueError("Adapters must be a mapping")
    result = set()
    for adapter in adapters.values():
        if not isinstance(adapter, dict):
            raise ValueError("Adapter must be a mapping")
        if "worker_instructions" in adapter:
            result.add(safe_path(config.parent, adapter["worker_instructions"]))
    return result


def review_inputs() -> set[Path]:
    """Review instructions and the code dependencies of assembly and its gates."""
    inputs = factory_inputs()
    package = FACTORY_ROOT / "tooling/factory"
    relevant_packages = {
        "decompose",
        "planning",
        "tasks",
        "project",
        "gates",
        "checks",
        "decisions",
    }
    shared = {"__init__.py", "file_reader.py", "markdown.py", "paths.py", "validation.py"}
    runtime = {
        package / "runtime/commands/process.py",
        package / "runtime/workflow_config.py",
        package / "runtime/workflow_core.py",
    }
    return {
        path
        for path in inputs
        if path.suffix == ".py"
        and (
            not path.is_relative_to(package)
            or (len(path.relative_to(package).parts) == 1 and path.name in shared)
            or path.relative_to(package).parts[0] in relevant_packages
            or path in runtime
            or path == package / "context/context.py"
        )
    }


def review_worker_materials(config: str | Path, selected: dict[str, str]) -> dict[str, object]:
    """Bind the same documents that the selected Decompose packets receive."""
    location = Path(config).resolve()
    settings = parse_yaml(file_reader.read_bytes(location))
    if "profiles" not in settings:
        # A graph-only configuration may carry just a project profile.
        location = FACTORY_ROOT / "factory.yaml"
        settings = parse_yaml(file_reader.read_bytes(location))
    profiles, defaults = expand_profiles(settings["profiles"])
    adapters = settings["adapters"]
    result: dict[str, object] = {}
    for role in ("task-decomposer", "task-reviewer"):
        role_path = f"roles/{role}.md"
        name = (
            selected.get(role)
            or defaults.get(role_path)
            or next((name for name, p in profiles.items() if p["role"] == role_path), "")
        )
        profile = profiles.get(name)
        if profile is None or profile["role"] != role_path:
            raise ValueError(f"Unknown Decompose profile for {role}: {name}")
        if profile["enforcement"] != "instructions":
            raise ValueError(f"Unsupported enforcement for {role}: {name}")
        adapter = adapters[profile["adapter"]]
        repair_allowed = role == "task-reviewer" and profile["capabilities"]["edit"]
        assignment = {"decompose_mode": "repair"} if repair_allowed else {}
        materials = factory_materials(
            profile, adapter["worker_instructions"], role, "decompose", {}, assignment
        )
        result[role] = {
            "name": name,
            "profile": {
                key: value for key, value in profile.items() if key in WORKER_PROFILE_FIELDS
            },
            "model": settings["models"][profile["model"]],
            "instructions": {
                rel: sha(file_reader.read_bytes(safe_path(location.parent, rel)))
                for rel, _ in materials
            },
        }
    return result


def protected_inputs(
    config: str | Path, staging: str | Path, source: str | Path, policy: Policy
) -> set[Path]:
    """Inventory all source, policy and project materials before any output write."""
    protected = {Path(config).resolve(), Path(staging).resolve(), Path(source).resolve()}
    protected.update(Path(path).resolve() for path in policy["files"])
    protected.update(path.resolve() for path in factory_inputs())
    protected.update(path.resolve() for path in configured_worker_inputs(config))
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
