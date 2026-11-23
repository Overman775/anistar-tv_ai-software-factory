# Plan content and template

## Reality Check Taxonomy

Use `INFO | ASK | BLOCK` internally. Present only resulting decisions and
unknowns, not a second Reality Check report.

Working-session statuses:

- `USER_DECISION`: pending choice kept in session until resolved;
- `BLOCK`: required fact/decision preventing a ready plan.

Working-session provenance may distinguish user-confirmed, evidence-backed
default, and explicitly AI-delegated choices. The reviewable plan does not
expose a decision-status state machine: approval authorizes the complete settled
revision either exactly or through recorded advance delegation.

Evidence levels:

- `official_fact`: specification, official API/platform documentation;
- `user_acceptance_observation`: user-confirmed expected behavior or observed
  acceptance evidence;
- `project_fact`: repository, project docs, current runtime evidence;
- `inference`: explicit reasoning, convention, or assumption.

Use evidence levels for facts in solution/evidence and for working-session
provenance. Never present inference as fact. Explicit planning delegation may
settle behavior, UI/design, app-owned API/architecture, scope, and technical
choices inside requested outcome. It cannot fabricate backend/external facts,
credentials, legal/compliance or security approval, or justify weaker
protection. Prefer safe, reversible, evidence-backed choices.

Reviewable-plan item ownership:

- `D-{NN}`: a settled choice changing behavior, scope, ownership, or a material
  constraint. Decision row contains final choice, reason, applicability, and
  verification/constraint.
- Source/project facts: live in `Solution structure` or
  `Contract and evidence`;
  they do not receive `D-*` IDs merely to prove the plan was researched.
- `EXT-{NN}`: unresolved externally owned fact/dependency with owner and
  handling, declared only in `Unknowns and boundaries`.
- Research result: describe under research/timebox; unresolved research gets
  explicit handling there, not a decision status.
- Out-of-scope boundary: state under `Out of scope` or boundaries, not as a
  decision row.

Split partially resolved external facts: resolved part becomes ordinary fact;
unresolved subfact keeps its own `EXT-{NN}` and handling.

## Human-first Rules

Ordinary prose follows task/project language, otherwise the dialogue language.
Exact identifiers, machine values, paths, commands and required headings stay intact.
Use natural wording in the chosen language; `loading/error/retry/empty` and similar
state words are ordinary prose unless they are exact identifiers.
Run one wording pass on the rendered candidate only; do not count language ratios,
maintain a glossary, or search code solely for wording.

Mandatory H2 sections are exact and ordered:

1. `## What changes`
2. `## How it works`
3. `## Solution structure`
4. `## Key decisions`
5. `## Unknowns and boundaries`
6. `## Readiness and verification`
7. `## Handoff`

First three let developer understand plan without reading evidence trail.

- Name problem, outcome, in-scope capabilities, and non-goals concretely.
- Give one numbered primary flow. Add a compact exception/decision table when
  flow branches; do not bury branches in prose.
- Describe component responsibility and ownership before paths/symbols.
- Exact files/classes/methods are optional and only decision-critical.
- Give each capability a stable execution seed: observable behavior, owner,
  behavior-shaping boundary, applicable states/effects, constraints, and
  acceptance. Do not turn that seed into an implementation inventory.
- Current code anchors may appear as evidence-backed references when they decide
  architecture or compatibility. Names that only help locate code downstream
  stay out of the durable plan.
- Earlier sections describe resulting behavior and ownership. Keep decision
  reason/evidence once in `Key decisions`; reference `D-{NN}` where useful
  instead of copying its rationale.
- When no settled choice changes behavior, scope, ownership, or constraints,
  write exactly `- No significant decisions.` under `Key decisions`. Do not
  manufacture a decision from a source fact or implementation detail.
- Keep full API/platform fingerprint internal. Plan shows only fields,
  callbacks, payload, key, or local contract details changing behavior.
