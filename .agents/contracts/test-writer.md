# Test Writer Contract

Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`. For long work,
emit progress after test design, test write, and execution boundaries; parent
validates checkpoints and explicit failures.

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- `docs/05_development_and_testing.md`, locked behavior/acceptance, affected
  specifications selected through `docs/specs/README.md`, and existing test helpers.
- `integration_test/README.md` and `tool/e2e/README.md` for Android E2E/fixture work;
  `docs/melos_tooling.md` for delegated commands.

## Input

- Locked execution source and source hash.
- `.ai-pipeline/state/pipeline.md` and optional `execution-brief.md`.
- Changed production files and project testing conventions.

## Allowed Writes

- Test files, test mocks/helpers, and `test-report.md`.

## Forbidden Writes

- Production code.
- Approved plan/source task.
- Golden baseline without explicit user approval.

## Test Quality

- Mock dependencies, never unit under test.
- Cover applicable success, failure, boundary, and no-op behavior.
- Keep tests deterministic; no uncontrolled time, randomness, or order.
- Read implementation only as evidence for locked behavior; never reinterpret
  source requirements.
- Fix test defects. Report production behavior failures without editing
  production.
- Report an exact testability/semantic blocker instead of inventing a seam,
  expected value, public API, behavior, or acceptance.

## Done Signal

- `PASS | FAIL_CODE | FAIL_TEST | GOLDEN_DIFF | BEHAVIOR_CHANGE | NEEDS_PLANNING | BLOCKED_UNTESTABLE`

## Evidence

- Report starts with current `run_id` and `source_hash`.
- `tested_files` keys exactly match current changed files in review scope.
  Existing files use `git hash-object -- "<path>"`; deleted files use
  `DELETED`. Run hashes from repository root, compute after test writes, and
  verify same values after execution.
- Test files plus direct commands with `cwd`, exact command, exit code, and a
  concise failure excerpt.
- `PASS` requires at least one direct test command and zero exit codes.
- Exact source behavior covered or exact blocker.
- Execute delegated test commands directly, including unchanged existing tests
  when requested. Delegated command execution is not valid evidence.
