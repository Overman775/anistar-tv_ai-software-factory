"""Profile routing, escalation-chain validation and retry-budget policy."""

from __future__ import annotations

import re
from dataclasses import dataclass
from functools import cache
from graphlib import CycleError
from typing import Literal, cast

from pydantic import TypeAdapter, ValidationError
from pydantic_graph import Graph, GraphBuilder, StepContext

from factory.dependency_graph import compile_dependencies, run_program
from factory.runtime.contracts import (
    Config,
    EscalationPolicy,
    Profile,
    State,
)
from factory.runtime.reports.acceptance import ensure
from factory.runtime.workflow_core import require
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
                role == "implementer",
                "Escalation supports only Implementer assignments",
            )
    dependencies = {
        name: [policy["to"]]
        if (policy := profile.get("escalation")) and policy["to"] != "human"
        else []
        for name, profile in profiles.items()
    }
    ensure(
        all(target in profiles for targets in dependencies.values() for target in targets),
        "Unknown escalation target",
    )
    try:
        chain = compile_dependencies(dependencies)
    except CycleError as exc:
        raise ValueError("Escalation cycle") from exc
    for name, profile in profiles.items():
        for target in chain.ancestors(name):
            current = profiles[target]
            ensure(current.get("escalation"), "Escalation chain must end at human")
            for key in ("role", "contract", "capabilities", "enforcement"):
                ensure(
                    current[key] == profile[key],
                    "Escalation must preserve specialty and permissions",
                )
            ensure(
                set(current["mcp"]) == set(profile["mcp"]),
                "Escalation must preserve required tools",
            )
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


@dataclass(frozen=True)
class RetryBudget:
    """A task's allowance against the counters of the locked run snapshot."""

    key: str
    limit: int
    counters: dict[str, int]

    @classmethod
    def for_task(cls, state: State, task_id: str, cause: str) -> RetryBudget:
        allowances = limits(state, task_id)
        require(cause in allowances, "Unknown retry stage")
        return cls(f"{task_id}:{cause}", allowances[cause], state["counters"])

    @property
    def used(self) -> int:
        return self.counters.get(self.key, 0)

    @property
    def remaining(self) -> int:
        return self.limit - self.used

    def require_available(self, message: str = "RETRY_BUDGET_EXHAUSTED") -> None:
        require(self.remaining > 0, message)

    def spend(self) -> None:
        self.require_available()
        self.counters[self.key] = self.used + 1


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


type CorrectionRoute = tuple[str, Literal["blocked", "human", "retry", "escalate"]]


@dataclass(frozen=True)
class CorrectionInput:
    kind: str
    profile: str
    policy: EscalationPolicy
    failures: int
    used: int
    limit: int


async def hold_for_resolution(ctx: StepContext) -> CorrectionRoute:
    return cast(CorrectionInput, ctx.inputs).profile, "blocked"


async def wait_for_human(ctx: StepContext) -> CorrectionRoute:
    return "human", "human"


async def retry_profile(ctx: StepContext) -> CorrectionRoute:
    return cast(CorrectionInput, ctx.inputs).profile, "retry"


async def escalate_profile(ctx: StepContext) -> CorrectionRoute:
    return cast(CorrectionInput, ctx.inputs).policy["to"], "escalate"


@cache
def correction_graph() -> Graph:
    builder = GraphBuilder(name="Correction", input_type=CorrectionInput, auto_instrument=False)
    blocked = builder.step(hold_for_resolution)
    human = builder.step(wait_for_human)
    retry = builder.step(retry_profile)
    escalate = builder.step(escalate_profile)
    target = (
        builder.decision(node_id="configured_escalation_target")
        .branch(
            builder.match(CorrectionInput, matches=lambda c: c.policy["to"] == "human").to(human)
        )
        .branch(
            builder.match(CorrectionInput, matches=lambda c: c.policy["to"] == c.profile).to(retry)
        )
        .branch(builder.match(CorrectionInput).to(escalate))
    )
    route = (
        builder.decision(node_id="diagnosis_and_budget")
        .branch(
            builder.match(
                CorrectionInput, matches=lambda c: c.kind in {"environment", "requirements"}
            ).to(blocked)
        )
        .branch(builder.match(CorrectionInput, matches=lambda c: c.used >= c.limit).to(human))
        .branch(
            builder.match(
                CorrectionInput, matches=lambda c: c.failures >= c.policy["after_failed_attempts"]
            ).to(target)
        )
        .branch(builder.match(CorrectionInput).to(retry))
    )
    builder.add_edge(builder.start_node, route)
    builder.add(builder.edge_from(blocked, human, retry, escalate).to(builder.end_node))
    return builder.build()


def correction_decision(
    kind: str, profile_id: str, policy: EscalationPolicy, failures: int, used: int, budget: int
) -> CorrectionRoute:
    facts = CorrectionInput(kind, profile_id, policy, failures, used, budget)
    return cast(CorrectionRoute, run_program(correction_graph(), inputs=facts))
