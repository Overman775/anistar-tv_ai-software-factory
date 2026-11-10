# Workflow state

One authoritative `.factory/memory/state/workflow.json` belongs to the active
implementation run in a checkout. `workflow.py` owns atomic ledger transitions.
The graph is supplied by the orchestrator; no separate pipeline.md can declare
success. Planning/decomposition keep their existing staging contracts.

See `.factory/workflow/README.md` for the exact graph/report format and commands.
Identity hierarchy: run → source → slice → stable task → node/attempt; logical
agent → physical session/epoch. Role names are not unique agent IDs. Each source
has its own immutable snapshot/hash; each task links one source. A joint task may
reference a separately locked combined source describing all source IDs/hashes.
Do not silently change source hashes, task meanings or approvals.

Nodes record dependencies, role/profile, ownership and shared resources. Repair
invalidates the corrected node and dependent evidence, preserves previous
reports in events, and increments task+stage counters. `reserved`, `running` and
`unknown` all hold slots. No timer frees them. The parent checks native open
threads/provider quotas in addition to ledger limits. The local ledger does not
coordinate independent machines/checkouts or enforce filesystem sandboxing.

A role handoff includes run/task/node/dispatch IDs, source hash, exact output
path, workspace, source/brief, allowed writes and applicable project documents.
Reports use unique dispatch identity; do not reuse a shared test-report.md or
review.md between instances. JSON report evidence is copied into the ledger by
`finish`; temporary prompt/transport files are distinct and declared separately.

Tests/reviews bind the exact task file scope and SHA-256 contents after all
writes (`DELETED` only for an absent file). Commands have kind, cwd, exact
command and integer exit code. A successful delivery is not a valid report.
Final integrated acceptance covers the union of task scopes. Earlier slice
snapshots remain historical when an explicitly dependent task supersedes them;
only current integrated evidence can establish batch success.

Continue useful sessions after checking the new assignment and current source.
For replacement record why, old terminal evidence, a handoff summary, new epoch
and handle; preserve counters and findings. Unknown writers must be reconciled
before replacement. Reviewer never continues an author's physical session.
Keep `blocked` state for repair; do not clean it as a completed run.

New sources are a new run. Technical graph revision may adjust unstarted steps
and assignments without changing locked outcome/checks; use `revise`, recording
reason and retaining completed evidence only when its meaning and inputs match.
Risk increases may add checks, never remove an already required gate. Source
revision uses explicit re-intake; technical scope extension and stronger risk/review
are allowed with recorded reasons and evidence invalidation.
