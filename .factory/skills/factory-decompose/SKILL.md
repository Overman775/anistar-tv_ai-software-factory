---
name: factory-decompose
description: "Use when Codex must split an approved Factory Planning plan into reviewed, human-readable project tasks with estimates and dependencies. Triggers: factory-decompose, split approved plan, create project tasks, estimates and dependencies, decompose approved plan, split the plan into tasks, task list. Raw requirements and semantic planning belong to factory-planning; implementation belongs to factory-implement; publication requires an explicit user request."
---

Read [communication rules](../../contracts/common/communication.md) for messages and artifact language.

# Factory Plan Decomposition

Read `.factory/contracts/common/project-policy.md`. Before dependent work, resolve
project inputs with `sh .factory/tools/python.sh .factory/tools/project.py context --process decompose --audience coordinator`
(add `--scope PATH` for every known scope path). Read the returned instructions and
actual applicable documents. Unknown scope retains obligations; it never waives them.


## Acceptance contract

Read [the shared acceptance contract](../../gates/common/verification-rules.md).
Carry stable AC IDs through source → tasks → required checks → results.
Acceptance criteria do not replace mandatory project gates or limit additional
risk-based checks. Preserve the skill's existing semantic and authorization boundaries.

## Language

Write task and epic prose in the task/project language, otherwise the dialogue
language. Preserve technical identity, exact template headings and machine values.
One final wording pass only: no language ratio, glossary, or code lookup.

## Boundary

FactoryDecompose converts one approved semantic plan into executable task files.
It does not discover requirements, choose behavior, design architecture, ask
semantic questions, revise plan content, or approve a second plan.

- `factory-planning` owns goal, scope, behavior, solution shape, decisions,
  contracts, risks, QA boundary, plan revision, and human approval.
- `factory-decompose` owns task IDs, vertical slices, purpose, owning scope,
  affected layers, estimates, dependencies, blockers, deferred allocation,
  task Markdown, and review.
- `factory-implement` executes either an approved plan directly or a self-contained
  task.

Raw BRD/specification/request without an approved Factory Planning plan returns
`NEEDS_PLANNING`. A semantic gap found during slicing also returns
`NEEDS_PLANNING`; never repair the plan inside this skill.

## Required Input

Accept an explicit approved plan path, normally `docs/plans/{plan_id}.md`.
Validate it with:

```bash
sh .factory/tools/python.sh .factory/gates/skills/planning/validate_plan.py \
  --plan docs/plans/{plan_id}.md --phase approved
```

Require:

- readable canonical plan;
- `status: approved`;
- numeric `revision` and `approved_revision == revision`;
- stable `plan_id`; FactoryDecompose computes and locks plan content hash at intake;
- no unresolved semantic blocker;
- at least one stable capability ID (`CAP-*`) or one clearly bounded global
  outcome.

For an already approved plan, successful `--phase approved` validation plus
existing approval evidence satisfies intake. A nested `planning.complete` BLOCKED
solely because no current completion-review was supplied does not request a new
approval. Do not treat `ok: true` alone as approval or invent provenance; apply
the existing canonical/external approval-evidence rules.

Invalid or unapproved input returns `BLOCKED_NO_APPROVED_PLAN`. Raw input or a
missing semantic decision returns `NEEDS_PLANNING` with evidence and affected
capabilities.

Approved plan is immutable. FactoryDecompose never writes `docs/plans/`.

## Team

Main session is orchestrator. Read active runtime adapter, then use:

- `task-decomposer`: creates complete vertical task map and task files;
- `task-reviewer`: reviews and repairs decomposition without changing plan
  semantics.

Build worker context with `sh .factory/tools/python.sh .factory/tools/context.py --process decompose --role ROLE --profile PROFILE ASSIGNMENT.json`. Include source, exact allowed staging paths, expected output and project read paths; deliver the full packet. For the decomposer, authorize temporary siblings of its assigned staging files and its checkpoint under `.factory/memory/staging/checkpoints/`.

Before either spawn, read `.factory/contracts/common/agent-checkpoint.md`. Validate
initial generation, metadata fast-fix, review, and repair handoffs equally;
fast-fix is not exempt because its scope is small.

No `task-decomposition-planner`. No Architect. No pre-plan staging files.

Canonical personas:

- `.factory/roles/task-decomposer.md`
- `.factory/roles/task-reviewer.md`

Both roles read selected project profile documents in full where required, plus
actual affected specifications, ADRs and package READMEs. The profile supplies the
layer vocabulary and task size limit; vertical behavior stays the unit of work.

Resolve profiles/adapters from `.factory/factory.yaml`; load the configured
adapter and pass role instructions/capabilities to generic agents. No native
role files are created. Decompose keeps its own state, not Implement packet/claim.

### Agent checkpoints

Keep waiting for `task-decomposer` and `task-reviewer` Done Signals. Progress
and checkpoints improve visibility; silence, poll timeouts, elapsed time,
generic `running` status, and missing runtime operations are not role failure.
Do not automatically interrupt a live writer. Never run two writers against
the same staging tree.

On explicit terminal failure or invalid returned handoff, preserve source lock
and last valid transactional checkpoint, then retry the same role once with only
unfinished work. Recovery does not consume graph fast-fix or reviewer repair
iteration. A second explicit failure returns `BLOCKED_AGENT_FAILURE` with
resumable checkpoint details; it never becomes `NEEDS_PLANNING`.

