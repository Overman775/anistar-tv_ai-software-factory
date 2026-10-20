---
name: factory-implement
description: "Use when user needs AniStar TV implementation, tests, and review from a self-contained request, local ticket, decomposed task, or approved factory-planning plan. Supports feature work, bugs, refactors, fixes, UI changes, execution pipelines, code exploration, and debugging. Triggers: implement, execute plan, docs/plans, docs/tasks, fix bug, refactor, update UI, run pipeline, реализуй, исполни план, возьми задачу, исправь баг, отрефактори. Semantic planning belongs only to factory-planning; review-only uses factory-code-review; decomposition-only uses factory-decompose."
---

# Factory Implement

## Core Boundary

Factory Implement executes an already bounded change. It does not create or revise a
semantic plan.

- `factory-planning` owns goal, behavior, scope, solution shape, product/API/
  architecture decisions, risks, readiness, plan revision, and approval.
- `factory-decompose` owns task IDs, vertical slices, estimates, dependencies, and
  local task files.
- `factory-implement` owns code Reality Check, non-semantic execution preparation,
  implementation, tests, review, and fix loops.

Never spawn `architect`, create `implementation-plan.md`, or ask for plan
approval inside execution. Do not silently invent semantics. Distinguish
explicit `без плана` from `решай сам`: first keeps bounded direct execution;
second delegates formal planning decisions if Material Semantic Gap Gate says a
real plan is needed. Parent orchestrator routes that gap through `factory-planning`
and may resume requested implementation from approved plan.

An ordinary self-contained ticket does not require a separate plan. Choosing
files, existing patterns, edit order, and verification commands is execution
preparation, not semantic planning.

## Team Rule

Main session is teamlead. Stateful initial runs and `full_team` follow-ups
delegate production code, tests, review, investigation, and documentation to
canonical roles. Do not combine Developer, TestWriter, or DevReviewer
responsibilities in those pipelines.

`inline_self_review` is the only exception: after the Post-Completion Follow-up
Gate passes, Teamlead root owns bounded production and test edits, final-byte
verification, and diff self-review. The exception does not apply to an initial
run, unfinished/resumable run, different task or checkout, or `full_team`.

Use active runtime adapter:

- Codex: `.agents/adapters/codex.md`
- Claude Code: `.agents/adapters/claude.md`

Read `.agents/contracts/common/agent-checkpoint.md` before spawning any role. Apply it to
CodeExplorer, BugHunter, Developer, TestWriter, DevReviewer, and DocWriter; small
fixes and re-review passes are not exempt.

Use role contracts before spawning:

- Developer: `.agents/contracts/developer.md`
- TestWriter: `.agents/contracts/test-writer.md`
- DevReviewer: `.agents/contracts/dev-reviewer.md`
- CodeExplorer: `.agents/contracts/code-explorer.md`
- BugHunter: `.agents/contracts/bug-hunter.md`
- DocWriter: `.agents/contracts/doc-writer.md`

## Execution Inputs

Classify source independently from execution mode.

| Execution mode | Accepted source | Rule |
| :--- | :--- | :--- |
| `single_task` | direct request, local task Markdown, Factory Decompose task | Execute when outcome and semantic boundary are self-contained. No plan revision required. |
| `approved_plan` | approved `docs/plans/{plan_id}.md` or equivalent approved plan embedded/referenced by a ticket | Verify planning approval tuple, then execute requested plan scope without reapproval. |

Resolve task and plan references before choosing an execution mode.

Read [execution source contract](references/execution-source-contract.md) for
sufficiency, source lock, provenance, drift, and `execution-brief.md` rules.
When Reality Check must resolve technical placement, apply the shared
[implementation detail contract](../../contracts/common/implementation-detail.md).
Tiny fixes with no technical unknown do not run a ceremonial codebase check.

### Source Sufficiency Gate

Proceed when source defines:

- one observable outcome or one approved plan boundary;
- behavior included and excluded strongly enough to prevent scope invention;
- acceptance or a concrete way to verify the outcome;
- known blockers and explicit product/API/architecture constraints;
- enough boundary to keep remaining choices evidence-backed/local/reversible or
  route them by explicit no-plan/delegated-planning directive.

For a tiny direct request, plain language may satisfy these items. Do not demand
ceremonial fields.

