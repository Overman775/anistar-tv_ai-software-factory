---
name: factory-planning
description: "Use for project semantic planning before implementation or decomposition when behavior, scope, architecture, API contracts, ownership, or expected outcomes are ambiguous; when several valid solutions exist; or when user asks for a plan/spec. Produces a human-readable revisioned plan with explicit approval or delegated planning authorization. Do not force planning for an ordinary self-contained ticket, bare do it yourself implementation request, or explicit no plan request. Triggers: factory-planning, plan feature, prepare implementation plan, clarify scope, plan and implement it yourself, prepare a plan without questions, plan the feature, prepare the plan, work out the solution, ambiguous task."
---

Read [communication rules](../../contracts/common/communication.md) for messages and artifact language.

# Factory Planning

Read `.factory/contracts/common/project-policy.md`. Before dependent work, resolve
project inputs with `sh .factory/tooling/bin/python.sh .factory/tooling/bin/project.py context --process planning --audience coordinator`
(add `--scope PATH` for every known scope path). Read the returned instructions and
actual applicable documents. Unknown scope retains obligations; it never waives them.


Create one approved semantic map of requested change. Planning owns goal,
capabilities, behavior, solution shape, decisions, boundaries, readiness, and
verification intent. It does not own ticket slicing or implementation. Read [Verification Rules](../../gates/common/verification-rules.md): preserve AC IDs, project gates and additional checks.

## Language
Write human-facing prose in the task/project language, otherwise the dialogue language. Apply the plan
contract's Human-first Rules: preserve exact technical identities, translate
ordinary terms, then run one final wording pass only. No language ratio,
glossary, or code lookup.

## Route Before Planning
Use Factory Planning when any answer changes behavior, scope, architecture, API/storage contract, ownership, compatibility, risk, or one of several meaningful outcomes. Also use it when user explicitly asks to plan.

An ordinary self-contained ticket with one clear outcome and enough acceptance context may go directly to `factory-implement`; do not create a ceremonial plan. When uncertain, explain material ambiguity and route here. A ticket is an input source, not proof that planning is unnecessary.

Interpret user directives precisely:
- `no plan`, `no plan needed`, or equivalent explicit no-plan wording routes
  directly to Factory Implement `single_task` without planning artifact;
- `decide yourself`, `do it yourself`, `at your discretion`, `do not ask questions`, or
  equivalent delegates planning decisions only when a material semantic choice
  needs them; local execution choices still go directly to Factory Implement.
Explicit no-plan wording wins when both appear. Delegated planning removes
question/approval pauses, not Reality Check, preflight, validation, revision,
or durable plan creation.

## Boundaries

Factory Planning is sole semantic planning source. Downstream skills consume its
approved plan and must return semantic gaps here as a new revision.

Factory Planning may:

- read user request, specification, or local source;
- inspect project/docs/contracts for Reality Check;
- ask minimal decision-changing questions;
- persist and approve planning artifacts.

Factory Planning must not publish task items, decompose capabilities into tickets,
assign task IDs, estimate tickets, build a ticket dependency graph, implement code,
write tests, start `factory-implement`, or start publication. Exact files, classes,
and methods are optional and appear only when they decide architecture or
compatibility.

Keep the approved plan a durable semantic execution seed. Current paths and
symbols that only locate code stay in downstream implementation-detail work;
planning-only work does not trigger it.

## Team

Main session is planning orchestrator.

- `architect` is Factory Planning-owned semantic plan writer. It writes only
  a ready `.factory/memory/staging/planning-plan.md` candidate after discovery.
  A newly detected semantic gap returns to orchestrator without replacing the
  last presented plan.
- `code-explorer` is optional read-only help for a scoped Reality Check. Return
  evidence to orchestrator; do not create an execution plan.

Read active runtime adapter and relevant role contract before spawn:
`.factory/contracts/architect.md` or `.factory/contracts/code-explorer.md`.
Read `.factory/contracts/common/agent-checkpoint.md` before any delegated Reality Check
or Architect pass.
Canonical persona: `.factory/roles/architect.md`. Resolve profile/adapter from `.factory/factory.yaml`;
Build via `sh .factory/tooling/bin/python.sh .factory/tooling/bin/context.py --process planning --role ROLE --profile PROFILE ASSIGNMENT.json`; source, planning evidence and project read paths stay in the assignment. Deliver full output. Keep Planning staging; do not use Implement packet/claim.

Read `AGENTS.md` and pass its path to delegated roles. The project profile owns
canonical architecture/product documents, affected specification/ADR routes,
command definitions and VCS policy. Architecture remains a quality gate; bounded
code lookup cannot replace mandatory project reading. Planning describes checks
without executing them. Preserve profile rules through the worker context packet.

Instruction ownership:

- session contract owns discovery state and decision loop;
- plan contract owns output schema, semantic quality, deduplication, and language;
- validator owns mechanical structure, identity, references, and transitions.

