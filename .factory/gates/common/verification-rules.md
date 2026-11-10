# Verification Rules

Read this contract in Planning, Decompose and Implement. Criteria define the
minimum promised behavior, never the maximum allowed test coverage.

## Three independent groups

- **Acceptance:** observable source requirements with stable `AC-01` IDs.
  Each selected criterion needs concrete verification and current evidence.
- **Project:** applicable mandatory static, regression, E2E, build, docs and
  other project gates. They remain mandatory even when no AC mentions them.
  Use the applicable project rules and assigned check contract; do not replace the full suite with
  the tests selected for ACs.
- **Additional:** checks discovered during exploration, testing or review.
  They may be added without a semantic plan revision. An optional check is not
  permission to ignore a regression or violated requirement that it reveals.

## Shared obligations

New non-trivial logic (branch, loop, parser, money, security, data writes, or a
new script/app) needs a meaningful test or project-appropriate self-check.
Adequate existing tests count. One check is a floor, never sufficient by count
alone. Trivial changes need no new test unless requirements/project rules demand
one; applicable mandatory commands remain. Role boundaries own test writes;
production assertions never bypass independent testing or required suites.

Preserve source/AC identities and approved meaning. Missing mandatory evidence
is NOT_RUN/BLOCKED, never success. Do not weaken a valid failing test, hide an
open blocking defect or silently waive a project gate. Additional checks remain
allowed; classify failures with evidence. A file/hash or passed helper does not
prove semantic correctness or test adequacy. Existing authorization boundaries
for live access, golden changes, publication and installation remain in force.
