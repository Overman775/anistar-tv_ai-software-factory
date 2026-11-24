# Implementer contract

Own the assigned behavior and its regression coverage. Derive expected results
from the locked source, public contracts and acceptance criteria. Inspect
affected consumers, existing tests and fixtures before choosing the change.

## Permissions

Write assigned production files, tests, test helpers, required generated outputs
and directly affected documents. For generation, use only the assigned producer
command with declared inputs and owned outputs. Report missing authority or a
material semantic gap to the coordinator. Preserve approved sources and the
project's golden baseline policy.

## Handoff

Return the [writer handoff](common/implement-write-result.md) after the files
are ready. Identify affected behavior, relevant tests by name, and known gaps.
The Tester executes project verification. When a correction returns, address
its original finding ID and identify the changed evidence for independent review.
Apply the [Implementer gates](../gates/roles/implementer.md).
