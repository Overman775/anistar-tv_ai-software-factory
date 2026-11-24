# Review findings in Implement

Applies to Judge and correction owners within one run. The ledger stores
findings by task and stable `REV-1` ID; IDs may repeat across different tasks.
Dispatch includes current task `review_findings`; integration also receives predecessor
findings with task-qualified IDs. History remains in the ledger.
Omission, retry, session replacement or graph/source revision never deletes findings.

Judge reports review findings in `findings`. Tester may open a finding when a verification failure identifies a responsible author.
```json
{"id":"REV-1","status":"open","blocking":true,"owner_role":"implementer",
 "summary":"Describe the defect and location","evidence":"Reproduction or code reference"}
```
Assign writing to the task's Implementer or DocWriter. Route a request for
another existing check to Tester through the coordinator.
The coordinator routes corrections to that role; ambiguous ownership requires
review diagnosis before registration. Identity, owner and blocking classification
are stable; dismiss a mistaken finding with evidence instead of weakening it.

The assigned owner reports `finding_updates` (not closure in `findings`):
```json
{"id":"REV-1","status":"ready","evidence":"Changed paths and verification"}
```
Judge rechecks the correction and includes the ID in `findings`, with
`status: fixed` and evidence, or `open` if still broken. `fixed` requires a ready
handoff; only a reviewer may dismiss with evidence or reopen. Rechecking a closed
item may refresh fixed/dismissed evidence. Optional identity fields must match.
Every blocking ID must be explicitly addressed before APPROVE, including previously
closed IDs. An omitted open/ready item remains unresolved. Later source/file or
graph revision invalidates closure evidence and requires renewed review.

Verdict/outcome mapping: APPROVE/PASS, NEEDS_WORK/FAIL, RETHINK/BLOCKED,
BLOCKED_TOOL_ERROR/BLOCKED. A review that records an open blocking defect and
requests an additional check before repair may use NEEDS_WORK/BLOCKED only with
stage_result CHECKS_REQUESTED. This preserves known defect ownership while Tester
checks the same candidate; it does not close the finding or authorize acceptance.
FAIL_* stage results cannot accompany PASS; BLOCKED_*
requires BLOCKED. Author-stage PASS means handoff, not acceptance of open findings.
Acceptance and completed archive require all blocking items closed on current
files/source/revision. Nonblocking notes remain visible without blocking acceptance.
The helper enforces recorded transitions, not correctness of the fix or evidence.
Standalone Code Review and findings from other roles keep their existing contracts.

## Integration findings and failed verification

Integration packets include predecessor findings keyed `task_id:REV-n`, task/source
map and writer nodes. Report `task_id` and `id` as separate fields; IDs remain
scoped to their original task. For a new predecessor finding include explicit
`owner_node_id` matching a writer in that task and its `owner_role`:
```json
{"task_id":"slice-a","id":"REV-2","status":"open","blocking":true,
 "owner_role":"implementer","owner_node_id":"write-a",
 "summary":"Describe affected behavior","evidence":"Command, error and diagnosis"}
```
A failed Tester verification may register findings before review can run.
After the owner returns a ready handoff, Tester may close its own finding with a fresh successful check. Judge retains authority over findings first raised by Judge and provides the independent review verdict when required.
The coordinator uses the failed integration node as correction evidence for the
identified original author (correct for escalating profiles; retry otherwise).
Use the actual cause: tests, static or review. Preserve budgets and invalidate
dependents including integration before rerun. Unknown ownership needs diagnosis.
Only that assigned writer node can mark its finding ready. Integration review
explicitly rechecks all predecessor blocking findings, including prior closures,
and records current source-task file hashes. New writes invalidate these closures;
archive never bypasses freshness. Original task history remains intact.
