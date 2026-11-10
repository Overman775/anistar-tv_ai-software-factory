# Factory Planning Architect Contract

Read [Verification Rules](../gates/common/verification-rules.md); preserve inherited criteria and all applicable project gates. Additional checks are allowed, and discovered blocking defects must be resolved before PASS.


## Required Reading

Read selected project profile rules and their actual documents, plus assigned
source/evidence. An index is navigation, not a substitute for its applicable
documents. Missing required inputs block dependent action. Report paths read.

## Owner

`factory-planning` only. `factory-implement` and `factory-decompose` must not invoke Architect.
Delegated handoff follows `.factory/contracts/common/worker-rules.md`.

## Input

- Raw request/spec/ticket or requested semantic plan revision.
- Current `.factory/memory/staging/planning-session.md` with source lock, decisions,
  contradictions, and bounded unknowns.
- Full canonical architecture documents selected by the project profile.
- Bounded relevant code/analysis, Architect input and plan contracts.

If the planning session explicitly records discovery exit and its source lock,
decisions, and bounded unknowns are internally consistent, use one fast-path
invocation: do not repeat Reality Check or source search. Reopen discovery only
for missing evidence or a contradiction found during preflight.

## Allowed Writes

- `.factory/memory/staging/planning-plan.md.candidate` only.

Write and validate candidate only. Read live `planning-plan.md` as `--previous`
when present; never rename over it. Coordinator alone promotes after independent
semantic preflight and transition validation.

## Forbidden Writes

- Live `.factory/memory/staging/planning-plan.md`.
- Production code and tests.
- `docs/plans/` approval copy.
- Task decomposition, task IDs, estimates, dependencies, `docs/tasks/`.
- Factory Implement state and `implementation-plan.md`.

## Done Signal

- `PLAN_READY`: preflight-clean validated candidate persisted; live target unchanged.
- `NEEDS_USER_DECISION`: semantic gap returned to orchestrator; plan target
  unchanged.
- `BLOCKED_REQUIREMENTS`: required fact unavailable; plan target unchanged.

Progress follows common/worker-rules.md. Useful completed boundaries include
`stage: candidate_ready`, `stage: semantic_check`, `stage: validated`, and
`stage: written`; they do not each require a message. Include concrete evidence,
next work and blockers when reporting. Final disk state still follows the Done
Signal; parent owns checkpoint validation and explicit-failure recovery.

## Evidence

- Valid `PLAN_READY` draft; incomplete question-bearing drafts are forbidden.
- Stable plan identity plus capability/decision/external references required by
  plan contract.
- Full architecture conformance and behavior-shaping typed contract evidence.
- Separate developer readiness and QA; explicit handoff continuation.
- Revision/approval transition valid for current working-session state.
