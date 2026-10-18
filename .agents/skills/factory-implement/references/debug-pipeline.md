# Debug Pipeline

Debug workflow investigates symptoms without production-write authorization.
It produces root-cause evidence, not an execution boundary.

Summary:

```text
BugHunter -> analysis.md -> present evidence -> done / investigate more /
explicit implementation request
```

State: `shared-state.md`. Cleanup: `shared-cleanup.md`.

## Step 1: BugHunter

Spawn canonical `bug-hunter`.

Prompt:

```text
Investigate issue: {symptom}.
Context: {steps, logs, expected behavior, screenshots}.
Trace symptom to evidence-backed root cause. Do not change production or tests.
Save .ai-pipeline/state/analysis.md with current run_id and source_hash when a
source lock exists; otherwise use source_hash: none.
Record reproduction, expected/actual evidence, root cause/confidence, affected
paths, minimal technical fix direction, regression-test idea, and risks.
Do not decide missing behavior, API, architecture, acceptance, or scope. Report
it as semantic_gap_candidate with evidence; parent classifies it.
Return ROOT_CAUSE_FOUND, BLOCKED_USER_INPUT, or BLOCKED_TOOL_ERROR.
```

When live observation is required, preserve evidence and return exact device or
user action. Do not claim unverified root cause.

## Step 2: Present and Route

Present root cause, evidence, confidence, affected paths, minimal fix direction,
test idea, and risks.

- `done`: capture investigation result, close BugHunter, mark completed, clean.
- `investigate more`: continue same BugHunter with focused question.
- explicit implementation request: close BugHunter. Keep same run only for same
  causal issue, then classify `task` mode/source, apply Source Sufficiency Gate,
  and create `execution-brief.md` before any production write.
- `close`: capture cancellation, close BugHunter, mark cancelled, clean.

Analysis never authorizes implementation. If expected behavior or another
semantic boundary remains unresolved, Teamlead applies exact directive routing
and the Material Semantic Gap Gate even when root cause is known. If new request is
self-contained, it may become `single_task`; if it references valid approved
scope, it may become `approved_plan`.

A request that already says “find and fix” belongs to `task-pipeline.md`: task
keeps implementation authorization while BugHunter performs read-only Reality
Check.

## Step 3: Cleanup

Use `shared-cleanup.md` for terminal investigation. Skip cleanup when same run
transitions to authorized task execution.
