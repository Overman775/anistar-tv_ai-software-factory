# Shared Gates

Use these gates for production workflows. Source boundary outranks convenience,
existing implementation, and teammate suggestions.

## Source Sufficiency Gate

Apply `execution-source-contract.md#source-sufficiency-gate` before production
writes.

Outcomes:

- `PASS`: record mode, provenance, source lock, and optional approved-plan tuple;
  continue Reality Check.
- `BLOCKED_NO_APPROVED_PLAN`: approved-plan tuple is missing, stale, or invalid.
- `NEEDS_PLANNING`: all conditions in
  `execution-source-contract.md#material-semantic-gap-gate` hold. This gate
  result is terminal only without delegated planning.

`Без плана` keeps `single_task` and forbids formal planning. `Решай сам` or
equivalent delegates planning decisions: local choices stay in execution;
material gaps route through Factory Planning and return as `approved_plan`. Exact
directive is part of locked source semantics. Neither creates another mode.

Missing files, classes, helpers, exact tests, DI locations, or edit order are
technical unknowns. Resolve them through code Reality Check and record them in
`execution-brief.md`; do not route them as semantic gaps.

Delegated handoffs follow
`.agents/contracts/common/agent-checkpoint.md#same-run-role-continuation` across
all gates and fix loops. Recovery after explicit failure or invalid returned
handoff is not a valid role result, does not consume static/test-fix/review-fix
counters, and never starts from silence.

## Source Drift Gate

For mutable source, re-read immediately before every Developer production-write
pass. Compare normalized `source_hash` and any recorded `source_updated_at`
with manifest and brief.

- unchanged: record `PASS`;
- changed: record `SOURCE_DRIFT`, stop before writes, and follow
  `execution-source-contract.md#mutable-source-and-drift`;
- immutable source or direct request: record `NOT_APPLICABLE`.

Never refresh hash in place and continue. Current source needs full re-intake.

## Adaptive Follow-up Verification

This gate applies only to `inline_self_review` after the Post-Completion
Follow-up Gate confirms eligibility. Teamlead root locks `source_hash`, exact
new delta, completed-run reference, and route in parent context, then may edit
production and tests inside that delta.

Test edits must express locked behavior. Never weaken or remove assertions,
expected values, scenarios, or goldens merely to make implementation pass. An
expected-value or golden change needs explicit source authorization and the
normal Golden Gate.

After all writes, perform this final-byte sequence:

1. Run focused tests covering the locked behavior.
2. Run the complete workspace Analyze, DCM, and Format Check triplet.
3. Record changed-file `git hash-object` values.
4. Review the final diff against the locked delta and exclusions.

Parent-held evidence records changed paths/hashes, cwd, exact commands, exit
codes, concise failures, and covered behavior. Any later write invalidates the
entire adaptive evidence bundle: focused tests, complete workspace static
triplet, changed-file hashes, final diff self-review, and `SELF_REVIEW PASS`.
Rerun the full final-byte sequence before success. `inline_self_review` success is
`SELF_REVIEW PASS`, never `APPROVE`.

## Static Gate

Developer runs narrowest reliable preflight checks directly after production
writes. Outside eligible `inline_self_review`, Teamlead only validates
returned command evidence and routes failures; Teamlead never executes these
commands.

Run from repository root using the current project commands in
`docs/melos_tooling.md`:

```bash
fvm dart run melos run analyze
fvm dart run melos run dcm
fvm dart run melos run format:check
```

These root scripts already cover the AniStar TV workspace; package `--scope`
does not narrow them. Run each command once and sequentially. When no
Dart/Flutter file changed, record `NOT_APPLICABLE` with reason. Full project
completion also follows the applicable `check` → fixture `test:e2e` →
`build:android:prod:apk` sequence. Teamlead serializes these gates with delegated
preflights and Flutter/Gradle/code generation. TestWriter directly runs `check`
and fixture `test:e2e`; Developer then directly runs the APK build. Teamlead
validates their current command evidence and never substitutes historical
results. Live tests and golden updates require explicit scope.

Developer handoff contains:

| Check | cwd | Exact command | Exit code | Result | Failure excerpt |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Analyze | `.` | command | integer | `PASS | FAIL` | `none` or concise output |
| DCM | `.` | command | integer | `PASS | FAIL` | `none` or concise output |
| Format Check | `.` | command | integer | `PASS | FAIL` | `none` or concise output |

Missing required row is an invalid Developer handoff. Failures in
Developer-owned files return to Developer. Max two retries. Record unrelated
pre-existing failures and continue only when changed files are clean. After two
failed retries, return `BLOCKED_STATIC_FAILURE`; reserve `BLOCKED_TOOL_ERROR`
for command launch/infrastructure failure. `PASS` requires all three rows for
the workspace and zero exit codes.

## Test Gate

Read `.ai-pipeline/state/test-report.md`. Require current `run_id` and
`source_hash`. Require `tested_files` keys to equal current changed review scope
and values to match:

```bash
git hash-object -- "<repo-relative-path>"
```

Run hash commands from repository root. Use `DELETED` only when path is absent.
Reject stale, missing, extra, or mismatched evidence and rerun TestWriter.
Outside eligible `inline_self_review`, Teamlead never executes tests.

TestWriter chooses the narrowest reliable direct command from repository root:

```bash
fvm flutter test "<test_path>" --reporter=failures-only
```

AniStar TV tests are in root `test/`; `<test_path>` is repository-relative.
For the common unit/widget suite use `fvm dart run melos run test:unit`.
Record `cwd`, exact command, exit code, and concise failure excerpt in
`test-report.md`. Follow `docs/melos_tooling.md` and
`docs/05_development_and_testing.md` for the required coverage. Run Flutter,
Gradle, code generation, and common gates sequentially.

