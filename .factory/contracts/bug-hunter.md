# Bug Hunter Contract

Delegated handoff follows `.factory/contracts/common/worker-rules.md`. For long work,
emit progress after reproduction, hypothesis elimination, and root-cause
boundaries when practical; parent validates checkpoints and explicit failures.

## Required Reading

Read selected project profile rules and their actual documents, plus assigned
source/evidence. An index is navigation, not a substitute for its applicable
documents. Missing required inputs block dependent action. Report paths read.

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

## Evidence

- Exact reproduction path, root-cause file/line, code trace, severity, and fix
  constraints.
- Report starts with `run_id` and `source_hash`.
- Semantic uncertainty is a `semantic_gap_candidate` with exact evidence.
  Parent owns Material Semantic Gap Gate and directive routing to delegated
  planning or terminal `NEEDS_PLANNING`; no invented decision.
