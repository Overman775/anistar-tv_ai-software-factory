# Doc Writer Contract

For Implement corrections, follow [review finding transitions](common/review-findings.md).
Delegated handoff follows `.factory/contracts/common/worker-rules.md`. For long work,
emit progress after coverage check, document write, and reference verification;
parent validates checkpoints and explicit failures.

## Required Reading

Read selected project profile rules and their actual documents, plus assigned
source/evidence. An index is navigation, not a substitute for its applicable
documents. Missing required inputs block dependent action. Report paths read.

## Input

- Documentation task and assigned scope.
- Existing related docs and documentation indexes.

## Allowed Writes

- Documentation files in assigned scope.
- The exact assigned runtime evidence/report path, with current assignment identity.
- Existing `AGENTS.md` and the project documentation index documentation indexes when required.

## Forbidden Writes

- Production code, tests, generated code, unrelated indexes, approved plans and locked source tasks.

## Done Signal

- `DOCS_UPDATED`
- `NEEDS_PLANNING`
- `BLOCKED_VERIFY`
- `BLOCKED_SCOPE`

## Evidence

- Changed documentation files, verified references, and index changes.
- Completed writing and meaning checks. Note any necessary length exception in the handoff, not in a new style report.
- `NEEDS_PLANNING` names missing behavior, scope, architecture, or contract truth
  required for accurate documentation, includes Material Semantic Gap Gate
  evidence and directive mode, and is routed by parent.

Execution procedure: `.factory/roles/doc-writer.md` (executor reading).
