# Implement handoff evidence

Required fields: run_id, task_id, slice_id, node_id, dispatch_id, source_hash,
terminal:true, outcome:PASS|FAIL|BLOCKED, summary, files, checks, stage_result.
Copy identities from the assignment. Use the displayed `finish_requirements`.
`files` records SHA-256 or DELETED for the authoritative handoff scope.
For projected integration work, `task.scope` shows the worker's local paths.
Use `prepare-report` to capture the authoritative snapshot at handoff.
`checks` contains actual results, never planned commands masquerading as evidence.
At author handoff, the worker may call `cli workflow prepare-report NODE DRAFT [RECEIPT_ID ...]`.
Use `-` for DRAFT to read JSON from stdin when no assigned draft path is available.
The draft carries run_id, dispatch_id, source_hash and node_id from the assignment,
author fields and any observation checks,
but no `files` field. The helper checks the bound dispatch, adds selected current
required receipts, derives task_id and slice_id, and captures scope files. A PASS
`WRITES_READY` node with explicit `handoff_inputs` captures owned task files and
those exhaustive dependency paths; without that declaration it captures the full
task scope. Other reports always capture the full task scope. PASS
requires passed receipts; FAIL/BLOCKED may include authentic fresh FAIL/BLOCKED
receipts without relabeling them. An invalid source snapshot permits a FAIL/BLOCKED handoff. PASS requires an
intact snapshot, and finish records observed drift for a terminal failure. Save its `result` as the report. The coordinator
must not use this helper to refresh a returned report or manufacture a fresh handoff; request
a new author handoff instead. `finish` still checks freshness. A full intermediate handoff must include every declared dependency.
Failed/blocked work is preserved. ACP/CLI transport success is not work success.

A work/docs node without an applicable command gate and without project-checks
edits only its allowed files and returns
stage_result:WRITES_READY and outcome:PASS; this is an intermediate handoff.
Include results for checks required by this assignment, including observations.
Use checks:[] only when the assignment has no required checks.
Do not run codegen/static/test/build commands without the reservation.
Checks assigned to the verification node are deferred, never waived.
