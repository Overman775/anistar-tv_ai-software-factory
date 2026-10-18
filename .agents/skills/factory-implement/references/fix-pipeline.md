# Fix Pipeline

This is the normal initial/stateful `fix` pipeline, used after the adaptive
Post-Completion Follow-up Gate is ineligible or selects stateful handling.
Completed-run follow-ups route through `SKILL.md` before this file; eligible
mechanical production/test edits may remain root-only.

Fix workflow handles tiny bounded edits: UI text, styles, assets, inert config,
and production-file typos. Documentation-only changes use the `docs` workflow
and DocWriter. BLoC, repository, domain, API, navigation logic,
runtime/security/release behavior, or other behavior changes use `task` or
`feature`.

Summary:

```text
source gate -> Developer -> focused verification -> finalize
```

Small direct request normally uses `single_task`. A tiny selected slice from a
valid approved source may use `approved_plan`.

## Step 1: Source Gate

Apply `shared-gates.md#source-sufficiency-gate`. Plain explicit micro-change is
sufficient when target and observable result are clear. A missing behavior or
scope choice is classified through exact directive routing and the Material
Semantic Gap Gate; technical file discovery does not trigger planning.

Execution brief is optional for a true micro edit. Manifest still records
mode, source provenance/hash, and gate result. Use brief if Reality Check needs
more than a trivial path lookup.

Apply Source Drift Gate for mutable source immediately before Developer.

## Step 2: Developer

Spawn canonical `developer`.

Prompt:

```text
Make bounded micro change: {change}.
Source: {source_ref}; hash: {source_hash}.
Affected files if known: {files}.
Use .agents/contracts/developer.md boundaries. Keep diff minimal.
Do not change behavior beyond locked source. Use bounded direct choice when
source permits it. If all Material Semantic Gap Gate conditions hold, route by
directive: delegated planning hands off; otherwise stop with NEEDS_PLANNING.
For Dart/Flutter changes, directly run workspace Analyze, DCM, and Format
Check. Return IMPLEMENTED with files, exact commands, cwd, and exit codes, or
return NEEDS_PLANNING, BLOCKED_STATIC_FAILURE, or BLOCKED_TOOL_ERROR with exact
evidence.
```

If edit reaches behavior logic or wider scope, apply the Material Semantic Gap
Gate or reclassify when source already contains a self-contained task boundary.

## Step 3: Focused Verification

For Dart/Flutter code, Developer must run
`shared-gates.md#static-gate`; it is final verification for micro fix because
this workflow has no TestWriter or DevReviewer. If correctness requires new or
changed tests, or edit reaches behavior logic, lifecycle, API, or architecture,
reclassify as `task`. For text/assets/non-code config, record focused validation
or skip reason. Documentation never routes through Developer.

## Step 4: Finalize

Use `shared-finalize.md` and `shared-cleanup.md`. Final report shows concise diff
and validation summary.
