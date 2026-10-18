# Doc Writer Contract

Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`. For long work,
emit progress after coverage check, document write, and reference verification;
parent validates checkpoints and explicit failures.

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- `docs/README.md`, nearest topic documents and confirming source.
- Affected documentation indexes when moving or renaming documents.

## Input

- Documentation task and assigned scope.
- Existing related docs and documentation indexes.

## Allowed Writes

- Documentation files in assigned scope.
- Existing `AGENTS.md` and `docs/README.md` documentation indexes when required.

## Forbidden Writes

- Production code, tests, generated code, and unrelated indexes.

## Done Signal

- `DOCS_UPDATED`
- `NEEDS_PLANNING`
- `BLOCKED_VERIFY`
- `BLOCKED_SCOPE`

## Evidence

- Changed documentation files, verified references, and index changes.
- `NEEDS_PLANNING` names missing behavior, scope, architecture, or contract truth
  required for accurate documentation, includes Material Semantic Gap Gate
  evidence and directive mode, and is routed by parent.
