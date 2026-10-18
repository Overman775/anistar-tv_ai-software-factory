"""Safe current-only Markdown renderer for Factory review results."""

from __future__ import annotations

import re
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
    if kind == "source":
        return (
            f"{evidence.get('path')}:{evidence.get('line')}"
            f" ({evidence.get('side')})"
        )
    if kind == "tool":
        return f"{evidence.get('tool_id')}[{evidence.get('command_index')}]"
    return f"binary:{evidence.get('path')}"


def render_finding(finding: dict[str, Any]) -> list[str]:
    location = (
        f"{finding['path']}:{finding['line']}"
        if finding.get("line") is not None
        else f"{finding['path']}:binary"
    )
    source_ids = ", ".join(finding.get("source_ids", [finding["finding_id"]]))
    found_by = ", ".join(finding.get("found_by", []))
    evidence = ", ".join(evidence_label(item) for item in finding["evidence"])
    rule = finding.get("rule_id") or finding["rule"]
    lines = [
        f"**{escape_markdown(finding['finding_id'])}.** "
        f"**`{escape_markdown(location)}`** — {escape_markdown(rule)}<br>",
        f"💥 **Влияние:** {escape_markdown(finding['description'])}<br>",
        f"🛠 **Как исправить:** {escape_markdown(finding['fix'])}<br>",
        f"🧾 **Детали:** gate `{escape_markdown(finding['gate_id'])}` · "
        f"evidence `{escape_markdown(evidence)}` · "
        f"уверенность `{escape_markdown(finding['confidence'])}` · "
        f"источник `{escape_markdown(found_by)}` · "
        f"source IDs `{escape_markdown(source_ids)}`",
    ]
    if finding.get("qa_severity_reason"):
        lines.append(
            f"<br>**QA severity:** {escape_markdown(finding['qa_severity_reason'])}"
        )
    if finding.get("qa_merge_reason"):
        lines.append(f"<br>**QA merge:** {escape_markdown(finding['qa_merge_reason'])}")
    return lines


def render_report(path: Path, result: dict[str, Any]) -> None:
    pipeline_status = result["pipeline_status"]
    code_verdict = result["code_verdict"]
    pipeline_icon = PIPELINE_ICONS.get(pipeline_status, "❓")
    verdict_icon = VERDICT_ICONS.get(code_verdict, "❓")
    tools = result.get("tool_statuses", {})
    tool_summary = ", ".join(
        f"{TOOL_ICONS.get(status, '❓')} "
        f"`{escape_markdown(tool_id)}={escape_markdown(status)}`"
        for tool_id, status in tools.items()
    )

    lines = [
        f"## 🔎 Factory Review · {verdict_icon} {escape_markdown(code_verdict)}",
        "",
        f"- {pipeline_icon} **Протокол:** `{escape_markdown(pipeline_status)}`",
        f"- 🆔 **Review ID:** `{escape_markdown(result.get('review_id'))}`",
        f"- 📍 **Режим:** `{escape_markdown(result.get('mode'))}`",
        f"- 🧪 **Инструменты:** {tool_summary or 'нет данных'}",
        "",
    ]
    if pipeline_status != "COMPLETE":
        lines.extend(
            [
                "⚠️ **Мерж заблокирован:** ревью неполное; см. диагностику.",
                "",
            ]
        )
    elif code_verdict == "APPROVE":
        lines.extend(["✅ **Мерж не заблокирован:** блокеров нет.", ""])
    elif code_verdict == "RETHINK":
        lines.extend(["⛔ **Мерж заблокирован:** требуется пересмотр решения.", ""])
    else:
        lines.extend(["🚧 **Мерж заблокирован:** найдены значимые замечания.", ""])

    if result.get("semantic_gap"):
        lines.extend(
            [
                f"🧭 **Semantic gap:** {escape_markdown(result['semantic_gap'])}",
                "",
            ]
        )

    findings = result.get("findings", [])
    for severity in ("critical", "high", "medium"):
        lines.extend(
            [f"### {SEVERITY_ICONS[severity]} {severity.title()}", ""]
        )
        items = [item for item in findings if item.get("severity") == severity]
        if not items:
            lines.extend(["Нет", ""])
            continue
        for finding in items:
            lines.extend(render_finding(finding))
            lines.append("")

    lines.extend(["<details>", "<summary>🧰 Внутренности ревью</summary>", ""])
    errors = result.get("errors", [])
    lines.append("🚨 **Diagnostics:**")
    lines.extend(
        [f"- {escape_markdown(item)}" for item in errors]
        if errors
        else ["- нет"]
    )
    notes = result.get("qa_notes", [])
    lines.append("")
    lines.append("🔬 **QA notes:**")
    lines.extend(
        [f"- {escape_markdown(item)}" for item in notes]
        if notes
        else ["- нет"]
    )
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
        lines.append("- нет")
    lines.extend(["", "</details>", ""])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
