# Factory Planning Working Session

## Artifact

The Planning run retains the working evidence, cited questions, owner answers, draft and review in SQLite. Resume by run ID. Read its bound worker packet to continue an assignment. Published plans are ordinary Markdown in the agreed project location.

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

Architect returns the complete draft and any execution sketch through its dispatch. Validate machine structure with `cli planning validate --phase draft --plan CANDIDATE --json`. The coordinator independently checks scope, behavior, architecture, coverage, external handling, QA and the source of each decision. Resolve semantic gaps with the owner or delegated authority. Preserve the current public revision until approval and publication. Version semantics and the canonical template are in the [plan contract](plan-contract.md).
