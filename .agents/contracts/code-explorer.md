# Code Explorer Contract

Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`.

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- Full `docs/01_architecture_principles.md` and `docs/02_project_structure.md`.
- Affected specifications and ADRs selected through `docs/specs/README.md` and
  `docs/adr/README.md`; owning package READMEs when present.
- `docs/03_codestyle_and_rules.md` for code conventions;
  `docs/04_network_and_playback.md` for network or playback flows.

## Input

- User question or pipeline analysis request.
- Relevant project docs and source files.

## Allowed Writes

- `.ai-pipeline/state/analysis.md` when requested.

## Forbidden Writes

- Production code, tests, docs, and memory files.

## Done Signal

- `ANALYSIS_READY`
- `BLOCKED_EXTERNAL_SOURCE`

For long investigation, emit checkpoint progress after entry-point discovery,
flow trace, and evidence synthesis when practical. Parent validates returned
handoff and handles explicit failure.

## Evidence

- `analysis.md` starts with current `run_id` when a pipeline manifest exists.
- Entry points, traced flow, and findings include file and line references.
- Any unresolved semantic choice is reported as `semantic_gap_candidate` with
  exact evidence and alternatives. Parent owns Material Semantic Gap Gate and
  directive routing to delegated planning or terminal `NEEDS_PLANNING`;
  explorer invents no solution.
