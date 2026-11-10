"""Typed decisions and acceptance thresholds; no providers, IO or model calls."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from math import isclose, isfinite
from typing import Literal, TypedDict, TypeGuard, cast

DecisionKind = Literal["predicate", "choice", "score"]


@dataclass(frozen=True)
class Definition:
    id: str
    kind: DecisionKind
    min_confidence: float
    options: tuple[str, ...]


class DecisionResult(TypedDict):
    id: str
    type: DecisionKind
    value: bool | str | float
    confidence: float
    source: str
    reason: str


def require(condition: object, message: str) -> None:
    if not condition:
        raise ValueError(message)


def number(value: object, low: float, high: float) -> TypeGuard[int | float]:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and low <= value <= high
        and isfinite(value)
    )


def text(value: object) -> TypeGuard[str]:
    return isinstance(value, str) and bool(value.strip())


def mapping(value: object, message: str) -> Mapping[str, object]:
    if not isinstance(value, Mapping) or not all(isinstance(key, str) for key in value):
        raise ValueError(message)
    return cast(Mapping[str, object], value)


def parse_definition(value: object) -> Definition:
    definition = mapping(value, "decision must be mapping")
    kind = definition.get("type", "predicate")
    if kind not in ("predicate", "choice", "score"):
        raise ValueError("unknown decision type")
    allowed = {"id", "question", "type", "min_confidence"}
    allowed |= {"predicate": {"criteria"}, "choice": {"choices"}, "score": {"levels"}}[kind]
    require(set(definition) <= allowed, "unknown decision fields")
    identity = definition.get("id")
    if not text(identity) or not text(definition.get("question")):
        raise ValueError("missing decision id/question")
    threshold = definition.get("min_confidence", 0)
    if not number(threshold, 0, 1):
        raise ValueError("invalid min_confidence")
    if kind == "predicate" and "criteria" in definition:
        criteria = mapping(definition["criteria"], "predicate needs true/false criteria")
        require(
            set(criteria) == {"true", "false"} and all(text(v) for v in criteria.values()),
            "predicate needs true/false criteria",
        )
    options: list[str] = []
    if kind in ("choice", "score"):
        field, key = ("choices", "value") if kind == "choice" else ("levels", "label")
        entries = definition.get(field)
        if (
            not isinstance(entries, list)
            or len(entries) < 2
            or (kind == "score" and len(entries) > 10)
        ):
            raise ValueError("invalid choices/levels count")
        for raw in entries:
            entry = mapping(raw, "invalid choice/level")
            option = entry.get(key)
            if (
                set(entry) != {key, "description"}
                or not text(option)
                or not text(entry.get("description"))
            ):
                raise ValueError("invalid choice/level")
            require(option not in options, "duplicate choice/level")
            options.append(option)
    return Definition(identity, kind, float(threshold), tuple(options))


def validate_definition(definition: object) -> None:
    parse_definition(definition)


def validate_answer(definition: object, answer: object) -> DecisionResult:
    """Return {id, type, value, confidence, source, reason} after full validation.

    Invalid or unresolved estimates raise ValueError; no result is manufactured.
    The original estimate stays unchanged and remains the stored evidence.
    """
    parsed = parse_definition(definition)
    estimate = mapping(answer, "UNKNOWN decision: answer needs evidence/reason")
    reason, source = estimate.get("reason"), estimate.get("source")
    if not text(reason):
        raise ValueError("UNKNOWN decision: answer needs evidence/reason")
    allowed = {"reason", "source"} | {
        "predicate": {"probability"},
        "choice": {"choice", "probabilities", "confidence"},
        "score": {"score", "probabilities", "confidence"},
    }[parsed.kind]
    if set(estimate) != allowed or not text(source):
        raise ValueError("invalid typed decision answer/source")
    result: bool | str | float
    if parsed.kind == "predicate":
        probability = estimate["probability"]
        if not number(probability, 0, 1):
            raise ValueError("invalid decision probability")
        require(probability != 0.5, "UNKNOWN predicate: equal probabilities")
        result = probability > 0.5
        confidence = abs(2 * probability - 1)
    else:
        keys = (
            list(parsed.options)
            if parsed.kind == "choice"
            else [str(i) for i in range(len(parsed.options))]
        )
        raw_distribution = mapping(estimate["probabilities"], "invalid decision probabilities")
        require(set(raw_distribution) == set(keys), "invalid decision probabilities")
        distribution: dict[str, float] = {}
        for key, amount in raw_distribution.items():
            if not number(amount, 0, 1):
                raise ValueError("invalid decision probabilities")
            distribution[key] = float(amount)
        require(
            isclose(sum(distribution.values()), 1, rel_tol=0, abs_tol=1e-6),
            "invalid decision probabilities",
        )
        raw_confidence = estimate["confidence"]
        if not number(raw_confidence, 0, 1):
            raise ValueError("invalid decision confidence")
        confidence = float(raw_confidence)
        value = estimate[parsed.kind]
        if parsed.kind == "choice":
            if (
                not isinstance(value, str)
                or value not in distribution
                or distribution[value] != max(distribution.values())
            ):
                raise ValueError("invalid decision choice")
            require(
                sum(p == max(distribution.values()) for p in distribution.values()) == 1,
                "UNKNOWN choice: tied options",
            )
            result = value
        else:
            expected = sum(i * distribution[str(i)] for i in range(len(keys)))
            if not number(value, 0, len(keys) - 1) or not isclose(
                value, expected, rel_tol=0, abs_tol=1e-6
            ):
                raise ValueError("invalid decision score")
            result = float(value)
    require(
        confidence >= parsed.min_confidence
        or isclose(confidence, parsed.min_confidence, rel_tol=0, abs_tol=1e-12),
        "UNKNOWN decision: below min_confidence",
    )
    return DecisionResult(
        id=parsed.id,
        type=parsed.kind,
        value=result,
        confidence=confidence,
        source=source,
        reason=reason,
    )


def validate_answers(definitions: Sequence[object], answers: object) -> dict[str, DecisionResult]:
    """Return validated results by ID for every supplied answer, including unused ones.

    Missing answers remain absent; the consumer must require any result it needs.
    No definitions and no answers returns an empty mapping.
    """
    by_id: dict[str, object] = {}
    for definition in definitions:
        parsed = parse_definition(definition)
        require(parsed.id not in by_id, "duplicate decision id")
        by_id[parsed.id] = definition
    estimates = mapping(answers, "policy_decisions must be mapping")
    require(set(estimates) <= set(by_id), "unknown policy decision")
    return {
        decision_id: validate_answer(by_id[decision_id], answer)
        for decision_id, answer in estimates.items()
    }


def preserve_obligations(
    definitions: Sequence[object],
    before: object,
    after: object,
    *,
    reintake: bool = False,
    previous_definitions: Sequence[object] | None = None,
) -> None:
    """Preserve accepted predicates; choice/score changes require explicit re-intake."""
    previous = validate_answers(
        previous_definitions if previous_definitions is not None else definitions, before
    )
    current = validate_answers(definitions, after)
    for decision_id, old in previous.items():
        require(decision_id in current, "Cannot remove accepted decision")
        new = current[decision_id]
        require(new["type"] == old["type"], "Cannot change accepted decision type")
        if old["type"] == "predicate":
            require(
                not old["value"] or new["value"],
                "Cannot remove or weaken project applicability decision",
            )
        elif not reintake:
            require(new["value"] == old["value"], "Changed choice/score requires re-intake")