FactoryDecompose identity is `plan_id + revision + plan_hash + canonical role`; lock
is approved-plan path plus tuple. Transactional checkpoint is continuation
evidence, not identity. Apply
`.factory/contracts/common/agent-checkpoint.md#same-run-role-continuation` only to
one decomposer graph fast-fix before Graph Gate `PASS`, or reviewer repair plus focused recheck.
Terminalize at those boundaries; new approved revision uses fresh roles and full
decomposition rerun.

## Workflow

### 1. Intake and source lock

1. Resolve explicit approved plan.
2. Run approved-plan validation.
3. Record `plan_id`, revision, source path, normalized plan hash, and declared
   `CAP-*` IDs and `project_policy_sha256` from the resolved profile context, using
   generation-contract source-lock schema in
   `.factory/memory/staging/decomposition-source.json`.
4. If plan changed after lock, stop with `SOURCE_DRIFT` and restart intake.

When an input references an approved plan, resolve the plan artifact; do not
treat the reference text as a second semantic source.

### 2. Decompose

Start one `task-decomposer` for complete plan. It maps capabilities to vertical
tasks and writes:

- `.factory/memory/staging/tasks/{scope}/task_result.json` — internal staging
  envelope;
- `.factory/memory/staging/tasks/{scope}/*.md` — human-readable task drafts.

Follow [generation contract](references/generation-contract.md) for the handoff
and envelope. Canonical `task-decomposer` persona owns policy, template,
implementation-detail, and architecture-source loading. Pass only run identity,
approved plan, source lock, and resumable checkpoint; do not copy its rules into
the spawn prompt.

### 3. Deterministic graph gate

Apply [the decompose gate](../../gates/skills/decompose/gate.md) at this step; complete all checks before continuing.

### 4. Review

Create a coordinator-owned review request with the gate assembler; see
[review contract](../../gates/skills/decompose/review-contract.md).
Start `task-reviewer` after graph preflight. Reviewer compares every task with the
approved plan, task template, and implementation detail contract. Allow one
repair pass followed by one focused recheck. Recheck does not start new
discovery.

Reviewer may repair wording, missing copied constraints, formatting,
affected-layer guidance, safe filenames, and internal-envelope consistency.
Reviewer may not change behavior, scope meaning, solution decision,
capability coverage, or acceptance semantics.

Pass the exact permitted staging task Markdown and `task_result.json` paths to
TaskReviewer. Its editable profile permits only that bounded repair; application
code, approved plan, source lock and final published tasks remain read-only.

After a repair, rerun deterministic graph preflight and prepare a new request
bound to the final bytes before focused semantic recheck.

Semantic gap uses exact envelope from generation contract. Stop, preserve last
complete staging checkpoint, and route to `factory-planning`. A new approved plan
revision requires full decomposition rerun.

### 5. Assemble

Use the assembler from [output contract](references/output-contract.md); manual
copying cannot substitute for decompose.complete. Final task files are
human-readable Markdown only. Do not embed staging schema, JSON task object,
technical machine contract, or execution plan.

- More than one task: `docs/tasks/{bundle_id}/*.md` plus `epic.md` inside that bundle.
- Exactly one task: `docs/tasks/{bundle_id}/{filename}.md` without an epic.

Every task visibly includes source-plan provenance, goal/outcome, scope,
implemented/deferred boundaries, architecture constraints, acceptance,
developer checks, separate QA checklist, estimate, dependencies, and blockers.

## Quality Invariants

Canonical personas enforce [decomposition policy](references/decomposition-policy.md):

- complete `CAP-*` coverage and vertical, independently verifiable slices;
- bounded, verifiable tasks; project-specific size constraints come from rules and gates;
- architecture constraints from approved plan and both canonical project docs;
- separate developer acceptance and QA checks;
- bounded current-code grounding without invented symbols or semantic changes.

The deterministic gate owns syntax and graph validity. Reviewer owns semantic
and architecture quality. Passing one never replaces the other.

## Approval and Handoff

Factory Planning approval authorizes semantic content. FactoryDecompose does not ask the
user to approve another plan revision. It presents reviewed task files as its
result; user may request edits before publication.

FactoryDecompose never publishes tasks and never starts Factory Implement. Separate
handoffs:

- local task Markdown -> `factory-implement`;
- reviewed `docs/tasks/` -> publication only on an explicit user request;
- semantic gap -> `factory-planning`.

## Transactional Staging

Follow [transactional staging](references/generation-contract.md#transactional-staging).

## Final Report

```text
FactoryDecompose completed.
Source plan: {plan_id} revision {N}
Tasks: {count}
Estimate: {min}–{max} h
Graph: PASS
Review: APPROVE | NEEDS_WORK
Files: {paths}
Next: inspect | publish | execute
```

## Dynamic implementation handoff

Task IDs, vertical slices, CAP coverage, dependencies and required deferred work
feed the implementation workflow. Do not hard-code backend/frontend agents into
tasks. Implement chooses staffing inside each slice, accepts predecessor slices
before dependents, and verifies the combined feature. Use configured profiles
from `.factory/factory.yaml` for the decomposer/reviewer too; adapters read model
settings there. Decomposition approval never authorizes implementation by itself.

Acceptance closure and contribution are separate. Use generation contract's
`acceptance_ids`, `contributes_to_acceptance_ids`, and `local_acceptance_criteria`;
accept functional producers locally while dependent closer verifies full parent AC.
Source lock pins exact approved bytes with `plan_content_hash`; record `plan_commit`
when available. Canonical replacement requires authorized re-intake, never silent adoption.

## Gate ownership

Decompose owns its artifact gate: validate dependencies, acceptance coverage and publication conditions with the existing graph validator. Project parameters supplement that contract; no Implement stage or command receipt substitutes for it.
