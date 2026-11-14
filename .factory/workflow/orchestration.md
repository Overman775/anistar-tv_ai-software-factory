# Dynamic orchestration

The parent builds and drives the workflow using `factory.yaml` and its configured
[router](router.md). Roles define permissions; skills define domain checks.
Scripts validate/record decisions, not product semantics. Apply the router
before creating or revising assignments; persist decisions before dispatch.

Every child launch or follow-up, including intake/research helpers, must use
an eligible configured role/profile and its adapter. ACP forbids direct native
spawn or implicit coordinator model/effort inheritance. If the adapter cannot
execute the assignment, report a blocker; never silently substitute native.
Until a valid Implement assignment can be reserved, prepare directly as coordinator.

Read [coordinator communication and waiting](../contracts/common/agent-checkpoint.md).

## Entry

Complete this entry before preparation or delegation, whether invoked through
Factory Implement or directly as Orchestrator.

Save `sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py config`
output as JSON in OS temporary storage. Keep it through `init`; do not send it
to workers. Use `sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py
read-instructions SNAPSHOT PATH...` for mandatory Implement factory instructions.
Paths are relative to `.factory/`. Use the returned content, including when
rereading this policy and the entry skill. The command verifies the same bytes.
Read the Orchestrator role and contract, communication and project policy,
execution source contract, configured router, this policy and their applicable
Implement instruction links through that command. Other process handoffs follow
their own entry instructions. On changed bytes, stop and reload the snapshot and
instructions; pass the same snapshot to `init`.

Resolve project inputs with `sh .factory/tooling/bin/python.sh
.factory/tooling/bin/project.py context --process implement --audience coordinator`.
Add `--scope PATH` for each known scope. Read returned instructions and applicable
documents: project `AGENTS.md`, architecture, structure, codestyle, testing, specs,
ADRs and package READMEs. Unknown scope retains obligations; read actual domain
rules and command definitions, not only indexes. Read selected adapter instructions
and role contracts before their assignments.

Inspect `.factory/memory/state/workflow.json`. Reconcile files and runtime before
resuming; cancel an old run only on user instruction. Never silently replace
legacy `pipeline.md` or an unknown writer.

## Intake

One active implementation run per checkout, with a fixed batch of direct tasks,
intents, approved plans or decomposed tasks. Resolve each source using
[execution source contract](../skills/factory-implement/references/execution-source-contract.md); preserve hashes and
approvals. New unrelated tasks need another run. A follow-up records its bounded
new delta without inheriting completed gate verdicts. Coordinate shared provider
quotas across checkouts. Planning owns product decisions and immutable approved
plans; Decompose owns published vertical tasks. The parent coordinates; even
small product edits go to a Generalist, not a root-only editing exception.

Lock intended behavior, exclusions, criteria and risk. For a direct source, copy
the complete request into `text`, excluding credentials, and check it against the
original. Preserve explicit no-plan and decision-delegation wording verbatim in
`directive`; use `none` only when neither appears. Apply the source contract's
directive precedence and Material Semantic Gap Gate. Technical graph preparation
is not a new semantic approval gate.

Inspect code before asking for missing product decisions. Self-contained requests
need no mandatory Planning; planning-only requests go to Planning or stop without an Implement run, assignments or product edits. Reuse an
execution sketch only after checking sources, checkout and available profiles;
otherwise build it before dispatch.

Approved outcomes, exclusions, checks and explicit constraints bind. Technical
reassignment/reordering within them needs a recorded reason, not new approval.
Changed product semantics, permissions or scope return to the source/planning
owner. Never rewrite approved sources to match bugs. Retain original and revised
graphs in history.

## Graph and verification

Build/reuse slices, tasks and agent steps; record why the selected team is sufficient.
Use the [state contract](../skills/factory-implement/references/shared-state.md)
and [workflow usage](README.md). Run `workflow.py init GRAPH --config-pin CONFIG_SNAPSHOT`
to verify observed instruction versions; validate before dispatch.
Persist an acyclic graph before the first worker. Each logical agent has one ID;
Developer instances have distinct IDs. Steps bind task, slice, source hashes,
profile, inputs, owned paths, dependencies and output. Fixes reuse nodes with new
attempts. Runtime state is authoritative; Mermaid sequenceDiagram only projects it: one lifeline
per agent, `par` for safe parallelism, dashed findings through the parent to owner.

