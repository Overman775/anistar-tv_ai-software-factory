"""Review evidence and tool-result validation."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from pydantic import TypeAdapter, ValidationError

from factory_tooling.review.review_contracts import (
    identity_errors,
)
from factory_tooling.review.review_io import load_object
from factory_tooling.review.review_shapes import Evidence, ToolResult
from factory_tooling.validation import validation_message

EVIDENCE = TypeAdapter[Evidence](Evidence)
TOOL_RESULT = TypeAdapter[ToolResult](ToolResult)


def validate_evidence(
    raw: object,
    manifest: dict[str, Any],
    diff: dict[str, Any],
    tool_commands: dict[str, int],
) -> tuple[bool, str]:
    try:
        evidence = EVIDENCE.validate_python(raw)
    except ValidationError as exc:
        return False, validation_message("Invalid evidence", exc, EVIDENCE)
    if evidence["kind"] == "requirement":
        known = {r["id"] for r in manifest.get("context", {}).get("requirements", [])}
        requirement_id = evidence.get("requirement_id")
        return (True, "") if requirement_id in known else (False, "unknown requirement evidence")
    if evidence["kind"] == "inspection":
        path = evidence["path"]
        record = manifest.get("source_evidence", {}).get(path)
        if record is None or evidence["line"] > len(record["content"].splitlines()):
            return False, "inspection outside pinned source evidence"
        return True, ""
    if evidence["kind"] == "tool":
        tool_id = evidence["tool_id"]
        if tool_id not in tool_commands or evidence["command_index"] >= tool_commands[tool_id]:
            return False, "tool evidence points outside validated parent results"
        return True, ""
    path = evidence["path"]
    if path not in manifest.get("scope_files", []):
        return False, "evidence path outside scope"
    if manifest.get("mode") == "feature" and not diff.get("feature_sources_valid", False):
        return False, "feature evidence invalid after source drift"
    if evidence["kind"] == "file_operation":
        if manifest.get("mode") == "feature":
            return False, "file operation evidence requires authoritative branch/PR diff"
        record = {key: value for key, value in evidence.items() if key not in {"path", "kind"}}
        if record not in diff.get("file_operations", {}).get(path, []):
            return False, "file operation evidence does not match authoritative diff metadata"
        return True, ""
    if evidence["kind"] == "binary":
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
    line, side = evidence["line"], evidence["side"]
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
            value: dict[str, Any] = dict(TOOL_RESULT.validate_python(load_object(path)))
        except ValidationError as exc:
            errors.append(validation_message(f"Invalid tool result {path}", exc, TOOL_RESULT))
            continue
        except (OSError, ValueError) as exc:
            errors.append(f"{path}: {exc}")
            continue
        tool_id = value["tool_id"]
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
        if status == "NOT_RUN":
            local.append(f"{label}: NOT_RUN")
        if status in {"PASS", "FAIL", "BLOCKED"}:
            exits: list[int] = []
            blocked = False
            for index, command in enumerate(value["commands"]):
                exit_code = command["exit_code"]
                execution_error = command.get("error")
                if execution_error is not None:
                    if exit_code is not None:
                        local.append(f"{label}[{index}]: invalid execution error")
                        command_schema_valid = False
                    blocked = True
                    local.append(f"{label}[{index}]: command unavailable: {execution_error}")
                elif exit_code is None:
                    local.append(f"{label}[{index}]: exit_code required")
                    command_schema_valid = False
                else:
                    exits.append(exit_code)
            derived = (
                "FAIL" if any(code != 0 for code in exits) else "BLOCKED" if blocked else "PASS"
            )
            if status != derived:
                local.append(f"{label}: status {status} contradicts exit codes")
            if derived == "FAIL":
                failures.append(tool_id)
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
