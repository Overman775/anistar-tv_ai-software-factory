from __future__ import annotations

import unittest

from factory_tooling.paths import FACTORY_ROOT
from factory_tooling.planning.plan_revision import semantic_normal_form
from factory_tooling.planning.validate_plan import validate

SCRIPT_DIR = FACTORY_ROOT / "gates/skills/planning"


PLAN = """# Plan: Trusted certificate authority for payment WebView
plan_id: payment-webview-trusted-ca
revision: 1
plan_state: PLAN_READY
status: draft
approved_revision: none
source: spec
handoff_recommendation: direct

## What changes
- Problem/goal: allow a trusted certificate authority only for payment WebView.
- Observable outcome: payment opens with a valid chain.
- In scope:
  - CAP-01 — certificate verification, limited by the platform context.
- Out of scope: changing all WebView.
- Source and context: local specification.

## How it works
### Main flow
1. Payment WebView starts loading an allowed host.
2. Platform verifies the certificate against the chosen trust contract.
3. Successful verification continues loading, failure stops it.

### Exceptions and branches
| Condition | Behavior | Related decision |
| :--- | :--- | :--- |
| Unknown host | Special trust verification does not apply | D-01 |

## Solution structure
| Area/owner | Responsibility and change | Why | Decision |
| :--- | :--- | :--- | :--- |
| Platform boundary | Limits special trust verification to the payment context | Do not expand trust globally | D-01 |

### Contract and evidence
| Applicability | Contract type | Behaviorally significant details | Evidence |
| :--- | :--- | :--- | :--- |
| CAP-01 | platform_plugin_api | Host and certificate participate in native verification | `official_fact`: API platform |

## Key decisions
| ID | Decision | Why | Applicability | Verification/constraint |
| :--- | :--- | :--- | :--- | :--- |
| D-01 | Special trust verification is limited to the payment host | Do not expand trust of ordinary WebView | CAP-01 | Unknown host is rejected |

## Unknowns and boundaries
- External dependencies and handling: absent.
- Research, timebox and outcome: not required.
- Risks: accidental expansion of special trust verification.

## Readiness and verification
### Acceptance criteria
| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | CAP-01 | Allowed host opens, unknown host receives no special trust | Verify allowed and unknown hosts |

### Developer acceptance and readiness
- Acceptance: allowed host opens, unknown host receives no special trust verification.
- Readiness: solution and platform boundary defined.

### QA checks
- Verify successful payment host and unknown host failure.

## Handoff
- Recommendation: `direct`.
- Why: one capability and a stable boundary.
- What the next stage receives: approved semantic plan.
- Warning/conditions: platform checks are mandatory.
- Continuation: awaiting user choice.
- Recommendation alone does not authorize continuation.
"""