Launch only ready, reserved assignments. Plan roles and assignments in advance;
create or resume a physical worker only when it can perform concrete authorized
work now, with available inputs, resources and a defined output. Do not create
a session whose only assignment is to wait for future work or a dependency.

Preparatory work may start early only as an ordinary assignment supported by
an existing stage and role contract, with a useful deliverable. Do not introduce
a preparation stage or create a separate node merely to read context. The parent
can do lightweight preparation inline; otherwise keep it in the worker's assignment.
Before dispatch, ensure the worker can satisfy the stage's result contract with
currently available inputs. Implement reports require current hashes of the entire
task scope, including files outside the worker's owned paths; concurrent writes
can invalidate that evidence. Coordinate a stable handoff before accepting it;
never omit hashes, reuse stale evidence or run a retry loop to race active writes.
If these conditions cannot be met, defer the assignment. Never remove dependencies
to start early; code-dependent tests and final review wait for their required inputs.

An existing session waiting between assignments is not a new idle worker.
Reuse it only under the existing role, context and host rules; do not automatically
recreate it to avoid waiting. Do not assume an idle session releases a host slot.
Dependent slices wait for predecessor acceptance; independent slices may overlap
when ownership/resources permit. Concurrent writers never
own overlapping paths. Shared build, generation/check commands serialize
on `project-checks`. Authoritative snapshot checks require a quiescent checkout;
never merge active writes into a tested snapshot.

After writers join, verify the integrated tree and end-to-end behavior, then
accept each slice. Batch acceptance additionally requires cross-slice scenarios
and mandatory deferred work; local PASS is not integration PASS.

## Gates and corrections

Read the [shared acceptance contract](../gates/common/verification-rules.md),
[Implement gates](../gates/skills/implement.md) and coordinator
[acceptance data](../skills/factory-implement/references/acceptance-data.md).
Carry stable AC IDs through source, tasks, required checks and results.
Acceptance criteria neither replace mandatory project gates nor limit additional
risk-based checks.

Apply Implement's shared gates: architecture, source drift, static/test/build,
golden, refactor and evidence. Reports bind final scope and file hashes;
process exit or ACP delivery is not a gate verdict.

Before any `run-check`, call `workflow.py next` and wait for every outstanding
native packet confirmation, including other nodes. A ready check reservation
does not clear this delivery gate.

Register applicable mandatory commands in task `required_checks.execution` before
intake, with argv/cwd/timeout and additional input files. Execute through
`workflow.py run-check NODE CHECK_ID --request REQUEST_ID --dispatch DISPATCH_ID` under project-checks; use the stored result
unchanged in the report. Never infer PASS from successful transport, CLI `ok`,
a missing exit code or a RUNNING receipt. A command failure needs diagnosis before
an explicit retry. See workflow README for synchronous locking and process recovery.
The runner does not decide whether test assertions or test selection are correct.

Update affected docs/specs within authorized scope before final verification;
author/DocWriter selection follows the router. If none apply, record
`not_applicable` with a reason. Final review covers code, tests and docs; eligible low-risk, local, reversible work with an explicit behavior and reliable oracle may finish with Generalist SELF_REVIEW PASS when no user or project rule requires independent review. Higher risk, required independence and multi-task integration require an independent Judge. Subsequent writes invalidate affected verification and review.

Return code/test defects to their respective owners; never weaken correct
assertions to pass broken code. Keep finding IDs across reviews. Ambiguous
ownership or environment failure returns to the parent; repeated failures require
diagnosis before team expansion (router).
For Judge corrections use [persistent review findings](../contracts/common/review-findings.md):
route open IDs to their owner, then ready IDs to independent re-review. Never erase
the registry during retries/revisions or treat an author handoff as closure.

Retry budgets belong to stable task+cause and come from `execution.retry_budgets`.
Initial work is separate from retries; integration uses feature review budget
when the fixed batch contains a feature. Session/profile/graph changes never
reset counters. Requirements, project gates and additional checks stay intact.

