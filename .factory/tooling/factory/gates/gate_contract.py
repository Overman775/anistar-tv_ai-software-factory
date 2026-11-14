"""One gate result: evidence for a transition, never an agent or a workflow engine."""

import json
from collections.abc import Iterable
from hashlib import sha256
from typing import Annotated, Literal

from pydantic import ConfigDict, Field, StringConstraints, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.validation import validation_message

GateStatus = Literal["PASS", "FAIL", "BLOCKED"]
EvidenceText = Annotated[str, StringConstraints(pattern=r"\S")]


@with_config(ConfigDict(strict=True, extra="forbid"))
class GateCheck(TypedDict):
    id: EvidenceText
    status: GateStatus
    message: EvidenceText
    evidence: Annotated[list[EvidenceText], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class GateResult(TypedDict):
    gate_id: EvidenceText
    boundary: EvidenceText
    subject: EvidenceText
    policy_hash: EvidenceText
    artifact_hash: EvidenceText
    status: GateStatus
    checks: Annotated[list[GateCheck], Field(min_length=1)]


STATUSES = {"PASS", "FAIL", "BLOCKED"}
GATE_CHECK = TypeAdapter[GateCheck](GateCheck)
GATE_RESULT = TypeAdapter[GateResult](GateResult)
REQUIREMENTS = TypeAdapter[list[str]](
    Annotated[list[EvidenceText], Field(min_length=1)], config=ConfigDict(strict=True)
)


def digest(value: object) -> str:
    return sha256(
        json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()
    ).hexdigest()


def text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_check(value: object) -> GateCheck:
    try:
        return GATE_CHECK.validate_python(value)
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid gate check", exc, GATE_CHECK)) from None


def evidence(check_id: str, status: str, message: str, references: list[str]) -> GateCheck:
    return validate_check(
        {"id": check_id, "status": status, "message": message, "evidence": references}
    )


def conclude(
    gate_id: str,
    boundary: str,
    subject: str,
    policy_hash: str,
    artifact_hash: str,
    required: list[str],
    records: Iterable[object],
) -> GateResult:
    try:
        required = REQUIREMENTS.validate_python(required)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid gate requirements", exc, REQUIREMENTS)
        ) from None
    if len(set(required)) != len(required):
        raise ValueError("Gate needs unique requirements")
    by_id: dict[str, GateCheck] = {}
    for record in records:
        checked = validate_check(record)
        if checked["id"] not in required or checked["id"] in by_id:
            raise ValueError("Unknown/duplicate gate check")
        by_id[checked["id"]] = checked
    checks = [
        by_id.get(key) or evidence(key, "BLOCKED", "Required evidence is missing", [key])
        for key in required
    ]
    statuses = {c["status"] for c in checks}
    status: GateStatus = (
        "FAIL" if "FAIL" in statuses else "BLOCKED" if "BLOCKED" in statuses else "PASS"
    )
    result = {
        "gate_id": gate_id,
        "boundary": boundary,
        "subject": subject,
        "policy_hash": policy_hash,
        "artifact_hash": artifact_hash,
        "status": status,
        "checks": checks,
    }
    try:
        return GATE_RESULT.validate_python(result)
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid gate result", exc, GATE_RESULT)) from None


def require_pass(result: GateResult) -> None:
    if result["status"] != "PASS":
        raise ValueError(
            "Gate "
            + result["status"]
            + ": "
            + "; ".join(c["message"] for c in result["checks"] if c["status"] != "PASS")
        )