class ValidatePlanTest(unittest.TestCase):
    def codes(
        self, text: str, phase: str = "draft", previous: str | None | None = None
    ) -> set[str]:
        return {item["code"] for item in validate(text, phase=phase, previous_text=previous)}

    def test_acceptance_table_is_required_and_ids_unique(self) -> None:
        self.assertIn(
            "ACCEPTANCE_INVALID",
            self.codes(PLAN.replace("### Acceptance criteria", "### Old criteria")),
        )
        row = "| AC-01 | CAP-01 | Different outcome | Verify it |\n"
        self.assertIn(
            "ACCEPTANCE_INVALID",
            self.codes(
                PLAN.replace("### Developer acceptance", row + "\n### Developer acceptance")
            ),
        )

    def test_acceptance_unknown_capability_rejected(self) -> None:
        self.assertIn(
            "ACCEPTANCE_INVALID",
            self.codes(PLAN.replace("| AC-01 | CAP-01 |", "| AC-01 | CAP-99 |")),
        )

    def test_acceptance_change_requires_new_revision(self) -> None:
        changed = PLAN.replace("| AC-01 | CAP-01 |", "| AC-02 | CAP-01 |")
        self.assertIn("SEMANTIC_REVISION_INVALID", self.codes(changed, previous=PLAN))

    def test_project_prose_may_use_other_languages(self) -> None:
        # Structural headings remain English; project content is unrestricted.
        multilingual = PLAN.replace(
            "Trusted certificate authority for payment", "Доверенный центр для оплаты"
        ).replace("allowed host opens", "разрешённый хост открывается")
        self.assertNotEqual(PLAN, multilingual)
        self.assertEqual([], validate(multilingual, phase="draft"))

    def test_valid_draft_passes(self) -> None:
        self.assertEqual([], validate(PLAN))

    def test_valid_approved_plan_passes(self) -> None:
        approved = PLAN.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        self.assertEqual([], validate(approved, phase="approved", previous_text=PLAN))

    def test_delegated_authorization_uses_same_approval_transition(self) -> None:
        delegated = PLAN.replace(
            "- Source and context: local specification.",
            "- Source and context: local specification.\n"
            '- Planning authorization: explicit_user_delegation — "decide yourself".',
        )
        self.assertEqual([], validate(delegated))
        approved = delegated.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        self.assertEqual([], validate(approved, phase="approved", previous_text=delegated))

    def test_required_headings_are_exact_and_ordered(self) -> None:
        broken = PLAN.replace("## What changes", "## One-minute overview")
        self.assertIn("HEADINGS_INVALID", self.codes(broken))

    def test_numbered_pseudocode_is_not_a_main_flow(self) -> None:
        text = PLAN.replace("1. Payment WebView starts loading an allowed host.\n", "")
        text = text.replace(
            "2. Platform verifies the certificate against the chosen trust contract.\n", ""
        )
        text = text.replace("3. Successful verification continues loading, failure stops it.\n", "")
        text = text.replace(
            "\n## Solution structure",
            "\n### Behavior pseudocode\n```text\n1. Decide\n```\n\n## Solution structure",
        )
        self.assertIn("MAIN_FLOW_NOT_NUMBERED", self.codes(text))

    def test_tilde_fenced_number_is_not_main_flow(self) -> None:
        text = PLAN.replace("1. Payment WebView starts loading an allowed host.\n", "")
        text = text.replace(
            "2. Platform verifies the certificate against the chosen trust contract.\n", ""
        )
        text = text.replace("3. Successful verification continues loading, failure stops it.\n", "")
        text = text.replace(
            "### Exceptions and branches",
            "~~~text\n1. This is code, not flow\n~~~\n\n### Exceptions and branches",
        )
        self.assertIn("MAIN_FLOW_NOT_NUMBERED", self.codes(text))

    def test_main_flow_requires_numbered_text_on_same_non_code_line(self) -> None:
        for replacement in ("    1. Indented code", "1.\nNot a list item"):
            text = PLAN.replace(
                "1. Payment WebView starts loading an allowed host.\n", replacement + "\n"
            )
            text = text.replace(
                "2. Platform verifies the certificate against the chosen trust contract.\n", ""
            )
            text = text.replace(
                "3. Successful verification continues loading, failure stops it.\n", ""
            )
            with self.subTest(replacement=replacement):
                self.assertIn("MAIN_FLOW_NOT_NUMBERED", self.codes(text))

    def test_metadata_is_minimal_and_handoff_is_typed(self) -> None:
        broken = PLAN.replace("revision: 1", "revision: 1\nquestion_budget_total: 3")
        broken = broken.replace("handoff_recommendation: direct", "handoff_recommendation: tickets")
        codes = self.codes(broken)
        self.assertIn("FORBIDDEN_METADATA", codes)
        self.assertIn("HANDOFF_INVALID", codes)

    def test_capabilities_are_declared_and_references_resolve(self) -> None:
        missing = PLAN.replace(
            "  - CAP-01 — certificate verification, limited by the platform context.\n",
            "",
        )
        codes = self.codes(missing)
        self.assertIn("CAPABILITY_MISSING", codes)
        self.assertIn("DECISION_CAPABILITY_UNKNOWN", codes)
        self.assertIn("API_EVIDENCE_CAPABILITY_UNKNOWN", codes)

    def test_every_capability_has_typed_contract_coverage(self) -> None:
        expanded = PLAN.replace(
            "  - CAP-01 — certificate verification, limited by the platform context.",
            "  - CAP-01 — certificate verification, limited by the platform context.\n"
            "  - CAP-02 — preserving the current navigation boundary.",
        )

        self.assertIn(
            "CAPABILITY_CONTRACT_COVERAGE_MISSING",
            self.codes(expanded),
        )

        globally_covered = expanded.replace(
            "| CAP-01 | platform_plugin_api |",
            "| global | platform_plugin_api |",
        )
        self.assertNotIn(
            "CAPABILITY_CONTRACT_COVERAGE_MISSING",
            self.codes(globally_covered),
        )

    def test_capability_references_must_be_declared_globally(self) -> None:
        broken = PLAN.replace(
            "- Verify successful payment host and unknown host failure.",
            "- Validate CAP-99 in success and failure scenarios.",
        )

        self.assertIn("CAPABILITY_REFERENCE_UNKNOWN", self.codes(broken))

    def test_handoff_section_matches_metadata(self) -> None:
        broken = PLAN.replace("- Recommendation: `direct`.", "- Recommendation: `decompose`.")
        self.assertIn("HANDOFF_SECTION_MISMATCH", self.codes(broken))

    def test_user_decision_cannot_enter_presented_plan(self) -> None:
        broken = PLAN.replace("- Risks:", "- USER_DECISION: choose a host.\n- Risks:")
        self.assertIn("UNRESOLVED_MARKER_IN_PLAN", self.codes(broken))

    def test_block_stays_in_working_session_not_plan(self) -> None:
        blocked = PLAN.replace("plan_state: PLAN_READY", "plan_state: BLOCKED_REQUIREMENTS")
        blocked = blocked.replace("- Risks:", "- BLOCK: missing contract.\n- Risks:")
        codes = self.codes(blocked)
        self.assertIn("PLAN_STATE_INVALID", codes)
        self.assertIn("UNRESOLVED_MARKER_IN_PLAN", codes)

    def test_active_question_subsection_cannot_enter_presented_plan(self) -> None:
        broken = PLAN.replace(
            "\n## Readiness and verification",
            "\n### Current question batch\n#### Q-01 — choice\n- Question: choose a host?\n\n## Readiness and verification",
        )
        self.assertIn("ACTIVE_QUESTIONS_IN_PLAN", self.codes(broken))

    def test_only_d_ids_can_enter_decision_table(self) -> None:
        broken = PLAN.replace(
            "| D-01 | Special trust verification",
            "| EXT-01 | Special trust verification",
        )
        self.assertIn("DECISION_ID_INVALID", self.codes(broken))

    def test_plan_without_material_decisions_does_not_invent_d_row(self) -> None:
        decision_table = """| ID | Decision | Why | Applicability | Verification/constraint |
| :--- | :--- | :--- | :--- | :--- |
| D-01 | Special trust verification is limited to the payment host | Do not expand trust of ordinary WebView | CAP-01 | Unknown host is rejected |"""
        no_decisions = PLAN.replace(" | D-01 |", " | — |").replace(
            decision_table,
            "- No significant decisions.",
        )
        self.assertEqual([], validate(no_decisions))
        dangling = no_decisions.replace(
            "- Risks: accidental expansion of special trust verification.",
            "- Risks: accidental expansion of special trust verification; see. D-01.",
        )
        self.assertIn("DECISION_REFERENCE_UNKNOWN", self.codes(dangling))

    def test_legacy_status_table_is_rejected(self) -> None:
        broken = PLAN.replace(
            "| ID | Decision | Why | Applicability | Verification/constraint |",
            "| ID | Status | Decision/fact | Evidence level | Source/rationale | Applicability | Verification/handling |",
        ).replace(
            "| :--- | :--- | :--- | :--- | :--- |\n| D-01 | Special trust verification is limited to the payment host | Do not expand trust of ordinary WebView | CAP-01 | Unknown host is rejected |",
            "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n| D-01 | DEFAULT | Special trust verification is limited to the payment host | project_fact | current scenario | CAP-01 | Unknown host is rejected |",
        )
        self.assertIn("DECISION_TABLE_INVALID", self.codes(broken))

    def test_api_evidence_type_is_checked(self) -> None:
        broken = PLAN.replace("platform_plugin_api", "swaggerish")
        self.assertIn("API_EVIDENCE_TYPE_INVALID", self.codes(broken))

    def test_external_contract_evidence_is_accepted(self) -> None:
        external = PLAN.replace("platform_plugin_api", "external_contract")
        self.assertEqual([], validate(external))

    def test_api_evidence_accepts_multiple_declared_capabilities(self) -> None:
        expanded = PLAN.replace(
            "  - CAP-01 — certificate verification, limited by the platform context.",
            "  - CAP-01 — certificate verification, limited by the platform context.\n  - CAP-02 — navigation boundary.",
        ).replace(
            "| CAP-01 | platform_plugin_api |",
            "| CAP-01, CAP-02 | platform_plugin_api |",
        )
        self.assertEqual([], validate(expanded))
        unknown = expanded.replace(
            "CAP-01, CAP-02 | platform_plugin_api", "CAP-01, CAP-03 | platform_plugin_api"
        )
        self.assertIn("API_EVIDENCE_CAPABILITY_UNKNOWN", self.codes(unknown))

    def test_external_references_require_boundary_declaration(self) -> None:
        referenced = PLAN.replace(
            "`official_fact`: API platform",
            "`official_fact`: API platform; EXT-01",
        )
        self.assertIn("EXTERNAL_REFERENCE_UNKNOWN", self.codes(referenced))
        declared = referenced.replace(
            "- External dependencies and handling: absent.",
            "- External dependencies and handling:\n  - EXT-01 — platform owner confirms API; handling: verify before implementation.",
        )
        self.assertEqual([], validate(declared))

    def test_external_boundary_requires_explicit_handling(self) -> None:
        broken = PLAN.replace(
            "- External dependencies and handling: absent.",
            "- External dependencies and handling:\n  - EXT-01 — platform owner confirms API.",
        )

        self.assertIn("EXTERNAL_HANDLING_MISSING", self.codes(broken))

    def test_developer_readiness_and_qa_are_separate(self) -> None:
        broken = PLAN.replace("### QA checks", "### Verification")
        self.assertIn("READINESS_SECTION_MISSING", self.codes(broken))

    def test_handoff_continuation_is_explicit_and_typed(self) -> None:
        missing = PLAN.replace(
            "- Continuation: awaiting user choice.\n",
            "",
        )
        self.assertIn("HANDOFF_CONTINUATION_MISSING", self.codes(missing))

        invalid = PLAN.replace(
            "- Continuation: awaiting user choice.",
            "- Continuation: maybe run later.",
        )
        self.assertIn("HANDOFF_CONTINUATION_INVALID", self.codes(invalid))

    def test_preauthorized_continuation_requires_delegation_evidence(self) -> None:
        unauthorized = PLAN.replace(
            "- Continuation: awaiting user choice.",
            "- Continuation: pre-authorized decomposition.",
        )
        self.assertIn(
            "HANDOFF_CONTINUATION_UNAUTHORIZED",
            self.codes(unauthorized),
        )

        authorized = unauthorized.replace(
            "- Source and context: local specification.",
            "- Source and context: local specification.\n"
            '- Planning authorization: explicit_user_delegation — "decide and decompose it yourself".',
        )
        self.assertNotIn(
            "HANDOFF_CONTINUATION_UNAUTHORIZED",
            self.codes(authorized),
        )

    def test_pseudocode_is_optional_but_constrained(self) -> None:
        pseudocode = """
### Behavior pseudocode
```text
Get the payment host
Check allowlist membership
Choose system or special trust verification
Continue loading after success
Stop loading after failure
```
"""
        valid = PLAN.replace("\n## Solution structure", pseudocode + "\n## Solution structure")
        self.assertEqual([], validate(valid))
        code_like = valid.replace("Stop loading after failure", "if (host) { return true; }")
        self.assertIn("PSEUDOCODE_CODE_SYNTAX", self.codes(code_like))
        too_short = PLAN.replace(
            "\n## Solution structure",
            "\n### Behavior pseudocode\n```text\nOne\nTwo\n```\n\n## Solution structure",
        )
        self.assertEqual([], validate(too_short))

    def test_semantic_change_requires_new_draft_revision(self) -> None:
        changed = PLAN.replace(
            "accidental expansion",
            "trust verification escapes the payment boundary",
        )
        self.assertIn("SEMANTIC_REVISION_INVALID", self.codes(changed, previous=PLAN))
        revised = changed.replace("revision: 1", "revision: 2")
        self.assertEqual([], validate(revised, previous_text=PLAN))

    def test_nonsemantic_edit_keeps_revision(self) -> None:
        formatted = PLAN.replace(
            "solution and platform boundary",
            "solution  and  platform boundary",
        )
        self.assertEqual([], validate(formatted, previous_text=PLAN))

    def test_coordinator_can_classify_markdown_formatting_without_new_revision(self) -> None:
        formatted = PLAN.replace(
            "allow a trusted certificate authority", "allow a **trusted** certificate authority"
        )
        self.assertEqual(
            [],
            validate(
                formatted,
                previous_text=PLAN,
                change_kind="nonsemantic",
                change_evidence="Only bold emphasis; words unchanged",
            ),
        )
        self.assertIn(
            "CHANGE_EVIDENCE_MISSING",
            {e["code"] for e in validate(formatted, previous_text=PLAN, change_kind="nonsemantic")},
        )

    def test_nonsemantic_classification_cannot_change_ids_or_approval_content(self) -> None:
        altered = PLAN.replace("AC-01", "AC-02")
        codes = {
            e["code"]
            for e in validate(
                altered,
                previous_text=PLAN,
                change_kind="nonsemantic",
                change_evidence="claimed formatting",
            )
        }
        self.assertIn("NONSEMANTIC_IDENTITY_CHANGED", codes)
        approved = (
            PLAN.replace("status: draft", "status: approved")
            .replace("approved_revision: none", "approved_revision: 1")
            .replace(
                "allow a trusted certificate authority", "allow a **trusted** certificate authority"
            )
        )
        codes = {
            e["code"]
            for e in validate(
                approved,
                phase="approved",
                previous_text=PLAN,
                change_kind="nonsemantic",
                change_evidence="Only bold emphasis",
            )
        }
        self.assertIn("APPROVAL_CONTENT_CHANGED", codes)

    def test_next_approved_revision_starts_as_draft_at_same_plan_identity(self) -> None:
        approved = PLAN.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        changed = PLAN.replace("revision: 1", "revision: 2").replace(
            "accidental expansion", "expansion after requirements change"
        )
        self.assertEqual([], validate(changed, previous_text=approved))
        next_approved = changed.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 2"
        )
        self.assertEqual([], validate(next_approved, phase="approved", previous_text=changed))

    def test_url_normalization_preserves_balanced_parentheses(self) -> None:
        valid = "https://developer.apple.com/documentation/security/sectrustevaluatewitherror%28_%3A_%3A%29"
        malformed = "https://developer.apple.com/documentation/security/sectrustevaluatewitherror%28_%3A_%3A"
        self.assertNotEqual(semantic_normal_form(valid), semantic_normal_form(malformed))
        self.assertEqual(semantic_normal_form(f"{valid})"), semantic_normal_form(valid))

    def test_approved_snapshot_is_immutable(self) -> None:
        approved = PLAN.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        reformatted = approved.replace(
            "solution and platform boundary",
            "solution  and  platform boundary",
        )
        self.assertIn(
            "APPROVED_IMMUTABLE",
            self.codes(reformatted, phase="approved", previous=approved),
        )


if __name__ == "__main__":
    unittest.main()
