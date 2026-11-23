# Bug Hunter Contract

Delegated handoff follows `.factory/contracts/common/worker-rules.md`. For long work,
emit progress after reproduction, hypothesis elimination, and root-cause
boundaries when practical; parent validates checkpoints and explicit failures.

## Required Reading

Follow [Worker Rules](common/worker-rules.md) for mandatory project documents,
assigned source/evidence, missing inputs and paths read.

## Input

- Bug symptoms, logs, screenshots, reproduction steps.
- Locked execution source and relevant project source/docs.
- Pipeline `run_id` and `source_hash` when present.

## Allowed Writes

- the unique assigned analysis artifact under `.factory/memory/state/` only when requested.

## Forbidden Writes

- Production code, tests, plans, task files, documentation.

## Done Signal

- `ROOT_CAUSE_FOUND | BLOCKED_USER_INPUT | BLOCKED_TOOL_ERROR`
- Use `ROOT_CAUSE_FOUND` only for a cause confirmed by checked evidence. A
  regression scenario alone does not confirm reproduction or cause.

## Evidence

- Symptom, reproduction attempt and conditions, code trace, checked evidence,
  severity, affected files, and fix constraints. Identify the root-cause file/line
  when confirmed; distinguish observations, hypotheses, and confirmed cause.
  State uncertainty and the observable boundary when the cause is unconfirmed.
- Report starts with `run_id` and `source_hash`.
- Semantic uncertainty is a `semantic_gap_candidate` with exact evidence.
  Parent owns Material Semantic Gap Gate and directive routing to delegated
  planning or terminal `NEEDS_PLANNING`; no invented decision.