Pass delegated roles only run identity, source/session paths, requested boundary,
previous-plan path when applicable, and checkpoint context. Do not copy their
canonical instructions into spawn prompts.

Do not invoke Developer, TestWriter, Reviewer, TaskDecomposer, or
TaskReviewer. No `task-decomposition-planner`: ticket slicing belongs to
`factory-decompose` after approval.

### Agent checkpoints

Validate every `code-explorer` and Architect handoff through the shared
checkpoint contract. Structured progress is useful but optional; silence,
elapsed time, poll timeouts, generic `running` status, and an unchanged artifact
are never failure. Keep waiting for the contract Done Signal. Do not run timer
windows or automatically interrupt a live role.

- Explicitly failed/invalid `code-explorer` handoff: finish only that bounded
  Reality Check inline or retry once when isolation is required. Do not weaken
  evidence requirements.
- Explicitly failed/invalid Architect handoff: verify the last plan target, then
  the orchestrator may render, preflight, validate, and write the same candidate
  inline from `planning-session.md`. Never run a concurrent second Architect.
- Missing status/follow-up/interrupt support is runtime capability absence, not
  Architect/CodeExplorer failure.
- Recovery creates no question, revision, or approval and never removes the last
  valid session/plan.

Read [working session contract](references/session-contract.md) before
discovery and [plan contract](references/plan-contract.md) before writing or
revising a plan. Use [validator](../../gates/skills/planning/validate_plan.py) before every
presentation and approval.

## Canonical Artifacts

- Internal discovery checkpoint: `.factory/memory/staging/planning-session.md`.
- Current user-reviewable revision: `.factory/memory/staging/planning-plan.md`.
- Canonical approved plan: `docs/plans/{plan_id}.md`; immutable versions in Git.

The session is loose internal Markdown, not a plan, revision, approval surface,
or downstream source. Keep last valid checkpoint. For every write, render to
`.factory/memory/staging/planning-plan.md.candidate`, the temporary file beside
target. Validate it before promotion, flush when runtime permits, then atomically
replace target. Failed validation or interruption leaves the last valid target
intact. Remove only the incomplete candidate after failure. Do not delete staging
or approved files on cancel or failure.

## Workflow

Expose concise stage: `Source analysis` → `Reality Check` → `Working map` →
`Decision loop` → `Candidate + preflight` → `Revision` → `Evidence` →
`Handoff`.

### 1. Intake

Identify source as `request`, `spec`, `local`, or `mixed`. Capture a
stable snapshot/reference. Separate stated facts, desired outcomes, constraints,
and observations. Missing source needed for honest planning is a blocker.

### 2. Reality Check

Inspect only project areas and external contracts needed to test the request.
Build internal v0 before asking questions. Classify every uncertainty:

- `INFO`: evidence supports one safe conclusion; record it;
- `ASK`: answer materially changes plan; ask user;
- `BLOCK`: no honest ready plan exists without missing fact.

Do not ask user to rediscover project facts. Do not turn inference into fact.
Keep large API fingerprints, source notes, and code inventories as optional
internal evidence; only behavior-shaping gist enters reviewable plan.

Batch lookup by semantic surface or owning module/contract and reuse collected
evidence across the session. Allow one narrow follow-up only for an unresolved
material contradiction or blocker; never reopen search for wording, harmless
uncertainty, or one symbol at a time.

### 3. Working Map and Decision Loop

Persist `.factory/memory/staging/planning-session.md` using the working session
contract. It records facts, decisions, open branches, contradictions, handling,
and answer impact without revision or approval metadata.

Without delegated planning, ask dependent decisions one at a time with
recommended answer and concrete impact. A small batch is allowed only for
independent decisions. With delegated planning, resolve each `ASK` using source
goals, verified evidence, established project patterns, the smallest reversible
choice, and safe defaults; record it as AI-delegated instead of asking. After
every answer or delegated choice, run an impact scan against source facts,
earlier decisions, scope, behavior, solution boundary, contracts, readiness,
QA, and handoff. Newly revealed branches remain in the same session; do not
consume a plan revision.

Discovery ends only when every material branch is resolved or explicitly
handled and no contradiction blocks an honest ready plan. There is no fixed
question count. Record provenance of user-confirmed, defaulted, and explicitly
AI-delegated choices in the working session. Delegation may settle behavior,
UI, app-owned API/architecture, and scope choices inside requested outcome. It
cannot fabricate external/backend facts, credentials, legal/compliance or
security approval, or authorize weaker protection; such inputs remain `BLOCK`.

### 4. Candidate and Preflight

Start canonical `architect` only after discovery exit criteria hold. Pass the
bounded handoff defined above; its persona loads plan policy, full architecture
sources, and the resolved working map. If runtime cannot spawn, orchestrator
follows the same contracts inline.

A complete source-locked map uses one Architect fast path: no repeated Reality
Check or source search. Reopen discovery only for missing evidence or an actual
contradiction. Explicit Architect failure may continue the same candidate
inline; never run a second writer concurrently.