Use `execution-source-contract.md#material-semantic-gap-gate` for the terminal
threshold. A semantic difference alone does not stop execution. All four gate
conditions must hold. Missing filenames, classes, exact tests, or edit order
never triggers planning by itself.

## Allowed Execution Preparation

Teamlead may create `.ai-pipeline/state/execution-brief.md` after source intake.
It is a source snapshot plus implementation checklist, not a plan:

- exact source provenance and hash;
- locked semantic claims copied without reinterpretation;
- relevant code paths and existing patterns found by Reality Check;
- proposed edit order and verification commands;
- technical risks that do not require a new semantic decision.

The brief has no independent decision log, question protocol, revision
approval, or invented acceptance. It may record bounded direct-execution
choices. If preparation exposes a `semantic_gap_candidate`, Teamlead applies
the Material Semantic Gap Gate, then continues locally, routes delegated
planning, or returns a terminal gap according to exact user directive.

Keep checkout-current findings in `execution-brief.md` and stop at the shared
contract's actionability boundary.

## Workflow Classification

| Workflow | Triggers | Pipeline |
| :--- | :--- | :--- |
| `feature` | new behavior, decomposed task, approved plan, multi-file feature | optional CodeExplorer -> source gate -> execution brief -> Developer -> TestWriter -> DevReviewer -> fix loop |
| `task` | broken existing behavior, bug, crash | BugHunter when needed -> source gate -> execution brief -> Developer -> TestWriter -> DevReviewer -> fix loop |
| `refactor` | behavior-preserving restructure or selected simplify findings | source gate -> execution brief -> Developer preflight -> TestWriter existing tests -> DevReviewer |
| `fix` | typo, copy, small style/config/UI tweak | Developer -> focused verification -> finalize |
| `review` | code review | Delegate `factory-code-review`. |
| `decompose` | split specification into tasks | Delegate `factory-decompose`. |
| `planning` | decide behavior, scope, architecture, API, readiness | Delegate `factory-planning`. |
| `explore` | explain or trace code | CodeExplorer. |
| `debug` | investigate without implementation authorization | BugHunter -> `analysis.md`. |
| `docs` | write project documentation | DocWriter. |

## Follow-up and Revision Requests

Apply the **Post-Completion Follow-up Gate** before normal Initialization. It is
eligible only when all conditions hold:

- a prior Factory Implement run is already `completed` and terminalized;
- request remains in the same parent task context and same checkout/worktree;
- no active or resumable `pipeline.md` or live writer exists;
- parent can lock the exact newly requested delta, current baseline/diff, and
  completed-run reference without reconstructing lost context.

If any condition fails, use normal Initialization and a stateful pipeline.
Eligible follow-ups lock only the new delta. Never inherit/restart the completed
source. Reality Check inspects consumers and test oracle before routing. Choose
by semantic risk and provability, never by line/file count:

| Route | Eligibility | Composition |
| :--- | :--- | :--- |
| `inline_self_review` | Mechanical change or explicitly specified local behavior inside one bounded package; focused/regression oracle is clear; no public API, DI, architecture, auth/security, storage/schema, networking contract, navigation/lifecycle, concurrency, generated-contract, or cross-package consumer impact. | Teamlead root edits production/tests, performs final-byte verification and final diff self-review, then reports `SELF_REVIEW PASS`. No teammate and no persistent Factory Implement state. |
| `full_team` | Any excluded/high-risk area, unclear behavior/test oracle, multi-package/public consumer impact, lost eligibility, or scope/risk growth. One-line changes are not exempt. | Start a fresh stateful run for follow-up delta only: Developer -> TestWriter -> DevReviewer. Preserve current partial diff/evidence and completed original work. |

The inline route never creates `.ai-pipeline/state/pipeline.md`, execution briefs,
test reports, or review reports. Parent context holds compact provenance until
final report. If work must become resumable, route to `full_team`.

Ambiguous workflow asks one classification question unless user delegated
planning decisions. A clear implementation request proceeds without a
workflow-confirmation checkpoint. Explicit `без плана` selects direct execution.
`Решай сам` selects direct execution only for local choices; material semantic
gaps route through `factory-planning` without question/approval pause.

## Initialization

Run Initialization only after the Post-Completion Follow-up Gate is ineligible
or selects `full_team`. `inline_self_review` does not create Factory Implement state.

