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

From the checkout root, run `.factory/tooling/bin/cli workflow status`
(`.\.factory\tooling\bin\cli.cmd workflow status` on native Windows). The shorthand
`cli` below means that checkout's launcher. For an active run, continue from the
accepted factory instructions via `cli workflow read-instructions - PATH...` and
accepted coordinator project reading via `cli workflow read-project`. Use that policy
and instruction text for current-run
decisions. Inspect candidate files separately for scoped edits. Reconcile files
and runtime before resuming. Cancel an old run only on user instruction.
Never silently replace legacy `pipeline.md` or an unknown writer.

For a new Implement intake (route a planning-only request to Planning first):

Run `.factory/tooling/bin/cli workflow prepare-workspace`.
Use the returned workspace and config for all remaining steps, including coordinator
reads, native and ACP workers, checks and handoff. Switch command cwd explicitly.
If the native host cannot place a worker in that checkout, report a blocker.
Keep the path and branch in the handoff so continuation opens the same checkout.
See [workspace selection](README.md#workspace-selection) for setup and failure modes.

Keep the instruction pin printed by `.factory/tooling/bin/cli workflow config` through initialization.
Read mandatory Implement instructions with `cli workflow read-instructions PIN PATH...`.
Paths are relative to `.factory/`. Use the returned content, including when
rereading this policy and the entry skill. The command verifies the same bytes.
Read the Orchestrator role and contract, communication and project policy,
execution source contract, configured router, this policy and their applicable
Implement instruction links through that command. Other process handoffs follow
their own entry instructions. On changed bytes, obtain a fresh pin, reread the instructions and pass that pin to `init`.

Resolve project inputs with `.factory/tooling/bin/cli project context --process implement --audience coordinator`.
Add `--scope PATH` for each known scope. Read returned instructions and applicable
documents: project `AGENTS.md`, architecture, structure, codestyle, testing, specs,
ADRs and package READMEs. Unknown scope retains obligations; read actual domain
rules and command definitions, not only indexes. Read selected adapter instructions
and role contracts before their assignments.


## Intake

One active implementation run per checkout, with a fixed batch of direct tasks,
intents, approved plans or decomposed tasks. Resolve each source using
[execution source contract](../skills/factory-implement/references/execution-source-contract.md); preserve hashes and
approvals. New unrelated tasks need another run. A follow-up records its bounded
new delta without inheriting completed gate verdicts. Coordinate shared provider
quotas across checkouts. Planning owns product decisions and immutable approved
plans; Decompose owns published vertical tasks. The parent coordinates; even
small product edits go to an Implementer, not a root-only editing exception.

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

For direct work register the typed execution with `graph_inputs.propose`; for an approved plan use `graph_inputs.propose_plan(root, execution, source_id, plan)`. To consume published Decompose tasks pass `decomposition_run=RUN_ID`. IDs, coverage, parent edges and prerequisites are verified from that run. Supply write scope, investigation objective, relevant public surfaces, binding directives and mandatory gates. Use empty nodes and agents for the ordinary graph-built route. Initialize with `cli workflow init PROPOSAL_ID --config-pin PIN`.

`workflow status` shows eligible nodes, source stops, selected roles and required checks. Resolve a named external fact with `workflow resume-task TASK EVIDENCE --stop STOP_ID`. Worker packages include their exact inputs, scope, authority, evidence and requested result. [State contract](../skills/factory-implement/references/shared-state.md) · [CLI](README.md)

## Gates and corrections

Read the offered operation, target, evidence and remaining budget in `workflow status`. Inspect `workflow explain NODE --dispatch TICKET` for the recorded route. Qualify a confirmed finding with owner and affected paths. State what is still unknown when evidence cannot identify the cause. The graph checks the permitted transition again on mutation. Only the coordinator can issue a correction, grant an additional check or accept a result.

Refer to [verification rules](../gates/common/verification-rules.md) for the evidence standard. Implementer hands over code, tests, documentation or the basis for current documentation; Tester executes scoped or integrated checks. Judge assesses the current AC evidence and can request additional verification. Retain open findings and the original review subject when recording new receipts.

## Sessions and recovery

After reserving a dispatch, bind the observed native handle or ACP session. Deliver only the accepted worker packet. A reservation alone does not prove that a worker started. Reconcile a lost reply against the stored ticket and host. A quiet worker remains active until terminal evidence arrives. Retry an identical mutation with its original key. Read `workflow status` after returning from a pause; use its applicable adapter action and preserve the remaining budget.

## History

Follow [finalize](../skills/factory-implement/references/shared-finalize.md), then
[cleanup](../skills/factory-implement/references/shared-cleanup.md). Commit, push,
publication, live tests, golden changes and destructive cleanup retain their
explicit authorization rules.

Record workflow transitions in `.factory/memory/workflow.sqlite3`. Use the final
summary for source versions, assignments, changes, checks, findings, retries,
unresolved work and measured usage (`null` when unknown). After all workers stop,
place additional evidence under `.factory/memory/history/<run-id>/` and archive
the completed or cancelled run. Record its run ID and database path. The journal
retains the original packets, reports and transport logs, which may contain sensitive data.
`cli workflow clean` verifies the inventory, removes its working copies and releases
the current run slot. For later inspection use `list-artifacts` and `export-artifact`.
Report any failed archival or cleanup with the remaining path and cause.

## Final integration execution

Slice acceptance releases its own dependents. Final acceptance needs evidence for all project and owner obligations against the combined changes. For an owner-requested verdict, set `independent_review` and `owner_review_ref`. If a task-level acceptance observation specifically needs Judge, set its `assessor` to `judge`; use `tester` for a Tester-only observation. For the first review of an unchanged candidate, dispatch the Judge with the packet and source. Preserve upstream hypotheses in their original reports while the Judge assesses the candidate independently. Assign checks by authority, including on a full verification. Tester owns execution. Judge owns any required independent verdict. Record the actual checks, exclusions, source and revision.

## Reconciliation

Use the returned action and exact run, node and ticket for every handoff. Reconcile a recorded execution before issuing another command. Acknowledge each consumed terminal result via `ack-result NODE DISPATCH_ID`. Successful finalize records any outstanding acknowledgements atomically with the archive. For an approval hold, present the bound `approval_request` in the handoff, including destination path, candidate SHA-256 and request ID. Wait for the owner before resuming. For a missing or ambiguous rule retain the reported branch, facts and reason. Healthy independent branches can proceed while that branch waits.

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
contract still controls semantic gaps and source revisions. Minimality preserves
security, error handling, accessibility and required tests. Prefer established
helpers, platform features and installed dependencies before new abstractions.

## Final report

Report actual outcome, completed slices, agents/models used, checks, review kind,
docs updates, unresolved work and history path. Missing checks are `NOT_RUN` or
`BLOCKED`, never success. Canonical instructions are English; user-facing reports
follow dialogue language and history follows task/project language. Internal
messages follow the shared communication contract.

## Teacher at run completion

Read `workflow status` after archive. Deliver the named Capture event through the [Teacher assignment](../skills/factory-lessons/references/dispatch.md). The event retains the archived run ID across cleanup, owner input and subsequent runs. A cancelled run produces no Capture event.