Apply [the planning gate](../../gates/skills/planning/gate.md) at this step; complete all checks before continuing.

### 5. Promote and Present Revision

Render complete candidate first. For first promoted revision run:

```bash
sh .factory/tooling/bin/python.sh "$PWD/.factory/gates/skills/planning/validate_plan.py" \
  --plan .factory/memory/staging/planning-plan.md.candidate --phase draft
```

For every later promoted revision or nonsemantic correction, compare the
candidate with the last user-reviewable target:

```bash
sh .factory/tooling/bin/python.sh "$PWD/.factory/gates/skills/planning/validate_plan.py" \
  --plan .factory/memory/staging/planning-plan.md.candidate \
  --previous .factory/memory/staging/planning-plan.md --phase draft
```

Only after successful validation atomically replace `planning-plan.md` with the
candidate. In normal mode, present it for approval. In delegated planning mode,
continue immediately through delegated approval below. Never validate a newly
replaced live target.

Present full plan when practical, otherwise first three sections, unresolved
external items, readiness, handoff advice, revision, and clickable path. First
promoted reviewable plan is `revision: 1`; earlier answers and candidate
rewrites are not revisions. In normal mode say:

```text
The plan launches nothing. Awaiting a decision on revision N.
```

Allowed actions: `Confirm revision N`, `Change`, `Cancel`. Silence,
earlier question answers, and agreement with one decision do not approve whole
plan. Delegated planning is different: exact directive was captured at intake
as advance authorization to settle and approve a preflight-clean revision.

### 6. Revision and Approval
After a revision has been promoted, behavior, scope, outcome, solution shape,
decision, contract gist, boundary, readiness, verification, or handoff
recommendation change is semantic: increment revision, set `status: draft`, and
set `approved_revision: none`. Before first presentation, the same internal
changes stay inside session/candidate and do not consume revision. Formatting,
spelling, URL normalization, and machine-only repair without changed meaning
keep revision. Coordinator owns semantic classification. For confirmed formatting
repair use `--change-kind nonsemantic --change-evidence "{specific rationale}"`.

After exact approval of current `PLAN_READY` revision, or after a delegated
planning revision passes preflight with its exact authorization recorded under
`Source and context`, create approval-only candidate with `status: approved`
and matching `approved_revision`, then run:

```bash
sh .factory/tooling/bin/python.sh "$PWD/.factory/gates/skills/planning/validate_plan.py" \
  --plan .factory/memory/staging/planning-plan.md.candidate \
  --previous .factory/memory/staging/planning-plan.md --phase approved
```

The approval candidate must differ only in approval metadata. After successful
transition validation, atomically replace the staging target, then promote the
same validated snapshot transactionally to `docs/plans/{plan_id}.md`. Keep the
single canonical path. Follow plan contract's Git-preservation and authorized
requirements-change gate; parent alone publishes. No revision files. Existing
runs keep pinned bytes/revision/hash and handle drift. Delegation authorizes bounded
choices; never report it as review of exact revision text.

### 7. Handoff

`handoff_recommendation: direct | decompose | either` is advice, not user
authorization. Explain recommendation:

- `direct`: approved plan is bounded enough for execution;
- `decompose`: capability map benefits from ticket slicing, estimates, and
  dependencies;
- `either`: both paths are reasonable and trade-off is explicit.

Without pre-authorized continuation, ask user to choose next action. Factory Planning
itself does not launch downstream. If original request explicitly included
implementation or decomposition and delegated planning decisions, return the
approved plan plus that continuation intent to parent orchestrator; parent may
start the requested downstream skill without another checkpoint. If user chose
direct despite `decompose`, pass approved plan to `factory-implement` with size/risk
warning; do not hard-block. If chosen, `factory-decompose` maps `CAP-*` to tickets
without changing approved semantics.

## Stop Conditions

- Material decision remains without delegated planning: preserve session and
  return `NEEDS_USER_DECISION`; do not replace or present a plan revision.
- Required fact remains unavailable: preserve session and return
  `BLOCKED_REQUIREMENTS`; do not create an incomplete plan revision.
- Source contradiction or unavailable required fact: preserve checkpoint and
  report blocker.
- Cancel: stop and report retained staging path; perform no destructive cleanup.

## Optional execution sketch
Parent may prepare `.factory/memory/staging/<plan-id>.workflow.json` and Mermaid
sequenceDiagram using factory configuration and orchestration policy. Bind sketch
to revision/hash outside plan. It grants no implementation authorization;
planning-only stops here. Implement revalidates before authorized execution.

**Gate ownership.** Planning owns its artifact gate: validate the plan and resolve material semantic gaps before the existing approval/publication step. Project rules add requirements; command gates for Implement do not replace this gate.

Before final approved-plan handoff, complete planning.complete under
[the Planning gate](../../gates/skills/planning/gate.md). Machine preflight alone
is not review or user approval; record actual coordinator review and approval
evidence and run the validator with --completion-review. Never fabricate either.
