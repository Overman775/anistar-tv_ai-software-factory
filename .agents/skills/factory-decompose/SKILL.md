---
name: factory-decompose
description: "Use when Codex must split an approved Factory Planning plan into reviewed, human-readable AniStar TV tasks with estimates and dependencies. Triggers: factory-decompose, split approved plan, create AniStar TV tasks, estimates and dependencies, декомпоз approved plan, нарежь план на задачи, список задач. Raw requirements and semantic planning belong to factory-planning; implementation belongs to factory-implement; publication requires an explicit user request."
---

# Factory Plan Decomposition

## Language

Write task and epic prose in Russian unless user asks otherwise. Keep English
only for exact identifiers, machine values, paths, commands, API, product names,
and established abbreviations; write ordinary terms and surrounding grammar in
Russian. If translation preserves technical identity, translate: `owner` ->
«владелец», `request/response` -> «запрос/ответ», `success/failure` ->
«успех/ошибка», `dirty outcome` -> «результат с изменениями». One final wording
pass only: no language ratio, glossary, or code lookup.

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
python3 .agents/skills/factory-planning/scripts/validate_plan.py \
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

Invalid or unapproved input returns `BLOCKED_NO_APPROVED_PLAN`. Raw input or a
missing semantic decision returns `NEEDS_PLANNING` with evidence and affected
capabilities.

Approved plan is immutable. FactoryDecompose never writes `docs/plans/`.

## Team

Main session is orchestrator. Read active runtime adapter, then use:

- `task-decomposer`: creates complete vertical task map and task files;
- `task-reviewer`: reviews and repairs decomposition without changing plan
  semantics.

Before either spawn, read `.agents/contracts/common/agent-checkpoint.md`. Validate
initial generation, metadata fast-fix, review, and repair handoffs equally;
fast-fix is not exempt because its scope is small.

No `task-decomposition-planner`. No Architect. No pre-plan staging files.

Canonical personas:

- `.agents/agents/task-decomposer.md`
- `.agents/agents/task-reviewer.md`

Both roles read full `docs/01_architecture_principles.md` and
`docs/02_project_structure.md`, plus `PRODUCT.md` and
`docs/05_development_and_testing.md`. Select affected specifications through
`docs/specs/README.md`, decisions through `docs/adr/README.md`, and owning
package READMEs through `docs/README.md`. Pass concrete paths to both roles. Architecture is a quality gate, not an optional
context optimization. Bounded lookup limits apply to feature-code exploration,
not to these canonical architecture sources.

Runtime adapters live under `.codex/agents/` and `.claude/agents/`.

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
`.agents/contracts/common/agent-checkpoint.md#same-run-role-continuation` only to
one decomposer graph fast-fix before Graph Gate `PASS`, or reviewer repair plus focused recheck.
Terminalize at those boundaries; new approved revision uses fresh roles and full
decomposition rerun.

## Workflow

### 1. Intake and source lock

1. Resolve explicit approved plan.
2. Run approved-plan validation.
3. Record `plan_id`, revision, source path, normalized plan hash, and declared
   `CAP-*` IDs using generation-contract source-lock schema in
   `.ai-pipeline/staging/decomposition-source.json`.
4. If plan changed after lock, stop with `SOURCE_DRIFT` and restart intake.

When an input references an approved plan, resolve the plan artifact; do not
treat the reference text as a second semantic source.

### 2. Decompose

Start one `task-decomposer` for complete plan. It maps capabilities to vertical
tasks and writes:

- `.ai-pipeline/staging/tasks/{scope}/task_result.json` — internal staging
  envelope;
- `.ai-pipeline/staging/tasks/{scope}/*.md` — human-readable task drafts.

Follow [generation contract](references/generation-contract.md) for the handoff
and envelope. Canonical `task-decomposer` persona owns policy, template,
implementation-detail, and architecture-source loading. Pass only run identity,
approved plan, source lock, and resumable checkpoint; do not copy its rules into
the spawn prompt.

### 3. Deterministic graph gate

```bash
python3 .agents/skills/factory-decompose/scripts/generate_task_graph.py \
  --staging-dir .ai-pipeline/staging/tasks/ \
  --source-lock .ai-pipeline/staging/decomposition-source.json \
  --output .ai-pipeline/staging/mermaid_graph.txt
```

Any reported source, coverage, schema, Markdown, identity, dependency,
deferred, estimate, or cycle violation blocks graph and assembly. Deterministic
errors return to decomposer for one fast-fix pass, then the complete gate reruns.
They do not invoke planning or require user approval.

### 4. Review

Start `task-reviewer` after graph gate. Reviewer compares every task with the
approved plan, task template, and implementation detail contract. Allow one
repair pass followed by one focused recheck. Recheck does not start new
discovery.

Reviewer may repair wording, missing copied constraints, formatting,
affected-layer guidance, safe filenames, and internal-envelope consistency.
Reviewer may not change behavior, scope meaning, solution decision,
capability coverage, or acceptance semantics.

After a repair, rerun deterministic graph gate before focused semantic recheck.

Semantic gap uses exact envelope from generation contract. Stop, preserve last
complete staging checkpoint, and route to `factory-planning`. A new approved plan
revision requires full decomposition rerun.

### 5. Assemble

Follow [output contract](references/output-contract.md). Final task files are
human-readable Markdown only. Do not embed staging schema, JSON task object,
technical machine contract, or execution plan.

- More than one task: `docs/tasks/{publication_id}/*.md` plus
  `docs/tasks/epic_{publication_id}.md` publication manifest.
- Exactly one task: `docs/tasks/{scope}/{filename}.md`.

Every task visibly includes source-plan provenance, goal/outcome, scope,
implemented/deferred boundaries, architecture constraints, acceptance,
developer checks, separate QA checklist, estimate, dependencies, and blockers.

## Quality Invariants

Canonical personas enforce [decomposition policy](references/decomposition-policy.md):

- complete `CAP-*` coverage and vertical, independently verifiable slices;
- target about 8 hours, hard maximum 16 hours;
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

Write internal envelopes and drafts through temporary sibling paths, validate,
then atomically rename. Keep last complete checkpoint under
`.ai-pipeline/staging/checkpoints/`. Interrupt or failed retry must not delete
last valid draft. Cleanup may remove only artifacts owned by current run after
final assembly succeeds.

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
