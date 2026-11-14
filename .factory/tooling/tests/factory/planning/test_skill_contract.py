from __future__ import annotations

import unittest
from pathlib import Path
from typing import Any

from factory.paths import FACTORY_ROOT
from tests.fixture_bundle import ROOT as FIXTURE_ROOT

ROOT = FACTORY_ROOT.parent
SKILL = ROOT / ".factory/skills/factory-planning/SKILL.md"
CONTRACT = ROOT / ".factory/skills/factory-planning/references/plan-contract.md"
SESSION = ROOT / ".factory/skills/factory-planning/references/session-contract.md"
VALIDATOR = ROOT / ".factory/gates/skills/planning/validate_plan.py"
ARCHITECT = ROOT / ".factory/roles/architect.md"
ARCHITECT_CONTRACT = ROOT / ".factory/contracts/architect.md"
CHECKPOINT = ROOT / ".factory/contracts/common/agent-checkpoint.md"
DETAIL_CONTRACT = ROOT / ".factory/contracts/common/implementation-detail.md"
ADAPTERS: dict[str, Any] = {
    "codex": ROOT / ".factory/adapters/codex.md",
    "claude": ROOT / ".factory/adapters/claude.md",
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_validator() -> str:
    return "\n".join(
        read(FACTORY_ROOT / "tooling/factory/planning" / name)
        for name in (
            "validate_plan.py",
            "plan_document.py",
            "plan_rules.py",
            "plan_revision.py",
        )
    )


class SkillContractTest(unittest.TestCase):
    def test_bundle_exists_and_skill_is_compact(self) -> None:
        for path in (
            SKILL,
            CONTRACT,
            SESSION,
            VALIDATOR,
            ARCHITECT,
            ARCHITECT_CONTRACT,
            CHECKPOINT,
            DETAIL_CONTRACT,
        ):
            self.assertTrue(path.is_file(), path)
        self.assertLessEqual(len(read(SKILL).splitlines()), 315)
        self.assertIn("[working session contract](references/session-contract.md)", read(SKILL))
        self.assertIn("[plan contract](references/plan-contract.md)", read(SKILL))
        self.assertIn("[validator](../../gates/skills/planning/validate_plan.py)", read(SKILL))

    def test_trigger_boundary_skips_clear_ticket_but_routes_ambiguity(self) -> None:
        skill = read(SKILL)
        for marker in (
            "ordinary self-contained ticket",
            "may go directly to `factory-implement`",
            "behavior, scope, architecture, API/storage contract",
            "sole semantic planning source",
        ):
            self.assertIn(marker, skill)

    def test_no_plan_and_delegated_planning_are_distinct(self) -> None:
        skill = read(SKILL)
        contract = read(CONTRACT)
        session = read(SESSION)
        for marker in (
            "`no plan`, `no plan needed`",
            "`decide yourself`, `do it yourself`, `at your discretion`",
            "Explicit no-plan wording wins",
            "delegated planning",
            "do not ask `ASK` questions",
            "`BLOCK` facts remain blockers",
        ):
            self.assertIn(marker, skill + session)
        self.assertIn("Planning authorization: explicit_user_delegation", contract)
        self.assertIn("Keep metadata unchanged", contract)

    def test_architect_is_planning_owned_and_developer_roles_are_excluded(self) -> None:
        skill = read(SKILL)
        self.assertIn("`architect` is Factory Planning-owned", skill)
        self.assertIn("`.factory/memory/staging/planning-plan.md`", skill)
        self.assertIn("Do not invoke Developer, TestWriter, Reviewer", skill)
        self.assertIn("No `task-decomposition-planner`", skill)

    def test_architect_persona_owns_planning_draft(self) -> None:
        content = read(ARCHITECT)
        self.assertIn("planning-plan.md", content)
        self.assertNotIn("implementation-plan.md", content)

    def test_paths_and_transactional_contract_are_explicit(self) -> None:
        content = read(SKILL) + read(CONTRACT)
        normalized = " ".join(content.split())
        for marker in (
            ".factory/memory/staging/planning-session.md",
            ".factory/memory/staging/planning-plan.md",
            "docs/plans/{plan_id}.md",
            "temporary file beside target",
            "atomically replace target",
            "last valid checkpoint",
            "Do not delete staging or approved files",
            "Never use destructive cleanup",
        ):
            self.assertIn(marker, normalized)
        self.assertIn("planning-plan.md.candidate", read(SKILL))
        self.assertIn("--previous .factory/memory/staging/planning-plan.md", read(SKILL))
        self.assertNotIn(
            "--plan .factory/memory/staging/planning-plan.md --phase",
            read(SKILL),
        )

    def test_human_first_sections_are_exact(self) -> None:
        contract = read(CONTRACT)
        sections = (
            "## What changes",
            "## How it works",
            "## Solution structure",
            "## Key decisions",
            "## Unknowns and boundaries",
            "## Readiness and verification",
            "## Handoff",
        )
        positions = [contract.index(section) for section in sections]
        self.assertEqual(positions, sorted(positions))
        self.assertIn("one numbered primary flow", contract)
        self.assertIn("exception/decision table", contract)
        self.assertIn("Write human-facing prose in the task/project language", read(SKILL))
        self.assertIn("Ordinary prose follows task/project language", contract)
        self.assertIn("`loading/error/retry/empty`", contract)
        self.assertIn("ordinary prose unless they are exact identifiers", contract)
        self.assertIn("do not count language ratios", contract)

    def test_architecture_sources_are_full_and_not_subject_to_lookup_budget(self) -> None:
        skill = read(SKILL)
        architect = read(ARCHITECT)
        contract = read(ARCHITECT_CONTRACT)
        project = read(FIXTURE_ROOT / "project/rules/planning.md")
        for path in ("docs/01_architecture_principles.md", "docs/02_project_structure.md"):
            self.assertIn(path, project)
            for generic in (skill, architect, contract):
                self.assertNotIn(path, generic)
        self.assertIn("read full", project)
        self.assertIn("not optional context optimization", project)
        self.assertIn("project profile", skill)
        self.assertIn("Full architecture documents\n   govern solution shape", architect)

    def test_pseudocode_is_optional_natural_language(self) -> None:
        content = read(SKILL) + read(CONTRACT)
        for marker in (
            "Pseudocode is optional",
            "state machine, reducer, schema, or\nalgorithm",
            "using natural-language lines",
            "no\nproduction code",
        ):
            self.assertIn(marker, content)

    def test_decisions_are_settled_choices_and_facts_externals_stay_separate(self) -> None:
        contract = read(CONTRACT)
        session = read(SESSION)
        for marker in (
            "`USER_DECISION`",
            "`BLOCK`",
            "`official_fact`",
            "`user_acceptance_observation`",
            "`project_fact`",
            "`inference`",
            "`D-{NN}`",
            "`EXT-{NN}`",
            "Facts and external dependencies do not become\ndecision rows",
        ):
            self.assertIn(marker, contract + session)
        self.assertIn(
            "| ID | Decision | Why | Applicability | Verification/constraint |",
            contract,
        )
        self.assertNotIn("| ID | Status | Decision/fact |", contract)
        self.assertIn("- No significant decisions.", contract)

    def test_planning_owns_capabilities_not_decomposition_fields(self) -> None:
        content = read(SKILL) + read(CONTRACT)
        for marker in (
            "stable capabilities/requirements (`CAP-{NN}`)",
            "does not own task/slice IDs",
            "affected\nlayers, estimates, ticket dependency graph",
            "Never use future task/slice IDs",
            "maps `CAP-*` to tickets",
        ):
            self.assertIn(marker, content)

    def test_metadata_is_minimal_without_question_counters(self) -> None:
        contract = read(CONTRACT)
        metadata_block = contract.split("Use exactly these metadata keys:", 1)[1].split("```", 2)[1]
        expected = {
            "plan_id",
            "revision",
            "plan_state",
            "status",
            "approved_revision",
            "source",
            "handoff_recommendation",
        }
        actual = {line.split(":", 1)[0] for line in metadata_block.splitlines() if ":" in line}
        self.assertEqual(expected, actual)
        self.assertIn("No question budgets, counters", contract)

    def test_api_evidence_is_typed_and_fingerprint_stays_internal(self) -> None:
        content = read(SKILL) + read(CONTRACT)
        for marker in (
            "`backend_api`",
            "`platform_plugin_api`",
            "`storage`",
            "`local_contract`",
            "`external_contract`",
            "`none`",
            "full API/platform fingerprint internal",
            "only behavior-shaping gist",
            "comma-separated list of declared `CAP-*`",
        ):
            self.assertIn(marker, content)

    def test_plan_is_durable_seed_and_implementation_detail_stays_downstream(self) -> None:
        skill = read(SKILL)
        contract = read(CONTRACT)
        detail_contract = read(DETAIL_CONTRACT)
        for marker in (
            "durable semantic execution seed",
            "planning-only work does not trigger it",
        ):
            self.assertIn(marker, skill)
        for marker in (
            "Plan content is the durable semantic layer",
            "A plan-only request stops without current\nimplementation-detail lookup",
            "stable execution seed",
            "Current code anchors may appear as evidence-backed references",
            "Both downstream paths may apply the shared implementation-detail contract",
        ):
            self.assertIn(marker, contract)
        self.assertIn("## Information Lifetime", detail_contract)
        self.assertIn("Planning-only work stops at the durable layer", detail_contract)
        self.assertIn("Exact anchors are\noptional current references", detail_contract)
        self.assertNotIn("## Consumer Rules", detail_contract)

    def test_preflight_removes_duplication_without_length_target(self) -> None:
        content = " ".join((read(SKILL) + read(CONTRACT) + read(SESSION)).split())
        for marker in (
            "section-role deduplication",
            "Section-role deduplication map",
            "single full statement and rationale",
            "Deduplicate semantically",
            "Do not optimize for a fixed word count",
            "No fixed word-count target applies",
            "never shorten against a word target",
        ):
            self.assertIn(marker, content)

    def test_ready_working_map_uses_single_architect_fast_path(self) -> None:
        content = read(SKILL) + read(SESSION)
        for marker in (
            "Architect fast path",
            "Give Architect source lock and working map once",
            "do not repeat Reality Check or source search",
            "Reopen discovery only",
        ):
            self.assertIn(marker, content)

    def test_checkpoint_contract_covers_explorer_and_every_architect_pass(self) -> None:
        skill = read(SKILL)
        checkpoint = read(CHECKPOINT)
        for marker in (
            "every `code-explorer` and Architect handoff",
            "Explicitly failed/invalid `code-explorer` handoff",
            "Explicitly failed/invalid Architect handoff",
            "Never run a concurrent second Architect",
        ):
            self.assertIn(marker, skill)
        for marker in (
            "Silence is not failure",
            "Do not count quiet or silent windows",
            "poll count or elapsed time",
            "Allowed Interruption",
            "BLOCKED_AGENT_FAILURE",
            "Never run two writer roles concurrently",
            "Runtime capability differences do not create role failure",
        ):
            self.assertIn(marker, checkpoint)

    def test_adapters_use_checkpoint_observation_without_timer_failure(self) -> None:
        for runtime, adapter in ADAPTERS.items():
            content = read(adapter)
            self.assertIn("checkpoint", content.lower(), runtime)
            self.assertNotIn("## Watchdog Capability", content, runtime)
            self.assertNotIn("checkpoint_only", content, runtime)
        self.assertIn("silence is failure", read(CHECKPOINT).lower())
        self.assertIn("wait timeout means only", read(CHECKPOINT).lower())

    def test_developer_blocking_externals_get_conditional_readiness_matrix(self) -> None:
        contract = read(CONTRACT)
        self.assertIn("prevents implementation of named capabilities", contract)
        self.assertIn("| Capability | Current readiness | Start condition |", contract)
        self.assertIn("QA/release do not require the matrix", contract)
        self.assertIn("Do not add readiness tables by quota", contract)

    def test_acceptance_and_qa_are_separate(self) -> None:
        contract = read(CONTRACT)
        self.assertIn("### Developer acceptance and readiness", contract)
        self.assertIn("### QA checks", contract)
        self.assertNotIn("### Developer acceptance readiness", contract)
        self.assertNotIn("### QA checklist", contract)

    def test_recursive_questions_live_before_first_revision(self) -> None:
        content = read(SKILL) + read(CONTRACT) + read(SESSION) + read_validator()
        for marker in (
            "After every answer, update the working map and run an impact scan",
            "newly revealed branch",
            "consume a plan revision",
            "First promoted user-reviewable plan is `revision: 1`",
            "Active questions belong to planning-session.md",
        ):
            self.assertIn(marker, content)

    def test_architect_only_returns_candidate_and_parent_promotes(self) -> None:
        role = read(ARCHITECT)
        contract = read(ROOT / ".factory/contracts/architect.md")
        self.assertIn("Never replace the live target", role)
        self.assertIn("planning-plan.md.candidate` only", contract)
        self.assertIn("Coordinator alone promotes", contract)
        self.assertIn("live target unchanged", contract)

    def test_single_canonical_plan_preserves_approved_git_history(self) -> None:
        content = read(CONTRACT)
        self.assertIn("do not create revision-specific plan files", content)
        self.assertIn("explicit", content)
        self.assertIn("immutable Git commit", content)
        self.assertIn("keep pinned bytes/revision/hash", content)
        self.assertIn("--change-kind nonsemantic --change-evidence", content)

    def test_candidate_preflight_returns_semantic_gaps_to_session(self) -> None:
        content = read(SKILL) + read(CONTRACT) + read(SESSION)
        for marker in (
            "semantic preflight",
            "semantic gap",
            "machine-only defects",
            "without user approval",
            "Atomically promote only after both checks pass",
        ):
            self.assertIn(marker, content)

    def test_bounded_reality_check_reuses_evidence(self) -> None:
        content = read(SKILL) + read(SESSION) + read(ARCHITECT)
        for marker in (
            "Batch lookup by semantic surface",
            "reuse collected\nevidence across the session",
            "one narrow follow-up",
            "never reopen search for wording",
            "Reuse evidence",
        ):
            self.assertIn(marker, content)

    def test_strict_quality_gates_cover_capabilities_externals_and_handoff(self) -> None:
        content = read(SKILL) + read(CONTRACT) + read(ARCHITECT) + read_validator()
        for marker in (
            "Every declared capability must\nbe covered by at least one typed row",
            "explicit non-empty `handling:`",
            "HANDOFF_CONTINUATION_MISSING",
            "HANDOFF_CONTINUATION_UNAUTHORIZED",
            "CAPABILITY_CONTRACT_COVERAGE_MISSING",
            "EXTERNAL_HANDLING_MISSING",
        ):
            self.assertIn(marker, content)

    def test_instruction_ownership_keeps_spawn_handoffs_bounded(self) -> None:
        skill = read(SKILL)
        for marker in (
            "session contract owns discovery state and decision loop",
            "plan contract owns output schema",
            "validator owns mechanical structure",
            "Do not copy their\ncanonical instructions into spawn prompts",
        ):
            self.assertIn(marker, skill)

    def test_handoff_is_advice_and_skill_does_not_launch_downstream(self) -> None:
        skill = read(SKILL)
        for marker in (
            "`handoff_recommendation: direct | decompose | either` is advice",
            "Without pre-authorized continuation, ask user to choose next action",
            "itself does not launch downstream",
            "parent may\nstart the requested downstream skill without another checkpoint",
            "do not hard-block",
            "must not publish task items",
        ):
            self.assertIn(marker, skill)

    def test_delegated_approval_reuses_existing_metadata_contract(self) -> None:
        contract = read(CONTRACT)
        metadata_block = contract.split("Use exactly these metadata keys:", 1)[1].split("```", 2)[1]
        self.assertNotIn("approval_mode", metadata_block)
        self.assertNotIn("approval_evidence", metadata_block)
        for marker in (
            "explicit delegated planning captured before discovery",
            "advance authorization, not exact revision review",
            "approval candidate must differ only in approval metadata",
            "pre-authorized direct execution",
        ):
            self.assertIn(marker, contract)


if __name__ == "__main__":
    unittest.main()
