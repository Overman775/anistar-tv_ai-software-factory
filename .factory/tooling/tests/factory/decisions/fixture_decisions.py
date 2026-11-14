from __future__ import annotations

from typing import Any


def definition(kind: str, threshold: float = 0.4) -> dict[str, Any]:
    result = dict(
        id="d", type=kind, question="Evaluate the supplied evidence", min_confidence=threshold
    )
    if kind == "choice":
        result["choices"] = [dict(value=k, description="Case " + k) for k in ("a", "b", "c")]
    if kind == "score":
        result["levels"] = [
            dict(label=k, description="Level " + k) for k in ("low", "medium", "high")
        ]
    return result


def answer(**value: Any) -> dict[str, Any]:
    return dict(reason="Inspected fixture inputs", source="agent:fixture", **value)
