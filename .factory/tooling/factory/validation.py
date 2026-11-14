"""Safe messages for Pydantic errors at the factory's public boundaries."""

from functools import cache
from typing import Any

from pydantic import TypeAdapter, ValidationError

# Pydantic includes the submitted tag in union errors and custom exception text
# in validator errors. These reasons contain contract information only.
REDACTED_REASONS = {
    "union_tag_invalid": "Unrecognized discriminator value",
    "union_tag_not_found": "Required discriminator is missing",
    "value_error": "Value does not meet the contract",
    "assertion_error": "Value does not meet the contract",
}


@cache
def _schema_names(adapter: TypeAdapter[Any]) -> frozenset[str]:
    """Collect public field/variant names for diagnostics, never for validation."""
    names: set[str] = set()

    def collect(value: object) -> None:
        if isinstance(value, dict):
            for key in ("properties", "$defs"):
                entries = value.get(key)
                if isinstance(entries, dict):
                    names.update(entries)
            discriminator = value.get("discriminator")
            if isinstance(discriminator, dict):
                names.update(discriminator.get("mapping", {}))
            for child in value.values():
                collect(child)
        elif isinstance(value, list):
            for child in value:
                collect(child)

    collect(adapter.json_schema())
    return frozenset(names)


def validation_message(label: str, error: ValidationError, adapter: TypeAdapter[Any]) -> str:
    names = _schema_names(adapter)
    issues = []
    for issue in error.errors(include_input=False, include_context=False, include_url=False):
        location = issue["loc"]
        kind = issue["type"]
        if kind == "extra_forbidden":
            location = (*location[:-1], "(extra field)")
        elif location and location[-1] == "[key]":
            location = (*location[:-2], "(key)")
        field = (
            ".".join(
                str(part)
                if isinstance(part, int) or part in names or part in {"(key)", "(extra field)"}
                else "*"
                for part in location
            )
            or "(root)"
        )
        issues.append(f"{field}: {REDACTED_REASONS.get(kind, issue['msg'])}")
    return f"{label}: " + "; ".join(issues)
