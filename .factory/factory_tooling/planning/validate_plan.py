#!/usr/bin/env python3
"""Deterministic validator for Factory Planning draft and approved plans."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Annotated, Literal

from pydantic import ConfigDict, Field, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory_tooling.gates.catalog import core_result as core_result
from factory_tooling.gates.gate_contract import EvidenceText, GateResult
from factory_tooling.gates.gate_contract import digest as digest
from factory_tooling.gates.gate_contract import evidence as evidence
from factory_tooling.planning.plan_document import API_EVIDENCE_TYPES as API_EVIDENCE_TYPES
from factory_tooling.planning.plan_document import CAPABILITY_RE as CAPABILITY_RE
from factory_tooling.planning.plan_document import CONTINUATIONS as CONTINUATIONS
from factory_tooling.planning.plan_document import DECISION_ID_RE as DECISION_ID_RE
from factory_tooling.planning.plan_document import DECISION_REFERENCE_RE as DECISION_REFERENCE_RE
from factory_tooling.planning.plan_document import EMPTY_VALUES as EMPTY_VALUES
from factory_tooling.planning.plan_document import EXTERNAL_ID_RE as EXTERNAL_ID_RE
from factory_tooling.planning.plan_document import FORBIDDEN_METADATA as FORBIDDEN_METADATA
from factory_tooling.planning.plan_document import HANDOFFS as HANDOFFS
from factory_tooling.planning.plan_document import NO_MATERIAL_DECISIONS as NO_MATERIAL_DECISIONS
from factory_tooling.planning.plan_document import PLAN_ID_RE as PLAN_ID_RE
from factory_tooling.planning.plan_document import PLAN_STATES as PLAN_STATES
from factory_tooling.planning.plan_document import (
    PREAUTHORIZED_CONTINUATIONS as PREAUTHORIZED_CONTINUATIONS,
)
from factory_tooling.planning.plan_document import REQUIRED_HEADINGS as REQUIRED_HEADINGS
from factory_tooling.planning.plan_document import REQUIRED_METADATA as REQUIRED_METADATA
from factory_tooling.planning.plan_document import SOURCES as SOURCES
from factory_tooling.planning.plan_document import URL_RE as URL_RE

# Compatibility exports: existing imports and command entry points stay valid.
from factory_tooling.planning.plan_document import declared_capabilities as declared_capabilities
from factory_tooling.planning.plan_document import error as error
from factory_tooling.planning.plan_document import extract_section as extract_section
from factory_tooling.planning.plan_document import is_separator as is_separator
from factory_tooling.planning.plan_document import parse_metadata as parse_metadata
from factory_tooling.planning.plan_document import split_row as split_row
from factory_tooling.planning.plan_document import table_after_header as table_after_header
from factory_tooling.planning.plan_document import validate_applicability as validate_applicability
from factory_tooling.planning.plan_revision import normalize_url as normalize_url
from factory_tooling.planning.plan_revision import semantic_normal_form as semantic_normal_form
from factory_tooling.planning.plan_revision import validate_transition as validate_transition
from factory_tooling.planning.plan_rules import validate_api_evidence as validate_api_evidence
from factory_tooling.planning.plan_rules import validate_cross_section as validate_cross_section
from factory_tooling.planning.plan_rules import validate_decisions as validate_decisions
from factory_tooling.planning.plan_rules import (
    validate_external_boundaries as validate_external_boundaries,
)
from factory_tooling.planning.plan_rules import validate_metadata as validate_metadata
from factory_tooling.planning.plan_rules import validate_pseudocode as validate_pseudocode
from factory_tooling.planning.plan_rules import validate_structure as validate_structure
from factory_tooling.runtime.acceptance import plan_criteria as plan_criteria
from factory_tooling.validation import validation_message


@with_config(ConfigDict(strict=True, extra="forbid"))
class CompletionReview(TypedDict):
    plan_hash: str
    policy_hash: str
    coordinator_id: EvidenceText
    verdict: Literal["APPROVE", "NEEDS_WORK", "BLOCKED"]
    evidence: Annotated[list[EvidenceText], Field(min_length=1)]
    approval_evidence: Annotated[list[EvidenceText], Field(min_length=1)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class PlanIssue(TypedDict):
    code: str
    message: str


@with_config(ConfigDict(strict=True, extra="forbid"))
class PlanResult(TypedDict):
    ok: bool
    errors: list[PlanIssue]
    plan_hash: str
    gate_result: GateResult


COMPLETION_REVIEW = TypeAdapter[CompletionReview](CompletionReview)
PLAN_RESULT = TypeAdapter[PlanResult](PlanResult)


def validate_acceptance(text: str) -> list[dict[str, str]]:
    """Check acceptance placement and capability references."""
    errors = []
    try:
        if "### Acceptance criteria" not in extract_section(text, "## Readiness and verification"):
            raise ValueError("Acceptance table belongs in readiness section")
        criteria = plan_criteria(text)
        known = declared_capabilities(text)
        for criterion in criteria:
            applies = criterion["applies_to"]
            if applies != "global" and not set(re.findall(r"CAP-\d{2,}", applies)) <= known:
                errors.append(
                    error("ACCEPTANCE_INVALID", "Acceptance references unknown capability")
                )
    except ValueError as exc:
        errors.append(error("ACCEPTANCE_INVALID", str(exc)))
    return errors


def validate(
    text: str,
    phase: str = "draft",
    previous_text: str | None = None,
    *,
    change_kind: str = "auto",
    change_evidence: str = "",
) -> list[dict[str, str]]:
    metadata, errors = parse_metadata(text)
    errors.extend(validate_structure(text))
    errors.extend(validate_acceptance(text))
    errors.extend(validate_pseudocode(text))
    errors.extend(validate_metadata(metadata, phase))
    errors.extend(validate_decisions(text))
    errors.extend(validate_external_boundaries(text))
    errors.extend(validate_api_evidence(text))
    errors.extend(validate_cross_section(text, metadata))
    if previous_text is not None:
        errors.extend(
            validate_transition(
                previous_text, text, change_kind=change_kind, change_evidence=change_evidence
            )
        )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--phase", choices=("draft", "approved"), default="draft")
    parser.add_argument("--previous", type=Path)
    parser.add_argument(
        "--change-kind", choices=("auto", "semantic", "nonsemantic"), default="auto"
    )
    parser.add_argument(
        "--change-evidence",
        default="",
        help="Coordinator classification rationale; required for explicit kind",
    )
    parser.add_argument(
        "--completion-review",
        type=Path,
        help="Coordinator review/approval evidence; without it only machine preflight runs",
    )
    args = parser.parse_args()

    text = args.plan.read_bytes().decode("utf-8")
    previous = args.previous.read_bytes().decode("utf-8") if args.previous else None
    errors = validate(
        text,
        phase=args.phase,
        previous_text=previous,
        change_kind=args.change_kind,
        change_evidence=args.change_evidence,
    )
    policy_hash = digest({p.name: p.read_text() for p in Path(__file__).parent.glob("*.py")})
    records = [
        evidence(
            "plan-contract",
            "FAIL" if errors else "PASS",
            str(errors) if errors else "Plan contract validated",
            [str(args.plan)],
        )
    ]
    if args.completion_review:
        try:
            review = COMPLETION_REVIEW.validate_json(args.completion_review.read_bytes())
            if review["plan_hash"] != digest(text) or review["policy_hash"] != policy_hash:
                raise ValueError("Stale coordinator review")
            records.append(
                evidence(
                    "plan-review",
                    {"APPROVE": "PASS", "NEEDS_WORK": "FAIL", "BLOCKED": "BLOCKED"}[
                        review["verdict"]
                    ],
                    review["verdict"],
                    review["evidence"],
                )
            )
            records.append(
                evidence(
                    "approval",
                    "PASS" if args.phase == "approved" else "BLOCKED",
                    "Approval applies only to approved plan phase",
                    review["approval_evidence"],
                )
            )
        except ValidationError as exc:
            records.append(
                evidence(
                    "plan-review",
                    "BLOCKED",
                    validation_message("Invalid coordinator review", exc, COMPLETION_REVIEW),
                    [str(args.completion_review)],
                )
            )
        except (ValueError, TypeError, KeyError, OSError) as exc:
            records.append(
                evidence("plan-review", "BLOCKED", str(exc), [str(args.completion_review)])
            )
    gate = core_result(
        "planning.complete",
        str(args.plan.absolute()) + ":" + args.phase,
        policy_hash,
        digest({"plan": text, "previous": previous}),
        records,
    )
    print(
        json.dumps(
            PLAN_RESULT.validate_python(
                {"ok": not errors, "errors": errors, "plan_hash": digest(text), "gate_result": gate}
            ),
            ensure_ascii=False,
            indent=2,
        )
    )
    return (
        (0 if gate["status"] == "PASS" else 1 if gate["status"] == "FAIL" else 2)
        if args.completion_review
        else (0 if not errors else 1)
    )


if __name__ == "__main__":
    sys.exit(main())