1. Read `AGENTS.md`, active runtime adapter, and required role contracts. Read
   applicable actual documents: `docs/01_architecture_principles.md`,
   `docs/02_project_structure.md`, `docs/03_codestyle_and_rules.md`, and
   `docs/05_development_and_testing.md`; select behavior specs/decisions through
   `docs/specs/README.md` and `docs/adr/README.md`, and affected package READMEs.
   Network/playback uses `docs/04_network_and_playback.md`; commands/versions use
   `docs/melos_tooling.md` and `docs/vcs_guidelines.md`. Pass concrete read paths
   to delegated roles, including roles without inherited history.
2. Create `.ai-pipeline/state/`.
3. If active `pipeline.md` exists, show run summary and ask resume or fresh
   start. Fresh start closes agents and follows `shared-cleanup.md`.
4. Classify workflow, execution mode, and source kind.
5. Create manifest with unique `run_id`, source provenance, artifact ownership,
   and relevant checklist.
6. Run Source Sufficiency Gate before any production write.
7. For mutable source, re-read immediately before Developer and compare the
   normalized hash and any recorded source timestamp. Drift stops
   execution for re-intake.

## Canonical Roles

| Role | Purpose |
| :--- | :--- |
| `code-explorer` | Read-only code flow and integration-point analysis. |
| `bug-hunter` | Root-cause evidence in `analysis.md`; no plan ownership. |
| `developer` | Production implementation inside locked source boundary. |
| `test-writer` | Tests only. |
| `dev-reviewer` | One integrated source/correctness/architecture/tests review. |
| `doc-writer` | Documentation only. |

`architect` is not a Factory Implement role. It belongs to `factory-planning`.

All Flutter, Gradle, and code-generation commands run sequentially. Teamlead
serializes and validates delegated commands and project-wide completion gates.
Applicable final project verification is `check` → fixture `test:e2e` →
`build:android:prod:apk` through `fvm dart run melos run`, using
`docs/melos_tooling.md`: TestWriter directly runs `check` and fixture `test:e2e`,
then Developer directly runs the APK build; Teamlead validates their evidence.
Live tests and golden updates require explicit scope.

## Agent Checkpoints

These persistent handle rules apply to stateful pipelines.
Persist each delegated handle, last valid stage, contract-owned artifact, and
recovery status in `pipeline.md`. Progress messages improve visibility but do
not expire. Poll timeouts, silence, generic `running` status, and missing
wait/status/follow-up/interrupt capability never create failure and never
authorize automatic interruption. Wait for the role Done Signal and validate
its artifact before advancing. Never merge role responsibilities or run
duplicate writers against the same files.

Recovery starts only after explicit terminal runtime failure, a role-defined
blocked/failure signal, or an invalid returned handoff. Verify source/diff/report
state, then resume or retry the same role once from locked source and last valid
checkpoint. Recovery does not consume static, test-fix, or review-fix counters.
A second explicit failure returns `BLOCKED_AGENT_FAILURE` with resumable state;
do not ask a replacement role to invent missing semantic context.

## Shared State

For stateful runs, `.ai-pipeline/state/` is temporary execution/resume state.
Inline evidence is parent-held and produces none of these files.

| File | Writer | Purpose |
| :--- | :--- | :--- |
| `pipeline.md` | Teamlead | Run, source, gates, counters, artifacts, live agents. |
| `execution-brief.md` | Teamlead | Immutable source snapshot plus non-semantic execution checklist. |
| `analysis.md` | CodeExplorer or BugHunter | Code flow or root-cause evidence. |
| `refactor-report.md` | Developer/teamlead | Behavior-preservation evidence. |
| `test-report.md` | TestWriter | Test commands, coverage, result, and tested file hashes. |
| `review.md` | DevReviewer | Integrated review result. |
| `re-review.md` | DevReviewer | Original finding recheck. |

Every report starts with current `run_id` and `source_hash`. Reject stale or
missing headers.

## Pipeline References

| Workflow | File |
| :--- | :--- |
| `feature` | `references/feature-pipeline.md` |
| `task` | `references/task-pipeline.md` |
| `refactor` | `references/refactor-pipeline.md` |
| `fix` | `references/fix-pipeline.md` |
| `explore` | `references/explore-pipeline.md` |
| `debug` | `references/debug-pipeline.md` |
| `docs` | `references/docs-pipeline.md` |

