"""One gate result: evidence for a transition, never an agent or a workflow engine."""

import json
from collections.abc import Iterable
from hashlib import sha256
from typing import Literal, TypedDict, cast

GateStatus = Literal["PASS", "FAIL", "BLOCKED"]


class GateCheck(TypedDict):
    id: str
    status: GateStatus
    message: str
    evidence: list[str]


class GateResult(TypedDict):
    gate_id: str
    boundary: str
    subject: str
    policy_hash: str
    artifact_hash: str
    status: GateStatus
    checks: list[GateCheck]


STATUSES = {"PASS", "FAIL", "BLOCKED"}


def digest(value: object) -> str:
    return sha256(
        json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()
    ).hexdigest()


def text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def evidence(check_id: str, status: str, message: str, references: list[str]) -> GateCheck:
    if not text(check_id) or status not in STATUSES or not text(message):
        raise ValueError("Invalid gate check identity/status/message")
    if not isinstance(references, list) or not references or not all(text(x) for x in references):
        raise ValueError("Gate check needs evidence references")
    return {
        "id": check_id,
        "status": cast(GateStatus, status),
        "message": message,
        "evidence": references,
    }


def conclude(
    gate_id: str,
    boundary: str,
    subject: str,
    policy_hash: str,
    artifact_hash: str,
    required: list[str],
    records: Iterable[object],
) -> GateResult:
    if not all(text(x) for x in (gate_id, boundary, subject, policy_hash, artifact_hash)):
        raise ValueError("Gate needs identity and current policy/artifact hashes")
    if not isinstance(required, list) or not required or len(set(required)) != len(required):
        raise ValueError("Gate needs unique requirements")
    by_id: dict[str, GateCheck] = {}
    for record in records:
        if not isinstance(record, dict) or set(record) != {"id", "status", "message", "evidence"}:
            raise ValueError("Invalid gate check shape")
        checked = evidence(record["id"], record["status"], record["message"], record["evidence"])
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
    return {
        "gate_id": gate_id,
        "boundary": boundary,
        "subject": subject,
        "policy_hash": policy_hash,
        "artifact_hash": artifact_hash,
        "status": status,
        "checks": checks,
    }


def require_pass(result: GateResult) -> None:
    if result["status"] != "PASS":
        raise ValueError(
            "Gate "
            + result["status"]
            + ": "
            + "; ".join(c["message"] for c in result["checks"] if c["status"] != "PASS")
        )
