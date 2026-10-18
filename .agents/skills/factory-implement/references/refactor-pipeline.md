# Refactor Pipeline

Refactor workflow executes behavior-preserving restructuring from a bounded
user request, selected simplify findings, or approved plan.

Visible behavior, visual design, text, API behavior, public compatibility, or
business behavior changes are not refactor execution.

Summary:

```text
source intake -> Source Sufficiency Gate -> Reality Check -> execution brief
-> Source Drift Gate -> Developer -> Static Gate -> TestWriter existing tests
-> optional mechanical test adaptation -> DevReviewer
-> Fix Loop -> finalize
```

Contracts: `execution-source-contract.md`, `shared-state.md`,
`shared-gates.md`, `shared-finalize.md`, `shared-cleanup.md`.

## Step 1: Intake Behavior Boundary

Choose mode:

- `single_task`: direct request or explicitly selected simplify findings name
  exact targets and behavior invariants;
- `approved_plan`: valid approved scope defines targets and invariants.

A `simplify-report.md` is input only after explicit user
selection; record it as adopted temporary evidence. Never apply stale findings
implicitly.

Apply Source Sufficiency Gate. Source must establish exact structural target,
behavior/public-API invariants, excluded changes, and verification contract.
Missing filenames or nearest existing pattern can be resolved technically.
Unclear invariants, target selection, public compatibility, or behavior choice
is a semantic-gap candidate. Apply exact directive routing and the Material
Semantic Gap Gate.

## Step 2: Reality Check and Brief

Inspect target, consumers, public exports, tests, and nearest established
project pattern. Write `execution-brief.md` with verified paths, reuse pattern,
edit order, unchanged-behavior checks, and technical risks.

Do not use brief to select new refactor targets or relax invariants unless exact
bounded direct choice is source-authorized and stays inside requested outcome. If
correct work requires API/behavior/architecture semantics outside source,
apply the Material Semantic Gap Gate.

## Step 3: Source Drift Gate

Use `shared-gates.md#source-drift-gate` immediately before Developer.

## Step 4: Developer

Spawn canonical `developer`.

Prompt:

```text
Apply bounded behavior-preserving refactor: {source_ref}.
Read source, pipeline.md, and execution-brief.md. Verify current run_id,
source_hash, Source Gate, and Drift Gate. Source wins.
Use .agents/contracts/developer.md boundaries. Do not edit tests, source, or
execution brief.
Preserve locked behavior, validation, errors, analytics, accessibility,
security, public API, and business scenarios.
Write .ai-pipeline/state/refactor-report.md using
shared-state.md#refactor-report with current run_id and source_hash.
Leave weak-benefit, behavior-changing, or outside-source candidates under
Stops instead of implementing them.
If execution exposes a semantic-gap candidate, apply exact directive routing and
the Material Semantic Gap Gate. Delegated planning hands off to Factory Planning;
otherwise stop dependent writes when all conditions hold and return
NEEDS_PLANNING with evidence and preserved diff status.
Return IMPLEMENTED, NEEDS_PLANNING, SOURCE_DRIFT, BLOCKED_STATIC_FAILURE, or
BLOCKED_TOOL_ERROR.
```

## Step 5: Static Checks and Existing Tests

Use `shared-gates.md#static-gate`, then spawn canonical `test-writer` for
`shared-gates.md#refactor-existing-tests-gate`. TestWriter owns existing test
execution even when no adaptation is needed. Record outcomes in
`refactor-report.md` and `test-report.md`.

Prompt:

```text
Run narrowest existing tests for refactor and adapt them mechanically only when
required by renamed/moved internals, imports, setup, DI, or mocks.
Read source, execution-brief.md, and refactor-report.md.
Use .agents/contracts/test-writer.md boundaries.
Adapt only renamed/moved internals, imports, setup, DI, or mocks. Do not change
expected values, business scenarios, behavior assertions, or goldens.
Run tests directly through `shared-gates.md#test-gate` command rules. Save
`test-report.md` exactly as `shared-state.md#test-report`, including any
mechanical test adaptations. Return one final PASS, BEHAVIOR_CHANGE,
GOLDEN_DIFF, BLOCKED_UNTESTABLE, or
NEEDS_PLANNING only with Material Semantic Gap Gate evidence and delegation
check.
```

Classify `BEHAVIOR_CHANGE` through exact directive routing and the Material
Semantic Gap Gate.

## Step 6: Integrated Review

Use `shared-gates.md#review-gate`. One DevReviewer writes
`.ai-pipeline/state/review.md` and verifies established-pattern fit, concrete
simplification, authorized targets, preserved invariants, behavior evidence,
and any mechanical test adaptation.

`APPROVE` finalizes. `NEEDS_WORK` enters Fix Loop. Teamlead classifies
`RETHINK` requiring changed target or invariants through the Material Semantic
Gap Gate.

## Step 7: Fix and Re-Review

Use `shared-gates.md#fix-loop`; one review-fix iteration by default. Developer
updates `refactor-report.md` when rationale/evidence changes.

DevReviewer writes `.ai-pipeline/state/re-review.md`.

## Step 8: Finalize

Final report includes concise refactor rationale and behavior evidence. Use
`shared-finalize.md`.
