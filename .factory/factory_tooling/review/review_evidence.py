"""Review evidence and tool-result validation."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from factory_tooling.review.review_contracts import (
    TOOL_STATUSES,
    identity_errors,
)
from factory_tooling.review.review_io import load_object


def validate_evidence(
    evidence: Any,
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
) -> tuple[bool, str]:
    if not isinstance(evidence, dict):
        return False, "evidence must be object"
    kind = evidence.get("kind")
    if kind == "requirement":
        known = {r["id"] for r in manifest.get("context", {}).get("requirements", [])}
        requirement_id = evidence.get("requirement_id")
        return (
            (True, "")
            if isinstance(requirement_id, str) and requirement_id in known
            else (False, "unknown requirement evidence")
        )
    if kind == "inspection":
        path = evidence.get("path")
        record = manifest.get("source_evidence", {}).get(path) if isinstance(path, str) else None
        line = evidence.get("line")
        if (
            not isinstance(record, dict)
            or type(line) is not int
            or not 0 < line <= len(record["content"].splitlines())
        ):
            return False, "inspection outside pinned source evidence"
        return True, ""
    if kind == "tool":
        tool_id = evidence.get("tool_id")
        index = evidence.get("command_index")
        if (
            not isinstance(tool_id, str)
            or tool_id not in tool_commands
            or type(index) is not int
            or not 0 <= index < tool_commands[tool_id]
        ):
            return False, "tool evidence points outside validated parent results"
        return True, ""
    path = evidence.get("path")
    if not isinstance(path, str) or path not in manifest.get("scope_files", []):
        return False, "evidence path outside scope"
    if manifest.get("mode") == "feature" and not diff.get("feature_sources_valid", False):
        return False, "feature evidence invalid after source drift"
    if kind == "file_operation":
        if manifest.get("mode") == "feature":
            return False, "file operation evidence requires authoritative branch/PR diff"
        operation = evidence.get("operation")
        fields = {"mode": ("old_mode", "new_mode"), "rename": ("old_path", "new_path")}
        if not isinstance(operation, str) or operation not in fields:
            return False, "unsupported file operation"
        record = {
            "operation": operation,
            **{field: evidence.get(field) for field in fields[operation]},
        }
        if record not in diff.get("file_operations", {}).get(path, []):
            return False, "file operation evidence does not match authoritative diff metadata"
        return True, ""
    if kind == "binary":
        if manifest.get("mode") == "feature":
            try:
                content = Path(path).read_bytes()
                is_binary = b"\x00" in content
                if not is_binary:
                    content.decode("utf-8")
            except UnicodeDecodeError:
                is_binary = True
            except OSError:
                is_binary = False
            if not is_binary:
                return False, "feature binary evidence does not resolve to binary content"
        if manifest.get("mode") != "feature" and path not in diff["binary"]:
            return False, "binary evidence has no matching diff section"
        return True, ""
    if kind != "source":
        return False, "unsupported evidence kind"
    line = evidence.get("line")
    side = evidence.get("side")
    if (
        type(line) is not int
        or line <= 0
        or not isinstance(side, str)
        or side not in {"new", "old"}
    ):
        return False, "source evidence requires positive line and side new|old"
    if manifest.get("mode") == "feature":
        try:
            source = Path(path)
            line_count = len(source.read_text(encoding="utf-8").splitlines())
        except (OSError, UnicodeError):
            line_count = 0
        if side != "new" or not source.is_file() or line > line_count:
            return False, "feature source evidence does not resolve"
    elif (path, line) not in diff[side]:
        return False, "source evidence does not resolve to changed diff line"
    return True, ""


def validate_tool_results(
    paths: list[Path],
    manifest: dict[str, Any],
) -> tuple[dict[str, dict[str, Any]], dict[str, int], list[str], list[str]]:
    planned = {c["id"]: c for c in manifest.get("checks", [])}
    results: dict[str, dict[str, Any]] = {}
    command_counts: dict[str, int] = {}
    errors: list[str] = []
    failures: list[str] = []
    for path in paths:
        try:
            value = load_object(path)
        except (OSError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{path}: {exc}")
            continue
        tool_id = value.get("tool_id")
        label = f"tool {tool_id}"
        local = identity_errors(value, manifest, label)
        if tool_id not in planned:
            local.append(f"{label}: unknown tool_id")
        elif tool_id in results:
            local.append(f"{label}: duplicate result")
        status = value.get("status")
        if tool_id in planned and status == "NOT_APPLICABLE":
            local.append(f"{label}: planned command cannot be waived")
        if tool_id in planned and status not in {"NOT_RUN", "NOT_APPLICABLE"}:
            expected = planned[tool_id]["execution"]
            actual = value.get("commands")
            if (
                not isinstance(actual, list)
                or len(actual) != 1
                or not isinstance(actual[0], dict)
                or any(
                    actual[0].get(k, 600 if k == "timeout_seconds" else None)
                    != expected.get(k, 600 if k == "timeout_seconds" else None)
                    for k in ("argv", "cwd", "timeout_seconds")
                )
            ):
                local.append(f"{label}: command differs from pinned plan")
        commands = value.get("commands")
        command_schema_valid = True
        if status not in TOOL_STATUSES:
            local.append(f"{label}: invalid status")
        if status in {"NOT_APPLICABLE", "NOT_RUN"}:
            if not isinstance(value.get("reason"), str) or not value["reason"]:
                local.append(f"{label}: {status} requires reason")
            if commands not in ([], None):
                local.append(f"{label}: {status} forbids command records")
            if status == "NOT_RUN":
                local.append(f"{label}: NOT_RUN")
        elif status in {"PASS", "FAIL", "BLOCKED"}:
            if not isinstance(commands, list) or not commands:
                local.append(f"{label}: completed result requires commands")
            else:
                exits: list[int] = []
                blocked = False
                for index, command in enumerate(commands):
                    if not isinstance(command, dict):
                        local.append(f"{label}[{index}]: command must be object")
                        command_schema_valid = False
                        continue
                    argv, cwd, exit_code = (
                        command.get("argv"),
                        command.get("cwd"),
                        command.get("exit_code"),
                    )
                    if (
                        not isinstance(argv, list)
                        or not argv
                        or any(not isinstance(x, str) or not x for x in argv)
                    ):
                        local.append(f"{label}[{index}]: argv invalid")
                        command_schema_valid = False
                    if not isinstance(cwd, str) or not cwd:
                        local.append(f"{label}[{index}]: cwd invalid")
                        command_schema_valid = False
                    execution_error = command.get("error")
                    if execution_error is not None:
                        if (
                            not isinstance(execution_error, str)
                            or not execution_error.strip()
                            or exit_code is not None
                        ):
                            local.append(f"{label}[{index}]: invalid execution error")
                            command_schema_valid = False
                        blocked = True
                        local.append(f"{label}[{index}]: command unavailable: {execution_error}")
                    elif type(exit_code) is not int:
                        local.append(f"{label}[{index}]: exit_code invalid")
                        command_schema_valid = False
                    else:
                        exits.append(exit_code)
                    if (
                        not isinstance(command.get("stdout_excerpt"), str)
                        or not isinstance(command.get("stderr_excerpt"), str)
                        or type(command.get("stdout_truncated")) is not bool
                        or type(command.get("stderr_truncated")) is not bool
                    ):
                        local.append(f"{label}[{index}]: output excerpts/truncation flags required")
                        command_schema_valid = False
                derived = (
                    "FAIL" if any(code != 0 for code in exits) else "BLOCKED" if blocked else "PASS"
                )
                if status != derived:
                    local.append(f"{label}: status {status} contradicts exit codes")
                if derived == "FAIL":
                    failures.append(str(tool_id))
        errors.extend(local)
        if (
            isinstance(tool_id, str)
            and tool_id in planned
            and tool_id not in results
            and not identity_errors(value, manifest, label)
        ):
            results[tool_id] = value
            if (
                status in {"PASS", "FAIL"}
                and isinstance(commands, list)
                and command_schema_valid
                and not any(c.get("error") for c in commands)
            ):
                command_counts[tool_id] = len(commands)
    errors.extend(
        f"tool {tool_id}: missing result" for tool_id in sorted(set(planned) - set(results))
    )
    return results, command_counts, errors, sorted(set(failures))
