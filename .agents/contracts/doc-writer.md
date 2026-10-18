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
- `docs/templates/README.md` and the matching template when creating a guide,
  ADR, specification, intent, or README, or changing its structure.

## Input

- Documentation task and assigned scope.
- Existing related docs and documentation indexes.

## Allowed Writes

- Documentation files in assigned scope.
- Existing `AGENTS.md` and `docs/README.md` documentation indexes when required.

## Forbidden Writes

- Production code, tests, generated code, and unrelated indexes.

## Completion Checks

Before `DOCS_UPDATED`:

- Apply the self-contained ASD-STE100-inspired rules in `.agents/agents/doc-writer.md`.
- Follow the applicable project template. Remove unused sections and authoring
  placeholders. Keep explicit open questions in an intent when unresolved.
- Compare changed claims with source. Preserve actors, conditions, exceptions, obligation, uncertainty, numbers and units.
- Verify commands, examples, links and affected index entries. Resolve draft `[VERIFY]` markers before success.
- Checking documented commands does not authorize executing them. Follow task permissions for tests, live calls and generated updates.
- Apply language-appropriate rules. Do not translate Russian text or claim certified STE compliance.
- Review meaning manually. An optional skill or linter is not required and cannot replace this review.

If source truth cannot be verified, use `BLOCKED_VERIFY`. Route material semantic
gaps through the existing `NEEDS_PLANNING` rules. Do not invent missing facts.

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
