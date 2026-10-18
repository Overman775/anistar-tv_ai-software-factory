# Factory Planning Working Session

Internal discovery checkpoint used before a user-reviewable plan revision exists.
It protects recursive reasoning from interrupts without becoming another plan,
approval surface, or downstream contract.

## Artifact

- Path: `.ai-pipeline/staging/planning-session.md`.
- Audience: Factory Planning orchestrator only.
- Format: loose Markdown, not schema-validated.
- Lifecycle: mutable until a plan candidate is ready; retain on cancel, failure,
  or interruption.
- Downstream skills must ignore it. Only approved `docs/plans/{plan_id}.md` is a
  semantic execution/decomposition source.

Write it transactionally through a temporary sibling and atomic rename. Never
replace `.ai-pipeline/staging/planning-plan.md` with an incomplete session.

## Minimum Working Map

Keep only information needed to continue honest reasoning:

- stable source snapshot/reference and desired outcome;
- confirmed facts with evidence level and source;
- user-confirmed and AI-delegated decisions;
- open decision branches and their dependencies;
- contradictions between source, repository facts, and answers;
- external/research/out-of-scope handling;
- impact of the latest answer on scope, behavior, solution boundary, contracts,
  readiness, QA, and likely handoff.
- exact user directive mode: normal, explicit no-plan, or delegated planning;
- requested continuation: plan only, direct implementation, or decomposition.

This is a decision ledger, not a seven-section plan. Do not assign revision,
approval status, estimates, task IDs, or decomposition metadata.

## Recursive Question Loop

Build an internal v0 before asking. Look up facts in the environment instead of
asking the user. Batch Reality Check by semantic surface or owning
module/contract, reuse evidence across the session, and ask only decisions that
materially change the plan. Allow one narrow lookup follow-up for an unresolved
critical contradiction or blocker; never search repeatedly for harmless
uncertainty, wording, or individual symbols.

- Ask dependent decisions one at a time, with recommended answer and impact.
- A small batch is allowed only for genuinely independent decisions.
- Under delegated planning, do not ask `ASK` questions. Select the recommended
  evidence-backed option, record exact rationale and AI-delegated provenance,
  then run the same impact scan. `BLOCK` facts remain blockers.
- After every answer, update the working map and run an impact scan:
  compare with source/repository facts and earlier decisions; trace affected
  capabilities, flow, ownership, contracts, readiness, QA, and handoff; then
  resolve, ask, or bound every newly revealed branch.
- A contradiction is a new decision point, not permission to guess or silently
  prefer the newest statement.

No question-count exit exists. Stop discovery only when every material branch
is resolved or explicitly handled as `EXTERNAL`, `RESEARCH`, or `OUT_OF_SCOPE`,
and no unresolved contradiction prevents an honest ready plan. An unresolved
required fact remains `BLOCKED_REQUIREMENTS` at session level.

## Candidate and Preflight Loop

When discovery exit criteria hold:

1. Give Architect source lock and working map once. Complete maps use the fast
   path: do not repeat Reality Check or source search. Reopen only for missing
   evidence or contradiction. Apply the shared checkpoint contract; explicit
   terminal failure may continue this candidate inline, never through a second
   concurrent Architect.
2. Render a temporary complete candidate. Check behavior, decisions, full
   capability coverage, architecture/ownership, typed contracts, external
   handling, readiness, QA boundary, downstream usability, and section-role
   deduplication. Keep source-required detail; never shorten against a word
   target.
3. Semantic gaps return to this session and decision rules without consuming a
   revision. Machine-only defects get one internal repair and full check rerun.
4. Run `validate_plan.py --phase draft`, with `--previous` after first
   promotion. Atomically promote only after both checks pass.

First promoted user-reviewable plan is `revision: 1`. Before that promotion,
answers, candidate rewrites, and machine-only fixes create no revision. After a
revision has been presented, any semantic change creates revision `N+1`; a
nonsemantic correction keeps `N`.
