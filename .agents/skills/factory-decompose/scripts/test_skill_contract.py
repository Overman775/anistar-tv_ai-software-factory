#!/usr/bin/env python3
"""Static contract tests for FactoryDecompose ownership boundaries."""

from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SKILL = ROOT / ".agents/skills/factory-decompose/SKILL.md"
POLICY = ROOT / ".agents/skills/factory-decompose/references/decomposition-policy.md"
GENERATION = ROOT / ".agents/skills/factory-decompose/references/generation-contract.md"
OUTPUT = ROOT / ".agents/skills/factory-decompose/references/output-contract.md"
TEMPLATE = ROOT / ".agents/skills/factory-decompose/references/task-template.md"
DECOMPOSER = ROOT / ".agents/agents/task-decomposer.md"
REVIEWER = ROOT / ".agents/agents/task-reviewer.md"
CHECKPOINT = ROOT / ".agents/contracts/common/agent-checkpoint.md"
DETAIL_CONTRACT = ROOT / ".agents/contracts/common/implementation-detail.md"


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
            " ".join(read(path).split())
            for path in (SKILL, POLICY, GENERATION, DETAIL_CONTRACT)
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
        self.assertIn("Источник плана", template)
        self.assertIn("Покрывает возможности", template)
        self.assertIn("Проверки QA", template)
        self.assertIn("Тип контракта", template)
        self.assertIn("`D-*`, где `Применимость`", template)
        self.assertIn("`EXT-*` — из границ", template)

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
            " ".join(read(path).split())
            for path in (SKILL, POLICY, GENERATION, DETAIL_CONTRACT)
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
        self.assertIn("Точные существующие символы\nнеобязательны", template)
        self.assertIn("Не повторяйте здесь полную сигнатуру", template)
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

    def test_human_markdown_uses_russian_ordinary_prose(self) -> None:
        skill = read(SKILL)
        template = read(TEMPLATE)
        reviewer = read(REVIEWER)
        self.assertIn("Write task and epic prose in Russian", skill)
        self.assertIn("no language ratio, glossary, or code lookup", skill)
        self.assertIn("Headings and ordinary prose are Russian", reviewer)
        for mixed_phrase in (
            "Для каждого самостоятельного flow",
            "Exact существующие symbols",
            "### QA checklist после MR",
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
        for token in (
            "docs/01_architecture_principles.md",
            "docs/02_project_structure.md",
            "Architecture is a quality gate",
        ):
            self.assertIn(token, skill)
        for path in (DECOMPOSER, REVIEWER):
            content = read(path)
            self.assertIn("docs/01_architecture_principles.md", content)
            self.assertIn("docs/02_project_structure.md", content)
            self.assertIn("in full", content)

    def test_graph_gate_is_documented_as_strict(self) -> None:
        skill = read(SKILL)
        generation = read(GENERATION)
        for content in (skill, generation):
            self.assertIn("--source-lock", content)
        self.assertIn("Every reported violation is a hard block", generation)
        self.assertIn("Graph gate: PASS", generation)
        self.assertIn("legacy schemas are rejected", generation)

    def test_task_template_has_single_implemented_body(self) -> None:
        template = read(TEMPLATE)
        self.assertIn("## 2. Что входит в задачу (`implemented`)", template)
        self.assertIn("## 3. Что отложено (`deferred`)", template)
        self.assertNotIn("### Входит в задачу (`implemented`)", template)

    def test_language_rule_translates_generic_english_prose(self) -> None:
        for path in (SKILL, DECOMPOSER, REVIEWER):
            self.assertIn("technical identity", read(path))
        template = read(TEMPLATE)
        self.assertIn("Если перевод не меняет техническую идентичность", template)
        self.assertIn("owner → «владелец»", template)

    def test_final_tasks_exclude_machine_technical_contract(self) -> None:
        output = read(OUTPUT)
        self.assertIn("no schema-v2 object", output)
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
        self.assertIn("atomically rename", read(SKILL))
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
            ROOT / ".agents/agents/task-decomposition-planner.md",
            ROOT / ".codex/agents/task-decomposition-planner.toml",
            ROOT / ".claude/agents/decompose/task-decomposition-planner.md",
            ROOT / ".gemini/agents/decompose/task-decomposition-planner.md",
            ROOT / ".opencode/agents/task-decomposition-planner.md",
            ROOT / ".agents/skills/factory-decompose/references/pre-plan-contract.md",
        )
        for path in obsolete:
            self.assertFalse(path.exists(), str(path))


if __name__ == "__main__":
    unittest.main()