For profiles with escalation, use `workflow.py correct NODE DECISION_JSON` after
reviewing terminal failed/blocked evidence. NODE identifies the responsible
worker's work, not necessarily the checking node. Include exact author/evidence
dispatch IDs, cause, diagnosis, reason, terminal evidence and a scoped handoff.
Use the schema in workflow README. The coordinator verifies diagnosis and actual
termination; the helper enforces identity, current source/files, budget and target.
Quiesce the whole run first. Never turn unknown work into a failure or resubmit
it merely because a wait timed out.

The correction transaction records the decision, invalidates affected dependent
results and opens only a permitted retry. Quality consumes one remaining retry;
profile changes require an evidenced unsuccessful attempt and the configured threshold.
Before a profile change, retain old handles/connection identities and close a
terminal ACP session through its adapter while the old node assignment still
addresses it. The node-scoped ACP helper addresses the new assignment after
correction; it cannot close the old session by that node then. Native closure
uses the actual host API, with retained capacity recorded if unavailable.
A changed profile gets a fresh logical agent and physical session for the corrected
author's affected nodes in this task. Other agents, independent nodes and other
tasks keep their assignments. The helper never closes a
backend or spawns a model. Same-profile retries may reuse a suitable session.
Check returned decision: CLI success is not task success; human/blocked stops
claim and acceptance. `resume-task` requires resolved blocker/human evidence and
opens the stopped work and its dependents as pending, spending one remaining
recovery for environment or one retry of the original cause otherwise. It never
resets budgets. An exhausted budget cannot be resumed through this command.

Use ordinary `retry` for non-escalating profiles and the separately budgeted
transport recovery without terminal FAIL/BLOCKED reports in affected nodes.
Reported blockers in escalation-enabled Developer/TestWriter assignments require
correct and resume-task. Non-escalating profiles use ordinary retry with recorded
blocker resolution; do not invoke an unsupported escalation transition. The next packet contains task-scoped correction history,
current source/AC, findings, dependencies and remaining budgets. Prior reports
are historical evidence, not proof that current files pass. No automatic parent
or predecessor transcript inheritance and no worker-side escalation policy.

