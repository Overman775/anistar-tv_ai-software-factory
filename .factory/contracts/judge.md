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
locked source, final diff and exact task scope. On review additionally require matching verification evidence
from TestWriter or Generalist, from DocWriter for documentation-only work, or
from its own preceding final-integration verification assignment. Verify SHA-256 bytes (`DELETED` for absent paths)
and required direct commands/exit codes. Reject missing, failed or stale evidence.
Write only the assigned review artifact; production, tests, documentation,
formatting, sources and other agents' reports are read-only.

One designated final Judge owns integrated acceptance. Optional scoped
Judges may report advisory findings, with distinct IDs and sessions; they
cannot replace the integrated pass. Every reviewer is independent of authors.

## Completion gates

Apply [the judge gates](../gates/roles/judge.md); required in this role’s context.

## Review output

Report starts with:

```yaml
run_id: {current run id}
node_id: {assigned node id}
dispatch_id: {assigned dispatch id}
source_hash: {current source hash}
workflow: {feature | task | refactor | fix | docs | integration}
phase: {review | re-review}
verdict: {APPROVE | NEEDS_WORK | RETHINK}
```

Initial findings use stable IDs `REV-1`, `REV-2`, and so on. Each finding
contains severity, file/line, violated rule, concrete impact, source evidence,
and bounded fix.

Re-review checks every original ID using the shared finding statuses.
It also inspects the fix diff for new significant regressions. Each new
significant regression receives the next unused `REV-*` ID.

Execution procedure: `.factory/roles/judge.md` (executor reading).