`PASS` requires at least one recorded test command and zero exit codes for all
recorded commands. Empty commands, missing exit codes, or a nonzero exit with
`PASS` are invalid evidence and return to TestWriter.

Outcomes:

- `PASS`: continue review.
- `FAIL_CODE`: return to Developer after Source Drift Gate. TestWriter never
  edits production code.
- `FAIL_TEST`: return to TestWriter. Developer never changes correct code to
  satisfy an invalid test.
- `GOLDEN_DIFF`: ask user before any golden update.
- `BEHAVIOR_CHANGE`: apply exact directive routing and the Material Semantic
  Gap Gate; tests cannot redefine locked behavior.
- `BLOCKED_UNTESTABLE`: Developer may improve a technical seam inside source
  boundary. If required seam changes architecture, public API, behavior, or
  acceptance, apply exact directive routing and the Material Semantic Gap Gate.
- `NEEDS_PLANNING`: require Material Semantic Gap Gate evidence and route by
  exact directive.

Max two test-fix iterations.

## Refactor Existing Tests Gate

Existing behavior is refactor contract. TestWriter runs narrowest relevant
existing tests directly and writes current `test-report.md`, even when no test
files need adaptation.

- `PASS`: continue review.
- `FAIL_CODE`: return to Developer to restore behavior.
- `FAIL_TEST`: return to TestWriter to fix invalid or broken test code.
- `GOLDEN_DIFF`: ask user before update.
- `BEHAVIOR_CHANGE`: changed expected values, business scenarios, or visual
  baselines are not refactor execution. Apply the Material Semantic Gap Gate.
- `BLOCKED_UNTESTABLE`: add characterization tests only when source or bounded
  direct-execution rules authorize them. Otherwise apply exact directive routing
  and the Material Semantic Gap Gate.
- `NEEDS_PLANNING`: require Material Semantic Gap Gate evidence and route by
  exact directive.

TestWriter may mechanically adapt imports, names, setup, DI, or mocks, then
reruns tests and returns one final status. Adaptation must not change expected
values, business scenarios, behavior assertions, or golden baselines.

## Review Gate

Review starts after tests pass unless user explicitly accepts review with known
test failures. Spawn exactly one canonical `dev-reviewer`. Pass current
`run_id`, `source_hash`, workflow, phase, locked source,
`execution-brief.md`, diff/changed files, matching `test-report.md`, and exact
output path.

DevReviewer performs one integrated pass over source alignment, correctness,
architecture/scope, and tests. Workflow changes emphasis, not agent count or
output schema. Initial review writes `.ai-pipeline/state/review.md`. Validate
current identity and stable IDs before accepting the artifact.

After all Developer and TestWriter writes, DevReviewer directly runs final
workspace Analyze, DCM, and Format Check using Static Gate commands. It records
the same command table under `Automatic checks`; this role never applies
formatting. DevReviewer continues semantic review after nonzero check result to
batch significant findings. Changed-file failures become stable findings owned
by affected path. Unrelated pre-existing failures are recorded but do not block
when changed files are clean. Required failed, missing, or stale checks prohibit
`APPROVE`. A matching Test Gate status other than `PASS` also prohibits
`APPROVE`; review with known failing tests is diagnostic only. Failure to launch
a required tool returns explicit
`BLOCKED_TOOL_ERROR` handoff without an authoritative verdict.

Outcomes:

- `APPROVE`: continue.
- `NEEDS_WORK`: enter Fix Loop for findings inside source lock.
- `RETHINK`: treat as a semantic-gap candidate. Teamlead applies the Material
  Semantic Gap Gate. If any condition fails, choose through source evidence or
  bounded direct-execution rules and convert concrete correction to stable
  `NEEDS_WORK`. Otherwise route by exact directive: delegated planning hands
  off to Factory Planning; explicit no-plan/none returns `NEEDS_PLANNING` with review
  evidence.

## Fix Loop

Steps and counters below apply only to stateful Developer/TestWriter pipelines.

For `NEEDS_WORK`, use current authoritative artifact: `review.md` before first
fix, current `re-review.md` afterward. Teamlead partitions every finding by
writable path owner; it never sends test-only work to Developer or
production-only work to TestWriter.

1. For production/generated findings, run Source Drift Gate, then continue
   Developer; it lists every fixed or intentionally open assigned ID.
2. For test/mocks findings, continue TestWriter; it lists every fixed or
   intentionally open assigned ID.
3. For a mixed finding, Developer fixes production first; TestWriter then fixes
   tests. A semantic-gap finding follows normal parent routing instead.
4. Developer reruns Static Gate only when production/generated files changed.
5. TestWriter reruns workflow tests after any relevant production/test change
   and refreshes `test-report.md` `tested_files`.
6. Continue `dev-reviewer` for original IDs; write `re-review.md`.
7. Validate `re-review.md` identity and original-ID coverage, then replace
   `pipeline.md.gates.review` with its verdict. When `review_fix > 0`,
   `re-review.md` is authoritative for current Review Gate; `review.md` remains
   immutable initial finding/fix evidence.

Re-review marks each original ID `FIXED`, `NOT_FIXED`, or `REGRESSION` and
inspects the fix diff for new significant regressions. Give each new significant
regression the next unused `REV-*` ID. Require current provenance header.

Max two review-fix iterations for feature. Max one for task/refactor. A finding
that passes the Material Semantic Gap Gate never enters normal Fix Loop; return
`NEEDS_PLANNING`.
