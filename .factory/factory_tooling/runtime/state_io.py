"""Check persisted record shapes; workflow modules own semantic validation."""

from __future__ import annotations

from functools import cache
from types import UnionType
from typing import (
    Any,
    Literal,
    NotRequired,
    Required,
    Union,
    cast,
    get_args,
    get_origin,
    get_type_hints,
    is_typeddict,
)

from factory_tooling.runtime.contracts import State
from factory_tooling.runtime.workflow_core import Invalid


@cache
def _fields(schema: Any) -> tuple[dict[str, Any], frozenset[str]]:
    # Typing descriptors are dynamic; data leaving this boundary has a concrete record type.
    hints = get_type_hints(schema, include_extras=True)
    required = set(schema.__required_keys__)
    for key, hint in hints.items():
        if get_origin(hint) is NotRequired:
            required.discard(key)
        elif get_origin(hint) is Required:
            required.add(key)
    return hints, frozenset(required)


def _check(value: object, schema: Any, location: str) -> None:
    if schema is Any or schema is object:
        return
    origin, arguments = get_origin(schema), get_args(schema)
    if origin in (Required, NotRequired):
        _check(value, arguments[0], location)
        return
    if origin in (Union, UnionType):
        for option in arguments:
            try:
                _check(value, option, location)
                return
            except ValueError:
                pass
    elif origin is Literal:
        if value in arguments:
            return
    elif is_typeddict(schema):
        hints, required = _fields(schema)
        if isinstance(value, dict) and required <= value.keys():
            for key, hint in hints.items():
                if key in value:
                    _check(value[key], hint, f"{location}.{key}")
            return
    elif origin is dict and isinstance(value, dict):
        for key, item in value.items():
            _check(key, arguments[0], location + ".key")
            _check(item, arguments[1], f"{location}[{key!r}]")
        return
    elif origin is list and isinstance(value, list):
        for index, item in enumerate(value):
            _check(item, arguments[0], f"{location}[{index}]")
        return
    elif schema is float and type(value) in (int, float):
        return
    elif isinstance(schema, type) and type(value) is schema:
        return
    raise ValueError(f"{location}: expected {schema}, got {type(value).__name__}")


def parse_state(value: object) -> State:
    try:
        _check(value, State, "workflow")
    except ValueError as exc:
        raise Invalid(f"Invalid persisted state: {exc}") from exc
    return cast(State, value)
