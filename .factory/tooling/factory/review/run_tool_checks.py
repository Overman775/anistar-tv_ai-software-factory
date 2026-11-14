#!/usr/bin/env python3
"""Execute parent-selected local review commands and persist raw results."""

from __future__ import annotations

import argparse
import json
import sys
import tempfile
from collections.abc import Callable, Mapping
from functools import partial
from pathlib import Path
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory.review.review_contracts import IDENTITY_FIELDS
from factory.review.review_evidence import COMMAND_RESULT, TOOL_RESULT, command_outcome
from factory.review.review_shapes import CommandResult, Manifest, ReviewCommand
from factory.runtime.check_process import run_process
from factory.validation import validation_message

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


def load_manifest(path: Path) -> Manifest:
    from factory.project.profile_io import validate_snapshot
    from factory.review.review_contracts import parse_manifest

    value = parse_manifest(json.loads(path.read_text(encoding="utf-8")))
    validate_snapshot(value["project_policy"])
    return value


def identity(manifest: Mapping[str, object]) -> dict[str, object]:
    return {field: manifest[field] for field in IDENTITY_FIELDS}


REVIEW_COMMAND = TypeAdapter[ReviewCommand](ReviewCommand)


def parse_command(raw: str) -> tuple[list[str], str, int]:
    try:
        value = REVIEW_COMMAND.validate_json(raw)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid review command", exc, REVIEW_COMMAND)
        ) from None
    return value["argv"], value.get("cwd", "."), value.get("timeout_seconds", 600)


def excerpt(value: bytes) -> tuple[str, bool]:
    return value[:EXCERPT_BYTES].decode("utf-8", errors="replace"), len(value) > EXCERPT_BYTES


def run_command(
    argv: list[str], cwd: str, timeout_seconds: int = 600, *, log_dir: str | Path | None = None
) -> CommandResult:
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
    manifest: dict[str, Any] | Manifest,
    tool_id: str,
    raw_commands: list[str],
    *,
    not_run_reason: str | None = None,
    not_applicable_reason: str | None = None,
    run: Callable[[list[str], str, int], CommandResult] = run_command,
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
        try:
            commands = [COMMAND_RESULT.validate_python(run(*command)) for command in parsed]
        except ValidationError as exc:
            raise ValueError(
                validation_message("Invalid review command result", exc, COMMAND_RESULT)
            ) from None
        for (argv, cwd, timeout), command in zip(parsed, commands, strict=True):
            if (command["argv"], command.get("cwd", "."), command.get("timeout_seconds", 600)) != (
                argv,
                cwd,
                timeout,
            ):
                raise ValueError("Invalid review command result: command differs from request")
        status, invalid = command_outcome(commands)
        if invalid:
            index, message = invalid[0]
            raise ValueError(f"Invalid review command result [{index}]: {message}")
        result = {
            **identity(manifest),
            "tool_id": tool_id,
            "status": status,
            "reason": None,
            "commands": commands,
        }
    try:
        return dict(TOOL_RESULT.validate_python(result))
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid review tool result", exc, TOOL_RESULT)
        ) from None


def main() -> int:
    args = parse_args()
    try:
        manifest = load_manifest(args.manifest)
        from factory.review.review_plan import validate_plan

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
