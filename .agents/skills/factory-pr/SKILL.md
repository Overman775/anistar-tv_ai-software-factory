---
name: factory-pr
description: "Prepare, create, update and follow up GitHub pull requests for the factory: PR descriptions, evidence, checks, review discussions and explicitly requested merge. Use for подготовь PR, создай PR, описание PR, проверь checks, разбери комментарии, merge PR. Technical code review uses factory-code-review."
metadata:
  credits:
    - skill: show-me
      author: Dex Horthy
      organisation: Humanlayer
      url: "https://github.com/humanlayer/skills/blob/main/plugins/show-me/skills/show-me/SKILL.md"
      description: "Concise visual explanations using diagrams, pseudocode, call trees and diff sketches."
    - skill: pr
      author: Matt Pocock
      url: "https://github.com/mattpocock/skills/blob/main/skills/engineering/pr/SKILL.md"
      description: "PR descriptions built around Summary, Evidence and Merge Danger, with credit to show-me."
---

# Factory PR

Make the change understandable to a reviewer who has not read the chat: show
what changes, provide observed evidence, and explain the consequences of merging.
Use the GitHub plugin for remote operations; keep project policy in the repository.

## Scope and tools

Match the requested operation. Reading a PR, checking a failed job or drafting a
description does not require the full publication/merge workflow. A request for a
description returns Markdown without remote writes. Technical review routes to
`factory-code-review`; implementation of review findings routes to
`factory-implement` with the relevant discussion and current diff.

Commit, push, PR/comment/review publication and merge require explicit user
instruction. Existing authorization is sufficient; do not ask again. A local
review verdict does not authorize publication or merge. Do not infer permission
for approval, auto-merge, branch deletion or release from a request to create a PR.
Standalone commit/push requests remain bounded Git operations; release/versioning
uses the repository's VCS guidance under its own explicit scope.

Discover the actual GitHub plugin capabilities first and inspect their schemas.
Prefer its PR, diff, checks, workflow logs and discussion tools. Use local Git for
checkout changes and verification. If the plugin cannot perform an operation,
use [CLI fallback](references/cli.md) only for that operation; plugin access does
not imply `gh` authentication. Report access failures without changing credentials.
If no tool can complete the action, preserve the useful draft and name the blocker.

## Repository context and evidence

Resolve repository/host from the actual remote, or from the supplied PR URL when
no checkout is needed. For local changes inspect branch, status and diff; preserve
user work. Read `AGENTS.md`, the applicable PR template and VCS rules. For AniStar
TV, `docs/vcs_guidelines.md` owns branches, title/commit conventions and merge
policy; `docs/melos_tooling.md` owns verification commands. Consult behavior specs,
ADRs and package READMEs only where needed to explain or assess this change.

Before drafting or publishing, gather the task/plan source, final change and
available verification evidence. Record base/head repositories, refs/SHA and
merge-base, including forks. For uncommitted work distinguish staged and unstaged
changes; do not present their combined state as an immutable branch diff. Obtain
all relevant file/comment/review pages. Missing or truncated patches require
complete local/fetched bytes or an explicit unverified scope. Re-read the head
after fetching; a changed head invalidates evidence tied to its previous contents.

Use matching Factory Implement results when available. If implementation and PR
preparation were requested together, capture the relevant results and tested file
hashes before temporary reports are cleaned up. Do not archive pipeline reports
or introduce permanent handoff state. If preparing a PR later, use available
evidence, verify that it still covers the change, and identify missing results.
Unknown history is not a successful check.

## Write the PR

Follow the repository template and requested language. When there is no template,
use the structure below. With an existing template, fit these three concerns into
its sections. Keep prose brief and use the project's domain vocabulary; consult
`GLOSSARY.md` if present. Write the title using current repository conventions.

### Summary

Lead with the concrete problem and resulting behavior. Show the smallest view
that makes the key change clear:

- a `diff` sketch for an existing behavior or structure;
- pseudocode or a call tree for logic and execution order;
- a shallow file/component tree for ownership or UI boundaries;
- Mermaid for interactions or data flow.

