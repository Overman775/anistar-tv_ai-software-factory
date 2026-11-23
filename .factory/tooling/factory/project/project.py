#!/usr/bin/env python3
"""Inspect project obligations without invoking agents or project commands."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

from factory import file_reader
from factory.logging_config import diagnostic_operation
from factory.project.contracts import (
    AcceptedDocument,
    Snapshot,
)
from factory.project.profile_io import (
    compose_profile,
    load_profile,
    material_entries,
    parse_yaml,
    review_materials,
    safe_path,
    sha,
    snapshot,
    validate_snapshot,
)
from factory.project.profile_rules import (
    PROCESSES,
    document_paths,
    local_policy_files,
    project_checks,
    relative,
    require,
    required_checks,
    review_criteria,
    select_rules,
)


def configured_profile(config: str | Path) -> Path:
    config = Path(config).absolute()
    data = parse_yaml(file_reader.read_bytes(config))
    from factory.project.profile_io import safe_path

    return safe_path(config.parent, data.get("project"))


def review_snapshot(
    workspace: str | Path, revision: str, profile_path: str | Path = ".factory/project/project.yaml"
) -> Snapshot:
    """Read accepted Git policy bytes, never a candidate working-tree override."""
    relative(profile_path)
    workspace = Path(workspace).absolute()
    git_root = Path(
        subprocess.run(
            ["git", "-C", str(workspace), "rev-parse", "--show-toplevel"],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.removesuffix("\n")
    ).resolve()
    object_format = subprocess.run(
        ["git", "-C", str(git_root), "rev-parse", "--show-object-format=storage"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    length = {"sha1": 40, "sha256": 64}.get(object_format)
    require(
        length is not None
        and isinstance(revision, str)
        and re.fullmatch(r"[0-9a-fA-F]{" + str(length) + r"}", revision) is not None,
        "full baseline commit SHA required",
    )
    revision = revision.lower()
    object_type = subprocess.run(
        ["git", "-C", str(git_root), "cat-file", "-t", revision],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
    require(object_type == "commit", "full baseline commit SHA required")
    anchor = next(
        (
            parent
            for parent in reversed((workspace, *workspace.parents))
            if not parent.is_symlink() and parent.samefile(git_root)
        ),
        None,
    )
    require(anchor is not None, "workspace is outside the Git root")
    assert anchor is not None
    workspace_prefix = workspace.relative_to(anchor)

    def read(file: Path) -> bytes:
        parts: list[str] = []
        # Check traversed components before normalizing .., including workspace aliases.
        for component in (*workspace_prefix.parts, *file.relative_to(workspace).parts):
            if component == "..":
                require(parts, "workspace is outside the Git root")
                parts.pop()
                continue
            parts.append(component)
            part = "/".join(parts)
            mode = subprocess.run(
                ["git", "-C", str(git_root), "ls-tree", revision, "--", ":(literal)" + part],
                check=True,
                capture_output=True,
            ).stdout
            require(
                mode and not mode.startswith(b"120000"), f"missing/symlink baseline policy: {part}"
            )
        rel = "/".join(parts)
        return subprocess.run(
            ["git", "-C", str(git_root), "show", f"{revision}:{rel}"],
            check=True,
            capture_output=True,
        ).stdout

    # load_profile normally checks local files. Materialize only the selected
    # trusted policy into a temporary bundle, preserving relative provenance.
    import tempfile

    profile_raw = read(workspace / profile_path)
    definition_bytes = {}

    def read_definition(rel: str) -> bytes:
        definition_bytes[rel] = read(workspace / Path(profile_path).parent / rel)
        return definition_bytes[rel]

    data, definition_paths = compose_profile(profile_raw, read_definition)
    project_paths = {"AGENTS.md"}
    user_path = ".factory/memory/USER.md"
    user_entry = subprocess.run(
        [
            "git",
            "-C",
            str(git_root),
            "ls-tree",
            revision,
            "--",
            ":(literal)" + (workspace_prefix / user_path).as_posix(),
        ],
        check=True,
        capture_output=True,
    )
    if user_entry.stdout:
        project_paths.add(user_path)
    for audience, role in [("worker", "reviewer"), ("coordinator", None)]:
        for rule in select_rules(
            data, process="code-review", audience=audience, role=role, stage="review", scope=None
        ):
            if "file" not in rule:
                project_paths.update(document_paths(data, rule))
    documents: dict[str, AcceptedDocument] = {}
    for rel in sorted(project_paths):
        raw = read(workspace / rel)
        documents[rel] = dict(content=raw.decode("utf-8"), sha256=sha(raw))
    with tempfile.TemporaryDirectory(prefix="factory-policy-") as tmp:
        root = Path(tmp)
        target = root / profile_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(profile_raw)
        local_paths = definition_paths + local_policy_files(data, str(Path(profile_path).parent))
        for rel in local_paths:
            dest = target.parent / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(
                definition_bytes[rel]
                if rel in definition_bytes
                else read(workspace / Path(profile_path).parent / rel)
            )
        return snapshot(
            load_profile(target, workspace_root=root), source="git:" + revision, documents=documents
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", default=".factory/factory.yaml")
    parser.add_argument("--workspace", default=".")
    sub = parser.add_subparsers(dest="action", required=True)
    explain = sub.add_parser("context", help="Resolve coordinator or worker project reading")
    explain.add_argument("--process", choices=sorted(PROCESSES), required=True)
    explain.add_argument("--audience", choices=["coordinator", "worker"], required=True)
    explain.add_argument("--role")
    explain.add_argument("--stage")
    explain.add_argument(
        "--policy-snapshot", help="Required accepted policy JSON for standalone review"
    )
    explain.add_argument(
        "--scope", action="append", help="Repeat exact project-relative path; absent means unknown"
    )
    checks = sub.add_parser("checks", help="Resolve mandatory Implement checks from a task JSON")
    checks.add_argument("task")
    checks.add_argument("--final", action="store_true")
    review = sub.add_parser(
        "review-policy", help="Capture accepted baseline policy before candidate review"
    )
    review.add_argument("--revision", required=True)
    review.add_argument("--profile-path", default=".factory/project/project.yaml")
    args = parser.parse_args()
    result: object
    try:
        with diagnostic_operation(args.workspace, "project." + args.action):
            if args.action == "review-policy":
                result = review_snapshot(args.workspace, args.revision, args.profile_path)
            elif args.action == "context" and args.process == "code-review":
                require(
                    args.policy_snapshot,
                    "standalone review needs --policy-snapshot from accepted baseline",
                )
                pinned = json.loads(
                    file_reader.read_text(Path(args.policy_snapshot), encoding="utf-8")
                )
                data = validate_snapshot(pinned)
                result = {
                    "project": data["id"],
                    "policy_hash": pinned["sha256"],
                    "scope_status": "unknown" if args.scope is None else "known",
                    "review_criteria": review_criteria(data, "code-review.complete"),
                    "gates": [
                        g for g in data.get("gates", []) if "code-review.complete" in g["at"]
                    ],
                    "instructions": review_materials(
                        pinned,
                        Path(args.config).absolute().parent,
                        Path(args.workspace).resolve(),
                        role=args.role,
                        stage=args.stage or "review",
                        scope=args.scope,
                        audience=args.audience,
                    ),
                }
            else:
                require(
                    args.action != "context" or not args.policy_snapshot,
                    "review snapshot only belongs to code-review",
                )
                policy = load_profile(configured_profile(args.config))
                if args.action == "checks":
                    result = required_checks(
                        policy["data"],
                        json.loads(file_reader.read_text(Path(args.task), encoding="utf-8")),
                        final=args.final,
                    )
                else:
                    user = safe_path(
                        Path(args.config).resolve().parent, "memory/USER.md", exists=False
                    )
                    instructions = material_entries(
                        policy,
                        args.workspace,
                        process=args.process,
                        audience=args.audience,
                        role=args.role,
                        stage=args.stage,
                        scope=args.scope,
                        user=user if user.is_file() else None,
                    )
                    result = {
                        "project": policy["data"]["id"],
                        "policy_hash": policy["hash"],
                        "scope_status": "unknown" if args.scope is None else "known",
                        "gates": [
                            g
                            for g in policy["data"].get("gates", [])
                            if any(at.startswith(args.process + ".") for at in g["at"])
                        ],
                        "decisions": policy["data"].get("decisions", []),
                        "checks": project_checks(policy["data"], all_processes=False)
                        if args.process == "implement"
                        else [],
                        "review_criteria": review_criteria(policy["data"])
                        if args.process in {"code-review", "code-audit", "implement"}
                        else [],
                        "instructions": instructions,
                    }
            print(json.dumps(result, ensure_ascii=False, indent=2))
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f"BLOCKED: {exc}\n")


if __name__ == "__main__":
    main()
