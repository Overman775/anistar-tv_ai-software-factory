"""Safe current-only Markdown renderer for Factory review results."""

from __future__ import annotations

import re
from collections.abc import Mapping
from pathlib import Path
from typing import Any

VERDICT_ICONS = {
    "APPROVE": "✅",
    "NEEDS_WORK": "🚧",
    "RETHINK": "⛔",
}
PIPELINE_ICONS = {
    "COMPLETE": "✅",
    "INCOMPLETE": "⚠️",
}
TOOL_ICONS = {
    "PASS": "✅",
    "FAIL": "❌",
    "NOT_APPLICABLE": "➖",
    "NOT_RUN": "⚠️",
    "MISSING": "❓",
}
SEVERITY_ICONS = {
    "critical": "🔴",
    "high": "🟠",
    "medium": "🟡",
}


def escape_markdown(value: Any) -> str:
    text = str(value).replace("\r", " ").replace("\n", " ")
    return re.sub(r"([\\`*_{}\[\]()#+!|<>])", r"\\\1", text)


def evidence_label(evidence: dict[str, Any]) -> str:
    kind = evidence.get("kind")
    if kind == "requirement":
        return f"requirement:{evidence.get('requirement_id')}"
    if kind == "inspection":
        return f"inspected:{evidence.get('path')}:{evidence.get('line')}"
    if kind == "source":
        return f"{evidence.get('path')}:{evidence.get('line')} ({evidence.get('side')})"
    if kind == "tool":
        return f"{evidence.get('tool_id')}[{evidence.get('command_index')}]"
    if kind == "file_operation":
        if evidence.get("operation") == "mode":
            return (
                f"mode:{evidence.get('path')} "
                f"({evidence.get('old_mode')} -> {evidence.get('new_mode')})"
            )
        return f"rename:{evidence.get('old_path')} -> {evidence.get('new_path')}"
    return f"binary:{evidence.get('path')}"


def render_finding(finding: dict[str, Any]) -> list[str]:
    file_location = (
        "file operation"
        if any(item.get("kind") == "file_operation" for item in finding["evidence"])
        else "binary"
    )
    if finding.get("kind") == "missing-requirement":
        location = "unimplemented requirement"
    else:
        location = (
            f"{finding['path']}:{finding['line']}"
            if finding.get("line") is not None
            else f"{finding['path']}:{file_location}"
        )
    source_ids = ", ".join(finding.get("source_ids", [finding["finding_id"]]))
    found_by = ", ".join(finding.get("found_by", []))
    evidence = ", ".join(evidence_label(item) for item in finding["evidence"])
    rule = finding["rule"]
    lines = [
        f"**{escape_markdown(finding['finding_id'])}.** "
        f"**`{escape_markdown(location)}`** — {escape_markdown(rule)}<br>",
        f"💥 **Impact:** {escape_markdown(finding['description'])}<br>",
        f"🛠 **How to fix:** {escape_markdown(finding['fix'])}<br>",
        f"🧾 **Details:** gate `{escape_markdown(finding['gate_id'])}` · "
        f"evidence `{escape_markdown(evidence)}` · "
        f"confidence `{escape_markdown(finding['confidence'])}` · "
        f"source `{escape_markdown(found_by)}` · "
        f"source IDs `{escape_markdown(source_ids)}`",
    ]
    if finding.get("qa_severity_reason"):
        lines.append(f"<br>**QA severity:** {escape_markdown(finding['qa_severity_reason'])}")
    if finding.get("qa_merge_reason"):
        lines.append(f"<br>**QA merge:** {escape_markdown(finding['qa_merge_reason'])}")
    return lines


