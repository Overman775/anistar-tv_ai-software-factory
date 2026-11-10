#!/usr/bin/env python3
"""Static contract tests for FactoryDecompose ownership boundaries."""

from __future__ import annotations

import unittest
from pathlib import Path

from factory_tooling.paths import FACTORY_ROOT
from tests.fixture_bundle import ROOT as FIXTURE_ROOT

ROOT = FACTORY_ROOT.parent
SKILL = ROOT / ".factory/skills/factory-decompose/SKILL.md"
POLICY = ROOT / ".factory/skills/factory-decompose/references/decomposition-policy.md"
GENERATION = ROOT / ".factory/skills/factory-decompose/references/generation-contract.md"
OUTPUT = ROOT / ".factory/skills/factory-decompose/references/output-contract.md"
TEMPLATE = ROOT / ".factory/skills/factory-decompose/references/task-template.md"
DECOMPOSER = ROOT / ".factory/roles/task-decomposer.md"
REVIEWER = ROOT / ".factory/roles/task-reviewer.md"
CHECKPOINT = ROOT / ".factory/contracts/common/agent-checkpoint.md"
DETAIL_CONTRACT = ROOT / ".factory/contracts/common/implementation-detail.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class FactoryDecomposeContractTest(unittest.TestCase):
    def test_skill_accepts_only_approved_planning_plan(self) -> None:
        skill = read(SKILL)
        self.assertIn("validate_plan.py", skill)
        self.assertIn("BLOCKED_NO_APPROVED_PLAN", skill)
        self.assertIn("NEEDS_PLANNING", skill)
        self.assertIn("docs/plans/{plan_id}.md", skill)

    def test_skill_has_no_semantic_planner_or_second_approval_loop(self) -> None:
        content = " ".join(
            " ".join(read(path).split()) for path in (SKILL, POLICY, GENERATION, DETAIL_CONTRACT)
        )
        self.assertNotIn("decompose-plan.md", content)
        self.assertNotIn("implementation-plan.md", content)
        self.assertIn("does not ask the\nuser to approve another plan revision", read(SKILL))

    def test_decomposition_owns_tasks_not_plan_semantics(self) -> None:
        content = "\n".join(read(path) for path in (SKILL, POLICY, DECOMPOSER))
        for token in (
            "task IDs",
            "estimates",
            "dependencies",
            "capability",
            "affected_layers",
        ):
            self.assertIn(token.lower(), content.lower())
        self.assertIn("Approved plan is immutable", read(SKILL))

    def test_human_task_has_plan_provenance_and_qa(self) -> None:
        template = read(TEMPLATE)
        self.assertIn("Plan source", template)
        self.assertIn("Covers capabilities", template)
        self.assertIn("QA checks", template)
        self.assertIn("Contract type", template)
        self.assertIn("`D-*` where `Applicability`", template)
        self.assertIn("`EXT-*` from boundaries", template)

    def test_shared_implementation_detail_is_actionable_without_symbol_inventory(self) -> None:
        for path in (
            DETAIL_CONTRACT,
            POLICY,
            GENERATION,
            TEMPLATE,
            DECOMPOSER,
            REVIEWER,
        ):
            self.assertTrue(path.is_file(), path)
        content = " ".join(
            " ".join(read(path).split()) for path in (SKILL, POLICY, GENERATION, DETAIL_CONTRACT)
        )
        for token in (
            "one plan-level",
            "task boundaries",
            "one bounded targeted lookup",
            "contract-level wording",
            "alone never returns `NEEDS_PLANNING`",
            "no internal-envelope fields",
        ):
            self.assertIn(token, content)
        template = read(TEMPLATE)
        self.assertIn("Exact existing symbols\nare optional", template)
        self.assertIn("Do not repeat the full signature here", template)
        self.assertIn("Do not inventory private symbols", read(DETAIL_CONTRACT))
        reviewer = read(REVIEWER)
        self.assertIn("one repair pass", reviewer)
        self.assertIn("one targeted spot-check", reviewer)
        self.assertIn("wording repair, not a planning gap", reviewer)
        detail_contract = read(DETAIL_CONTRACT)
        for token in (
            "## Information Lifetime",
            "## Risk-Adaptive Depth",
            "## Anchors and Bounded Check",
            "## Human Output and Deduplication",
            "## Escalation",
        ):
            self.assertIn(token, detail_contract)
        self.assertNotIn("## Consumer Rules", detail_contract)
        self.assertLessEqual(len(detail_contract.splitlines()), 115)

    def test_human_markdown_uses_assigned_artifact_language(self) -> None:
        skill = read(SKILL)
        template = read(TEMPLATE)
        reviewer = read(REVIEWER)
        self.assertIn("Write task and epic prose in the task/project language", skill)
        self.assertIn("no language ratio, glossary, or code lookup", skill)
        self.assertIn("Ordinary prose follows the assigned artifact language", reviewer)
        for mixed_phrase in (
            "For each independent flow",
            "Exact existing symbols are mandatory",
            "### QA checklist after MR",
        ):
            self.assertNotIn(mixed_phrase, template)

    def test_contract_types_follow_planning_taxonomy(self) -> None:
        contract_types = (
            "backend_api",
            "platform_plugin_api",
            "storage",
            "local_contract",
            "external_contract",
            "none",
        )
        for path in (POLICY, TEMPLATE):
            content = read(path)
            for contract_type in contract_types:
                self.assertIn(contract_type, content, f"{contract_type} missing from {path}")

    def test_architecture_sources_remain_mandatory_for_both_roles(self) -> None:
        skill = read(SKILL)
        project = read(FIXTURE_ROOT / "project/rules/decomposition.md")
        for token in ("docs/01_architecture_principles.md", "docs/02_project_structure.md"):
            self.assertIn(token, project)
            self.assertNotIn(token, skill)
        self.assertIn("project profile", skill)
        for path in (DECOMPOSER, REVIEWER):
            content = read(path)
            self.assertIn("in full", content)
            self.assertIn("profile", content)

    def test_graph_gate_is_documented_as_strict(self) -> None:
        skill = read(SKILL)
        self.assertIn("../../gates/skills/decompose/gate.md", skill)
        skill += read(FACTORY_ROOT / "gates/skills/decompose/gate.md")
        generation = read(GENERATION)
        for content in (skill, generation):
            self.assertIn("--source-lock", content)
        self.assertIn("Every reported violation is a hard block", generation)
        self.assertIn("Graph gate: PASS", generation)
        self.assertIn(
            "Single-task/list payloads, version tags and inferred filenames are rejected",
            generation,
        )

    def test_task_template_has_single_implemented_body(self) -> None:
        template = read(TEMPLATE)
        self.assertIn("## 2. Task scope (`implemented`)", template)
        self.assertIn("## 3. Deferred work (`deferred`)", template)
        self.assertNotIn("### In scope (`implemented`)", template)

    def test_language_rule_preserves_project_language_and_technical_identity(self) -> None:
        for path in (SKILL, DECOMPOSER, REVIEWER):
            self.assertIn("technical identity", read(path))
        template = read(TEMPLATE)
        self.assertIn("If translation does not change technical identity", template)
        self.assertIn("Exact template headings and machine values remain unchanged", template)

    def test_final_tasks_exclude_machine_technical_contract(self) -> None:
        output = read(OUTPUT)
        self.assertIn("no internal task_result.json envelope", output)
        self.assertIn("publication composition", output)
        self.assertIn("not technical\nimplementation contract", output)

    def test_personas_route_semantic_gaps_to_planning(self) -> None:
        decomposer = read(DECOMPOSER)
        reviewer = read(REVIEWER)
        self.assertIn("NEEDS_PLANNING", decomposer)
        self.assertIn("generation-contract.md", decomposer)
        self.assertIn("NEEDS_PLANNING", reviewer)
        self.assertIn("affected_capabilities", reviewer)
        self.assertNotIn("BLOCKED_PLAN_GAP", decomposer + reviewer)

    def test_transactional_staging_is_required(self) -> None:
        self.assertIn("generation-contract.md#transactional-staging", read(SKILL))
        self.assertIn("atomically rename", read(GENERATION))
        self.assertIn("generation-contract.md", read(DECOMPOSER))
        self.assertIn("Transaction", read(OUTPUT))

    def test_agent_checkpoint_preserves_checkpoint_and_retry_budget(self) -> None:
        content = "\n".join(read(path) for path in (SKILL, DECOMPOSER, REVIEWER, CHECKPOINT))
        for token in (
            "task-decomposer",
            "task-reviewer",
            "Keep waiting",
            "BLOCKED_AGENT_FAILURE",
            "last valid checkpoint",
            "Recovery does not consume graph fast-fix or reviewer repair\niteration",
            "Never run two writer roles concurrently",
        ):
            self.assertIn(token, content)
        self.assertNotIn("STALLED_AGENT", content)

    def test_role_lifecycles_are_bounded_by_plan_tuple_and_gate(self) -> None:
        normalized = " ".join(read(SKILL).split())
        for token in (
            "`plan_id + revision + plan_hash + canonical role`",
            "Transactional checkpoint is continuation evidence, not identity",
            "one decomposer graph fast-fix before Graph Gate `PASS`",
            "reviewer repair plus focused recheck",
            "Terminalize at those boundaries",
            "new approved revision uses fresh roles and full decomposition rerun",
        ):
            self.assertIn(" ".join(token.split()), normalized)

    def test_obsolete_planner_files_are_absent(self) -> None:
        obsolete = (
            ROOT / ".factory/roles/task-decomposition-planner.md",
            ROOT / ".codex/agents/task-decomposition-planner.toml",
            ROOT / ".claude/agents/decompose/task-decomposition-planner.md",
            ROOT / ".gemini/agents/decompose/task-decomposition-planner.md",
            ROOT / ".opencode/agents/task-decomposition-planner.md",
            ROOT / ".factory/skills/factory-decompose/references/pre-plan-contract.md",
        )
        for path in obsolete:
            self.assertFalse(path.exists(), str(path))


if __name__ == "__main__":
    unittest.main()
