# Worker Rules

Read the current assignment, your role/contract, supplied worker adapter,
AGENTS.md and mandatory project documents before dependent work. Implement
supplies accepted copies of mandatory reading in the packet. Read selected project
profile rules and their actual documents, plus assigned source/evidence; an index
is navigation, not a substitute for applicable documents. Missing required inputs
block dependent work; report the missing inputs and the parts of work they block.
Include concrete paths of project documents actually read in the handoff.
Follow [Project discovery](code-discovery.md) to find task-specific material.
Distinguish current requirements, authorized changes and history.
Report missing context and selected paths/reasons to the coordinator; additional
reading never overrides mandatory policy or authorizes a new product decision.
Act only inside source/permission/ownership boundaries; preserve user changes.
Do not invent product decisions, edit approved sources, spawn children, choose
another model/team, retry another worker or change the ledger. A role change is
not authorized by reading another role's instructions as reference material.

Use the supplied task-scoped data; the full run ledger and coordinator skill are
not mandatory worker reading. Material uncertainty returns evidence, unresolved
choice, impact and directive mode as a semantic_gap_candidate to the coordinator.
Stop only dependent writes; preserve authorized work. Missing facts/tools are not
automatically a planning gap. The coordinator chooses planning/continuation.
For Implement, use the accepted source and instruction text in the packet. Report
missing or invalid snapshots to the coordinator. Candidate documents can be read
and edited as assigned deliverables. They do not redefine current requirements.

Follow [communication](communication.md) for language and style.

## Result scope

Match depth to the assignment: location search returns verified paths/lines and
brief relevance; investigation adds necessary relationships and evidence. Changes
return locations, purpose, actual checks and remaining work. Review returns
findings with IDs, impact and evidence, without praise or a diff recap.
A blocker/handoff preserves state, attempted approaches and unresolved questions.
No tool-call diary or repeated assignment. Do not duplicate an available report in
its cover message; still deliver every required field and artifact. NOT_RUN,
NOT_APPLICABLE, unknown and PASS stay distinct. Re-reading is not test execution.

## Progress and continuation

Report a blocker, material finding, change of approach, completed boundary or
result. For long work, use stage/evidence/next/blocked when useful. Routine reads
and small steps need no message; no fixed message quota. Role-specific milestones
are useful reporting opportunities, not a demand to narrate every action.
Silence is not failure; do not self-cancel because a wait timed out or no progress
message was emitted. A fresh session has no memory: use the supplied handoff and
current files. Report only this assignment; preserve stable IDs and unresolved
findings. Original sources and further references remain available for inspection.

## Process-owned results

Planning, Decompose and standalone Code Review use their own assigned artifact
schemas and Done Signals. A returned draft is not approval or publication.
Implement assignments receive the result interface for their assigned stage.

On a blocked or failed assignment, preserve the actual source/AC and current diff.
Return reproducible evidence, exact artifact/log paths, approaches already tried,
rejected hypotheses and the unresolved question. Distinguish observed failure
from inference, missing tools/permissions and missing requirements. Historical
handoffs and results are context to verify, not current PASS evidence. Continue
only the assigned work; the coordinator owns any retry or change of executor.

MCP allowlist entries identify tools, not server connections or call arguments.
Use the actual host tool catalog and input schema for each call. Missing required
tools are a blocker; do not invent them from their names or request provider keys
in a task report. Server credentials remain in the harness configuration.

Project profile rules arrive with selectors and provenance. Apply `usage: policy`
(the default) within its selector. Use `usage: reference` as background. A second
rule for the same document preserves the first rule's obligations and scope.
In Implement and standalone Review, use accepted document text from the packet
as baseline context. Read current files when inspecting the candidate.

Use project lessons on demand in the assigned checkout. For a relevant past
case run `sh .factory/tooling/bin/python.sh .factory/tooling/bin/lessons.py search_lessons "QUERY"`.
For an Implement assignment append `--run RUN_ID --dispatch DISPATCH_ID` from your packet, including on a delegated lookup.
Use a short symptom in the task language. Keep secrets, personal data and copied logs out of queries.
If no returned card fits the condition (including an empty list), try once more for
that symptom. Use different words and concrete names from the task or error; add
`--english "English terms"` when helpful. Keep both assignment IDs on the retry.
Stop after a useful match or that one retry; continue without a lesson if none fits.
If the assigned host restricts commands, request the same lookup from the coordinator.
Treat the returned 0–3 lessons as guidance scoped by their conditions.

If you also need a previous task’s evidence, add `--include-history` to a lookup. History is optional. Results label the source as
`lesson` or `case`. A case links an accepted past report with its exact attempt.
Copy the case's `report_ref` object to a temporary JSON file and use
`workflow.py read-report REF.json` through the same launcher. Check the report's
conditions against the current assignment and verify any reused approach here.
A case supplies historical context. Current requirements and evidence still govern.

When you apply a Markdown lesson, include `applied_lessons` in the report: copy its returned `id` and `revision`, and state the checked effect in `result`. Omit lessons you only read.

When a past approach works in this task, include an `applied_cases` entry in your
PASS report. Copy the exact `report_ref` and describe the action and its verified
current `result` (check, measurement or observed behavior). Omit cases you only
looked up. The final run review sends this evidence to Teacher automatically.