Before finishing a predecessor needed downstream, read its author report against
the [dependency-handoff contract](../contracts/common/implement-result.md#dependency-handoff);
compare it with the locked source and applicable documents for the downstream
consumer. Return missing or ambiguous facts to the same bound author for a
report-only amendment after the terminal turn and writer reconciliation, if the
adapter permits continuation; reread before `finish`. If continuation is
unavailable, preserve the terminal report and use the normal verification-failure
and correction path, or block; do not change its outcome or dispatch the successor.
After `finish`, the ledger holds
a copy: use the existing correction/retry path and invalidate dependent evidence,
not an edit to the output file. For an explicitly required durable handoff, also
apply the required observation in [acceptance data](../skills/factory-implement/references/acceptance-data.md)
before predecessor acceptance and successor dispatch.

Before successor dispatch, check predecessor reports. For facts discovered after
a terminal report, provide authorized scoped sources
for dependent workers; do not keep required handoff only in chat. The packet follows relevant dependencies through
acceptance, deduplicates nodes and preserves full evidence for verification/review.
It does not infer missing reasons or import every task in a slice/run. Supply any
additional required source through scoped reading; keep messages Telegraphic.

## Sessions and recovery

For each ready node, recheck source, model/tools/permissions and host capacity;
reserve with `claim`, then execute the selected adapter's packet delivery and
session-binding procedure. Native/ACP launch commands belong to that adapter.
Use [shared adapter rules](../adapters/common.md) for context ownership; workers
receive worker instructions and assignments, not coordinator instructions.
Do not run multiple active turns in one session. Validate returned evidence
before `finish` or routing findings to their owner.

Reuse sessions for related work only after checking specialization, instructions,
context and newly locked assignment; a new slice alone needs no new agent.
Reviewers never share author sessions. If unavailable or context is harmful,
explicitly replace the session, record epoch and old/new handles, and hand off
goal, decisions, completed work, findings and evidence. Verify against files;
new sessions have no automatic memory.

Native and per-ACP limits cap unresolved assignments across roles, excluding the
parent. Host open-thread limits and provider quotas also apply; completed open
sessions may still consume slots. Retiring a record does not close a host thread;
without real closure, wait/report capacity. Disable nested delegation unless its
capacity is included. Backend aliases share one pool; never duplicate quotas.

Reserve slots/paths and persist dispatch ID before transport, then record the
returned handle. Interrupted/ambiguous requests stay `unknown` and retain resources;
inspect runtime, diff, artifacts and source before recovery, never blindly resend.
Silence is not failure. Explicit failure allows one same-role recovery only after
confirming the old writer stopped. Cancel only on user instruction or an explicitly
allowed failure condition; cancellation acknowledgement does not prove writes ended.

## History

Follow [finalize](../skills/factory-implement/references/shared-finalize.md), then
[cleanup](../skills/factory-implement/references/shared-cleanup.md). Commit, push,
publication, live tests, golden changes and destructive cleanup retain their
explicit authorization rules.

Checkpoint every transition in `.factory/memory/state/`, separately from planning/
decomposition staging. Before terminal cleanup, save a self-contained record in
`.factory/memory/history/<run-id>/`, retained until explicit deletion. Include source
versions, final graph/assignments, change reasons, checks/revisions/findings/retries,
unresolved work and measured usage (`null` if unknown). Separate observations
from facts; exclude secrets and exhaustive transcripts. After all workers actually
stop, put any additional required evidence in the run's history directory, then
archive the completed/cancelled run. Call `workflow.py clean` after the bundle
is verified. It removes packed loose copies and the active manifest. Keep
foreign files and the archive. Failed archive writes and live or resumable
runs block cleanup; report failures and remaining paths.

## Final integration execution

Distinguish slice-local gates from final run gates before dispatch. Slice acceptance
unblocks dependents; it never claims whole-run completion. Assign final integration
verify (all required tests/build/static) and subsequent review to an independent
Judge with combined source/AC, slice map and current reports. Reuse its session
across those two nodes, never an author session. A single eligible solo Generalist executes all applicable final checks and records SELF_REVIEW PASS; user or project independent-review requirements still require Judge. Preserve mandatory slice checks and project rules.
Store full command logs; hand off short results and bounded failure excerpts.
Reviewer diagnoses affected task and owner using evidence; coordinator routes code
fixes to Developer, test fixes to TestWriter, unknown causes to diagnosis. Cross-slice
defects need explicit correction ownership and rechecking combined behavior.
No product writes by the reviewer. Retry invalidates downstream evidence; final
verification and review rerun on corrected bytes before accept/archive.


## Reconciliation

Call `workflow.py next` after dispatch, transport return, check result,
correction, scope change and on resumed entry. Reconcile saved dispatches,
session handles, pending executions and reports before any repeat request.
Inspect new terminal reports once per dispatch and acknowledge with `ack-result`. Claim
runnable assignments, accept eligible nodes, wait on active handles, and
perform only evidence-supported correction or reconciliation. Report material
progress in commentary. Keep the turn active while work remains and the host
supports waiting. The native adapter supplies no autonomous launcher or wakeup.
Respect recorded user pause/stop. Final completion follows successful archive.

## Task guidance

| Work | Additional guidance |
| --- | --- |
| Feature | [feature](../skills/factory-implement/references/feature-pipeline.md) |
| Bug | [task](../skills/factory-implement/references/task-pipeline.md) |
| Refactor | [refactor](../skills/factory-implement/references/refactor-pipeline.md) |
| Tiny bounded change | [fix](../skills/factory-implement/references/fix-pipeline.md) |
| Read-only exploration | [explore](../skills/factory-implement/references/explore-pipeline.md) |
| Diagnosis only | [debug](../skills/factory-implement/references/debug-pipeline.md) |
| Documentation only | [docs](../skills/factory-implement/references/docs-pipeline.md) |

These are domain requirements/examples, not fixed agent sequences. The source
contract still controls semantic gaps and source drift. Minimality preserves
security, error handling, accessibility and required tests. Prefer established
helpers, platform features and installed dependencies before new abstractions.

## Final report

Report actual outcome, completed slices, agents/models used, checks, review kind,
docs updates, unresolved work and history path. Missing checks are `NOT_RUN` or
`BLOCKED`, never success. Canonical instructions are English; user-facing reports
follow dialogue language and history follows task/project language. Internal
messages follow the shared communication contract.
