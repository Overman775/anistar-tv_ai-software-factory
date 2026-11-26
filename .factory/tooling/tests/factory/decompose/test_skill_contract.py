#!/usr/bin/env python3
"""Static contract tests for FactoryDecompose ownership boundaries."""

from __future__ import annotations

import unittest
from pathlib import Path

from factory.paths import FACTORY_ROOT
from tests.fixture_bundle import ROOT as FIXTURE_ROOT

ROOT = FACTORY_ROOT.parent
SKILL = ROOT / ".factory/skills/factory-decompose/SKILL.md"
POLICY = ROOT / ".factory/skills/factory-decompose/references/decomposition-policy.md"
GENERATION = ROOT / ".factory/skills/factory-decompose/references/generation-contract.md"
STAGING = GENERATION.with_name("staging-contract.md")
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
        self.assertIn("decompose run init", read(SKILL))
        self.assertIn("--plan docs/plans/PLAN.md", read(SKILL))
        self.assertIn("plan ID, revision, hash", read(SKILL))
        self.assertIn("--authorization", read(SKILL))

    def test_skill_has_no_semantic_planner_or_second_approval_loop(self) -> None:
        self.assertIn("approved plan is immutable", read(SKILL))
        self.assertIn("unresolved product decision goes back to Planning", read(SKILL))

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
        self.assertIn("approved plan is immutable", read(SKILL))

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
        self.assertIn("template headings", skill)
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

    def test_sources_and_final_review_follow_profile_and_locked_plan(self) -> None:
        for path in (DECOMPOSER, REVIEWER):
            content = " ".join(read(path).split())
            self.assertIn("all applicable", content.lower())
            self.assertIn("matching locked plan bytes", content)
            self.assertIn("specific gap and evidence", content)
            self.assertNotIn("both canonical", content)
        decomposer = read(DECOMPOSER)
        self.assertIn("`plan_path` in the source lock", decomposer)
        self.assertIn("then reread the saved files", decomposer)
        self.assertIn("decomposition-policy.md#decomposition-order", decomposer)
        reviewer = " ".join(read(REVIEWER).split())
        self.assertIn("one repair pass", reviewer)
        self.assertIn("complete final task set against the locked plan", reviewer)
        opening = reviewer.split("## Required Sources", 1)[0]
        self.assertIn("complete final task set against the locked plan", opening)
        self.assertIn("Reuse prior discovery where unchanged", opening)
        self.assertNotIn("recheck of changed sections", reviewer)
        self.assertIn("transport, session and media contracts", reviewer)
        skill = " ".join(read(SKILL).split())
        self.assertIn("project profile", skill)
        self.assertIn("complete corrected set", skill)

    def test_graph_gate_is_documented_as_strict(self) -> None:
        self.assertIn("run validate", read(ROOT / ".factory/gates/skills/decompose/gate.md"))
        self.assertIn("coverage", read(ROOT / ".factory/gates/skills/decompose/gate.md"))
        self.assertIn("cycles", read(ROOT / ".factory/gates/skills/decompose/gate.md"))
        self.assertIn("project checks", read(ROOT / ".factory/gates/skills/decompose/gate.md"))
        self.assertIn("independent verdict", read(ROOT / ".factory/gates/skills/decompose/gate.md"))

    def test_task_template_has_single_implemented_body(self) -> None:
        template = read(TEMPLATE)
        self.assertIn("## 2. Task scope (`implemented`)", template)
        self.assertIn("## 3. Deferred work (`deferred`)", template)
        self.assertNotIn("### In scope (`implemented`)", template)

    def test_language_rule_preserves_project_language_and_technical_identity(self) -> None:
        for path in (SKILL, DECOMPOSER, REVIEWER):
            self.assertIn("technical identit", read(path))
        template = read(TEMPLATE)
        self.assertIn("If translation does not change technical identity", template)
        self.assertIn("Exact template headings and machine values remain unchanged", template)

    def test_final_tasks_exclude_machine_technical_contract(self) -> None:
        self.assertIn("public task Markdown", read(STAGING))
        self.assertIn("Internal schema never appears in final task Markdown", read(STAGING))

    def test_personas_route_semantic_gaps_to_planning(self) -> None:
        decomposer = read(DECOMPOSER)
        reviewer = read(REVIEWER)
        self.assertIn("SEMANTIC_GAP", decomposer)
        self.assertIn("generation-contract.md", decomposer)
        self.assertIn("SEMANTIC_GAP", reviewer)
        self.assertIn("affected capabilities", reviewer)
        self.assertNotIn("BLOCKED_PLAN_GAP", decomposer + reviewer)

    def test_transactional_staging_is_required(self) -> None:
        self.assertIn("in SQLite", read(STAGING) + read(OUTPUT))
        self.assertIn("exact bytes", read(STAGING) + read(OUTPUT))
        self.assertIn("prepare-publication", read(STAGING) + read(OUTPUT))
        self.assertIn("lost response", read(STAGING) + read(OUTPUT))
        self.assertIn("foreign directory", read(STAGING) + read(OUTPUT))

    def test_agent_checkpoint_preserves_checkpoint_and_retry_budget(self) -> None:
        self.assertIn("original ticket", read(CHECKPOINT))
        self.assertIn("lost response", read(CHECKPOINT))
        self.assertIn("terminal", read(CHECKPOINT))
        self.assertIn("Never run two writer roles concurrently", read(CHECKPOINT))

    def test_role_lifecycles_are_bounded_by_plan_tuple_and_gate(self) -> None:
        self.assertIn("plan ID, revision, hash", read(SKILL))
        self.assertIn("first assignment reads", read(SKILL))
        self.assertIn("allowed files", read(SKILL))
        self.assertIn("fresh verdict", read(SKILL))
        self.assertIn("complete corrected set", read(SKILL))

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
