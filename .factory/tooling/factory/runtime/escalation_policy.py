"""Profile routing, escalation-chain validation and retry-budget policy."""

from __future__ import annotations

import re
from typing import Literal

from pydantic import TypeAdapter, ValidationError

from factory.runtime.acceptance import ensure
from factory.runtime.contracts import (
    Config,
    EscalationPolicy,
    Profile,
    State,
)
from factory.validation import validation_message

CAUSES = {"static", "tests", "docs", "review"}


CONFIG = TypeAdapter[Config](Config)


def configure(config: object) -> None:
    """Validate a composed runtime configuration and its routing policy."""
    try:
        value = CONFIG.validate_python(config)
    except ValidationError as exc:
        raise ValueError(validation_message("Invalid runtime configuration", exc, CONFIG)) from None
    routing(value["profiles"], value["routing"]["defaults"])


def routing(
    profiles: dict[str, Profile], defaults: dict[str, str]
) -> tuple[dict[str, list[str]], dict[str, str]]:
    roles: dict[str, list[str]] = {}
    for name, profile in profiles.items():
        if not (re.fullmatch("[a-z][a-z0-9-]*", name) and name != "human"):
            raise ValueError("Invalid profile name")
        match = re.fullmatch(r"roles/([a-z][a-z0-9-]*)\.md", profile["role"])
        if not (match is not None):
            raise ValueError("Role path must be roles/<role-id>.md")
        role = match[1]
        ensure(
            profile["contract"] == f"contracts/{role}.md",
            "Role and contract must identify the same specialty",
        )
        roles.setdefault(role, []).append(name)
        policy = profile.get("escalation")
        if policy is not None:
            ensure(
                role in {"developer", "test-writer"},
                "Escalation supports Developer/TestWriter in Implement",
            )
    for name, profile in profiles.items():
        seen, cursor = set(), name
        while cursor != "human":
            ensure(cursor not in seen, "Escalation cycle")
            seen.add(cursor)
            ensure(cursor in profiles, "Unknown escalation target")
            current = profiles[cursor]
            for key in ("role", "contract", "capabilities", "enforcement"):
                ensure(
                    current[key] == profile[key],
                    "Escalation must preserve specialty and permissions",
                )
            ensure(
                set(current["mcp"]) == set(profile["mcp"]),
                "Escalation must preserve required tools",
            )
            policy = current.get("escalation")
            if policy is None:
                ensure(cursor == name, "Escalation chain must end at human")
                break
            cursor = policy["to"]
    ensure(set(defaults) <= {f"roles/{role}.md" for role in roles}, "Unknown default role")
    runtime_defaults = {}
    for role, names in roles.items():
        default = defaults.get(f"roles/{role}.md", names[0] if len(names) == 1 else "")
        ensure(default in names, "Multiple profiles require an explicit valid default")
        runtime_defaults[role] = default
    return roles, runtime_defaults


def limits(state: State, task_id: str) -> dict[str, int]:
    task = state["graph"]["tasks"][task_id]
    feature = task["kind"] == "feature" or (
        task["kind"] == "integration"
        and any(t["kind"] == "feature" for t in state["graph"]["tasks"].values())
    )
    budgets = state["config"]["execution"]["retry_budgets"]
    result = {
        "static": budgets["static"],
        "tests": budgets["tests"],
        "docs": budgets["docs"],
        "recovery": budgets["recovery"],
    }
    result["review"] = budgets["review"]["feature" if feature else "other"]
    return result


def guard(
    state: State, task_id: str, profile: str | None = None, node_id: str | None = None
) -> None:
    ensure(
        task_id not in state.get("escalation_stops", {}),
        "Task stopped; explicit coordinator resume required",
    )
    ensure(
        profile not in state.get("retired_node_profiles", {}).get(node_id or "", []),
        "Profile already escalated for this node",
    )


def correction_decision(
    kind: str, profile_id: str, policy: EscalationPolicy, failures: int, used: int, budget: int
) -> tuple[str, Literal["blocked", "human", "retry", "escalate"]]:
    """Pure retry/escalation choice; no counters or sessions are changed here."""
    target = profile_id
    decision: Literal["blocked", "human", "retry", "escalate"]
    if kind in {"environment", "requirements"}:
        decision = "blocked"
    elif used >= budget:
        target, decision = "human", "human"
    else:
        if failures >= policy["after_failed_attempts"]:
            target = policy["to"]
        decision = (
            "human" if target == "human" else ("escalate" if target != profile_id else "retry")
        )
    return target, decision
