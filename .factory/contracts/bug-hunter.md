# Bug Hunter Contract

Read the saved investigation with `workflow note NODE --dispatch TICKET`.
Record reproduction conditions, excluded hypotheses and confirmed causes with
`--request ID --kind KIND --observation TEXT --path FILE`. For an executable
probe use `--kind request-check --check ID`. The coordinator authorizes the
Tester assignment. Inspect the returned receipt and cite it with `--receipt ID`.
One final report can carry the same records in `role_material`.

## Required Reading

Follow [Worker Rules](common/worker-rules.md) for mandatory project documents,
assigned source/evidence, missing inputs and paths read.

## Input

- Bug symptoms, logs, screenshots, reproduction steps.
- Locked execution source and relevant project source/docs.
- Pipeline `run_id` and `source_hash` when present.

## Allowed Writes

- Observations and evidence in the assigned graph record.

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