- Do not optimize for a fixed word count. Large sources may require large plans;
  remove repetition, evidence dumps, and non-decision implementation detail.

Section-role deduplication map:

- `What changes`: problem, outcome, scope, and non-goals; no decision rationale.
- `How it works`: sequence and branches; reference `D-*` without retelling
  why the choice was made.
- `Solution structure`: responsibility, ownership boundary, and contract gist;
  its `Why` cell explains component placement, not the full decision history.
- `Key decisions`: the single full statement and rationale for each choice.
- `Unknowns and boundaries`: only unresolved external facts, research handling,
  and risks; do not restate settled decisions.
- Developer acceptance: observable deterministic outcomes, without rationale or
  device/integration matrix. QA: runtime, device, and integration evidence only.
- When an `EXT-*` prevents implementation of named capabilities, add a compact
  readiness matrix under `Developer acceptance and readiness`: capability,
  current readiness, and exact start condition. This makes `PLAN_READY` mean
  "semantic map is ready" without pretending all development can start.
  External items that affect only QA/release do not require the matrix; state
  that boundary in one sentence instead. Do not add readiness tables by quota.

A short repeated guard condition is allowed when a flow or check would otherwise
be ambiguous. Do not copy the full rationale, source trail, or risk explanation
across sections. Deduplicate semantically; never use word count or text-similarity
thresholds as a quality gate.

Pseudocode is optional. Use only when state machine, reducer, schema, or
algorithm is clearer than prose. Put it under `### Behavior pseudocode` in a
`text` fence, using natural-language lines. Describe states and decisions; no
production code, method bodies, imports, braces, semicolons, or code syntax.

## API Evidence

Every plan has compact contract/evidence table in `Solution structure`:

```markdown
### Contract and evidence
| Applicability | Contract type | Behaviorally significant details | Evidence |
| :--- | :--- | :--- | :--- |
| CAP-01 | backend_api | `status` changes the available action | official_fact: URL Swagger |
| CAP-01, CAP-03 | local_contract | Shared outcome changes both screens | project_fact: coordinator contract |
| CAP-02 | external_contract | Provider rules constrain the scenario | official_fact: provider documentation |
| global | none | External contract not involved | project_fact: current scenario |
```

Allowed types:

- `backend_api`;
- `platform_plugin_api`;
- `storage`;
- `local_contract`;
- `external_contract`;
- `none`.

Use `external_contract` for behavior-shaping rules owned by an external service,
provider, SDK vendor, or integration specification when they are not a backend
endpoint contract or platform/plugin API.

`none` is explicit evidence classification, not missing analysis. Fingerprint
may live in optional internal evidence but never becomes mandatory plan bulk.
`Applicability` accepts `global` or a comma-separated list of declared `CAP-*`
IDs. Combine capabilities when one evidence statement is genuinely shared; do
not duplicate a row only to satisfy formatting. Every declared capability must
be covered by at least one typed row; `global` covers all capabilities and
`none` is valid explicit coverage.

## Canonical Template

````markdown
# Plan: {short title}
plan_id: {stable-kebab-case-id}
revision: {N}
plan_state: PLAN_READY
status: draft | approved
approved_revision: {none | N}
source: request | spec | local | mixed
handoff_recommendation: direct | decompose | either

## What changes
- Problem/goal:
- Observable outcome:
- In scope:
  - CAP-01 — {complete capability or requirement}.
- Out of scope:
- Source and context:
- Planning authorization: {awaiting revision approval | `explicit_user_delegation` — "exact user wording"}.

## How it works
### Main flow
1. {Action/user or system state}.
2. {Next observable behavior}.

### Exceptions and branches
| Condition | Behavior | Related decision |
| :--- | :--- | :--- |
| ... | ... | D-01 |

### Behavior pseudocode
```text
Optional natural-language lines only when clearer than prose.
```

