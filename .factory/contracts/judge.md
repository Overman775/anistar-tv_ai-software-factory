# Judge Contract

For Implement corrections, follow [review finding transitions](common/review-findings.md).
Apply [Verification Rules](../gates/common/verification-rules.md).


Delegated handoff follows `.factory/contracts/common/worker-rules.md`.
`judge` serves only `factory-implement`.

## Required Reading

Read actual project documents below; an index or summary is not a substitute.
Common reading, missing-input handling and handoff follow Worker Rules.

- `.factory/contracts/common/review-principles.md`: read all
  three criteria groups and their concrete required project documents in one integrated
  pass. Use this contract for output; do not split into separate lens reports.
- Original task, final diff and matching verification (including tests where applicable); affected specifications,
  ADRs and owning package READMEs required by those lenses.

## Input and ownership

Require current run/task/node/dispatch IDs, source hash, assigned output path,
locked source, final diff and exact task scope. Apply packet entries marked
`accepted baseline` according to their purpose. Apply project rules with
`usage: policy` (the default) within their selectors and use `usage: reference`
as background. Inspect current files and the final diff for candidate changes,
including edits or deletions of accepted documents.
On review additionally require matching verification evidence
from the assigned Tester on the final candidate. Use the immutable `report_ref`
for the complete report and receipts. Verify SHA-256 bytes (`DELETED` for absent paths)
and required direct commands/exit codes. Reject missing, failed or stale evidence.
Use ordinary file reads and diff inspection during review. When the resolved
profile grants commands, read-only shell helpers may parse existing JSON,
calculate evidence hashes and display diffs. Do not import or execute project
code, run project validation, or create product/cache artifacts. A profile with
`commands: false` requires native read tools; it does not permit a shell bypass.
Route executable checks, including whitespace validation, through Tester. Write only the assigned review artifact; production, tests, documentation,
formatting, sources and other agents' reports are read-only.

One designated final Judge owns integrated acceptance. Optional scoped
Judges may report advisory findings, with distinct IDs and sessions; they
cannot replace the integrated pass. Every reviewer is independent of authors.

## Completion gates

Apply [the judge gates](../gates/roles/judge.md); required in this role’s context.

## Review output

Use the [Implement result format](common/implement-result.md) and the
[verdict/outcome mapping](common/review-findings.md). Compare the actual assertions and affected consumers with each criterion.
For a missing registered check on the same candidate, return `outcome: BLOCKED`, `stage_result: CHECKS_REQUESTED`, its check ID and the affected behavior. The coordinator assigns Tester and returns the new receipt for review. Request an
Implementer correction for a deficient change or test. Record each known defect
immediately as your own open blocking `findings` entry, including when requesting
an extra check before any repair. Use `verdict: NEEDS_WORK`, `outcome: BLOCKED`
and `stage_result: CHECKS_REQUESTED` together with that finding for this evidence-only
pause. The same candidate may be checked before author writes; the finding remains
Judge-owned and open until the original author hands off a repair and Judge closes
it on fresh evidence. Do not defer a known finding to Tester or encode a clear
implementation defect as semantic RETHINK. A pure missing-evidence request without
a diagnosed defect keeps the existing blocked mapping. Inspect fresh evidence
before issuing an independent verdict. A tool execution blocker uses `BLOCKED_TOOL_ERROR` with `BLOCKED`.
An open blocking finding excludes `APPROVE`.

Initial findings use stable IDs `REV-1`, `REV-2`, and so on. Each finding
contains severity, file/line, violated rule, concrete impact, source evidence,
and bounded fix.

Re-review checks every original ID using the shared finding statuses.
It also inspects the fix diff for new significant regressions. Each new
significant regression receives the next unused `REV-*` ID.

Execution procedure: `.factory/roles/judge.md` (executor reading).
