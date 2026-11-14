"""Typed decisions and acceptance thresholds; no providers, IO or model calls."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from math import isclose
from typing import Annotated, Literal, NotRequired, cast

from pydantic import ConfigDict, Field, StringConstraints, TypeAdapter, ValidationError, with_config
from typing_extensions import TypedDict

from factory.validation import validation_message

DecisionKind = Literal["predicate", "choice", "score"]
Text = Annotated[str, StringConstraints(pattern=r"\S")]
Probability = (
    Annotated[int, Field(ge=0, le=1)] | Annotated[float, Field(ge=0, le=1, allow_inf_nan=False)]
)
Score = Annotated[int, Field(ge=0)] | Annotated[float, Field(ge=0, allow_inf_nan=False)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class DecisionDefinition(TypedDict):
    id: Text
    question: Text
    min_confidence: NotRequired[Probability]


class PredicateCriteria(TypedDict):
    true: Text
    false: Text


with_config(ConfigDict(strict=True, extra="forbid"))(PredicateCriteria)


@with_config(ConfigDict(strict=True, extra="forbid"))
class PredicateDefinition(DecisionDefinition):
    type: NotRequired[Literal["predicate"]]
    criteria: NotRequired[PredicateCriteria]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ChoiceOption(TypedDict):
    value: Text
    description: Text


@with_config(ConfigDict(strict=True, extra="forbid"))
class ScoreLevel(TypedDict):
    label: Text
    description: Text


@with_config(ConfigDict(strict=True, extra="forbid"))
class ChoiceDefinition(DecisionDefinition):
    type: Literal["choice"]
    choices: Annotated[list[ChoiceOption], Field(min_length=2)]


@with_config(ConfigDict(strict=True, extra="forbid"))
class ScoreDefinition(DecisionDefinition):
    type: Literal["score"]
    levels: Annotated[list[ScoreLevel], Field(min_length=2, max_length=10)]


DefinitionData = PredicateDefinition | ChoiceDefinition | ScoreDefinition
DEFINITION = TypeAdapter[DefinitionData](DefinitionData)


@with_config(ConfigDict(strict=True, extra="forbid"))
class EstimateEvidence(TypedDict):
    source: Text
    reason: Text


@with_config(ConfigDict(strict=True, extra="forbid"))
class PredicateEstimate(EstimateEvidence):
    probability: Probability


@with_config(ConfigDict(strict=True, extra="forbid"))
class DistributionEstimate(EstimateEvidence):
    probabilities: dict[str, Probability]
    confidence: Probability


@with_config(ConfigDict(strict=True, extra="forbid"))
class ChoiceEstimate(DistributionEstimate):
    choice: Text


@with_config(ConfigDict(strict=True, extra="forbid"))
class ScoreEstimate(DistributionEstimate):
    score: Score


Estimate = PredicateEstimate | ChoiceEstimate | ScoreEstimate
PREDICATE = TypeAdapter[PredicateEstimate](PredicateEstimate)
CHOICE = TypeAdapter[ChoiceEstimate](ChoiceEstimate)
SCORE = TypeAdapter[ScoreEstimate](ScoreEstimate)
ANSWERS = TypeAdapter[dict[str, Estimate]](dict[str, Estimate], config=ConfigDict(strict=True))


@dataclass(frozen=True)
class Definition:
    id: str
    kind: DecisionKind
    min_confidence: float
    options: tuple[str, ...]


@with_config(ConfigDict(strict=True, extra="forbid"))
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


def parse_definition(value: object) -> Definition:
    try:
        definition = DEFINITION.validate_python(value)
    except ValidationError as exc:
        raise ValueError(
            validation_message("Invalid decision definition", exc, DEFINITION)
        ) from None
    options: list[str] = []
    kind: DecisionKind = definition.get("type", "predicate")
    if "choices" in definition:
        options = [option["value"] for option in cast(ChoiceDefinition, definition)["choices"]]
    if "levels" in definition:
        options = [level["label"] for level in cast(ScoreDefinition, definition)["levels"]]
    require(len(options) == len(set(options)), "duplicate choice/level")
    return Definition(definition["id"], kind, definition.get("min_confidence", 0.0), tuple(options))


def validate_definition(definition: object) -> None:
    parse_definition(definition)


def validate_answer(definition: object, answer: object) -> DecisionResult:
    """Return {id, type, value, confidence, source, reason} after full validation.

    Invalid or unresolved estimates raise ValueError; no result is manufactured.
    The original estimate stays unchanged and remains the stored evidence.
    """
    parsed = parse_definition(definition)
    adapter: (
        TypeAdapter[PredicateEstimate] | TypeAdapter[ChoiceEstimate] | TypeAdapter[ScoreEstimate]
    )
    adapter = (
        PREDICATE if parsed.kind == "predicate" else CHOICE if parsed.kind == "choice" else SCORE
    )
    try:
        estimate = adapter.validate_python(answer)
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid decision answer", exc, adapter)) from None
    result: bool | str | float
    if "probability" in estimate:
        probability = cast(PredicateEstimate, estimate)["probability"]
        require(probability != 0.5, "UNKNOWN predicate: equal probabilities")
        result = probability > 0.5
        confidence = abs(2 * probability - 1)
    else:
        keys = (
            list(parsed.options)
            if parsed.kind == "choice"
            else [str(i) for i in range(len(parsed.options))]
        )
        distribution = estimate["probabilities"]
        require(set(distribution) == set(keys), "invalid decision probabilities")
        require(
            isclose(sum(distribution.values()), 1, rel_tol=0, abs_tol=1e-6),
            "invalid decision probabilities",
        )
        confidence = estimate["confidence"]
        if "choice" in estimate:
            value = cast(ChoiceEstimate, estimate)["choice"]
            if value not in distribution or distribution[value] != max(distribution.values()):
                raise ValueError("invalid decision choice")
            require(
                sum(p == max(distribution.values()) for p in distribution.values()) == 1,
                "UNKNOWN choice: tied options",
            )
            result = value
        else:
            expected = sum(i * distribution[str(i)] for i in range(len(keys)))
            score = estimate["score"]
            if not 0 <= score <= len(keys) - 1 or not isclose(
                score, expected, rel_tol=0, abs_tol=1e-6
            ):
                raise ValueError("invalid decision score")
            result = score
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
        source=estimate["source"],
        reason=estimate["reason"],
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
    try:
        estimates = ANSWERS.validate_python(answers)
    except ValidationError as exc:
        raise ValueError(
            validation_message("UNKNOWN decision: invalid policy_decisions", exc, ANSWERS)
        ) from exc
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
