# Factory Planning Plan Contract

Canonical contract for `.factory/memory/staging/planning-plan.md` and
`docs/plans/{plan_id}.md`. Plan is developer map, not evidence warehouse and not
ticket backlog.

## Ownership

Planning owns:

- goal, observable outcome, scope, non-goals;
- stable capabilities/requirements (`CAP-{NN}`);
- main behavior and meaningful exceptions;
- solution shape, ownership, behavior-shaping contract gist;
- decisions, unknowns, risks, developer readiness, QA intent;
- handoff recommendation.

Planning does not own task/slice IDs, task purpose, owning scope, affected
layers, estimates, ticket dependency graph, implementation/deferred task fields, or
publication ID. `factory-decompose` derives these later without changing approved
semantics. `factory-implement` may execute any approved plan after explicit user
choice or pre-authorized delegated continuation, even when recommendation is
`decompose`; report size/risk warning.

Never use future task/slice IDs in plan applicability or structure.

Plan content is the durable semantic layer. If information must remain true
after internal refactoring, keep it here. Task-local delivery detail belongs to
Factory Decompose; checkout-current paths, symbols, edit order, and commands belong to
Factory Implement execution preparation. A plan-only request stops without current
implementation-detail lookup.

## Metadata and State

Use exactly these metadata keys:

```text
plan_id: stable-kebab-case-id
revision: 1
plan_state: PLAN_READY
status: draft | approved
approved_revision: none | N
source: request | spec | local | mixed
handoff_recommendation: direct | decompose | either
```

No question budgets, counters, publication metadata, task counts, or estimates.

Only a complete preflight-clean plan becomes a user-reviewable revision.
Unresolved decisions, blockers, and recursive questions remain in
`.factory/memory/staging/planning-session.md` and must not replace the last
presented revision.

Approval invariants:

- user-reviewable draft requires `PLAN_READY`, `status: draft`, and
  `approved_revision: none`;
- approved requires `PLAN_READY`, `status: approved`, and
  `approved_revision == revision`;

Approval authorization has two forms:

- exact approval of presented revision `N`;
- explicit delegated planning captured before discovery, allowing planner to
  settle and approve a preflight-clean revision without another checkpoint.

Keep metadata unchanged. For delegated planning, record human-readable evidence
under `Source and context` as
`Planning authorization: explicit_user_delegation — "{exact directive}"`. This
distinguishes delegation from exact revision review without adding machine
contract fields.

First candidate promoted as reviewable plan is revision `1`. Normal mode
presents it; delegated planning proceeds to approval without pause. Before that
promotion, question answers, semantic candidate rewrites, preflight returns,
and machine-only repairs consume no revision. After promotion, semantic
change increments exactly once and resets approval. Semantic changes include
behavior, scope, outcome, solution shape, decision, contract gist, boundary,
readiness, verification, source conclusion, or handoff recommendation.
Formatting, spelling, URL normalization, and machine-only repair without
changed meaning keep revision and approval state for drafts. Coordinator owns
semantic classification. Default validator comparison is conservative; confirmed
formatting/spelling repair uses `--change-kind nonsemantic --change-evidence` with
specific rationale. IDs, metadata identity and approval-only byte invariants remain
mechanically checked. A classification does not prove unchanged meaning.
Approved bytes stay immutable in Git history. Keep one canonical
`docs/plans/{plan_id}.md`; do not create revision-specific plan files. Only explicit
user-authorized requirements changes start next draft revision in staging. After
approval, parent may replace canonical path only when previous approved bytes and
approval evidence are preserved in an immutable Git commit. Record prior/new
commits in session when available; never rewrite approved history. Existing runs
keep pinned bytes/revision/hash and require authorized re-intake for any drift.
Implement and Decompose cannot revise approved requirements to fit implementation.

Use the [shared plan content and canonical template](plan-content.md).

## Working Session and Questions

Use [Factory Planning Working Session](session-contract.md) before creating or
revising a user-reviewable plan. Active questions, `USER_DECISION`, `BLOCK`,
contradictions, and answer-impact history stay there; they are discovery state,
not canonical plan content. Promote only after its exit criteria hold and both
semantic and deterministic preflight pass.

## Transactional Persistence and Approval

For first revision candidate, later revision, or approval candidate:

1. Render complete temporary sibling; run semantic preflight, then validator.
2. A semantic gap returns to working session without replacing target or
   consuming revision. Repair machine-only defects without user approval.
3. Validate the temporary candidate, never live target. After first promotion,
   pass `--previous` for revision, approval-only, and nonsemantic transitions.
4. Flush when supported; atomically replace only after both checks pass. Keep
   previous valid target/checkpoint after failure or interruption.

Never use destructive cleanup. Cancel stops work and reports retained session
and plan paths. Normal approval is exact `Confirm revision N`; discovery
answers are not approval. Explicit delegated planning recorded before discovery
is advance authorization, not exact revision review. Approval-only metadata
transition does not increment revision. Both paths use same approval candidate;
approval candidate must differ only in approval metadata from validated draft.

`handoff_recommendation` advises. Without pre-authorization, user chooses
`factory-implement` direct execution or `factory-decompose` after durable approval. With an
original explicit implementation/decomposition request plus delegated planning,
parent orchestrator may continue requested handoff automatically; Factory Planning
itself never launches downstream.

Both downstream paths may apply the shared implementation-detail contract
without a new semantic approval. Factory Decompose adds slice-relevant anchors to task
Markdown; Factory Implement records checkout-current anchors in `execution-brief.md`.
Neither consumer changes approved behavior when current code placement differs.

## Execution sketch boundary

The parent may attach a separate non-authorizing agent workflow sidecar under
staging, bound to this plan revision/hash. It is not a new semantic plan section
or a ticket dependency DAG. Its assignments can change inside approved outcome
and check constraints; semantic changes still require a new approved revision.
