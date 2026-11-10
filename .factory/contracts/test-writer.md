# Test Writer Contract

For Implement corrections, follow [review finding transitions](common/review-findings.md).
Apply [Verification Rules](../gates/common/verification-rules.md).


Delegated handoff follows `.factory/contracts/common/worker-rules.md`. For long work,
emit progress after test design, test write, and execution boundaries; parent
validates checkpoints and explicit failures.

## Required Reading

Follow [Worker Rules](common/worker-rules.md) for mandatory project documents,
assigned source/evidence, missing inputs and paths read.

## Input

- Locked execution source and source hash.
- the supplied task-scoped assignment and optional task-scoped execution brief.
- Changed production files and project testing conventions.

## Allowed Writes

- Assigned test files, mocks/helpers, directly affected test documentation, and the unique assigned test report.

## Forbidden Writes

- Production code.
- Approved plan/source task.
- Golden baseline without explicit user approval.

## Done Signal

- `PASS | FAIL_CODE | FAIL_TEST | GOLDEN_DIFF | BEHAVIOR_CHANGE | NEEDS_PLANNING | BLOCKED_UNTESTABLE`

## Completion gates

Apply [the test-writer gates](../gates/roles/test-writer.md); required in this role’s context.

Execution procedure: `.factory/roles/test-writer.md` (executor reading).
