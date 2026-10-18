from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SKILL = ROOT / ".agents/skills/factory-implement"
REFERENCES = SKILL / "references"
DETAIL_CONTRACT = ROOT / ".agents/contracts/common/implementation-detail.md"


def read(path: str | Path) -> str:
    candidate = Path(path)
    if not candidate.is_absolute():
        candidate = ROOT / candidate
    return candidate.read_text(encoding="utf-8")


def compact(value: str) -> str:
    return " ".join(value.split())


class FactoryImplementExecutionContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.skill = read(SKILL / "SKILL.md")
        self.source_contract = read(REFERENCES / "execution-source-contract.md")
        self.feature = read(REFERENCES / "feature-pipeline.md")
        self.task = read(REFERENCES / "task-pipeline.md")
        self.refactor = read(REFERENCES / "refactor-pipeline.md")
        self.debug = read(REFERENCES / "debug-pipeline.md")
        self.fix = read(REFERENCES / "fix-pipeline.md")
        self.explore = read(REFERENCES / "explore-pipeline.md")
        self.docs = read(REFERENCES / "docs-pipeline.md")
        self.state = read(REFERENCES / "shared-state.md")
        self.gates = read(REFERENCES / "shared-gates.md")
        self.cleanup = read(REFERENCES / "shared-cleanup.md")
        self.finalize = read(REFERENCES / "shared-finalize.md")
        self.checkpoint = read(".agents/contracts/common/agent-checkpoint.md")
        self.detail_contract = read(DETAIL_CONTRACT)

    def test_root_skill_routes_to_execution_source_contract(self) -> None:
        self.assertIn("references/execution-source-contract.md", self.skill)
        self.assertIn("single_task", self.skill)
        self.assertIn("approved_plan", self.skill)
        self.assertIn("NEEDS_PLANNING", self.skill)

    def test_exactly_two_execution_modes_are_defined(self) -> None:
        table = compact(self.source_contract)
        self.assertIn("| `single_task` |", table)
        self.assertIn("| `approved_plan` |", table)
        manifest_modes = re.search(r"execution_mode: ([^\n]+)", self.state)
        self.assertIsNotNone(manifest_modes)
        self.assertEqual(
            {item.strip() for item in manifest_modes.group(1).split("|")},
            {"single_task", "approved_plan", "not_applicable"},
        )
        for content in (self.feature, self.task, self.refactor, self.fix, self.docs):
            self.assertIn("single_task", content)
            self.assertIn("approved_plan", content)

    def test_source_kinds_are_independent_from_execution_modes(self) -> None:
        source_kinds = "direct | local_task | factory_decompose_task | approved_plan"
        self.assertIn(f"source_kind: {source_kinds}", self.source_contract)
        self.assertIn(f"source_kind: {source_kinds} | none", self.state)
        self.assertIn(
            "Resolve task and plan references before choosing an execution mode.",
            compact(self.source_contract),
        )

    def test_source_sufficiency_separates_semantic_and_technical_gaps(self) -> None:
        for token in (
            "one observable outcome",
            "included and excluded behavior",
            "acceptance criteria or a concrete verification method",
            "dependencies",
            "NEEDS_PLANNING",
            "filenames",
            "class names",
            "exact tests",
            "edit order",
        ):
            self.assertIn(token, self.source_contract)
        self.assertIn("technical unknowns", self.gates)
        self.assertIn("semantic gaps", self.gates)

    def test_canonical_approved_plan_needs_no_reapproval(self) -> None:
        for token in (
            "plan_id:",
            "revision:",
            "plan_hash:",
            "approval_state: approved",
            "approval_evidence:",
            "execution_scope:",
            "BLOCKED_NO_APPROVED_PLAN",
        ):
            self.assertIn(token, self.source_contract)
        normalized = compact(self.source_contract)
        self.assertIn("canonical_plan_metadata", normalized)
        self.assertIn("never ask user to approve same canonical revision again", normalized)
        self.assertIn("explicit_external_hash_approval", normalized)

    def test_execution_brief_is_nonsemantic_and_source_bound(self) -> None:
        for token in (
            ".ai-pipeline/state/execution-brief.md",
            "run_id:",
            "source_hash:",
            "# Зафиксированный источник",
            "# Reality Check",
            "# Чек-лист исполнения",
            "Forbidden content",
            "invented outcome or acceptance",
            "decision log",
            "Freeze brief before Developer starts",
        ):
            self.assertIn(token, self.source_contract)
        self.assertIn("brief prose/headings in Russian", self.source_contract)
        self.assertIn("execution-brief.md", self.state)
        self.assertIn("source wins on conflict", compact(self.state).lower())

    def test_direct_execution_uses_checkout_current_implementation_detail(self) -> None:
        self.assertIn("implementation detail contract", self.skill)
        for token in (
            "implementation-detail.md",
            "checkout-current",
            "Material Semantic Gap Gate",
            "shared information-lifetime rule",
            "Текущие технические опоры",
            "shared anchor and bounded-check rules",
        ):
            self.assertIn(token, self.source_contract)
        self.assertIn("## Information Lifetime", self.detail_contract)
        self.assertIn("## Anchors and Bounded Check", self.detail_contract)
        self.assertIn("Missing or renamed technical anchor", self.detail_contract)
        self.assertNotIn("## Consumer Rules", self.detail_contract)

    def test_old_semantic_execution_artifacts_are_absent(self) -> None:
        old_contract = "implementation" + "-plan-contract.md"
        old_artifact = ".ai-pipeline/state/" + "implementation" + "-plan.md"
        self.assertFalse((REFERENCES / old_contract).exists())
        for path in sorted(REFERENCES.glob("*.md")):
            content = read(path)
            self.assertNotIn(old_contract, content, path)
            self.assertNotIn(old_artifact, content, path)
            self.assertIsNone(re.search(r"\bArchitect\b", content), path)
            self.assertNotIn("plan_revision", content, path)
            self.assertNotIn("PLAN_READY", content, path)

    def test_source_provenance_and_drift_are_enforced(self) -> None:
        for token in (
            "source_ref:",
            "source_updated_at:",
            "source_hash:",
            "re-read immediately before every Developer",
            "SOURCE_DRIFT",
            "Re-intake current source",
        ):
            self.assertIn(token, self.source_contract)
        self.assertIn("Source Drift Gate", self.gates)
        self.assertIn("Never refresh hash in place", self.gates)
        for content in (self.feature, self.task, self.refactor, self.fix):
            self.assertIn("Source Drift Gate", content)
        developer_contract = read(".agents/contracts/developer.md")
        developer_persona = read(".agents/agents/developer.md")
        self.assertIn("SOURCE_DRIFT", developer_contract)
        self.assertNotIn("SOURCE_DRIFT", developer_persona)
        for content in (developer_contract, developer_persona):
            self.assertNotIn("BLOCKED_SOURCE_DRIFT", content)

    def test_test_writer_wrappers_match_source_behavior_contract(self) -> None:
        for path in (
            ".codex/agents/test-writer.toml",
            ".claude/agents/test-writer.md",
        ):
            content = read(path)
            self.assertIn(".agents/contracts/test-writer.md", content, path)
            self.assertIn("locked source", content, path)
            self.assertNotIn("based ONLY on Domain contracts", content, path)

    def test_feature_pipeline_executes_source_without_reapproval(self) -> None:
        normalized = compact(self.feature)
        self.assertIn("source intake -> Source Sufficiency Gate", normalized)
        self.assertIn("execution brief -> Source Drift Gate -> Developer", normalized)
        self.assertIn("TestWriter", normalized)
        self.assertIn("DevReviewer", normalized)
        self.assertNotIn("approval checkpoint", normalized.lower())

    def test_micro_fix_finishes_without_second_approval(self) -> None:
        normalized = compact(self.fix)
        self.assertIn("source gate -> Developer -> focused verification -> finalize", normalized)
        self.assertIn("normal initial/stateful `fix` pipeline", normalized)
        self.assertNotIn("Ask: approve", self.fix)
        self.assertNotIn("User Checkpoint", self.fix)

    def test_bug_root_cause_is_technical_until_semantics_change(self) -> None:
        normalized = compact(self.task)
        self.assertIn("root cause may be discovered", normalized)
        self.assertIn("technical discovery, not a semantic gap", normalized)
        self.assertIn("canonical `bug-hunter`", normalized)
        self.assertIn("expected behavior", normalized)
        self.assertIn("NEEDS_PLANNING", normalized)
        self.assertIn("find and fix", compact(self.debug))

    def test_refactor_locks_behavior_and_public_api(self) -> None:
        normalized = compact(self.refactor)
        for token in (
            "behavior-preserving",
            "public-API invariants",
            "selected simplify findings",
            "existing tests",
            "mechanical test adaptations",
            "NEEDS_PLANNING",
        ):
            self.assertIn(token, normalized)
        self.assertNotIn("TEST_ADAPTATION", normalized)

    def test_reports_use_run_and_source_provenance(self) -> None:
        self.assertIn("run_id: {current run id}", self.state)
        self.assertIn("source_hash: {current source hash", self.state)
        self.assertIn("Reject reports with missing or stale headers", self.state)
        self.assertIn("current `run_id` and `source_hash`", compact(self.gates))
        for content in (self.feature, self.task, self.refactor, self.debug):
            self.assertIn("run_id", content)
            self.assertIn("source_hash", content)

    def test_rethink_and_untestable_semantic_routes_need_planning(self) -> None:
        normalized = compact(self.gates)
        self.assertIn("`RETHINK`: treat as a semantic-gap candidate", normalized)
        self.assertIn("return `NEEDS_PLANNING`", normalized)
        self.assertIn("`BLOCKED_UNTESTABLE`", normalized)
        self.assertIn("semantic seam", compact(self.skill))

    def test_manifest_owns_resume_and_cleanup(self) -> None:
        for token in (
            "run_id:",
            "status: in_progress",
            "needs_planning",
            "owned_artifacts:",
            "adopted_artifacts:",
            "source_hash:",
            "gates:",
            "cleanup: PENDING",
        ):
            self.assertIn(token, self.state)

    def test_agent_checkpoint_covers_all_execution_roles_and_separate_recovery(self) -> None:
        for role in (
            "CodeExplorer",
            "BugHunter",
            "Developer",
            "TestWriter",
            "DevReviewer",
            "DocWriter",
        ):
            self.assertIn(role, self.skill)
        for token in (
            "BLOCKED_AGENT_FAILURE",
            "Persist each delegated handle",
            "silence",
            "agent_recoveries: N",
            "terminal `retired`",
        ):
            self.assertIn(token, self.skill + self.state)
        self.assertIn("Silence is not failure", self.checkpoint)
        self.assertIn("Do not count quiet or silent windows", self.checkpoint)
        self.assertNotIn("STALLED_AGENT", self.skill + self.state + self.checkpoint)
        self.assertIn(
            "does not consume static, test-fix, or review-fix",
            compact(self.skill),
        )

    def test_role_done_signals_match_pipeline_semantic_escalation(self) -> None:
        explorer_contract = read(".agents/contracts/code-explorer.md")
        bug_hunter_contract = read(".agents/contracts/bug-hunter.md")
        doc_writer_contract = read(".agents/contracts/doc-writer.md")
        self.assertNotIn("- `NEEDS_PLANNING`", explorer_contract)
        self.assertNotIn("| NEEDS_PLANNING |", bug_hunter_contract)
        self.assertIn("semantic_gap_candidate", explorer_contract)
        self.assertIn("semantic_gap_candidate", bug_hunter_contract)
        self.assertIn("`NEEDS_PLANNING`", doc_writer_contract)
        self.assertIn("NEEDS_PLANNING", self.feature)
        self.assertIn("NEEDS_PLANNING", self.docs)

    def test_explicit_no_plan_stays_single_task(self) -> None:
        normalized = compact(self.source_contract)
        for token in (
            "## User Directives: No Plan vs Delegated Planning",
            "`без плана`",
            "`план не нужен`",
            "explicitly forbids formal",
            "Neither directive creates a third execution mode",
            "# Делегированные решения исполнения",
        ):
            self.assertIn(token, self.source_contract)
        self.assertIn("Keep `execution_mode: single_task`", normalized)
        self.assertIn("source_hash", normalized)
        self.assertIn("fail closed", normalized)

    def test_solve_yourself_routes_material_gap_through_planning(self) -> None:
        normalized = compact(self.source_contract)
        for token in (
            "`решай сам`",
            "`делай сам`",
            "`на твоё усмотрение`",
            "`вопросы не задавай`",
            "routes automatically through Factory Planning",
            "resume only from its approved plan",
            "explicit no-plan wording wins",
        ):
            self.assertIn(token, normalized)

    def test_material_semantic_gap_requires_all_conditions(self) -> None:
        section = self.source_contract.split("## Material Semantic Gap Gate", 1)[1]
        for token in (
            "only when all conditions hold",
            "observable behavior",
            "verified code",
            "non-local",
            "bounded, local, reversible",
            "Directive:",
            "Routing:",
            "Teamlead alone",
        ):
            self.assertIn(token, section)
        self.assertIn("Material Semantic Gap Gate", self.gates)
        self.assertIn("RETHINK", self.gates)

    def test_runtime_adapters_are_workflow_neutral(self) -> None:
        paths = (
            ".agents/adapters/codex.md",
            ".agents/adapters/claude.md",
        )
        forbidden = (
            "factory-implement",
            "factory-code-review",
            "factory-api-reviewer",
            "dev-reviewer",
            "Material Semantic Gap Gate",
            "single_task",
            "approved_plan",
        )
        for path in paths:
            content = read(path)
            for token in forbidden:
                self.assertNotIn(token, content, path)

    def test_implement_and_code_review_use_separate_reviewer_roles(self) -> None:
        contract = read(".agents/contracts/reviewer.md")
        persona = read(".agents/agents/reviewer.md")
        dev_contract = read(".agents/contracts/dev-reviewer.md")
        dev_persona = read(".agents/agents/dev-reviewer.md")
        review_prompt = read(
            ".agents/skills/factory-code-review/references/reviewer-prompts.md"
        )
        self.assertIn("factory-code-review", contract)
        self.assertNotIn("factory-implement", contract)
        self.assertNotIn("CALLER_CONTEXT", contract)
        self.assertNotIn("factory-code-review", persona)
        self.assertNotIn("factory-implement", persona)
        self.assertNotIn("CALLER_CONTEXT", persona)
        self.assertIn("factory-implement", dev_contract)
        self.assertIn("review.md", dev_contract)
        self.assertIn("REV-", dev_contract)
        self.assertNotIn("factory-implement", dev_persona)
        self.assertNotIn("review.md", dev_persona)
        self.assertNotIn("REV-", dev_persona)
        for workflow_token in (
            "schema `3`",
            "system-design",
            "runtime-safety",
            "verification-quality",
            "gate_id",
            "evidence_refs",
            "done_signal",
            "parent QA",
        ):
            self.assertNotIn(workflow_token, persona)
        self.assertNotIn("CALLER_CONTEXT", review_prompt)
        self.assertIn("exactly one canonical `dev-reviewer`", self.gates)
        self.assertNotIn("review_context.md", self.gates)
        self.assertNotIn("review_context.md", self.state)
        self.assertIn("`review.md` | DevReviewer", self.state)
        self.assertIn("`re-review.md` | DevReviewer", self.state)
        self.assertIn("`re-review.md` is authoritative", self.gates)
        self.assertIn(
            "current `re-review.md` afterward",
            compact(self.gates),
        )
        self.assertIn("new significant regressions", self.gates)
        self.assertIn("next unused `REV-*` ID", dev_contract)
        self.assertIn("validated `re-review.md` owns it", compact(self.state))
        self.assertIn(
            "with `review_fix > 0`, require `re-review.md`",
            compact(self.finalize),
        )
        self.assertIn(
            "may use `review: NOT_RUN` only with nonempty `gate_notes.review`",
            compact(self.finalize),
        )
        self.assertIn("gate_notes:", self.state)
        self.assertIn("required reason when review is NOT_RUN", self.state)
        for path in (
            ".codex/agents/dev-reviewer.toml",
            ".claude/agents/dev-reviewer.md",
        ):
            wrapper = read(path)
            self.assertIn("dev-reviewer", wrapper, path)
            self.assertIn(".agents/agents/dev-reviewer.md", wrapper, path)
        codex_wrapper = read(".codex/agents/dev-reviewer.toml")
        self.assertIn('model = "gpt-6.1-sol"', codex_wrapper)
        self.assertIn('model_reasoning_effort = "high"', codex_wrapper)
        claude_wrapper = read(".claude/agents/dev-reviewer.md")
        self.assertIn("model: opus", claude_wrapper)
        self.assertIn("effort: high", claude_wrapper)
        for content in (
            self.feature,
            self.task,
            self.refactor,
            self.gates,
            self.state,
        ):
            self.assertNotIn("spec-review.md", content)
            self.assertNotIn("quality-review.md", content)
            self.assertNotIn("correctness-review.md", content)
            self.assertNotIn("architecture-review.md", content)
            self.assertNotIn("tests-review.md", content)


    def test_same_run_role_continuation_uses_skill_identity_and_no_retained_pool(self) -> None:
        policy = compact(
            self.checkpoint.split("## Same-Run Role Continuation", 1)[1].split(
                "## Runtime Mapping", 1
            )[0]
        )
        for token in (
            "active pipeline identity tuple",
            "immutable source lock",
            "non-terminal manifest",
            "persisted checkpoint/evidence",
            "valid live follow-up handle",
            "physical handle `retired`",
            "neither failure, recovery, nor gate/fix-loop iteration",
            "requires fresh handling",
            "uses **Recovery**",
        ):
            self.assertIn(token, policy)
        for token in (
            "`run_id + source_hash + canonical role`",
            "through final Review Gate",
            "terminalize all three on `APPROVE` or another terminal outcome",
            "terminal `retired`",
        ):
            self.assertIn(token, compact(self.state))
        self.assertIn(
            ".agents/contracts/common/agent-checkpoint.md#same-run-role-continuation",
            self.state,
        )
        self.assertIn("living or unknown non-terminalized agents", compact(self.finalize))
        fresh_start = self.cleanup.split("When user chooses fresh start:", 1)[1].split(
            "## Deterministic Procedure", 1
        )[0]
        self.assertLess(fresh_start.index("Terminalize previous-run teammates"), fresh_start.index("Mark previous manifest `cancelled`"))
        self.assertLess(fresh_start.index("Mark previous manifest `cancelled`"), fresh_start.index("Run exact-path cleanup"))
        self.assertLess(fresh_start.index("Run exact-path cleanup"), fresh_start.index("Start new run"))

    def test_fix_routes_documentation_to_doc_writer(self) -> None:
        normalized = compact(self.fix)
        self.assertIn("Documentation-only changes use the `docs` workflow", normalized)
        self.assertIn("Documentation never routes through Developer", normalized)
        self.assertNotIn("text/assets/docs/non-code config", normalized)

    def test_follow_up_requests_route_from_new_delta(self) -> None:
        section = self.skill.split("## Follow-up and Revision Requests", 1)[1]
        section = section.split("Ambiguous workflow", 1)[0]
        normalized = compact(section)
        for token in (
            "prior Factory Implement run is already `completed`",
            "same parent task context and same checkout/worktree",
            "no active or resumable `pipeline.md`",
            "parent can lock the exact newly requested delta",
            "`inline_self_review`",
            "`full_team`",
            "semantic risk and provability, never by line/file count",
            "follow-up delta only",
            "Never inherit/restart the completed source",
            "explicitly specified local behavior inside one bounded package",
            "focused/regression oracle is clear",
            "No teammate and no persistent Factory Implement state",
        ):
            self.assertIn(token, normalized)
        self.assertIn("Post-Completion Follow-up Gate", self.fix)
        finalize = compact(self.finalize)
        self.assertIn("If the user cancels before success", finalize)
        self.assertIn("preserve the current working tree", finalize)
        self.assertIn("create/clean no Factory Implement state", finalize)

        adaptive_bundle = "\n".join(
            (
                self.skill,
                self.gates,
                self.state,
                self.finalize,
                self.fix,
                read(".agents/contracts/dev-reviewer.md"),
            )
        )
        self.assertNotIn("inline_" + "reviewed", adaptive_bundle)
        self.assertNotIn("compact_" + "follow_up", adaptive_bundle)

    def test_final_report_has_explicit_standard_execution_label(self) -> None:
        self.assertIn(
            "Execution: {STANDARD/INLINE_SELF_REVIEW/FULL_TEAM}",
            self.skill,
        )
        self.assertIn(
            "`Execution: STANDARD` for a normal initial/stateful pipeline",
            compact(self.finalize),
        )


    def test_execution_ownership_keeps_teamlead_as_orchestrator(self) -> None:
        developer_contract = read(".agents/contracts/developer.md")
        developer_persona = read(".agents/agents/developer.md")
        test_contract = read(".agents/contracts/test-writer.md")
        test_persona = read(".agents/agents/test-writer.md")
        dev_contract = read(".agents/contracts/dev-reviewer.md")
        dev_persona = read(".agents/agents/dev-reviewer.md")
        skill_bundle = "\n".join(
            (
                self.skill,
                self.gates,
                self.feature,
                self.task,
                self.refactor,
                self.fix,
                developer_contract,
                developer_persona,
                test_contract,
                test_persona,
                dev_contract,
                dev_persona,
            )
        )

        self.assertNotIn("Analyze, DCM, and Format Check", developer_contract)
        self.assertIn("melos run analyze", self.gates)
        self.assertIn("melos run dcm", self.gates)
        self.assertIn("melos run format:check", self.gates)
        self.assertNotIn("Test Gate", developer_contract)
        self.assertNotIn("test-report.md", developer_contract)
        self.assertNotIn("test-report.md", developer_persona)
        self.assertIn("`tested_files`", test_contract)
        self.assertIn("`git hash-object", test_contract)
        self.assertIn("--reporter=failures-only", self.gates)
        self.assertIn("Execute delegated test commands directly", test_contract)
        self.assertIn("unchanged existing tests", test_contract)
        self.assertIn("Final Static Checks", dev_contract)
        self.assertNotIn("Analyze, DCM, and Format Check", dev_contract)
        self.assertIn("Automatic checks", self.gates)
        self.assertIn("prohibits `APPROVE`", dev_contract)
        self.assertIn("matching Test Gate status is `PASS`", dev_contract)
        self.assertIn("## Test Report", self.state)
        self.assertIn("git hash-object --", self.state)
        self.assertIn("Outside eligible `inline_self_review`", self.gates)
        self.assertIn("Teamlead never executes these\ncommands", self.gates)
        self.assertIn("Teamlead never executes tests", self.gates)
        adaptive = compact(
            self.gates.split("## Adaptive Follow-up Verification", 1)[1].split(
                "## Static Gate", 1
            )[0]
        )
        for token in (
            "entire adaptive evidence bundle",
            "focused tests",
            "complete workspace static triplet",
            "changed-file hashes",
            "final diff self-review",
            "Never weaken or remove assertions",
            "`SELF_REVIEW PASS`",
            "Rerun the full final-byte sequence before success",
        ):
            self.assertIn(token, adaptive)
        self.assertIn("Static: {PASS/FAIL/NOT_APPLICABLE/NOT_RUN}", self.skill)
        self.assertIn("TestWriter runs narrowest relevant", self.gates)
        self.assertIn("never sends test-only work to Developer", self.gates)
        self.assertIn("production-only work to TestWriter", self.gates)
        self.assertIn("it is final verification for micro fix", compact(self.fix))
        self.assertNotIn("run_checked_command.py", skill_bundle)
        self.assertNotIn("static-report.md", skill_bundle)
        self.assertNotIn("canonical `verifier`", skill_bundle.lower())
        self.assertNotIn("diff_hash", skill_bundle)
        self.assertNotIn("TEST_ADAPTATION", skill_bundle)
        self.assertNotIn("Compile Gate", skill_bundle)
        for persona in (developer_persona, test_persona, dev_persona):
            for workflow_token in (
                ".ai-pipeline",
                "pipeline.md",
                "execution-brief.md",
                "test-report.md",
                "review.md",
                "re-review.md",
                "refactor-report.md",
                "run_id",
                "source_hash",
                "diff_hash",
                "Source Gate",
                "Material Semantic Gap Gate",
                "SOURCE_DRIFT",
                "NEEDS_PLANNING",
                "DCM",
                "Format Check",
                "--reporter=failures-only",
                "Automatic checks",
                "Python runner",
            ):
                self.assertNotIn(workflow_token, persona)

    def test_cleanup_is_terminal_exact_and_verified(self) -> None:
        for token in (
            "status is `in_progress`, `waiting_user`, `blocked`, or `needs_planning`",
            "exact temporary paths declared",
            "never add adopted paths to deletion list",
            "delete exact",
            "CLEANUP PASS",
            "CLEANUP FAIL",
        ):
            self.assertIn(token, self.cleanup)
        guard = compact(self.cleanup)
        self.assertIn(
            "Do not translate this into `rm -rf`, `rm .ai-pipeline/state/*`, "
            "`find -delete`, or any pattern-based deletion.",
            guard,
        )
        for forbidden in ("rm -rf", "find -delete", "state/*"):
            self.assertEqual(self.cleanup.count(forbidden), 1)

    def test_finalize_verifies_then_captures_then_cleans(self) -> None:
        verify = self.finalize.index("Verify every report header")
        capture = self.finalize.index("Capture final report data")
        terminal = self.finalize.index("Only now mark manifest")
        cleanup = self.finalize.index("Execute `shared-cleanup.md`")
        self.assertLess(verify, capture)
        self.assertLess(capture, terminal)
        self.assertLess(terminal, cleanup)
        self.assertIn("Cleanup: PASS", self.finalize)
        self.assertIn("Cleanup: FAIL", self.finalize)
        self.assertIn("execution-brief.md", self.finalize)
        self.assertIn(
            "`static: PASS | NOT_APPLICABLE`, `tests: PASS`",
            compact(self.finalize),
        )
        self.assertIn(
            "Every `static: NOT_APPLICABLE` requires nonempty `gate_notes.static`",
            compact(self.finalize),
        )

    def test_gate_statuses_and_failure_routes_are_total(self) -> None:
        developer_contract = read(".agents/contracts/developer.md")
        self.assertIn(
            "tests: PASS | FAIL_CODE | FAIL_TEST | GOLDEN_DIFF | "
            "BEHAVIOR_CHANGE | BLOCKED_UNTESTABLE | NEEDS_PLANNING | NOT_RUN",
            self.state,
        )
        self.assertIn("`NEEDS_PLANNING`: require Material Semantic Gap Gate", self.gates)
        self.assertIn("`BLOCKED_STATIC_FAILURE`", developer_contract)
        self.assertIn("After two\nfailed retries", self.gates)
        self.assertIn(
            "reserve `BLOCKED_TOOL_ERROR`\nfor command launch/infrastructure failure",
            self.gates,
        )

    def test_static_and_test_commands_have_unambiguous_working_directories(self) -> None:
        for token in (
            "Run from repository root",
            "Run hash commands from repository root",
            "`<test_path>` is repository-relative",
            "Run each command once and sequentially",
            "Failure excerpt",
        ):
            self.assertIn(token, self.gates)
        self.assertIn("root scripts already cover the AniStar TV workspace", compact(self.gates))
        self.assertIn(
            "`PASS` requires at least one recorded test command and zero exit codes",
            compact(self.gates),
        )
        self.assertIn(
            "`PASS` requires all three rows for the workspace",
            compact(self.gates),
        )

    def test_reference_anchors_and_root_links_exist(self) -> None:
        sources = [SKILL / "SKILL.md", *sorted(REFERENCES.glob("*.md"))]
        for source in sources:
            content = read(source)
            for target_name, anchor in re.findall(
                r"`([^`/\s]+\.md)#([a-z0-9-]+)`", content
            ):
                target = REFERENCES / target_name
                self.assertTrue(target.exists(), f"missing {target} from {source}")
                slugs = set()
                for line in read(target).splitlines():
                    if not line.startswith("#"):
                        continue
                    heading = line.lstrip("#").strip().lower()
                    slug = re.sub(r"[^\w\s-]", "", heading)
                    slugs.add(re.sub(r"\s+", "-", slug))
                self.assertIn(anchor, slugs, f"missing #{anchor} in {target}")

        for target_name in re.findall(r"\(references/([a-z0-9-]+\.md)\)", self.skill):
            self.assertTrue((REFERENCES / target_name).exists(), target_name)




    def test_temporary_skill_workspace_is_absent(self) -> None:
        self.assertFalse((ROOT / ".agents/skills/factory-implement-workspace").exists())


if __name__ == "__main__":
    unittest.main()
