# Explore Pipeline

Explore workflow explains existing code. It is read-only.

Summary:

```text
CodeExplorer -> analysis.md -> present -> done / deeper / explicit execution
```

## Step 1: CodeExplorer

Spawn canonical `code-explorer`.

Prompt:

```text
Analyze feature/module: {question}.
Trace entry points, data flow, architecture layers, dependencies, and risks.
Save .ai-pipeline/state/analysis.md with current run_id and source_hash: none.
Do not change production or tests.
Return ANALYSIS_READY or BLOCKED_EXTERNAL_SOURCE.
```

## Step 2: Present and Route

Present concise analysis and evidence.

- `done`: close teammate, capture summary, mark completed, clean.
- `deeper`: continue CodeExplorer with focused follow-up.
- explicit execution request: close CodeExplorer; keep same run only for same
  causal goal. Classify workflow and `single_task`/`approved_plan`, perform
  source intake and Source Sufficiency Gate, then create execution brief before
  production writes.

Exploration evidence is Reality Check input only. It never authorizes behavior,
scope, API, architecture, acceptance, or task-boundary decisions. On an
execution request, bounded direct choices may proceed; Teamlead applies exact
directive routing and Material Semantic Gap Gate to anything remaining.

## Step 3: Cleanup

Use `shared-cleanup.md` for terminal explore. Skip cleanup during same-run
transition to authorized execution.
