# Code Explorer Contract

Delegated handoff follows `.factory/contracts/common/worker-rules.md`.

## Required Reading

Follow [Worker Rules](common/worker-rules.md) for mandatory project documents,
assigned source/evidence, missing inputs and paths read.

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
- Location search returns verified paths, symbols and brief relevance with file/line
  evidence. A cross-module failure investigation traces the call chain to the
  observable effect or the exact boundary of available evidence. Other investigations
  include the entry points, flow and findings needed to answer the question.
- Any unresolved semantic choice is reported as `semantic_gap_candidate` with
  exact evidence and alternatives. Parent owns Material Semantic Gap Gate and
  directive routing to delegated planning or terminal `NEEDS_PLANNING`;
  explorer invents no solution.
