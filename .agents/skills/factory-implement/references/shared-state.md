# Shared State

Use `.ai-pipeline/state/` only for one active stateful initial or `full_team` Factory
Dev Team run. State supports handoff and resume; it is not product
documentation.

## Stateless Adaptive Follow-ups

`inline_self_review` creates no `pipeline.md`, execution brief,
`test-report.md`, `review.md`, `re-review.md`, or other persistent execution
state. Provenance and evidence match `shared-gates.md` and remain in parent
context.

If same-task/same-checkout context is lost, user wait needs resumability, or
scope/risk grows, start a stateful `full_team` run with the follow-up delta
only. Do not transfer old completed gate verdicts. Preserved partial diff and
evidence are inputs, not `PASS` verdicts.

## Pipeline Manifest

Teamlead owns `.ai-pipeline/state/pipeline.md` and updates it after every state
transition. It is resume and cleanup authority.

Required shape:

```yaml
run_id: factory-implement-{timestamp}-{short-id}
status: in_progress | waiting_user | blocked | needs_planning | completed | cancelled
resumable: true | false
workflow: feature | task | refactor | fix | explore | debug | docs
execution_mode: single_task | approved_plan | not_applicable
source_kind: direct | local_task | factory_decompose_task | approved_plan | none
source_ref: {prompt id, path, plan id, or none}
source_updated_at: {source timestamp or none}
source_hash: {SHA-256 or none}
current_step: {pipeline step id and name}
wait_or_block_reason: none | {stable token and detail}

approved_plan:
  plan_id: {id or none}
  revision: {approved revision or none}
  plan_hash: {hash or none}
  approval_state: approved | none
  approval_evidence: canonical_plan_metadata | explicit_external_hash_approval | none
  execution_scope: all | {CAP IDs or named bounded outcome} | none

owned_artifacts:
  - .ai-pipeline/state/{file created by this run}
adopted_artifacts:
  - path: .ai-pipeline/state/{explicit foreign handoff file}
    from_run_id: {source run or handoff id}
    reason: {why execution needs it}

counters:
  static_retries: N
  test_fix: N
  review_fix: N
  agent_recoveries: N

gates:
  source: PASS | NEEDS_PLANNING | BLOCKED_NO_APPROVED_PLAN | NOT_RUN
  drift: PASS | SOURCE_DRIFT | NOT_APPLICABLE | NOT_RUN
  static: PASS | FAIL | NOT_APPLICABLE | NOT_RUN
  tests: PASS | FAIL_CODE | FAIL_TEST | GOLDEN_DIFF | BEHAVIOR_CHANGE | BLOCKED_UNTESTABLE | NEEDS_PLANNING | NOT_RUN
  review: APPROVE | NEEDS_WORK | RETHINK | NOT_RUN
gate_notes:
  static: none | {required reason when static is NOT_APPLICABLE}
  review: none | {required reason when review is NOT_RUN}

agents: {role -> runtime handle/status/last_stage/checkpoint/recovery, if available}
cleanup: PENDING | PASS | FAIL
tasks:
  - [ ] Source intake and sufficiency
  - [ ] Reality Check / execution brief
  - [ ] Developer
  - [ ] Static gate
  - [ ] TestWriter or existing tests
  - [ ] Review
  - [ ] Fix loop
  - [ ] Finalize
```

Use only relevant checklist steps. `not_applicable` is limited to read-only
`explore`/`debug` until implementation is explicitly requested.

State rules:

- Generate a unique `run_id` before first teammate starts.
- Store delegated handle, last valid checkpoint, and Done Signal per role. Factory Dev
  identity is `run_id + source_hash + canonical role`; immutable lock is source
  provenance plus `source_hash`; follow
  `.agents/contracts/common/agent-checkpoint.md#same-run-role-continuation`.
  Continuation remains open for Developer, TestWriter, and DevReviewer only through
  final Review Gate: Fix Loop is bounded, then terminalize all three on `APPROVE`
  or another terminal outcome. Capability absence and poll timeouts are not recovery
  or counter increments.
- Track explicit failure/invalid-handoff recovery separately from static/test/review
  counters. Statuses include `running`, `blocked`, `failed`, `retrying`,
  `completed`, and terminal `retired`; silence never changes status.
- `waiting_user`, `blocked`, and `needs_planning` keep `resumable: true`, source
  provenance, counters, agents, and artifact lists intact.
- `completed` and `cancelled` use `resumable: false`; they remain only until
  final summary capture and verified cleanup.
- `pipeline.md` is implicitly owned and never listed in `owned_artifacts`.
- Source gate must pass before production writes. Mutable source also requires
  Drift Gate immediately before every Developer write pass.
- Do not mutate source provenance to hide drift. Re-intake creates a new
  `source_hash` and a new `execution-brief.md` snapshot before execution resumes.
