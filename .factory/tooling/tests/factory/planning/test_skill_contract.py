from __future__ import annotations

import unittest
from pathlib import Path
from typing import Any

from factory.graphs.definition import Selection, parse
from factory.paths import FACTORY_ROOT
from tests.fixture_bundle import ROOT as FIXTURE_ROOT

ROOT = FACTORY_ROOT.parent
SKILL = ROOT / ".factory/skills/factory-planning/SKILL.md"
CONTRACT = ROOT / ".factory/skills/factory-planning/references/plan-contract.md"
PLAN_CONTENT = CONTRACT.with_name("plan-content.md")
SESSION = ROOT / ".factory/skills/factory-planning/references/session-contract.md"
VALIDATOR = ROOT / ".factory/tooling/bin/cli"
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


def routes(process: str) -> dict[str, str]:
    definition = parse(process, read(FACTORY_ROOT / "graphs" / (process + ".yaml")))
    entry = definition.nodes[definition.entry]
    assert isinstance(entry, Selection)
    return {r.outcome: r.target for r in entry.routes}


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
        self.assertIn("[working session](references/session-contract.md)", read(SKILL))
        self.assertIn("[plan contract](references/plan-contract.md)", read(SKILL))
        self.assertIn("cli planning run init", read(SKILL))

    def test_architect_and_coordinator_use_one_plan_template(self) -> None:
        self.assertIn("## Canonical Template", read(PLAN_CONTENT))
        for reference in (CONTRACT, CONTRACT.with_name("architect-plan-contract.md")):
            text = read(reference)
            self.assertIn("(plan-content.md)", text)
            self.assertNotIn("## Canonical Template", text)

    def test_trigger_boundary_skips_clear_ticket_but_routes_ambiguity(self) -> None:
        self.assertEqual(routes("implement-source")["approved_or_ready"], "admit")
        self.assertEqual(routes("implement-source")["gap"], "hold")
        self.assertIn("self-contained execution request", read(SKILL))

    def test_no_plan_and_delegated_planning_are_distinct(self) -> None:
        graph = routes("implement-source")
        self.assertEqual((graph["forbidden"], graph["delegated"]), ("hold", "planning"))
        self.assertIn("explicit_user_delegation", read(CONTRACT) + read(PLAN_CONTENT))

    def test_architect_is_planning_owned_and_implementation_roles_are_excluded(self) -> None:
        graph = routes("planning")
        self.assertEqual(graph["intake"], "architect")
        self.assertNotIn("implementer", graph.values())
        self.assertNotIn("tester", graph.values())

    def test_architect_persona_owns_planning_draft(self) -> None:
        content = read(ARCHITECT)
        self.assertIn("candidate", content)
        self.assertNotIn("implementation-plan.md", content)

    def test_architect_receives_nonsemantic_revision_evidence(self) -> None:
        candidate = read(
            ROOT / ".factory/skills/factory-planning/references/architect-plan-contract.md"
        )
        normalized = " ".join(candidate.split())
        self.assertIn(
            '--change-kind nonsemantic --change-evidence "{specific rationale}"', normalized
        )
        self.assertIn("using the coordinator's evidence", normalized)
        self.assertIn("classification or required evidence is missing", normalized)

    def test_paths_and_transactional_contract_are_explicit(self) -> None:
        self.assertIn("--destination docs/plans/PLAN.md", read(SKILL))
        self.assertIn("--previous", read(SKILL))
        self.assertIn("previous public file", read(SKILL))
        self.assertIn("planning run history", read(SKILL))

    def test_human_first_sections_are_exact(self) -> None:
        contract = read(CONTRACT) + read(PLAN_CONTENT)
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
        self.assertIn("Use the task/project language", read(SKILL))
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
        content = read(SKILL) + (read(CONTRACT) + read(PLAN_CONTENT))
        for marker in (
            "Pseudocode is optional",
            "state machine, reducer, schema, or\nalgorithm",
            "using natural-language lines",
            "no\nproduction code",
        ):
            self.assertIn(marker, content)

    def test_decisions_are_settled_choices_and_facts_externals_stay_separate(self) -> None:
        contract = read(CONTRACT) + read(PLAN_CONTENT)
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
        content = read(SKILL) + (read(CONTRACT) + read(PLAN_CONTENT))
        for marker in (
            "stable capabilities/requirements (`CAP-{NN}`)",
            "does not own task/slice IDs",
            "affected\nlayers, estimates, ticket dependency graph",
            "Never use future task/slice IDs",
        ):
            self.assertIn(marker, content)

    def test_metadata_is_minimal_without_question_counters(self) -> None:
        contract = read(CONTRACT) + read(PLAN_CONTENT)
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
        content = read(SKILL) + (read(CONTRACT) + read(PLAN_CONTENT))
        for marker in (
            "`backend_api`",
            "`platform_plugin_api`",
            "`storage`",
            "`local_contract`",
            "`external_contract`",
            "`none`",
            "full API/platform fingerprint internal",
            "comma-separated list of declared `CAP-*`",
        ):
            self.assertIn(marker, content)

    def test_plan_is_durable_seed_and_implementation_detail_stays_downstream(self) -> None:
        skill = read(SKILL)
        contract = read(CONTRACT) + read(PLAN_CONTENT)
        detail_contract = read(DETAIL_CONTRACT)
        for marker in ("A planning request alone ends at the approved plan",):
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
        content = " ".join(
            (read(SKILL) + (read(CONTRACT) + read(PLAN_CONTENT)) + read(SESSION)).split()
        )
        for marker in (
            "Section-role deduplication map",
            "single full statement and rationale",
            "Deduplicate semantically",
            "Do not optimize for a fixed word count",
            "No fixed word-count target applies",
        ):
            self.assertIn(marker, content)

    def test_ready_working_map_uses_single_architect_fast_path(self) -> None:
        self.assertEqual(routes("planning")["analysis_ready"], "architect")
        self.assertIn("do not repeat Reality Check or source search", read(ARCHITECT_CONTRACT))

    def test_checkpoint_contract_covers_explorer_and_every_architect_pass(self) -> None:
        r = routes("planning")
        self.assertEqual(r["blocked_external_source"], "owner")
        self.assertEqual(r["blocked_requirements"], "owner")
        self.assertEqual(r["needs_exploration"], "explorer")
        self.assertIn("observe the original handle", read(SKILL))
        self.assertIn("Silence is not failure", read(CHECKPOINT))

    def test_adapters_use_checkpoint_observation_without_timer_failure(self) -> None:
        for runtime, adapter in ADAPTERS.items():
            content = read(adapter)
            self.assertIn("checkpoint", content.lower(), runtime)
            self.assertNotIn("## Watchdog Capability", content, runtime)
            self.assertNotIn("checkpoint_only", content, runtime)
        self.assertIn("silence is failure", read(CHECKPOINT).lower())
        self.assertIn("wait timeout means only", read(CHECKPOINT).lower())

    def test_developer_blocking_externals_get_conditional_readiness_matrix(self) -> None:
        contract = read(CONTRACT) + read(PLAN_CONTENT)
        self.assertIn("prevents implementation of named capabilities", contract)
        self.assertIn("| Capability | Current readiness | Start condition |", contract)
        self.assertIn("QA/release do not require the matrix", contract)
        self.assertIn("Do not add readiness tables by quota", contract)

    def test_acceptance_and_qa_are_separate(self) -> None:
        contract = read(CONTRACT) + read(PLAN_CONTENT)
        self.assertIn("### Developer acceptance and readiness", contract)
        self.assertIn("### QA checks", contract)
        self.assertNotIn("### Developer acceptance readiness", contract)
        self.assertNotIn("### QA checklist", contract)

    def test_recursive_questions_live_before_first_revision(self) -> None:
        self.assertEqual(routes("planning")["needs_user_decision"], "owner")
        self.assertEqual(routes("planning")["answer_received"], "architect")
        self.assertIn("After every answer", read(SESSION))
        self.assertIn("owner answers", read(SESSION))

    def test_architect_only_returns_candidate_and_parent_promotes(self) -> None:
        self.assertEqual(routes("planning")["plan_ready"], "review")
        self.assertEqual(routes("planning")["approved"], "publish")
        self.assertIn("coordinator alone reviews", read(ARCHITECT_CONTRACT))

    def test_single_canonical_plan_preserves_approved_git_history(self) -> None:
        content = read(CONTRACT) + read(PLAN_CONTENT)
        self.assertIn("do not create revision-specific plan files", content)
        self.assertIn("explicit", content)
        self.assertIn("immutable Git commit", content)
        self.assertIn("keep pinned bytes/revision/hash", content)
        self.assertIn("--change-kind nonsemantic --change-evidence", content)

    def test_candidate_preflight_returns_semantic_gaps_to_session(self) -> None:
        self.assertEqual(routes("planning")["needs_work"], "architect")
        self.assertIn("Resolve semantic gaps", read(SESSION))
        self.assertIn("cli planning validate --phase draft", read(SESSION))

    def test_bounded_reality_check_reuses_evidence(self) -> None:
        self.assertIn("reuse evidence across the session", read(SESSION))
        self.assertIn("one narrow lookup follow-up", read(SESSION))
        self.assertIn("critical contradiction", read(SESSION))

    def test_strict_quality_gates_cover_capabilities_externals_and_handoff(self) -> None:
        content = (
            read(SKILL) + (read(CONTRACT) + read(PLAN_CONTENT)) + read(ARCHITECT) + read_validator()
        )
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
        self.assertIn("bound `packet`", read(SKILL))
        self.assertIn("plan contract", read(SKILL))
        self.assertIn("working session", read(SKILL))
        self.assertIn("planning gate", read(SKILL))

    def test_handoff_is_advice_and_skill_does_not_launch_downstream(self) -> None:
        self.assertIn("A planning request alone ends at the approved plan", read(SKILL))
        self.assertIn("execution authority to start work", read(SKILL))
        self.assertIn("execution sketch", read(SKILL))

    def test_delegated_approval_reuses_existing_metadata_contract(self) -> None:
        contract = read(CONTRACT) + read(PLAN_CONTENT)
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
