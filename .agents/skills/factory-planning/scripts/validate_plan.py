#!/usr/bin/env python3
"""Deterministic validator for Factory Planning draft and approved plans."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote


REQUIRED_METADATA = (
    "plan_id",
    "revision",
    "plan_state",
    "status",
    "approved_revision",
    "source",
    "handoff_recommendation",
)
REQUIRED_HEADINGS = (
    "## Что меняем",
    "## Как будет работать",
    "## Как устроено решение",
    "## Ключевые решения",
    "## Неизвестное и границы",
    "## Готовность и проверка",
    "## Передача дальше",
)
PLAN_STATES = {"PLAN_READY"}
API_EVIDENCE_TYPES = {
    "backend_api",
    "platform_plugin_api",
    "storage",
    "local_contract",
    "external_contract",
    "none",
}
SOURCES = {"request", "spec", "local", "mixed"}
HANDOFFS = {"direct", "decompose", "either"}
CONTINUATIONS = {
    "ожидает выбора пользователя",
    "заранее разрешённое прямое выполнение",
    "заранее разрешённый декомпоз",
    "только план",
}
PREAUTHORIZED_CONTINUATIONS = {
    "заранее разрешённое прямое выполнение",
    "заранее разрешённый декомпоз",
}
PLAN_ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
DECISION_ID_RE = re.compile(r"^D-\d{2,}$")
DECISION_REFERENCE_RE = re.compile(r"\bD-\d{2,}\b")
EXTERNAL_ID_RE = re.compile(r"\bEXT-\d{2,}\b")
CAPABILITY_RE = re.compile(r"\bCAP-\d{2,}\b")
URL_RE = re.compile(r"https?://[^\s|<>]+")
NO_MATERIAL_DECISIONS = "- Существенных решений нет."
EMPTY_VALUES = {"", "-", "—", "none", "null", "n/a"}
FORBIDDEN_METADATA = {
    "publication_id",
    "question_budget_total",
    "question_budget_remaining",
    "question_batches_used",
    "current_question_batch",
    "estimate",
    "task_count",
}


def error(code: str, message: str) -> dict[str, str]:
    return {"code": code, "message": message}


def parse_metadata(text: str) -> tuple[dict[str, str], list[dict[str, str]]]:
    metadata: dict[str, str] = {}
    errors: list[dict[str, str]] = []
    prefix = text.split("\n## ", 1)[0]
    for line in prefix.splitlines():
        match = re.match(r"^([a-z][a-z0-9_]*):\s*(.*?)\s*$", line)
        if not match:
            continue
        key, value = match.groups()
        if key in metadata:
            errors.append(error("METADATA_DUPLICATE", f"Duplicate metadata: {key}"))
        metadata[key] = value

    for key in REQUIRED_METADATA:
        if key not in metadata:
            errors.append(error("METADATA_MISSING", f"Missing metadata: {key}"))
    for key in metadata:
        if key not in REQUIRED_METADATA:
            code = "FORBIDDEN_METADATA" if key in FORBIDDEN_METADATA else "METADATA_EXTRA"
            errors.append(error(code, f"Metadata is not canonical: {key}"))
    return metadata, errors


def extract_section(text: str, heading: str) -> str:
    start = text.find(heading)
    if start < 0:
        return ""
    start += len(heading)
    end = text.find("\n## ", start)
    return text[start:] if end < 0 else text[start:end]


def declared_capabilities(text: str) -> set[str]:
    return set(
        re.findall(
            r"(?m)^\s*[-*]\s+(CAP-\d{2,})\s+[—-]\s+\S",
            extract_section(text, "## Что меняем"),
        )
    )


def split_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_separator(cells: list[str]) -> bool:
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def table_after_header(section: str, header_marker: str) -> tuple[list[str], list[list[str]]]:
    lines = section.splitlines()
    for index, line in enumerate(lines):
        if not line.lstrip().startswith("|"):
            continue
        header = split_row(line)
        if header_marker not in header:
            continue
        rows: list[list[str]] = []
        for candidate in lines[index + 1 :]:
            if not candidate.lstrip().startswith("|"):
                if rows:
                    break
                continue
            cells = split_row(candidate)
            if is_separator(cells):
                continue
            rows.append(cells)
        return header, rows
    return [], []


def validate_applicability(
    value: str,
    known_capabilities: set[str],
    *,
    invalid_code: str,
    unknown_code: str,
    subject: str,
) -> list[dict[str, str]]:
    if value == "global":
        return []
    capabilities = CAPABILITY_RE.findall(value)
    residue = CAPABILITY_RE.sub("", value)
    residue = re.sub(r"[,\s]+", "", residue)
    if not capabilities or residue:
        return [error(invalid_code, f"{subject} must use comma-separated CAP IDs or global")]
    unknown = set(capabilities) - known_capabilities
    if unknown:
        return [error(unknown_code, f"{subject} references undeclared capabilities: {sorted(unknown)}")]
    return []


def validate_structure(text: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    first_line = next((line.strip() for line in text.splitlines() if line.strip()), "")
    if not first_line.startswith("# План: "):
        errors.append(error("TITLE_INVALID", "Plan must start with '# План: ...'"))
    actual_h2 = [line.strip() for line in text.splitlines() if line.startswith("## ")]
    if tuple(actual_h2) != REQUIRED_HEADINGS:
        errors.append(
            error(
                "HEADINGS_INVALID",
                "Mandatory H2 headings must exist exactly once in canonical order",
            )
        )
    for heading in REQUIRED_HEADINGS:
        section = extract_section(text, heading).strip()
        if not section:
            errors.append(error("SECTION_EMPTY", f"Section is empty: {heading}"))

    behavior = extract_section(text, "## Как будет работать")
    numbered = re.findall(r"(?m)^\s*\d+\.\s+\S", behavior)
    if len(numbered) < 2:
        errors.append(error("MAIN_FLOW_NOT_NUMBERED", "Main flow needs at least two numbered steps"))

    change = extract_section(text, "## Что меняем")
    declarations = re.findall(r"(?m)^\s*[-*]\s+(CAP-\d{2,})\s+[—-]\s+\S", change)
    if not declarations:
        errors.append(error("CAPABILITY_MISSING", "At least one CAP-{NN} declaration is required"))
    if len(declarations) != len(set(declarations)):
        errors.append(error("CAPABILITY_DUPLICATE", "Capability IDs must be unique"))

    readiness = extract_section(text, "## Готовность и проверка")
    for subsection in ("### Приёмка разработчиком и готовность", "### Проверки QA"):
        if subsection not in readiness:
            errors.append(error("READINESS_SECTION_MISSING", f"Missing subsection: {subsection}"))
        else:
            body = readiness.split(subsection, 1)[1]
            next_heading = re.search(r"\n###\s", body)
            if next_heading:
                body = body[: next_heading.start()]
            if not re.search(r"(?m)^\s*[-*]\s+\S", body):
                errors.append(error("READINESS_SECTION_EMPTY", f"No checks under: {subsection}"))
    return errors


def validate_pseudocode(text: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    heading = "### Псевдокод поведения"
    if heading not in text:
        return errors
    behavior = extract_section(text, "## Как будет работать")
    if heading not in behavior:
        return [error("PSEUDOCODE_LOCATION_INVALID", "Pseudocode must be inside behavior section")]
    block = behavior.split(heading, 1)[1]
    next_heading = re.search(r"\n###\s", block)
    if next_heading:
        block = block[: next_heading.start()]
    match = re.search(r"```text\s*\n(.*?)\n```", block, re.DOTALL)
    if not match:
        return [error("PSEUDOCODE_FENCE_INVALID", "Pseudocode needs a text fence")]
    lines = [line.strip() for line in match.group(1).splitlines() if line.strip()]
    if not 5 <= len(lines) <= 12:
        errors.append(error("PSEUDOCODE_LENGTH_INVALID", "Pseudocode must contain 5-12 non-empty lines"))
    joined = "\n".join(lines)
    code_patterns = (
        r"[{};]",
        r"=>",
        r"\b(?:class|void|Future<|import\s|return\s+|if\s*\(|switch\s*\()",
        r"\w+\s*\([^\n)]*\)\s*[{;]",
    )
    if any(re.search(pattern, joined, re.IGNORECASE) for pattern in code_patterns):
        errors.append(error("PSEUDOCODE_CODE_SYNTAX", "Pseudocode contains production-code syntax"))
    return errors


def validate_decisions(text: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    section = extract_section(text, "## Ключевые решения")
    referenced = set(DECISION_REFERENCE_RE.findall(text))
    if section.strip() == NO_MATERIAL_DECISIONS:
        if referenced:
            errors.append(
                error(
                    "DECISION_REFERENCE_UNKNOWN",
                    f"Plan declares no material decisions but references: {sorted(referenced)}",
                )
            )
        return errors

    header, rows = table_after_header(section, "Решение")
    expected_header = [
        "ID",
        "Решение",
        "Почему",
        "Применимость",
        "Проверка/ограничение",
    ]
    if header != expected_header:
        return [error("DECISION_TABLE_INVALID", "Decision table header is not canonical")]
    if not rows:
        return [error("DECISION_TABLE_EMPTY", "Decision table needs at least one material row")]

    seen: set[str] = set()
    known_capabilities = declared_capabilities(text)
    for row in rows:
        if len(row) != len(expected_header):
            errors.append(error("DECISION_ROW_INVALID", f"Decision row has {len(row)} cells"))
            continue
        decision_id, statement, reason, applicability, verification = row
        if not DECISION_ID_RE.fullmatch(decision_id):
            errors.append(error("DECISION_ID_INVALID", f"Invalid decision ID: {decision_id}"))
        elif decision_id in seen:
            errors.append(error("DECISION_ID_DUPLICATE", f"Duplicate decision ID: {decision_id}"))
        seen.add(decision_id)
        for name, value in (("statement", statement), ("reason", reason), ("verification", verification)):
            if value.strip().lower() in EMPTY_VALUES:
                errors.append(error("DECISION_FIELD_EMPTY", f"{decision_id} has empty {name}"))
        errors.extend(
            validate_applicability(
                applicability,
                known_capabilities,
                invalid_code="DECISION_APPLICABILITY_INVALID",
                unknown_code="DECISION_CAPABILITY_UNKNOWN",
                subject=decision_id,
            )
        )
    unknown = referenced - seen
    if unknown:
        errors.append(
            error(
                "DECISION_REFERENCE_UNKNOWN",
                f"Plan references undeclared decisions: {sorted(unknown)}",
            )
        )
    return errors


def validate_external_boundaries(text: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    section = extract_section(text, "## Неизвестное и границы")
    declarations = re.findall(r"(?m)^\s*[-*]\s+(EXT-\d{2,})\s+[—-]\s+(\S.*)$", section)
    declared_ids = [item_id for item_id, _ in declarations]
    if len(declared_ids) != len(set(declared_ids)):
        errors.append(error("EXTERNAL_ID_DUPLICATE", "EXT IDs must be unique in boundaries"))
    for item_id, body in declarations:
        handling = re.search(r"\bобработка:\s*(\S.*)$", body, re.IGNORECASE)
        if not handling or handling.group(1).strip().lower() in EMPTY_VALUES:
            errors.append(
                error(
                    "EXTERNAL_HANDLING_MISSING",
                    f"{item_id} needs explicit non-empty handling",
                )
            )
    referenced_ids = set(EXTERNAL_ID_RE.findall(text))
    unknown = referenced_ids - set(declared_ids)
    if unknown:
        errors.append(error("EXTERNAL_REFERENCE_UNKNOWN", f"Undeclared external dependencies: {sorted(unknown)}"))
    return errors


def validate_api_evidence(text: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    known_capabilities = declared_capabilities(text)
    unknown = set(CAPABILITY_RE.findall(text)) - known_capabilities
    if unknown:
        errors.append(
            error(
                "CAPABILITY_REFERENCE_UNKNOWN",
                f"Plan references undeclared capabilities: {sorted(unknown)}",
            )
        )

    section = extract_section(text, "## Как устроено решение")
    header, rows = table_after_header(section, "Тип контракта")
    expected_header = ["Применимость", "Тип контракта", "Поведенчески значимая суть", "Подтверждение"]
    if header != expected_header:
        errors.append(error("API_EVIDENCE_TABLE_INVALID", "API evidence table header is not canonical"))
        return errors
    if not rows:
        errors.append(error("API_EVIDENCE_TABLE_EMPTY", "At least one typed API evidence row is required"))
        return errors

    covered: set[str] = set()
    for row in rows:
        if len(row) != len(expected_header):
            errors.append(error("API_EVIDENCE_ROW_INVALID", "API evidence row has invalid cell count"))
            continue
        applicability, evidence_type, gist, evidence = row
        if evidence_type not in API_EVIDENCE_TYPES:
            errors.append(error("API_EVIDENCE_TYPE_INVALID", f"Invalid API evidence type: {evidence_type}"))
        errors.extend(
            validate_applicability(
                applicability,
                known_capabilities,
                invalid_code="API_EVIDENCE_APPLICABILITY_INVALID",
                unknown_code="API_EVIDENCE_CAPABILITY_UNKNOWN",
                subject=f"API evidence applicability '{applicability}'",
            )
        )
        if applicability == "global":
            covered.update(known_capabilities)
        else:
            covered.update(set(CAPABILITY_RE.findall(applicability)) & known_capabilities)
        if any(value.strip().lower() in EMPTY_VALUES for value in (gist, evidence)):
            errors.append(error("API_EVIDENCE_FIELD_EMPTY", "API evidence gist/evidence cannot be empty"))

    missing = known_capabilities - covered
    if missing:
        errors.append(
            error(
                "CAPABILITY_CONTRACT_COVERAGE_MISSING",
                f"Capabilities lack typed contract coverage: {sorted(missing)}",
            )
        )
    return errors


def validate_metadata(metadata: dict[str, str], phase: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    if not PLAN_ID_RE.fullmatch(metadata.get("plan_id", "")):
        errors.append(error("PLAN_ID_INVALID", "plan_id must be stable kebab-case"))
    try:
        revision = int(metadata.get("revision", ""))
        if revision < 1:
            raise ValueError
    except ValueError:
        revision = None
        errors.append(error("REVISION_INVALID", "revision must be integer >= 1"))
    if metadata.get("plan_state") not in PLAN_STATES:
        errors.append(error("PLAN_STATE_INVALID", "User-reviewable plan must use PLAN_READY"))
    if metadata.get("source") not in SOURCES:
        errors.append(error("SOURCE_INVALID", "source must be request|spec|local|mixed"))
    if metadata.get("handoff_recommendation") not in HANDOFFS:
        errors.append(error("HANDOFF_INVALID", "handoff_recommendation must be direct|decompose|either"))

    status = metadata.get("status")
    approved = metadata.get("approved_revision")
    state = metadata.get("plan_state")
    if status == "draft":
        if approved != "none":
            errors.append(error("APPROVAL_INVARIANT_INVALID", "Draft must use approved_revision: none"))
    elif status == "approved":
        if state != "PLAN_READY" or revision is None or approved != str(revision):
            errors.append(error("APPROVAL_INVARIANT_INVALID", "Approved plan needs PLAN_READY and matching revision"))
    else:
        errors.append(error("STATUS_INVALID", "status must be draft|approved"))

    if phase == "draft" and status != "draft":
        errors.append(error("PHASE_STATUS_MISMATCH", "Draft phase requires status: draft"))
    if phase == "approved" and status != "approved":
        errors.append(error("PHASE_STATUS_MISMATCH", "Approved phase requires status: approved"))
    return errors


def validate_cross_section(text: str, metadata: dict[str, str]) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    if re.search(r"\b(?:TBD|TODO)\b", text, re.IGNORECASE):
        errors.append(error("PLACEHOLDER_FORBIDDEN", "Plan cannot contain TBD/TODO placeholders"))
    if "### Текущий пакет вопросов" in text:
        errors.append(
            error(
                "ACTIVE_QUESTIONS_IN_PLAN",
                "Active questions belong to planning-session.md, not presented plan",
            )
        )
    unresolved = sorted(set(re.findall(r"\b(?:USER_DECISION|BLOCK)\b", text)))
    if unresolved:
        errors.append(
            error(
                "UNRESOLVED_MARKER_IN_PLAN",
                f"Working-session markers cannot enter presented plan: {unresolved}",
            )
        )
    handoff = metadata.get("handoff_recommendation", "")
    handoff_section = extract_section(text, "## Передача дальше")
    recommendation = re.search(r"(?mi)^\s*[-*]\s*Рекомендация:\s*`?([a-z]+)`?", handoff_section)
    if not recommendation or recommendation.group(1) != handoff:
        errors.append(error("HANDOFF_SECTION_MISMATCH", "Handoff section must match metadata recommendation"))
    continuation = re.search(
        r"(?mi)^\s*[-*]\s*Продолжение:\s*(.*?)\s*$",
        handoff_section,
    )
    if not continuation:
        errors.append(
            error(
                "HANDOFF_CONTINUATION_MISSING",
                "Handoff section needs explicit continuation authorization",
            )
        )
    else:
        continuation_value = continuation.group(1).replace("`", "").strip().rstrip(".")
        if continuation_value not in CONTINUATIONS:
            errors.append(
                error(
                    "HANDOFF_CONTINUATION_INVALID",
                    "Continuation must use one canonical authorization value",
                )
            )
        elif (
            continuation_value in PREAUTHORIZED_CONTINUATIONS
            and not re.search(
                r'(?m)^\s*[-*]\s*Авторизация планирования:\s*'
                r'explicit_user_delegation\s+[—-]\s+".+"\.?\s*$',
                text,
            )
        ):
            errors.append(
                error(
                    "HANDOFF_CONTINUATION_UNAUTHORIZED",
                    "Pre-authorized continuation needs explicit_user_delegation evidence",
                )
            )
    return errors


def normalize_url(match: re.Match[str]) -> str:
    url = unquote(match.group(0)).rstrip("/.,")
    while url.endswith(")") and url.count(")") > url.count("("):
        url = url[:-1]
    return url


def semantic_normal_form(text: str) -> str:
    lines: list[str] = []
    for line in text.splitlines():
        if re.match(r"^(revision|status|approved_revision):", line):
            continue
        if re.fullmatch(r"\s*\|?(?:\s*:?-{3,}:?\s*\|)+\s*", line):
            continue
        line = URL_RE.sub(normalize_url, line)
        line = re.sub(r"\s+", " ", line).strip()
        if line:
            lines.append(line)
    return "\n".join(lines)


def validate_transition(previous_text: str, current_text: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    previous, previous_errors = parse_metadata(previous_text)
    current, current_errors = parse_metadata(current_text)
    if previous_errors or current_errors:
        return [error("TRANSITION_METADATA_INVALID", "Cannot validate transition with invalid metadata")]
    if previous["plan_id"] != current["plan_id"]:
        errors.append(error("PLAN_ID_CHANGED", "plan_id must remain stable across revisions"))
    previous_revision = int(previous["revision"])
    current_revision = int(current["revision"])
    semantic_changed = semantic_normal_form(previous_text) != semantic_normal_form(current_text)

    approval_only = (
        not semantic_changed
        and previous["status"] == "draft"
        and current["status"] == "approved"
        and current_revision == previous_revision
    )
    if approval_only:
        return errors
    if semantic_changed:
        if current_revision != previous_revision + 1:
            errors.append(error("SEMANTIC_REVISION_INVALID", "Semantic change requires revision N+1"))
        if current.get("status") != "draft" or current.get("approved_revision") != "none":
            errors.append(error("SEMANTIC_APPROVAL_NOT_RESET", "Semantic change must reset approval"))
    elif current_revision != previous_revision:
        errors.append(error("NONSEMANTIC_REVISION_CHANGED", "Non-semantic edit must keep revision"))

    if previous["status"] == "approved" and not semantic_changed and previous_text != current_text:
        errors.append(error("APPROVED_IMMUTABLE", "Approved durable snapshot must not be edited"))
    return errors


def validate(text: str, phase: str = "draft", previous_text: str | None = None) -> list[dict[str, str]]:
    metadata, errors = parse_metadata(text)
    errors.extend(validate_structure(text))
    errors.extend(validate_pseudocode(text))
    errors.extend(validate_metadata(metadata, phase))
    errors.extend(validate_decisions(text))
    errors.extend(validate_external_boundaries(text))
    errors.extend(validate_api_evidence(text))
    errors.extend(validate_cross_section(text, metadata))
    if previous_text is not None:
        errors.extend(validate_transition(previous_text, text))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--phase", choices=("draft", "approved"), default="draft")
    parser.add_argument("--previous", type=Path)
    args = parser.parse_args()

    text = args.plan.read_text(encoding="utf-8")
    previous = args.previous.read_text(encoding="utf-8") if args.previous else None
    errors = validate(text, phase=args.phase, previous_text=previous)
    print(json.dumps({"ok": not errors, "errors": errors}, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
