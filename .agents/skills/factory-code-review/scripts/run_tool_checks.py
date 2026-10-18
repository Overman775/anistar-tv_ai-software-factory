#!/usr/bin/env python3
"""Execute parent-selected local review commands and persist raw results."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = "3"
TOOL_IDS = ("static", "tests", "deps")
IDENTITY_FIELDS = (
    "schema_version",
    "review_id",
    "mode",
    "base_sha",
    "head_sha",
    "scope_hash",
)
EXCERPT_BYTES = 24 * 1024


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--tool-id", choices=TOOL_IDS, required=True)
    parser.add_argument(
        "--command",
        action="append",
        default=[],
        help='JSON object: {"argv":["cmd","arg"],"cwd":"."}. Repeatable.',
    )
    parser.add_argument("--not-run-reason")
    parser.add_argument("--not-applicable-reason")
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def load_manifest(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("manifest must be a JSON object")
    if value.get("schema_version") != SCHEMA_VERSION:
        raise ValueError(f"manifest schema_version must be {SCHEMA_VERSION}")
    for field in IDENTITY_FIELDS:
        if field not in value:
            raise ValueError(f"manifest missing {field}")
    return value


def identity(manifest: dict[str, Any]) -> dict[str, Any]:
    return {field: manifest[field] for field in IDENTITY_FIELDS}


def parse_command(raw: str) -> tuple[list[str], str]:
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise ValueError("command must be a JSON object")
    argv = value.get("argv")
    cwd = value.get("cwd", ".")
    if (
        not isinstance(argv, list)
        or not argv
        or any(not isinstance(item, str) or not item for item in argv)
    ):
        raise ValueError("command argv must be nonempty strings")
    if not isinstance(cwd, str) or not cwd:
        raise ValueError("command cwd must be nonempty")
    return argv, cwd


def excerpt(value: bytes) -> tuple[str, bool]:
    return value[:EXCERPT_BYTES].decode("utf-8", errors="replace"), len(value) > EXCERPT_BYTES


def run_command(argv: list[str], cwd: str) -> dict[str, Any]:
    completed = subprocess.run(
        argv,
        cwd=cwd,
        capture_output=True,
        check=False,
    )
    stdout_excerpt, stdout_truncated = excerpt(completed.stdout)
    stderr_excerpt, stderr_truncated = excerpt(completed.stderr)
    return {
        "argv": argv,
        "cwd": cwd,
        "exit_code": completed.returncode,
        "stdout_excerpt": stdout_excerpt,
        "stderr_excerpt": stderr_excerpt,
        "stdout_truncated": stdout_truncated,
        "stderr_truncated": stderr_truncated,
    }


def default_output(tool_id: str) -> Path:
    return Path(f".ai-pipeline/state/review-tool-{tool_id}.json")


def main() -> int:
    args = parse_args()
    try:
        manifest = load_manifest(args.manifest)
        if args.not_run_reason or args.not_applicable_reason:
            if args.command:
                raise ValueError("applicability reason cannot be combined with --command")
            if args.not_run_reason and args.not_applicable_reason:
                raise ValueError("choose NOT_RUN or NOT_APPLICABLE, not both")
            result = {
                **identity(manifest),
                "tool_id": args.tool_id,
                "status": "NOT_RUN" if args.not_run_reason else "NOT_APPLICABLE",
                "reason": args.not_run_reason or args.not_applicable_reason,
                "commands": [],
            }
        else:
            if not args.command:
                raise ValueError(
                    "at least one --command, --not-run-reason, or "
                    "--not-applicable-reason required"
                )
            commands = [run_command(*parse_command(raw)) for raw in args.command]
            result = {
                **identity(manifest),
                "tool_id": args.tool_id,
                "status": (
                    "FAIL"
                    if any(command["exit_code"] != 0 for command in commands)
                    else "PASS"
                ),
                "reason": None,
                "commands": commands,
            }
        output = args.output or default_output(args.tool_id)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, ensure_ascii=False))
        return 1 if result["status"] == "FAIL" else 0
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
