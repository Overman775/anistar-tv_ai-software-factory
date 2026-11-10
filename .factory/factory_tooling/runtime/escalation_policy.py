"""Profile routing, escalation-chain validation and retry-budget policy."""

from __future__ import annotations

import re
from typing import Any

from factory_tooling.runtime.acceptance import ensure
from factory_tooling.runtime.contracts import (
    State,
)

CAUSES = {"static", "tests", "docs", "review"}


def configure(config: Any) -> None:
    ensure(
        "roles" not in config and "tier" not in config,
        "Use profile role paths, not roles/tier catalogues",
    )
    roles: dict[str, list[str]] = {}
    for name, profile in config["profiles"].items():
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
        ensure("tier" not in profile, "Separate tiers are unsupported")
        roles.setdefault(role, []).append(name)
        policy = profile.get("escalation")
        if policy is not None:
            ensure(
                role in {"developer", "test-writer"},
                "Escalation supports Developer/TestWriter in Implement",
            )
            if not (isinstance(policy, dict) and set(policy) == {"to", "after_failed_attempts"}):
                raise ValueError("Invalid escalation policy")
            if not (isinstance(policy["to"], str) and policy["to"]):
                raise ValueError("Escalation target must be a profile or human")
            ensure(
                type(policy["after_failed_attempts"]) is int
                and policy["after_failed_attempts"] > 0,
                "Positive failure threshold required",
            )
    for name, profile in config["profiles"].items():
        seen, cursor = set(), name
        while cursor != "human":
            ensure(cursor not in seen, "Escalation cycle")
            seen.add(cursor)
            ensure(cursor in config["profiles"], "Unknown escalation target")
            current = config["profiles"][cursor]
            for key in ("role", "contract", "capabilities", "enforcement"):
                ensure(
                    current[key] == profile[key],
                    "Escalation must preserve specialty and permissions",
                )
            ensure(
                set(current["mcp"]) == set(profile["mcp"]),
                "Escalation must preserve required tools",
            )
            if not current.get("escalation"):
                ensure(cursor == name, "Escalation chain must end at human")
                break
            cursor = current["escalation"]["to"]
    routing = config.get("routing", {})
    if not (isinstance(routing, dict) and set(routing) <= {"defaults"}):
        raise ValueError("Invalid routing configuration")
    defaults = routing.get("defaults", {})
    if not (isinstance(defaults, dict)):
        raise ValueError("Invalid defaults")
    ensure(set(defaults) <= {f"roles/{role}.md" for role in roles}, "Unknown default role")
    config["_roles"], config["_defaults"] = roles, {}
    for role, names in roles.items():
        default = defaults.get(f"roles/{role}.md", names[0] if len(names) == 1 else None)
        ensure(default in names, "Multiple profiles require an explicit valid default")
        config["_defaults"][role] = default
    execution = config.get("execution")
    if not (
        isinstance(execution, dict) and set(execution) == {"retry_budgets", "on_budget_exhausted"}
    ):
        raise ValueError("Explicit execution budgets required")
    ensure(execution["on_budget_exhausted"] == "human", "Budget exhaustion requires human handoff")
    budgets = execution["retry_budgets"]
    if not (isinstance(budgets, dict) and set(budgets) == CAUSES | {"recovery"}):
        raise ValueError("Invalid retry budget causes")
    if not (isinstance(budgets["review"], dict) and set(budgets["review"]) == {"feature", "other"}):
        raise ValueError("Invalid review budgets")
    values = [budgets[k] for k in ("static", "tests", "docs", "recovery")] + list(
        budgets["review"].values()
    )
    ensure(
        all(type(v) is int and v >= 0 for v in values), "Retry budgets must be nonnegative integers"
    )


def limits(state: State, task_id: str) -> dict[str, int]:
    task = state["graph"]["tasks"][task_id]
    feature = task["kind"] == "feature" or (
        task["kind"] == "integration"
        and any(t["kind"] == "feature" for t in state["graph"]["tasks"].values())
    )
    budgets = state["config"]["execution"]["retry_budgets"]
    result = {key: budgets[key] for key in ("static", "tests", "docs", "recovery")}
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
