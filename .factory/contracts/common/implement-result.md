# Implement result and stage boundaries


Required fields: run_id, task_id, slice_id, node_id, dispatch_id, source_hash,
terminal:true, outcome:PASS|FAIL|BLOCKED, summary, files, checks, stage_result.
Copy identities from the assignment. `files` contains every exact task.scope
path with SHA-256 of current bytes or DELETED. Compute after writes/commands.
`checks` contains actual results, never planned commands masquerading as evidence.
At author handoff, the worker may call `workflow.py prepare-report NODE DRAFT [RECEIPT_ID ...]`.
Use `-` for DRAFT to read JSON from stdin when no assigned draft path is available.
The draft carries run_id, dispatch_id, source_hash and node_id from the assignment,
author fields and any observation checks,
but no `files` field. The helper checks the bound dispatch, adds selected current
required receipts, derives task_id and slice_id, and captures scope files. PASS
requires passed receipts; FAIL/BLOCKED may include authentic fresh FAIL/BLOCKED
receipts without relabeling them. A changed source permits a FAIL/BLOCKED handoff;
PASS remains blocked and finish records observed drift. Save its `result` as the report. The coordinator
must not use this helper to refresh a returned report or manufacture a fresh handoff; request
a new author handoff instead. `finish` still checks freshness. Existing reports remain valid.
Failed/blocked work is preserved. ACP/CLI transport success is not work success.

A work/docs node without an applicable command gate and without project-checks
edits only its allowed files and returns
stage_result:WRITES_READY, outcome:PASS, checks:[]; this is an intermediate handoff.
Do not run codegen/static/test/build commands without the reservation.
Required checks are deferred to the assigned verification node, never waived.
For a command-capable assignment follow the supplied check-execution contract.
Final role Done Signals apply only after its assigned verification completes.
Review requires an independent APPROVE for PASS; known FAIL/BLOCKED stage results
must agree with outcome. Report discovered defects and evidence; tracked reviewer
IDs use review-findings when supplied. Never omit an unresolved defect to get PASS.

Project boundary gates arrive in project_policy.gates. Return all selected check
results; missing or stale runner receipts prevent PASS. Runtime derives gate_results;
do not invent them. Gate success never replaces final verification/acceptance.
For review, answer each selected project_policy.review_criteria in review_checks:
{id, result: PASS|NOT_APPLICABLE, evidence}; NOT_APPLICABLE also needs reason.
Defects use existing findings and non-APPROVE verdicts; never hide them with N/A.

## Dependency handoff

Summarize consequential decisions and reasons, constraints, unverified behavior and
open questions; distinguish facts from hypotheses. Preserve exact paths, interfaces
and evidence references in existing fields without repeating checks. Keep full logs
in artifacts; include paths and necessary failure excerpts.

Use `report_ref` path and keys to read only that predecessor report when needed;
require matching run_id and dispatch_id, otherwise request fresh context. Prior PASS
is historical; verify current files. Author explanations never replace requirements
as the test oracle.