def render_report_text(result: Mapping[str, Any]) -> str:
    pipeline_status = result["pipeline_status"]
    code_verdict = result["code_verdict"]
    pipeline_icon = PIPELINE_ICONS.get(pipeline_status, "❓")
    verdict_icon = VERDICT_ICONS.get(code_verdict, "❓")
    tools = result.get("tool_statuses", {})
    tool_summary = ", ".join(
        f"{TOOL_ICONS.get(status, '❓')} `{escape_markdown(tool_id)}={escape_markdown(status)}`"
        for tool_id, status in tools.items()
    )

    lines = [
        f"## 🔎 Factory Review · {verdict_icon} {escape_markdown(code_verdict)}",
        "",
        f"- {pipeline_icon} **Protocol:** `{escape_markdown(pipeline_status)}`",
        f"- 🆔 **Review ID:** `{escape_markdown(result.get('review_id'))}`",
        f"- 📍 **Mode:** `{escape_markdown(result.get('mode'))}`",
        f"- 🧪 **Tools:** {tool_summary or 'no data'}",
        "",
    ]
    if pipeline_status != "COMPLETE":
        lines.extend(
            [
                "⚠️ **Review does not permit approval:** review incomplete; see diagnostics.",
                "",
            ]
        )
    elif code_verdict == "APPROVE":
        lines.extend(
            [
                "✅ **Review complete:** no findings blocking approval. This does not authorize merge.",
                "",
            ]
        )
    elif code_verdict == "RETHINK":
        lines.extend(
            ["⛔ **Review does not permit approval:** requires decision reconsideration.", ""]
        )
    else:
        lines.extend(["🚧 **Review does not permit approval:** significant findings detected.", ""])

    from factory.project.review_definition import DIRECTIONS

    for lens, coverage in result.get("gate_coverage", {}).items():
        lines.append(
            f"- **{DIRECTIONS.get(lens, lens)}:** {len(coverage['reported'])}/{len(coverage['expected'])} criteria reported; details in the result."
        )
    for limitation in result.get("context_limitations", []):
        lines.append(f"- **Limitation:** {escape_markdown(limitation)}")
    lines.append("")
    if result.get("semantic_gap"):
        lines.extend(
            [
                f"🧭 **Semantic gap:** {escape_markdown(result['semantic_gap'])}",
                "",
            ]
        )

    findings = result.get("findings", [])
    for severity in ("critical", "high", "medium"):
        lines.extend([f"### {SEVERITY_ICONS[severity]} {severity.title()}", ""])
        items = [item for item in findings if item.get("severity") == severity]
        if not items:
            lines.extend(["None", ""])
            continue
        for finding in items:
            lines.extend(render_finding(finding))
            lines.append("")

    lines.extend(["<details>", "<summary>🧰 Review internals</summary>", ""])
    errors = result.get("errors", [])
    lines.append("🚨 **Diagnostics:**")
    lines.extend([f"- {escape_markdown(item)}" for item in errors] if errors else ["- none"])
    notes = result.get("qa_notes", [])
    lines.append("")
    lines.append("🔬 **QA notes:**")
    lines.extend([f"- {escape_markdown(item)}" for item in notes] if notes else ["- none"])
    lines.extend(["", "🔬 **QA dismissed findings:**", ""])
    dismissed = result.get("dismissed_findings", [])
    if dismissed:
        for decision in dismissed:
            original = decision["finding"]
            lines.append(f"**Original severity:** `{escape_markdown(original['severity'])}`<br>")
            lines.extend(render_finding(original))
            evidence = ", ".join(evidence_label(item) for item in decision["evidence"])
            lines.extend(
                [
                    f"<br>**QA dismissal:** {escape_markdown(decision['reason'])}<br>",
                    f"**QA evidence:** `{escape_markdown(evidence)}`",
                    "",
                ]
            )
    else:
        lines.append("- none")
    lines.extend(["", "💻 **Failing commands:**"])
    failing_commands = result.get("failing_commands", [])
    if failing_commands:
        for command in failing_commands:
            argv = " ".join(str(item) for item in command.get("argv", []))
            lines.extend(
                [
                    "- "
                    f"`{escape_markdown(command.get('tool_id'))}"
                    f"[{escape_markdown(command.get('command_index'))}]` "
                    f"argv=`{escape_markdown(argv)}` "
                    f"cwd=`{escape_markdown(command.get('cwd'))}` "
                    f"exit=`{escape_markdown(command.get('exit_code'))}`",
                    f"  stdout=`{escape_markdown(command.get('stdout_excerpt'))}` "
                    f"truncated=`{escape_markdown(command.get('stdout_truncated'))}`",
                    f"  stderr=`{escape_markdown(command.get('stderr_excerpt'))}` "
                    f"truncated=`{escape_markdown(command.get('stderr_truncated'))}`",
                ]
            )
    else:
        lines.append("- none")
    lines.extend(["", "</details>", ""])
    return "\n".join(lines) + "\n"


def render_report(path: Path, result: Mapping[str, Any]) -> None:
    """Persist the same report returned by render_report_text."""
    text = render_report_text(result)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
