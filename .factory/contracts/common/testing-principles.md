# Testing Principles

Design tests that detect concrete wrong behavior. Apply within assigned writes
and locked requirements. Role/process contracts own permissions, command stages
and results; [Verification Rules](../../gates/common/verification-rules.md) own mandatory checks.

## Establish expected behavior

Derive scenarios and expected outcomes from locked requirements/ACs and public
interfaces first. Implementation and author handoffs guide discovery, never define
the oracle. Do not reinterpret requirements to match current code.

Then inspect implementation and existing tests for remaining risks: errors,
boundaries, no-ops, regressions and affected interactions, including unchanged
callers. Reuse adequate coverage; add checks for meaningful uncovered risks.
Follow project coverage thresholds; percentage alone does not prove adequacy.

## Build meaningful checks

- Each added test detects a concrete wrong result. Assert observable behavior;
  choose smallest readable setup preserving the failure.
- Mock dependencies, never unit under test. Preserve significant real-data
  semantics in fixtures; test affected integration paths where mocks hide risks.
- Deterministic tests: no uncontrolled time, randomness or execution order.
- No duplicate checks, speculative test framework or helpers without current use.
- Refactor tests protect established behavior and public contracts.

## Protect regressions

Reproduce original failure and verify corrected behavior. When feasible within
assigned checks, demonstrate failure on old behavior and success on the fix in
an isolated reproduction, without reverting the working tree. Otherwise disclose
the evidence limit; never fabricate a red run.

## Diagnose before changing expectations

Failure may belong to code, test or requirements. Inspect expected behavior,
setup and actual failure before correction; never weaken/delete a valid failing
test for green. Fix only defects within role ownership; report other work with
evidence and affected paths.

Report exact testability/semantic blockers. Never invent a seam, expected value,
public API, behavior or acceptance criterion. Creating a test is not executing
it; report only actual assigned runs and uncovered behavior.
