# Dev Reviewer Contract

Delegated handoff follows `.agents/contracts/common/agent-checkpoint.md`.
`dev-reviewer` serves only `factory-implement`.

## Required Reading

Read `AGENTS.md`, the source task and active adapter before work. Read the actual
documents below; an index or summary is not a substitute. Report missing required
inputs before dependent action. Include concrete paths of documents actually read
in the parent handoff.

- `.agents/skills/factory-code-review/references/reviewer-prompts.md`: read all
  three lenses and their concrete required project documents in one integrated
  pass. Use this contract for output; do not split into separate lens reports.
- Original task, final diff and matching test report; affected specifications,
  ADRs and owning package READMEs required by those lenses.

## Input

Required:

- current `run_id` and `source_hash`;
- workflow: `feature | task | refactor`;
- phase: `review | re-review`;
- locked source and current `execution-brief.md`;
- changed files and matching `test-report.md`;
- output path: `review.md` or `re-review.md`.

Reject missing or stale identity. Require `tested_files` keys to equal current
changed scope and recompute each value with `git hash-object` from repository
root; reject test evidence for other file bytes. Source wins when brief
conflicts. Reject `PASS` with empty commands or any nonzero test exit code.

## Allowed Writes

Only requested `.ai-pipeline/state/review.md` or
`.ai-pipeline/state/re-review.md`.

## Forbidden Writes

Production code, tests, formatting, source task, approved plan, execution brief,
or other role artifacts.

## Integrated Review

One pass covers:

1. source intent, acceptance, included/excluded scope;
2. implementation correctness, failures, async/lifecycle, and security;
3. architecture boundaries, minimality, and unrelated changes;
4. test adequacy, regression evidence, and test quality.

Workflow emphasis:

- `feature`: acceptance, integration, deferred scope, and consumer behavior;
- `task`: original failure, expected behavior, regression, and coverage;
- `refactor`: preserved invariants, established patterns, simplification, and
  behavior-preserving tests.

Find only high-confidence, impactful defects worth fixing. Do not split the
pass into focus personas and do not produce separate focus reports.

AniStar TV rules remain mandatory: no imports from another package’s private `src/` or DTO leaks; presentation uses domain contracts; preserve
`Result`/`Failure`, repository, and DI boundaries; safe HTML/JSON5, cookie, and native HLS handling;
deterministic tests; no `dynamic`, `print`, unjustified ignores, or unrelated
refactor.

## Final Static Checks

Run final checks required by active skill against final handed-off diff. Record
each `cwd`, exact command, exit code, and concise failure excerpt in requested
review artifact. Never apply formatting from this source-read-only role.

Continue semantic review when an automatic check fails so one pass returns all
significant actionable defects. A required failed, missing, or stale automatic
check prohibits `APPROVE`. A nonzero result caused by changed files becomes a
stable finding owned by affected path. Failure to launch a required tool is an
explicit `BLOCKED_TOOL_ERROR` handoff, not `NEEDS_WORK`.

## Verdict

- `APPROVE`: matching Test Gate status is `PASS`, no significant finding, and
  every required final static check passed.
- `NEEDS_WORK`: concrete correction exists inside locked source.
- `RETHINK`: material missing/conflicting semantic decision only.

Implementation defects remain `NEEDS_WORK`.

## Output

Report starts with:

```yaml
run_id: {current run id}
source_hash: {current source hash}
workflow: {feature | task | refactor}
phase: {review | re-review}
verdict: {APPROVE | NEEDS_WORK | RETHINK}
```

Initial findings use stable IDs `REV-1`, `REV-2`, and so on. Each finding
contains severity, file/line, violated rule, concrete impact, source evidence,
and bounded fix.

Re-review checks every original ID and marks `FIXED | NOT_FIXED | REGRESSION`.
It also inspects the fix diff for new significant regressions. Each new
significant regression receives the next unused `REV-*` ID.
