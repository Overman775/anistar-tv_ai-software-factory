# Bug Hunter Contract

Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`. For long work,
emit progress after reproduction, hypothesis elimination, and root-cause
boundaries when practical; parent validates checkpoints and explicit failures.

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- Affected specification selected through `docs/specs/README.md`, owning package
  README when present, and diagnostics in `docs/05_development_and_testing.md`.
- `docs/04_network_and_playback.md` for network/playback causes;
  `infrastructure/app_logging/README.md` for logging causes.
- Relevant ADRs selected through `docs/adr/README.md` for suspected contract failures.

## Input

- Bug symptoms, logs, screenshots, reproduction steps.
- Locked execution source and relevant project source/docs.
- Pipeline `run_id` and `source_hash` when present.

## Allowed Writes

- `.ai-pipeline/state/analysis.md` only when requested.

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
