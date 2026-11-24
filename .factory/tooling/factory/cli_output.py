"""Shared machine output for the project launcher and factory CLI."""

import json
import os
import sys
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from contextvars import ContextVar
from io import TextIOWrapper

LAUNCHER = r".\.factory\tooling\bin\cli.cmd" if os.name == "nt" else ".factory/tooling/bin/cli"

CLI_ERROR_GUIDANCE = {
    "usage_error": "Run the command with --help and correct the arguments.",
    "environment_not_ready": f"Run `{LAUNCHER} setup` from the checkout that owns this launcher.",
    "setup_failed": "Check the setup error, the selected Python 3.14 and the checkout's permissions.",
    "decompose_graph": f"Check the staging task inputs and run `{LAUNCHER} decompose graph --help` for accepted paths.",
    "decompose_source_lock": "Verify the approved plan, review evidence and source paths before retrying.",
    "decompose_assemble": "Check the staging bundle, approval evidence and permitted output paths.",
    "pr_note": "Check the comment ID and kind, or provide the corresponding comment list on stdin.",
    "pr_recent_notes": "Check the pull request, requested comment kind and GitHub access.",
    "review_run": "Check the run directory and the assignment or check selected for this action.",
    "review_checks": "Check the pinned assignment, command ID and review checkout.",
    "journal_unavailable": "Check the checkout and whether the local diagnostic journal is readable.",
    "observation_not_found": "Check the run and dispatch IDs against the selected checkout.",
    "observations_unavailable": "Check access to the selected checkout and its workflow database.",
    "invalid_telemetry_config": "Check telemetry and logs settings in .factory/factory.yaml.",
    "missing_telemetry_credential": "Provide the named credential through the configured environment or env file.",
    "telemetry_export_failed": "Check the receiver settings, connectivity and local workflow database.",
}

json_mode = ContextVar("factory_cli_json_mode", default=False)


def json_requested(args: Sequence[str]) -> bool:
    for arg in args:
        if arg == "--":
            return False
        if arg == "--json":
            return True
    return False


def configure_process_io(args: Sequence[str]) -> None:
    """The JSON wire format uses UTF-8 independently of the terminal locale."""
    if json_requested(args):
        for stream in (sys.stdin, sys.stdout):
            if isinstance(stream, TextIOWrapper):
                stream.reconfigure(encoding="utf-8")


@contextmanager
def output_mode(as_json: bool) -> Iterator[None]:
    token = json_mode.set(as_json)
    try:
        yield
    finally:
        json_mode.reset(token)


def emit_json(value: object) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2))


def emit_error(code: str, message: str, *, next_action: str | None = None) -> None:
    error = {"code": code, "message": message}
    if action := next_action or CLI_ERROR_GUIDANCE.get(code):
        error["next_action"] = action
    emit_json({"ok": False, "error": error})