- For workflows with required Review Gate, `review.md` owns current verdict
  while `review_fix: 0`. With `review_fix > 0`, validated `re-review.md` owns
  it; `review.md` remains immutable initial evidence. Update `gates.review`
  from authoritative artifact before any finalize decision. A `fix` workflow
  may keep `gates.review: NOT_RUN` with explicit skip reason.

## Artifact Ownership and Provenance

Add every current-run file to `owned_artifacts` before or immediately after its
first write. Explicit foreign handoff files belong only in `adopted_artifacts`.
Never claim persistent task, approved-plan, source, or docs files as
temporary artifacts.

Every execution report starts with:

```yaml
run_id: {current run id}
source_hash: {current source hash or none for read-only investigation}
```

Reject reports with missing or stale headers.
Write report/state prose in Russian unless user asks otherwise; keep manifest
keys, identifiers, commands, paths, hashes, and verdict tokens stable.

| Artifact | Writer | Purpose | Ownership |
| :--- | :--- | :--- | :--- |
| `pipeline.md` | Teamlead | Resume, source, gates, counters | Implicit; delete last |
| `execution-brief.md` | Teamlead | Locked source snapshot and non-semantic checklist | Owned |
| `analysis.md` | CodeExplorer or BugHunter | Code-flow/root-cause evidence | Owned |
| `refactor-report.md` | Developer or Teamlead | Behavior-preservation evidence | Owned |
| `test-report.md` | TestWriter | Test commands, result, coverage, and tested file hashes | Owned |
| `review.md` | DevReviewer | Integrated review and stable findings | Owned |
| `re-review.md` | DevReviewer | Original finding recheck | Owned |
| `simplify-report.md` | `factory-code-simplify` | Explicitly selected refactor evidence | Adopted only through explicit handoff |

New report types require an exact ownership rule here before use. Stateless
adaptive follow-ups never introduce an inline report type.

## Test Report

`test-report.md` uses common header, then:

```yaml
status: PASS | FAIL_CODE | FAIL_TEST | GOLDEN_DIFF | BEHAVIOR_CHANGE | BLOCKED_UNTESTABLE | NEEDS_PLANNING
tested_files:
  relative/path.dart: {git hash-object output | DELETED}
commands:
  - cwd: {repo-relative directory}
    command: {exact direct command}
    exit_code: {integer}
    failure_excerpt: {none | concise relevant output}
coverage:
  - {locked behavior and test file}
blockers: []
```

`tested_files` keys exactly equal current changed files in review scope.
TestWriter computes existing-file values with
`git hash-object -- "<relative-path>"` after writes and verifies them again
after commands. `PASS` requires a nonempty `commands` list and zero exit codes.
Full command output stays in tool result; report keeps only relevant failure
excerpt.

## Execution Brief Lifecycle

Create `execution-brief.md` only after Source Sufficiency Gate passes. Follow
`execution-source-contract.md#execution-brief` exactly.

- Brief may change during read-only Reality Check.
- Freeze it before Developer starts.
- Developer, TestWriter, and DevReviewer read source plus brief; source wins on
  conflict.
- A mismatch needing a semantic choice is classified through exact directive
  routing and the Material Semantic Gap Gate; nobody rewrites source
  semantics inside brief.
- A source re-intake replaces brief with current hash before execution resumes.

## Refactor Report

`refactor-report.md` uses common header, then:

```markdown
# Refactor Report

## Applied
- Target:
  Why:
  Better:
  Behavior evidence:
  Test edits: none | {mechanical adaptations and reason}
  Risk:

## Stops
- Candidate not applied: {weak benefit, behavior risk, or outside source}

## Gate outcomes
- Static:
- Existing tests:
- Adapted tests:
```

## Workflow Transitions

`task -> debug -> task` may remain one run when implementation was requested
and BugHunter only supplies root-cause evidence. Keep `run_id`, source lock,
counters, and `analysis.md`. Re-run source gate after diagnosis; classify any
new semantic choice through exact directive routing and the Material Semantic
Gap Gate.

`explore -> feature|task|refactor|fix` may remain one run only after explicit
implementation authorization. Classify mode, run source intake, and create a
brief before production writes. Exploration evidence cannot authorize scope.

Independent work uses a new run. Capture needed facts in parent context, clean
old terminal state, and create fresh provenance. Never transfer gate verdicts
between run IDs.

## Review Tracking

DevReviewer numbers initial findings `REV-1`, `REV-2`, and so on in
`review.md`:

| ID | Severity | File:Line | Status | Issue |
| :--- | :--- | :--- | :--- | :--- |

Use `OPEN` for new findings. No cross-reviewer merge exists. Developer fix
summaries reference every addressed ID. `re-review.md` marks each original ID
`FIXED`, `NOT_FIXED`, or `REGRESSION`; new significant regressions receive next
unused `REV-*` IDs.