Keep only the calls, states, files and boundaries needed to understand the change.
Place the visual next to the short explanation it supports. Label sketches as
illustrations; do not present pseudocode as executed source. A tiny change may
need only a sentence; a diagram should earn its space.

Show a whole code block when most of that block is new, omitted context would
hide ownership or execution order, or a copyable example helps the reviewer.
Choose the smallest complete logical unit. For a large PR, summarize the overall
structure and include only a few short examples; link to larger blocks in the
diff. PR size alone does not justify reproducing whole files or the full patch.

### Evidence

Show **Before** and **After** using actual observations where available. For
visual changes, prefer comparable screenshots when the environment supports them.
For behavior changes, prefer execution evidence: the regression test/command,
observed failure and passing result. For refactors, document the relevant
behavior-preservation checks; do not invent a failure that never existed.

Include exact commands and concise results, tied to the tested revision or file
contents. Distinguish local checks, remote checks, fixtures, live verification and
manual observation. If Before was not captured or a check was not run, say so;
never invent output or replace a missing execution with a hypothetical result.
Link durable evidence when available; temporary local paths are not useful proof
for remote reviewers. Golden updates and live tests require explicit scope.

### Merge Danger

Describe both dimensions, with a brief explanation:

- **Door — one-way or two-way:** what a rollback requires and which effects
  survive a code revert, such as lost data, migrations or external side effects.
- **Blast Radius:** affected flows, consumers, platforms or contracts and the
  plausible consequences. Name the scope concretely; a one-word label alone is
  insufficient.

Use a proportionate assessment, including uncertainty that affects review. A
revertible commit does not prove that its runtime effects are reversible.

## Publish and follow up

Before an authorized write, verify the destination, target branch, head and exact
content. Use structured plugin arguments for multiline bodies. Search for an
existing PR for the same source/target before creating one, including after an
ambiguous create result; do not create a duplicate on retry. Read back the result,
report its URL and attach every created PR with the host artifact tool when
available. A draft PR may truthfully describe incomplete verification; it is not
a merge-readiness verdict.

For discussions distinguish conversation comments, formal reviews and inline
comments. Preserve the author, URL, full body and relevant replies. Inline
context includes path, side/line and commit/original position; anchor outdated
comments to the correct diff. REST root comment IDs and GraphQL review-thread
IDs are different. Use the operation's required ID; never try another namespace
after a lookup failure. Reading one comment does not establish complete thread
context. Publish replies/reviews or resolve threads only within the user's scope.

## Merge readiness

Before an explicitly requested merge, verify current head SHA, target,
draft/conflict/merge state and actual checks/review requirements. Use current
repository merge policy; do not infer stacks from change size or create mandatory
issues/epic branches. An agreed stack must preserve dependency SHA where required.

For a partial stacked task, implemented work must be complete and verified; every
deferred entry needs its concrete `completed_by` owner. For a finished feature,
acceptance must be complete with no required work deferred or reachable temporary
stubs/fixtures/`UnimplementedError`. Permanent fallbacks belong in the accepted
behavior. Verify affected production contracts; fixture success is not live proof.

Require fresh applicable local gates and completed technical review, plus the
actual remote requirements. For AniStar TV use `docs/melos_tooling.md`: `check` →
fixture `test:e2e` → `build:android:prod:apk` where applicable. Report check names,
tested commits, failures and missing evidence. Absent CI is not a green pipeline.
Do not merge while an applicable gate is unsatisfied.

Immediately before merging re-check the head and pass the expected SHA to the
merge operation. If it changed, reassess the new diff and affected evidence before
retrying. Do not bypass protections or implicitly enable auto-merge. Confirm the
actual merge result; branch deletion remains a separate scoped action.

## Attribution

See [CREDITS.md](CREDITS.md) for the contributions of Dex Horthy / Humanlayer
and Matt Pocock, original skill links and Factory adaptation details.