Shared refs: `references/execution-source-contract.md`,
`references/shared-state.md`, `references/shared-gates.md`,
`references/shared-finalize.md`, and `references/shared-cleanup.md`.

## Gates

Stateful initial and `full_team` pipelines use role ownership below. Eligible
`inline_self_review` instead uses adaptive verification in `shared-gates.md`.

- Source Sufficiency Gate before production writes.
- Source Drift Gate immediately before Developer for external mutable source.
- Developer before TestWriter.
- Developer directly runs Static Gate preflight before tests when Dart code
  changes; Teamlead validates evidence but never executes commands.
- TestWriter owns direct test execution and current `test-report.md`.
- TestWriter before DevReviewer unless user explicitly accepts review with failing
  tests.
- DevReviewer directly runs final Analyze/DCM/Format Check after all writers,
  then compares diff with locked source semantics and project rules.
- Fixable `NEEDS_WORK` findings enter fix loop. `RETHINK` is evidence, not an
  automatic stop; Teamlead applies the Material Semantic Gap Gate. Factory Implement
  never revises source semantics.
- Refactor preserves behavior. Expected-value or golden behavior change requires
  task/feature authorization or planning.

Use `shared-gates.md` for retry limits and verdicts.

## Factory Minimality Ladder

Before new code, Developer checks:

1. Needed for current source outcome?
2. Existing helper, extension, widget, component, or pattern?
3. Dart, Flutter, UIKit, or native platform capability?
4. Already installed dependency?
5. Smaller correct diff?
6. Only then new code.

Minimality never removes security, trust validation, error handling,
accessibility, tests, or explicit requirements.

For graph freshness, follow
`references/shared-finalize.md#stateful-finalize`: the Teamlead owns one final
refresh after all writers finish. Delegates and reviewers may query the current
graph; refresh again only when a later change modifies indexed inputs.

## Failure Routing

| Failure | Action |
| :--- | :--- |
| Material semantic gap + delegated planning | Stop dependent writes; parent runs `factory-planning`, then resumes requested execution from approved plan. |
| Material semantic gap + explicit no-plan/none | Respect directive; return `NEEDS_PLANNING` with evidence. |
| Approved plan metadata invalid | Return `BLOCKED_NO_APPROVED_PLAN`. |
| Source drift | Return `SOURCE_DRIFT`; re-intake current source. |
| Missing technical detail only | Resolve through code Reality Check and execution brief. |
| Role semantic-gap candidate | Teamlead applies Material Semantic Gap Gate and exact directive routing. |
| Static Gate failure | Return to Developer; after two failed retries return `BLOCKED_STATIC_FAILURE`. |
| Untestable code | Developer improves seam inside source boundary; semantic seam choice routes planning. |
| Golden diff | Ask user; never update automatically. |
| DevReviewer `RETHINK` | Convert in-boundary technical fix to `NEEDS_WORK`; otherwise apply Material Semantic Gap Gate. |
| User/device action needed | Return `BLOCKED_USER_INPUT` with exact action. |
| Teammate unavailable or returns explicit terminal failure | Retry same role once from locked state, then return `BLOCKED_AGENT_FAILURE`. |
| Teammate remains `running` without messages/artifact | Continue waiting; silence and elapsed time are not failure. |

Never discard user changes or run destructive git cleanup.

## Language and Context Diet

Canonical skill, contract, adapter, and persona instructions are English.
User-facing reports and `.ai-pipeline/state/` files are Russian unless asked
otherwise. Preserve identifiers, commands, paths, and verdict tokens.

Later teammates read `execution-brief.md`, the locked source, and only relevant
files/docs. Disk source wins over inline context.

## Final Report

```text
Pipeline {type} completed.
Execution: {STANDARD/INLINE_SELF_REVIEW/FULL_TEAM}
State: {NOT_CREATED/STATEFUL}
Files: {count}
Static: {PASS/FAIL/NOT_APPLICABLE/NOT_RUN}
Tests: {PASS/FAIL/NOT_RUN}
Review: {SELF_REVIEW PASS/APPROVE/NEEDS_WORK/RETHINK/NOT_RUN}
Agents: {none/chain}
Cleanup: {PASS/FAIL/NOT_APPLICABLE/NOT_RUN}
Notes: {blockers or skipped gates}
```
