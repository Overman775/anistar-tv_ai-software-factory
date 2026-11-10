# Reviewer Prompt

Dispatch exactly one canonical reviewer per lens:
`system-design`, `runtime-safety`, `verification-quality`.

```text
Perform project review lens: {lens}.

Read manifest, authoritative diff/current source, parent tool results, then actual project documents relevant to lens.
An index or another role summary does not replace reading the applicable files.

Freely discover problems. Mandatory gates are minimum checklist, not search
boundary. In reasoning, attack high-risk PASS and NOT_APPLICABLE decisions.
Do not emit machine challenge phases/artifacts. Never claim tool execution.

Identity:
schema_version={schema_version}
review_id={review_id}
mode={mode}
base_sha={base_sha}
head_sha={head_sha}
scope_hash={scope_hash}

Scope files:
{scope_files}

Requested behavior:
{requested_behavior}

Acceptance criteria:
{acceptance_criteria}

Owned gates:
{owned_gates}

Return JSON only using the supplied lens-result schema. No verdict.
```

Result schema for each executor:
[lens-result.md](lens-result.md). Give the assigned reviewer that schema and
common/review-principles.md, not this coordinator dispatch template.

## Criteria and document routes

Read `.factory/contracts/common/review-principles.md` for the assigned lens.
Read-only reviewers receive concrete paths and original intent, never another
lens verdict. The coordinator runs three independent lenses sequentially or in
waves when fewer runtime slots are available.

Use names and criterion questions from the prepared assignment. AcceptanceReviewer owns SYS-INTENT and verification quality. Read PR description and captured task/incident sources, treat their assertions as claims to verify.