## Solution structure
| Area/owner | Responsibility and change | Why | Decision |
| :--- | :--- | :--- | :--- |
| ... | ... | ... | D-01 |

### Contract and evidence
| Applicability | Contract type | Behaviorally significant details | Evidence |
| :--- | :--- | :--- | :--- |
| CAP-01 | local_contract | ... | `project_fact`: ... |

## Key decisions
| ID | Decision | Why | Applicability | Verification/constraint |
| :--- | :--- | :--- | :--- | :--- |
| D-01 | ... | ... | CAP-01, CAP-03 | ... |

`Applicability`: comma-separated declared `CAP-{NN}` or
`global`, but not future task IDs. Facts and external dependencies do not become
decision rows.

If there are no significant decisions, replace the table with:

```markdown
- No significant decisions.
```

In that case use `—` in the preceding `Related decision` and
`Decision` cells. Each referenced `D-*` must have one declared decision row.

## Unknowns and boundaries
- External dependencies and handling:
  - EXT-01 — {external owner and missing fact}; handling: {what, who verifies it and when}.
- Research, timebox and outcome:
- Risks:

## Readiness and verification
### Acceptance criteria
| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | CAP-01 | {Observable mandatory outcome} | {How to verify the outcome} |

### Developer acceptance and readiness
- Acceptance:
- Readiness:

{Optional, when external dependencies delay implementation:}

| Capability | Current readiness | Start condition |
| :--- | :--- | :--- |
| CAP-01 | Partially ready | Contract EXT-01 published |

### QA checks
- {Observable user/integration check}.

## Handoff
- Recommendation: `direct | decompose | either`.
- Why:
- What the next stage receives:
- Warning/conditions:
- Continuation: {awaiting user choice | pre-authorized direct execution | pre-authorized decomposition | plan only}.
- Recommendation alone does not authorize continuation.
````

Omit optional pseudocode. Do not rename or omit mandatory H2 sections. A
presented plan contains no active question subsection, `USER_DECISION`, or
`BLOCK`; those remain in planning session until resolved.
Pre-authorized continuation requires recorded `explicit_user_delegation` plus
the matching original downstream request; otherwise use `awaiting user
choice` or `plan only`.

## Quality Bar

- Plan can be read top-to-bottom once; first three sections explain feature.
- Every capability is semantically executable either directly or after task
  slicing, without requiring exact current file or symbol names.
- Main flow is numbered; branches use decision table when meaningful.
- No fake precision: task IDs, estimates, dependency graph, or file inventory.
- Every unknown has owner/handling; every readiness claim is observable.
- Every declared `CAP-*` has typed contract coverage; every `EXT-*` names its
  owner or missing fact and has explicit non-empty `handling:`.
- A developer-blocking `EXT-*` maps to affected `CAP-*` readiness and an exact
  start condition; QA/release-only externals do not force a ceremonial matrix.
- No unresolved decision, contradiction, active question, or blocking fact is
  hidden inside a presented revision.
- `Developer acceptance and readiness` is separate from `QA checks`.
- Every `D-*` is a real choice; facts stay in solution/evidence and every
  referenced `EXT-*` has one boundary declaration with handling.
- Architecture and ownership satisfy full canonical architecture sources; they
  are never reduced to a feature-code guess.
- Each section has a distinct job: rationale is not copied across flow,
  solution, decisions, acceptance, and QA. No fixed word-count target applies.
- No `TBD`, hidden requirements, copied full Swagger response, implementation,
  test execution, task publishing, decomposition, or downstream launch.

## Stable acceptance criteria

The AC table above is mandatory and follows the [shared contract](../../../gates/common/verification-rules.md).
Keep stable IDs across revisions; reference the source requirement in the criterion's
wording/context. Every promised outcome needs appropriate coverage; validator checks
rows/identities/applicability, while Architect and parent check semantic completeness.
Project gates remain separate and additional tests may be discovered downstream.
QA may explore beyond this minimum; a new test alone does not revise approved behavior.
