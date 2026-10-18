# Feature Pipeline

Feature workflow executes new behavior or a bounded multi-file change from a
self-contained task or approved plan. It never fills semantic gaps.

Summary:

```text
source intake -> Source Sufficiency Gate -> optional CodeExplorer
-> execution brief -> Source Drift Gate -> Developer -> Static Gate
-> TestWriter -> Test Gate -> DevReviewer -> Fix Loop -> finalize
```

Contracts: `execution-source-contract.md`, `shared-state.md`,
`shared-gates.md`, `shared-finalize.md`, `shared-cleanup.md`.
Update `pipeline.md` after each transition.

## Step 1: Intake and Classify

Choose exactly one execution mode:

- `single_task`: direct request, local task, or
  Factory Decompose task defines one observable outcome and semantic boundary;
- `approved_plan`: resolved approved artifact has valid approval tuple and
  selected scope.

Classify source separately. Resolve any task/plan reference before choosing
an execution mode. Record provenance and normalized hash.

Apply `shared-gates.md#source-sufficiency-gate`. Several independently valuable
outcomes, missing behavior boundary, undecided API/UI contract, or missing
acceptance are semantic-gap candidates, not automatic stops. Apply the Material
Semantic Gap Gate and explicit user-delegation rules. Missing affected
files/layers/classes/tests does not trigger planning.

For Factory Decompose source, lock observable outcome, in/out behavior, acceptance,
dependencies/blockers, deferred boundary, and explicit constraints. Technical
guidance such as affected layers or exact files remains Reality Check input.

For approved mode, verify tuple before proceeding. Invalid tuple returns
`BLOCKED_NO_APPROVED_PLAN`; Factory Implement does not repair approval metadata.

## Step 2: Reality Check

Use canonical `code-explorer` for cross-module, unfamiliar, migration,
navigation, storage, or integration-heavy work.

Prompt:

```text
Analyze codebase for bounded execution source: {source_ref}.
Read source without changing it. Trace entry points, data flow, existing
patterns, reusable components, integration points, and technical risks.
Do not decide product, behavior, API, architecture, acceptance, or scope gaps.
Report any unresolved choice as semantic_gap_candidate with evidence; parent
classifies it through the Material Semantic Gap Gate.
Save .ai-pipeline/state/analysis.md with current run_id and source_hash.
Return ANALYSIS_READY or BLOCKED_EXTERNAL_SOURCE.
```

Teamlead verifies critical paths in source code, then writes
`.ai-pipeline/state/execution-brief.md` using
`execution-source-contract.md#execution-brief`. Brief may select existing
technical patterns but cannot expand or reinterpret source.

If Reality Check exposes a semantic-gap candidate, Teamlead applies the
Material Semantic Gap Gate before production writes. Explicitly delegated,
bounded choices are recorded in the brief and proceed.

## Step 3: Source Drift Gate

Apply `shared-gates.md#source-drift-gate` immediately before Developer. On
`SOURCE_DRIFT`, do not edit; re-intake current source.

## Step 4: Developer

Spawn canonical `developer`.

Prompt:

```text
Implement bounded source: {source_ref}.
Execution mode: {single_task|approved_plan}.
Read current source, .ai-pipeline/state/pipeline.md, and
.ai-pipeline/state/execution-brief.md. Verify run_id/source_hash match and
Source/Drift gates pass. Source wins on any brief conflict.
Use .agents/contracts/developer.md boundaries.
Keep implementation inside locked outcome, in/out behavior, acceptance,
dependencies, blockers, constraints, and selected approved scope.
Treat files, classes, layers, exact tests, and edit order as technical guidance;
adjust them to code reality without changing semantics.
Do not edit source or execution-brief.md.
If execution exposes a semantic-gap candidate, apply the Material Semantic Gap
Gate and exact directive routing. Delegated planning hands off to Factory Planning;
otherwise stop only dependent writes and return NEEDS_PLANNING with evidence,
directive check, and preserved diff status.
Return IMPLEMENTED, NEEDS_PLANNING, SOURCE_DRIFT, BLOCKED_STATIC_FAILURE, or
BLOCKED_TOOL_ERROR.
```

For a Factory Decompose task, implement only current `implemented` behavior. Keep
`deferred` behavior explicit and safe; do not silently pull it into scope. A
research task stays inside its timebox/result. Technical preparation preserves
named consumers.

## Step 5: Static Gate

Use `shared-gates.md#static-gate`.

After implementation, compare diff with source lock. Large diff alone is not a
semantic gap. Independently valuable new outcomes, changed behavior, or wider
API/architecture boundary are candidates for the Material Semantic Gap Gate.

## Step 6: TestWriter

Spawn canonical `test-writer`.

Prompt:

```text
Write tests for changed production files: {changed_files}.
Read locked source and .ai-pipeline/state/execution-brief.md. Source wins.
Use .agents/contracts/test-writer.md boundaries.
Cover observable outcome, acceptance, implemented scenarios, constraints, and
regressions. Do not assert deferred behavior as complete.
Run tests directly through `shared-gates.md#test-gate` command rules. Save
`.ai-pipeline/state/test-report.md` exactly as
`shared-state.md#test-report`.
Classify production failures as FAIL_CODE. Never change production code.
Return PASS, FAIL_CODE, FAIL_TEST, GOLDEN_DIFF, BLOCKED_UNTESTABLE, or
NEEDS_PLANNING only when testability passes the Material Semantic Gap Gate;
include directive mode for parent routing.
```

## Step 7: Test Gate

Use `shared-gates.md#test-gate`.

## Step 8: Integrated Review

Use `shared-gates.md#review-gate`. One DevReviewer writes
`.ai-pipeline/state/review.md`.

It compares diff directly with locked source and approved scope. For
Factory Decompose tasks, verify implemented/deferred separation, dependencies,
blockers, acceptance, named consumers, and timebox/result constraints.

`APPROVE` finalizes. `NEEDS_WORK` enters Fix Loop. Teamlead classifies
`RETHINK` through the Material Semantic Gap Gate; no teammate rewrites source
boundary.

## Step 9: Fix and Re-Review

Use `shared-gates.md#fix-loop`. DevReviewer writes
`.ai-pipeline/state/re-review.md`.

Fix only findings inside source lock. Re-run drift, static, and test gates.
Only findings that pass the Material Semantic Gap Gate end with
`NEEDS_PLANNING` and retained evidence.

## Step 10: Finalize

For Factory Decompose task inside epic, report readiness only for its locked outcome;
do not claim whole epic ready. Never update task/epic source during
finalization.

Use `shared-finalize.md`.
