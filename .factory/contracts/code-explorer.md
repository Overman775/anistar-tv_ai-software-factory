# Code Explorer Contract

Delegated handoff follows `.factory/contracts/common/worker-rules.md`.

## Required Reading

Read selected project profile rules and their actual documents, plus assigned
source/evidence. An index is navigation, not a substitute for its applicable
documents. Missing required inputs block dependent action. Report paths read.

## Input

- User question or pipeline analysis request.
- Relevant project docs and source files.

## Allowed Writes

- the unique assigned analysis artifact under `.factory/memory/state/` when requested.

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
- Location search returns verified sites and relevance; investigation adds applicable
  entry points, traced flow and findings with file/line evidence.
- Any unresolved semantic choice is reported as `semantic_gap_candidate` with
  exact evidence and alternatives. Parent owns Material Semantic Gap Gate and
  directive routing to delegated planning or terminal `NEEDS_PLANNING`;
  explorer invents no solution.
