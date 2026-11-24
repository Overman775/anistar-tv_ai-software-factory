"""Select an Implement workspace before intake."""

from __future__ import annotations

import subprocess
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import NotRequired, TypedDict

from factory.environment import settings
from factory.runtime.contracts import Config
from factory.runtime.workflow_core import Invalid, require

BRANCH_PREFIX = "worktree/factory-"


class WorkspaceSelection(TypedDict):
    mode: str
    workspace: str
    config: str
    would_create: NotRequired[bool]
    head: NotRequired[str]


def _git(root: Path, *args: str) -> str:
    env = dict(settings())
    for name in ("GIT_DIR", "GIT_COMMON_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
        env.pop(name, None)
    env["GIT_OPTIONAL_LOCKS"] = "0"
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


def checkout_ref(root: Path) -> str | None:
    """Identify the current branch, or the immutable commit of a detached checkout."""
    if not any((parent / ".git").exists() for parent in (root, *root.parents)):
        return None
    branch = _git(root, "branch", "--show-current")
    return "refs/heads/" + branch if branch else _git(root, "rev-parse", "--verify", "HEAD")


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


def prepare_workspace(
    root: Path,
    config: Config,
    *,
    has_current: Callable[[Path], bool] | None = None,
    dry_run: bool = False,
) -> WorkspaceSelection:
    mode = config["execution"].get("workspace", "shared")
    selected = WorkspaceSelection(mode=mode, workspace=str(root), config=config["_path"])
    if dry_run:
        selected["would_create"] = False
    if mode != "worktree":
        check_workspace(root, config)
        return selected

    config_rel = _worktree_config(root, config)
    if not _linked_factory_worktree(root):
        require(
            Path(_git(root, "rev-parse", "--show-toplevel")).resolve() == root,
            "Prepare the worktree from the Git checkout root",
        )
        if has_current is None:
            from factory.database.provider import current_database

            has_current = current_database().runs.has_current
        require(
            not has_current(root),
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
        selected["workspace"] = str(target)
        selected["config"] = str(target / config_rel)
        if dry_run:
            selected["would_create"] = True
            selected["head"] = head
        else:
            _git(root, "worktree", "add", "-b", BRANCH_PREFIX + key, "--", str(target), head)
    return selected
