#!/usr/bin/env python3
"""Execute parent-selected local review commands and persist raw results."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from collections.abc import Callable
from functools import partial
from pathlib import Path
from typing import Any

from factory_tooling.review.review_contracts import IDENTITY_FIELDS, SCHEMA_VERSION
from factory_tooling.runtime.check_process import run_process
from factory_tooling.runtime.command_contract import validate_execution

EXCERPT_BYTES = 24 * 1024


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--tool-id", required=True)
    parser.add_argument(
        "--command",
        action="append",
        default=[],
        help='JSON object: {"argv":["cmd","arg"],"cwd":".","timeout_seconds":600}. Repeatable.',
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
    from factory_tooling.project.profile_io import validate_snapshot

    validate_snapshot(value.get("project_policy"))
    return value


def identity(manifest: dict[str, Any]) -> dict[str, Any]:
    return {field: manifest[field] for field in IDENTITY_FIELDS}


def parse_command(raw: str) -> tuple[list[str], str, int]:
    value = json.loads(raw)
    if not isinstance(value, dict):
        raise ValueError("command must be a JSON object")
    if set(value) - {"argv", "cwd", "timeout_seconds"}:
        raise ValueError("unknown review command field")
    execution = {"cwd": ".", "timeout_seconds": 600, **value}
    validate_execution(execution)
    return execution["argv"], execution["cwd"], execution["timeout_seconds"]


def excerpt(value: bytes) -> tuple[str, bool]:
    return value[:EXCERPT_BYTES].decode("utf-8", errors="replace"), len(value) > EXCERPT_BYTES


def run_command(
    argv: list[str], cwd: str, timeout_seconds: int = 600, *, log_dir: str | Path | None = None
) -> dict[str, Any]:
    log_dir = Path(log_dir or Path(cwd) / ".factory/memory/state/review-logs").resolve()
    log_dir.mkdir(parents=True, exist_ok=True)
    folder = Path(tempfile.mkdtemp(prefix="command-", dir=log_dir))
    stdout, stderr = folder / "stdout.log", folder / "stderr.log"
    result = run_process(
        {"argv": argv, "cwd": cwd, "timeout_seconds": timeout_seconds},
        Path(cwd),
        stdout,
        stderr=stderr,
    )
    # Bound memory as well as the report; full output remains in the log files.
    with stdout.open("rb") as stream:
        stdout_excerpt, stdout_truncated = excerpt(stream.read(EXCERPT_BYTES + 1))
    with stderr.open("rb") as stream:
        stderr_excerpt, stderr_truncated = excerpt(stream.read(EXCERPT_BYTES + 1))
    return {
        "argv": argv,
        "cwd": cwd,
        "timeout_seconds": timeout_seconds,
        **result,
        "stdout_path": str(stdout),
        "stderr_path": str(stderr),
        "stdout_excerpt": stdout_excerpt,
        "stderr_excerpt": stderr_excerpt,
        "stdout_truncated": stdout_truncated,
        "stderr_truncated": stderr_truncated,
    }


def default_output(tool_id: str) -> Path:
    return Path(f"review-tool-{tool_id}.json")


def collect_results(
    manifest: dict[str, Any],
    tool_id: str,
    raw_commands: list[str],
    *,
    not_run_reason: str | None = None,
    not_applicable_reason: str | None = None,
    run: Callable[[list[str], str, int], dict[str, Any]] = run_command,
) -> dict[str, Any]:
    """Build one tool result with an injected command runner; no artifact writes.

    Validate the complete command list before executing the first command.
    """
    if not_run_reason or not_applicable_reason:
        if raw_commands:
            raise ValueError("applicability reason cannot be combined with --command")
        if not_run_reason and not_applicable_reason:
            raise ValueError("choose NOT_RUN or NOT_APPLICABLE, not both")
        result = {
            **identity(manifest),
            "tool_id": tool_id,
            "status": "NOT_RUN" if not_run_reason else "NOT_APPLICABLE",
            "reason": not_run_reason or not_applicable_reason,
            "commands": [],
        }
    else:
        if not raw_commands:
            raise ValueError(
                "at least one --command, --not-run-reason, or --not-applicable-reason required"
            )
        parsed = [parse_command(raw) for raw in raw_commands]
        commands = [run(*command) for command in parsed]
        result = {
            **identity(manifest),
            "tool_id": tool_id,
            "status": (
                "FAIL"
                if any(
                    command["exit_code"] is not None
                    and command["exit_code"] != 0
                    and not command.get("error")
                    for command in commands
                )
                else "BLOCKED"
                if any(command.get("error") for command in commands)
                else "PASS"
            ),
            "reason": None,
            "commands": commands,
        }
    return result


def main() -> int:
    args = parse_args()
    try:
        manifest = load_manifest(args.manifest)
        from factory_tooling.review.review_plan import validate_plan

        validate_plan(manifest)
        check = next((c for c in manifest["checks"] if c["id"] == args.tool_id), None)
        if check is None:
            raise ValueError("check not in pinned plan")
        if check.get("after"):
            raise ValueError("dependent checks must run through review_run.py check")
        if args.not_applicable_reason:
            raise ValueError("planned check cannot be waived")
        planned = {
            k: check["execution"][k]
            for k in ("argv", "cwd", "timeout_seconds")
            if k in check["execution"]
        }
        if args.command and [parse_command(x) for x in args.command] != [
            parse_command(json.dumps(planned))
        ]:
            raise ValueError("command differs from pinned plan")
        args.command = [] if args.not_run_reason else [json.dumps(planned)]
        output = args.output or args.manifest.parent / default_output(args.tool_id)
        result = collect_results(
            manifest,
            args.tool_id,
            args.command,
            not_run_reason=args.not_run_reason,
            not_applicable_reason=args.not_applicable_reason,
            run=partial(run_command, log_dir=output.parent / (output.stem + "-logs")),
        )
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(result, ensure_ascii=False))
        return 2 if result["status"] == "BLOCKED" else 1 if result["status"] == "FAIL" else 0
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
