"""Select an Implement workspace before intake."""

from __future__ import annotations

import os
import subprocess
import uuid
from pathlib import Path

from factory.runtime.contracts import Config
from factory.runtime.workflow_core import Invalid, require

BRANCH_PREFIX = "worktree/factory-"


def _git(root: Path, *args: str) -> str:
    env = os.environ.copy()
    for name in ("GIT_DIR", "GIT_COMMON_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
        env.pop(name, None)
    result = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, text=True, env=env, check=False
    )
    require(result.returncode == 0, f"Git workspace preparation failed: {result.stderr.strip()}")
    return result.stdout.rstrip("\r\n")


def _linked_factory_worktree(root: Path) -> bool:
    if not (root / ".git").is_file():
        return False
    git_dir, common_dir, top = _git(
        root,
        "rev-parse",
        "--path-format=absolute",
        "--git-dir",
        "--git-common-dir",
        "--show-toplevel",
    ).splitlines()
    return (
        Path(top).resolve() == root
        and Path(git_dir).resolve() != Path(common_dir).resolve()
        and _git(root, "rev-parse", "--abbrev-ref", "HEAD").startswith(BRANCH_PREFIX)
    )


def _worktree_config(root: Path, config: Config) -> Path:
    path = Path(config["_path"])
    require(
        path.is_relative_to(root / ".factory"), "Use the factory config in the selected checkout"
    )
    return path.relative_to(root)


def check_workspace(root: Path, config: Config) -> None:
    mode = config["execution"].get("workspace", "shared")
    if mode == "container":
        raise Invalid("Container workspace is not implemented; select shared or worktree")
    if mode == "worktree":
        _worktree_config(root, config)
        require(
            _linked_factory_worktree(root), "Run prepare-workspace and use the returned worktree"
        )


def prepare_workspace(root: Path, config: Config) -> dict[str, str]:
    mode = config["execution"].get("workspace", "shared")
    if mode != "worktree":
        check_workspace(root, config)
        return {"mode": mode, "workspace": str(root), "config": config["_path"]}

    config_rel = _worktree_config(root, config)
    if not _linked_factory_worktree(root):
        require(
            Path(_git(root, "rev-parse", "--show-toplevel")).resolve() == root,
            "Prepare the worktree from the Git checkout root",
        )
        require(
            not (root / ".factory/memory/state/workflow.json").exists(),
            "Existing run: resume or archive/clean it first",
        )
        require(
            not _git(root, "status", "--porcelain", "--untracked-files=normal"),
            "Worktree requires a clean checkout; commit intended inputs or select shared",
        )
        head = _git(root, "rev-parse", "--verify", "HEAD")
        _git(root, "ls-files", "--error-unmatch", "--", config_rel.as_posix())
        key = uuid.uuid4().hex[:12]
        target = root.with_name(f"{root.name}-factory-{key}")
        _git(root, "worktree", "add", "-b", BRANCH_PREFIX + key, "--", str(target), head)
        root = target
    return {"mode": mode, "workspace": str(root), "config": str(root / config_rel)}
