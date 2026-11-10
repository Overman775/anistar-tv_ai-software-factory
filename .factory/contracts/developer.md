# Developer Contract

For Implement corrections, follow [review finding transitions](common/review-findings.md).
Apply [Verification Rules](../gates/common/verification-rules.md).


Delegated handoff follows `.factory/contracts/common/worker-rules.md`. For long work,
emit progress after target inspection, production write, and verification
boundaries when practical; parent validates checkpoints and explicit failures.

## Required Reading

Follow [Worker Rules](common/worker-rules.md) for mandatory project documents,
assigned source/evidence, missing inputs and paths read.

## Input

- Locked execution source: self-contained request/ticket/task or approved plan.
- the supplied task-scoped assignment and optional task-scoped execution brief.
- Changed-file scope.
- Current correction evidence during a delegated fix pass.

## Allowed Writes

- Production files inside source boundary.
- Required generated files for touched package.
- Small directly affected documentation/specification updates describing already authorized behavior; follow DocWriter completion checks.
- Requested execution reports under `.factory/memory/state/`.

## Forbidden Writes

- Tests.
- Approved plan or source task.
- `implementation-plan.md`.
- Unrelated files or semantic scope expansion.

## Done Signal

- `IMPLEMENTED`
- `NEEDS_PLANNING`
- `SOURCE_DRIFT`
- `BLOCKED_STATIC_FAILURE`
- `BLOCKED_TOOL_ERROR`

## Completion gates

Apply [the developer gates](../gates/roles/developer.md); required in this role’s context.

Execution procedure: `.factory/roles/developer.md` (executor reading).
