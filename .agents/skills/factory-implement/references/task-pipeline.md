# Task Pipeline

Task workflow fixes existing broken behavior. Execution source must define
expected outcome and semantic boundary; root cause may be discovered during
read-only investigation.

Summary:

```text
source intake -> Source Sufficiency Gate -> [BugHunter] -> execution brief
-> Source Drift Gate -> Developer -> Static Gate -> TestWriter -> Test Gate
-> DevReviewer -> Fix Loop -> finalize
```

Contracts: `execution-source-contract.md`, `shared-state.md`,
`shared-gates.md`, `shared-finalize.md`, `shared-cleanup.md`.

## Step 1: Intake Expected Behavior

Classify `single_task` or `approved_plan`, record provenance/hash, and apply
Source Sufficiency Gate.

A bug request may omit root cause and exact file. That is technical discovery,
not a semantic gap, when expected behavior, excluded behavior, and verification
are clear. Missing or disputed expected behavior, compatibility boundary, or
acceptance becomes a semantic-gap candidate. Apply exact directive routing and
the Material Semantic Gap Gate before stopping or handing off to Factory Planning.

Resolve referenced source before choosing an execution mode.
Approved-plan mode requires valid tuple.

## Step 2: Root-Cause Reality Check

If root cause is not established by quick focused inspection, continue same run
through canonical `bug-hunter`. Keep original source lock and implementation
authorization; investigation itself adds no scope.

Prompt:

```text
Investigate bug for bounded source: {source_ref}.
Expected behavior and source lock: {summary}.
Trace symptom to evidence-backed root cause. Do not change production or tests.
Save .ai-pipeline/state/analysis.md with current run_id and source_hash.
If device/user action is needed, return BLOCKED_USER_INPUT with exact action.
If fixing root cause may need behavior, API, architecture, acceptance, or scope
not defined by source, report semantic_gap_candidate with evidence; parent
classifies it.
Return ROOT_CAUSE_FOUND, BLOCKED_USER_INPUT, or BLOCKED_TOOL_ERROR.
```

When root cause is found, Teamlead verifies code evidence and writes
`execution-brief.md`: reproduction/evidence under Reality Check, minimal edit
map, regression checks, and technical risk. Root cause cannot redefine expected
behavior or authorize adjacent fixes.

For `BLOCKED_USER_INPUT`, preserve manifest, source provenance, and analysis;
resume same BugHunter after user action.

## Step 3: Source Drift Gate

Apply `shared-gates.md#source-drift-gate` immediately before Developer.

## Step 4: Developer

Spawn canonical `developer`.

Prompt:

```text
Fix bounded bug source: {source_ref}.
Read current source, pipeline.md, execution-brief.md, and analysis.md when
present. Verify run_id/source_hash and Source/Drift gates. Source wins.
Use .agents/contracts/developer.md boundaries.
Implement minimal production fix for locked expected behavior. Do not edit tests,
source, or execution brief. Do not fix adjacent behavior.
If required change exposes a semantic-gap candidate, apply exact directive
routing and the Material Semantic Gap Gate. Delegated planning hands off to Factory
Planning; otherwise stop dependent writes and return NEEDS_PLANNING with
evidence and preserved diff status.
Return IMPLEMENTED, NEEDS_PLANNING, SOURCE_DRIFT, BLOCKED_STATIC_FAILURE, or
BLOCKED_TOOL_ERROR.
```

## Step 5: Static and Scope Gates

Use `shared-gates.md#static-gate`. Compare diff with source lock. Extra
behavior, wider API/architecture boundary, or independent outcomes are
classified through the Material Semantic Gap Gate; technical file spread alone
does not trigger planning.

## Step 6: TestWriter

Spawn canonical `test-writer`.

Prompt:

```text
Write regression tests for bounded bug fix.
Changed files: {changed_files}.
Read source, execution-brief.md, and analysis.md when present.
Use .agents/contracts/test-writer.md boundaries.
Cover original failure, locked expected behavior, acceptance, and regression.
Run tests directly through `shared-gates.md#test-gate` command rules. Save
`.ai-pipeline/state/test-report.md` exactly as
`shared-state.md#test-report`.
Return PASS, FAIL_CODE, FAIL_TEST, GOLDEN_DIFF, BLOCKED_UNTESTABLE, or
NEEDS_PLANNING only when testability passes the Material Semantic Gap Gate;
include directive mode for parent routing.
```

Use `shared-gates.md#test-gate`.

## Step 7: Integrated Review

Use `shared-gates.md#review-gate`. One DevReviewer writes
`.ai-pipeline/state/review.md` and compares original failure, source-locked
expected behavior, diff, regression evidence, and test quality. Teamlead
classifies `RETHINK` needing wider semantics through the Material Semantic Gap
Gate.

## Step 8: Fix and Re-Review

Use `shared-gates.md#fix-loop`; task allows one review-fix iteration by default.

DevReviewer writes `.ai-pipeline/state/re-review.md`.

## Step 9: Finalize

Use `shared-finalize.md`.
