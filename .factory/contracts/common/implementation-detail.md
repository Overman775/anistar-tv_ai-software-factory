# Implementation Detail

Use this shared contract when an approved plan, Factory Decompose task, or
self-contained execution source needs enough current implementation detail for
a developer to start safely. It reduces ambiguity without turning semantic
planning into a code inventory or prescribing production code.

## Information Lifetime

Place information according to how long it should remain true:

| Lifetime | Artifact | Content |
| :--- | :--- | :--- |
| Durable | approved Factory Planning plan | behavior, ownership, contract gist, constraints, acceptance |
| Delivery | Factory Decompose task | vertical slice, task-local flow, dependencies, relevant current anchors |
| Checkout-current | Factory Implement execution brief | exact paths, current symbols/patterns, edit order, commands |

Use this test:

- must remain true after an internal refactor -> planning semantics;
- defines one independently deliverable result -> task content;
- mainly helps locate or edit code today -> execution preparation.

Planning-only work stops at the durable layer. Do not collect implementation
detail merely because a plan was created.

## Actionability Boundary

A task or execution brief is actionable when a developer can answer:

1. What triggers the flow and what observable result is required?
2. Which boundary supplies input or receives effects, and who owns them?
3. Which success, empty, error, retry, or no-op paths apply?
4. Which neighboring flows or states remain unchanged?
5. How is completion verified?

New class/file names, private helpers, BLoC event shape, state mechanics, and
exact test structure remain developer-owned. A Factory Decompose task does not
prescribe them. An execution brief may record existing paths, symbols, commands,
and edit order, but not invent production design.

## Risk-Adaptive Depth

Use only the profile relevant to the flow; never apply every item by quota.

- Static UI: projection source, visible states, Figma/UIKit reference,
  interaction or explicit passivity, and relevant zero-effect boundary.
- API read: trigger, operation, behavior-shaping inputs/output, lifecycle, and
  applicable cache, retry, or isolation rules.
- Mutation or storage: write semantics, confirmed or optimistic state,
  success/no-op/failure/rollback, persistence, and dirty outcome.
- Navigation or local contract: producer, consumer, input/output, binding owner,
  dismiss/result semantics, and preserved host state.
- Integration or concurrency: competing scenarios, accepted/ignored result,
  preserved state, and observable recovery.
- Technical preparation: stable contract, named consumers, and verification.

## Anchors and Bounded Check

An anchor is an existing generated API operation/DTO, public route or service,
storage key, UIKit component, or required reuse target. Exact anchors are
optional current references. Include one only when it materially reduces
ambiguity and is present in locked evidence or confirmed by one bounded targeted
lookup.

For one plan or execution source:

1. Stabilize semantic coverage and delivery boundaries before code lookup.
2. Group high-value anchors by module or contract surface and run one batched
   pass, not one pass per task.
3. Allow one narrow follow-up only for an unresolved critical boundary; read its
   declaration and local context, not complete clients or feature trees.
4. Reuse evidence and stop when the actionability boundary is satisfied.

Prefer public or generated boundaries. Do not inventory private symbols, fields,
helpers, or transitive dependencies, and do not name new implementation symbols.
Include a full signature only when null/omission, serialization, replacement, or
ordering changes behavior. Otherwise use operation, boundary, and meaningful
inputs/outputs.

An unconfirmed non-semantic anchor uses honest contract-level wording. A missing
or renamed method/class alone never returns `NEEDS_PLANNING`. Approved semantics
need no downstream re-verification and current code never silently overrides
them.

## Human Output and Deduplication

State each fact in its owning section:

- implementation/task flow: behavior sequence and effects;
- scope/deferred: only delivery boundary and temporary behavior;
- architecture context: ownership, reuse anchors, and constraints;
- acceptance: observable checks and high-risk invariants;
- contract/reference section: compact fingerprint and source links.

Do not repeat full signatures, decision rationale, DTO inventories, or state
matrices across sections. No minimum bullet count or word target: detail follows
risk, not document size.

## Escalation

- Missing or renamed technical anchor or placement: use contract-level wording
  or resolve in checkout-current execution preparation.
- Code contradiction or a new product, API, architecture, security,
  compatibility, or acceptance choice: return one semantic-gap candidate with
  evidence to the owning planning gate.
- Missing external fact: return the specific external, tool, or user blocker.

Do not research any gap in a loop or rewrite locked plan/task semantics.
