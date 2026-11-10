# Shared gates

These checks apply regardless of runner or number of agents. Source boundaries
and user-required verification outrank an economical composition.

## Transition contract

A check produces evidence; a gate decides whether a stage can finish. Project
supplements arrive as project_policy.gates. Reserve project-checks on every node
with a command gate; require its receipts before PASS. WRITES_READY cannot defer
that gate. Final verify repeats the complete required set after all writers.
Judge answers project_policy.review_criteria through review_checks; existing
independence, findings, verdict and final acceptance rules still apply.

## Source and drift

Use [source sufficiency](../../skills/factory-implement/references/execution-source-contract.md#source-sufficiency-gate)
and [material gap](../../skills/factory-implement/references/execution-source-contract.md#material-semantic-gap-gate) per
source. Re-read mutable sources before every writer/correction and acceptance.
Drift stops dependent work for re-intake; do not update the hash to hide it.
`no plan` forbids formal planning; delegated planning allows the Planning
handoff, never invented facts or missing external approvals.

## Author checks and integration

Developer writes production, TestWriter writes tests, Generalist may write both
under its own contract. Authors run relevant checks directly; parent validates
the returned evidence and serializes shared commands. Tests express locked
behavior, mock dependencies rather than the subject, and cover success, failure,
boundary and no-op where applicable. Untestable code returns to its owner for an
in-scope seam. Never weaken correct tests or silently update golden baselines.

All relevant writers, including documentation, finish before the authoritative
verification snapshot. Join isolated branches before testing integrated behavior.
Check the final actual tree, not a sum of independent branch PASS reports.

## Static and project commands

Read [project checks](../../skills/factory-implement/references/project-checks.md) and selected project rules. The profile
owns commands, applicability and order; the shared contract owns evidence and acceptance.

## Test and verification evidence

Each report must match run, task, node, dispatch and source. Exact scope and
SHA-256 bytes must match the current tree after execution. Every executed check
records kind (`tests`, `static`, `docs`, `build`), cwd, exact command, integer exit
code and concise relevant output. `PASS` requires required commands to succeed;
missing/empty evidence cannot pass. A tool launch failure is `BLOCKED_TOOL_ERROR`.
A required failed check cannot be called success merely because it predates the
change; report the limitation and obtain an explicit narrowed acceptance if needed.

`FAIL_CODE` returns to code author; `FAIL_TEST` to test author; `GOLDEN_DIFF` to
user; behavioral conflict to source/planning owner; unclear cause to diagnosis.
For failure investigation use the [diagnostic sequence](../../skills/factory-implement/references/project-checks.md#diagnose-before-a-broad-rerun).
A clear failure stays with its current owner; add BugHunter only for an uncertain
cause. Check selection/completion evidence under the common check-execution contract.
Refactor retains expected values, scenarios and baselines. Mechanical test import,
setup or mock changes are allowed but cannot redefine behavior.

## Review and docs

Use one final integrated Judge for every task requiring independent review.
Optional scoped reviewers contribute findings; their reports do not replace the
final source/correctness/architecture/tests/docs pass. Reviewer is a distinct
logical and physical agent from every author. Code, tests, docs and formatting
are read-only. Missing required passing tests prevent APPROVE; diagnostic review
of failed tests is allowed only when requested and never establishes acceptance.

Stable findings include severity, path/line, source, violated rule, impact and
bounded fix. Initial IDs are `REV-1` etc.; re-review marks each as FIXED,
NOT_FIXED or REGRESSION and checks new defects. A new finding gets a new ID.
`RETHINK` signals a possible semantic gap; the parent decides whether it is an
in-scope technical fix or a Planning handoff.

Update affected docs/specs automatically. Small updates belong to author; broad
updates to DocWriter. Verify links, examples and described behavior. A spec is
not rewritten to justify buggy code; approved source remains immutable. If no
update is needed, record why. After any correction refresh affected test/static,
docs and review evidence against final bytes before acceptance.

## Limits and continuation

Initial pass plus at most: static retries 2; test-fix 2; review-fix feature 2,
task/refactor/fix/docs 1; docs revision 2. Integrated feature acceptance uses its
stable integration task with review-fix 2. Explicit runtime failure recovery 1
is separate. Preserve task+stage counters across agents/sessions/graph revisions.
Do not count silence, polling or mere unavailable optional capabilities as a
failure. On exhaustion preserve resumable work and report the exact cause.

## Acceptance minimum and additional checks

Apply [the shared acceptance contract](../common/verification-rules.md).
The source AC registry is a mandatory minimum, not an exhaustive test inventory.
All gates in this file remain applicable independently of AC coverage. Populate
required_checks with both concrete acceptance scenarios and applicable project gates.
TestWriter/Generalist may add negative, boundary, regression and diagnostic checks
without changing agreed behavior. Classify and resolve discovered failures; optional
execution never makes a blocking product defect optional. Unknown/incomplete mandatory
results block acceptance. Independent review checks semantic coverage and the actual
meaning of reported evidence, including test selection and final integration.
