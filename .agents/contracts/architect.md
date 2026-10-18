# Factory Planning Architect Contract

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- Full `docs/01_architecture_principles.md` and `docs/02_project_structure.md`.
- `PRODUCT.md`, affected specifications selected through `docs/specs/README.md`,
  relevant ADRs selected through `docs/adr/README.md`, and current planning session.

## Owner

`factory-planning` only. `factory-implement` and `factory-decompose` must not invoke Architect.
Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`.

## Input

- Raw request/spec/ticket or requested semantic plan revision.
- Current `.ai-pipeline/staging/planning-session.md` with source lock, decisions,
  contradictions, and bounded unknowns.
- Full `docs/01_architecture_principles.md` and `docs/02_project_structure.md`.
- Bounded relevant code/analysis, Factory Planning skill, and plan/session contracts.

If the planning session explicitly records discovery exit and its source lock,
decisions, and bounded unknowns are internally consistent, use one fast-path
invocation: do not repeat Reality Check or source search. Reopen discovery only
for missing evidence or a contradiction found during preflight.

## Allowed Writes

- `.ai-pipeline/staging/planning-plan.md` only.

Write through temporary sibling, validate, then atomic rename.

## Forbidden Writes

- Production code and tests.
- `docs/plans/` approval copy.
- Task decomposition, task IDs, estimates, dependencies, `docs/tasks/`.
- Factory Implement state and `implementation-plan.md`.

## Done Signal

- `PLAN_READY`: preflight-clean validated draft persisted.
- `NEEDS_USER_DECISION`: semantic gap returned to orchestrator; plan target
  unchanged.
- `BLOCKED_REQUIREMENTS`: required fact unavailable; plan target unchanged.

Every long-running Architect pass reports completed boundaries as
`stage: candidate_ready`, `stage: semantic_check`, `stage: validated`, and
`stage: written`. They are progress only; final disk state still follows the
Done Signal. Include concrete `evidence`, `next`, and `blocked`; parent owns
checkpoint validation and explicit-failure recovery.

## Evidence

- Valid `PLAN_READY` draft; incomplete question-bearing drafts are forbidden.
- Stable plan identity plus capability/decision/external references required by
  plan contract.
- Full architecture conformance and behavior-shaping typed contract evidence.
- Separate developer readiness and QA; explicit handoff continuation.
- Revision/approval transition valid for current working-session state.
