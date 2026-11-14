"""Pure structural and semantic consistency rules for a plan."""

from __future__ import annotations

import re

from factory.planning.plan_document import (
    API_EVIDENCE_TYPES,
    CAPABILITY_RE,
    CONTINUATIONS,
    DECISION_ID_RE,
    DECISION_REFERENCE_RE,
    EMPTY_VALUES,
    EXTERNAL_ID_RE,
    NO_MATERIAL_DECISIONS,
    PREAUTHORIZED_CONTINUATIONS,
    REQUIRED_HEADINGS,
    declared_capabilities,
    error,
    extract_section,
    parse_revision,
    table_after_header,
    validate_applicability,
)


def without_fenced_code(text: str) -> str:
    """Remove Markdown fenced blocks before identifying the numbered main flow."""
    result: list[str] = []
    fence = ""
    for line in text.splitlines(keepends=True):
        match = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line.rstrip("\r\n"))
        if not fence:
            if match:
                fence = match.group(1)
            else:
                result.append(line)
        elif (
            match
            and match.group(1)[0] == fence[0]
            and len(match.group(1)) >= len(fence)
            and not match.group(2).strip()
        ):
            fence = ""
    return "".join(result)


def validate_structure(text: str) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    first_line = next((line.strip() for line in text.splitlines() if line.strip()), "")
    if not first_line.startswith("# Plan: "):
        errors.append(error("TITLE_INVALID", "Plan must start with '# Plan: ...'"))
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

    behavior = extract_section(text, "## How it works")
    flow = without_fenced_code(behavior)
    main = re.search(r"(?m)^### Main flow\s*$", flow)
    flow = flow[main.end() :] if main else flow
    next_section = re.search(r"(?m)^### ", flow)
    if next_section:
        flow = flow[: next_section.start()]
    numbered = re.findall(r"(?m)^ {0,3}\d+\.[ \t]+[^\s]", flow)
    if not numbered:
        errors.append(error("MAIN_FLOW_NOT_NUMBERED", "Main flow needs a numbered step"))

    change = extract_section(text, "## What changes")
    declarations = re.findall(r"(?m)^\s*[-*]\s+(CAP-\d{2,})\s+[—-]\s+\S", change)
    if not declarations:
        errors.append(error("CAPABILITY_MISSING", "At least one CAP-{NN} declaration is required"))
    if len(declarations) != len(set(declarations)):
        errors.append(error("CAPABILITY_DUPLICATE", "Capability IDs must be unique"))

    readiness = extract_section(text, "## Readiness and verification")
    for subsection in ("### Developer acceptance and readiness", "### QA checks"):
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
    heading = "### Behavior pseudocode"
    if heading not in text:
        return errors
    behavior = extract_section(text, "## How it works")
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
    if not lines:
        errors.append(error("PSEUDOCODE_EMPTY", "Pseudocode must not be empty"))
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
    section = extract_section(text, "## Key decisions")
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

    header, rows = table_after_header(section, "Decision")
    expected_header = [
        "ID",
        "Decision",
        "Why",
        "Applicability",
        "Verification/constraint",
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
        for name, value in (
            ("statement", statement),
            ("reason", reason),
            ("verification", verification),
        ):
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
    section = extract_section(text, "## Unknowns and boundaries")
    declarations = re.findall(r"(?m)^\s*[-*]\s+(EXT-\d{2,})\s+[—-]\s+(\S.*)$", section)
    declared_ids = [item_id for item_id, _ in declarations]
    if len(declared_ids) != len(set(declared_ids)):
        errors.append(error("EXTERNAL_ID_DUPLICATE", "EXT IDs must be unique in boundaries"))
    for item_id, body in declarations:
        handling = re.search(r"\bhandling:\s*(\S.*)$", body, re.IGNORECASE)
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
        errors.append(
            error(
                "EXTERNAL_REFERENCE_UNKNOWN", f"Undeclared external dependencies: {sorted(unknown)}"
            )
        )
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

    section = extract_section(text, "## Solution structure")
    header, rows = table_after_header(section, "Contract type")
    expected_header = [
        "Applicability",
        "Contract type",
        "Behaviorally significant details",
        "Evidence",
    ]
    if header != expected_header:
        errors.append(
            error("API_EVIDENCE_TABLE_INVALID", "API evidence table header is not canonical")
        )
        return errors
    if not rows:
        errors.append(
            error("API_EVIDENCE_TABLE_EMPTY", "At least one typed API evidence row is required")
        )
        return errors

    covered: set[str] = set()
    for row in rows:
        if len(row) != len(expected_header):
            errors.append(
                error("API_EVIDENCE_ROW_INVALID", "API evidence row has invalid cell count")
            )
            continue
        applicability, evidence_type, gist, evidence = row
        if evidence_type not in API_EVIDENCE_TYPES:
            errors.append(
                error("API_EVIDENCE_TYPE_INVALID", f"Invalid API evidence type: {evidence_type}")
            )
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
            errors.append(
                error("API_EVIDENCE_FIELD_EMPTY", "API evidence gist/evidence cannot be empty")
            )

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
    revision = parse_revision(metadata.get("revision", ""))
    if revision is None:
        errors.append(error("REVISION_INVALID", "revision must be integer >= 1"))

    status = metadata.get("status")
    approved = metadata.get("approved_revision")
    state = metadata.get("plan_state")
    if status == "draft":
        if approved != "none":
            errors.append(
                error("APPROVAL_INVARIANT_INVALID", "Draft must use approved_revision: none")
            )
    elif status == "approved":
        if state != "PLAN_READY" or revision is None or approved != str(revision):
            errors.append(
                error(
                    "APPROVAL_INVARIANT_INVALID",
                    "Approved plan needs PLAN_READY and matching revision",
                )
            )

    if phase == "draft" and status != "draft":
        errors.append(error("PHASE_STATUS_MISMATCH", "Draft phase requires status: draft"))
    if phase == "approved" and status != "approved":
        errors.append(error("PHASE_STATUS_MISMATCH", "Approved phase requires status: approved"))
    return errors


def validate_cross_section(text: str, metadata: dict[str, str]) -> list[dict[str, str]]:
    errors: list[dict[str, str]] = []
    if re.search(r"\b(?:TBD|TODO)\b", text, re.IGNORECASE):
        errors.append(error("PLACEHOLDER_FORBIDDEN", "Plan cannot contain TBD/TODO placeholders"))
    if "### Current question batch" in text:
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
    handoff_section = extract_section(text, "## Handoff")
    recommendation = re.search(r"(?mi)^\s*[-*]\s*Recommendation:\s*`?([a-z]+)`?", handoff_section)
    if not recommendation or recommendation.group(1) != handoff:
        errors.append(
            error("HANDOFF_SECTION_MISMATCH", "Handoff section must match metadata recommendation")
        )
    continuation = re.search(
        r"(?mi)^\s*[-*]\s*Continuation:\s*(.*?)\s*$",
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
        elif continuation_value in PREAUTHORIZED_CONTINUATIONS and not re.search(
            r"(?m)^\s*[-*]\s*Planning authorization:\s*"
            r'explicit_user_delegation\s+[—-]\s+".+"\.?\s*$',
            text,
        ):
            errors.append(
                error(
                    "HANDOFF_CONTINUATION_UNAUTHORIZED",
                    "Pre-authorized continuation needs explicit_user_delegation evidence",
                )
            )
    return errors
