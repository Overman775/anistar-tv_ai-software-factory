# Execution Source Contract

Factory Implement executes a bounded source. Formal semantic planning belongs to
Factory Planning. A direct source may explicitly delegate bounded execution choices
to Factory Implement; this is execution authorization, not an internal plan.

## Execution Modes

Choose exactly one mode before production writes.

| Mode | Use when | Authorization |
| :--- | :--- | :--- |
| `single_task` | A direct request, local task, or Factory Decompose task defines one self-contained outcome. | The explicit implementation request authorizes only the source boundary captured at intake. |
| `approved_plan` | An approved `docs/plans/{plan_id}.md`, equivalent approved artifact, or ticket reference contains the execution boundary. | A valid approval tuple authorizes only the selected plan scope and exact approved content. |

Do not create another semantic artifact for `single_task`. Do not reinterpret,
revise, or reapprove an `approved_plan` inside Factory Implement.

## Source Kinds

Source kind is provenance, not execution mode:

- `direct`: current user request;
- `local_task`: local Markdown or other immutable task artifact;
- `factory_decompose_task`: published or local Factory Decompose task;
- `approved_plan`: approved plan artifact embedded in or referenced by another
  source.

Resolve task and plan references before choosing an execution mode.

## Source Sufficiency Gate

Proceed when current source establishes enough boundary for honest execution:

1. one observable outcome, or one selected approved-plan boundary;
2. included and excluded behavior sufficient to prevent scope invention;
3. acceptance criteria or a concrete verification method;
4. known blockers, dependencies, and explicit product/API/architecture
   constraints;
5. every remaining choice is resolved by locked source/project evidence, local
   and reversible without changing requested outcome, or routed by explicit
   user directive under rules below.

Plain language can satisfy this gate. Do not require ceremonial sections,
machine JSON, filenames, class names, exact tests, or an implementation order.

Missing technical placement is resolved by Reality Check. Examples: exact
files, existing helper choice, test command, class name, DI registration point,
or edit order. If choosing among alternatives would change source semantics,
apply the Material Semantic Gap Gate below instead of stopping automatically.

For nontrivial technical placement, follow
`.factory/contracts/common/implementation-detail.md` and write checkout-current
findings to `execution-brief.md`. Technical anchors resolve there; semantic
differences use the Material Semantic Gap Gate below.

## User Directives: No Plan vs Delegated Planning

Do not merge these intentions:

- `no plan`, `no plan needed`, or equivalent explicitly forbids formal
  planning. Keep `execution_mode: single_task` and make only bounded direct
  execution choices inside requested outcome.
- `decide yourself`, `do it yourself`, `at your discretion`, `do not ask questions`, or
  equivalent delegates decisions. Local choices stay in `single_task`; a
  material semantic gap routes automatically through Factory Planning, which creates
  and validates a real plan without question/approval pauses.

When both appear, explicit no-plan wording wins. Do not infer either directive
from urgency, silence, or a generic implementation request. Preserve exact
directive and requested continuation in locked source semantics and
`source_hash`. Neither directive creates a third execution mode.

Choose in this order:

1. established behavior and project pattern supported by source/code evidence;
2. smallest compatible solution and minimal diff;
3. local, reversible choice with narrow blast radius;
4. backward-compatible, data-preserving, security-preserving behavior; fail
   closed when uncertainty affects trust or access.

Record each bounded direct-execution choice in `execution-brief.md`:

```text
# Delegated execution decisions
- Choice: {what was selected}
- Rationale: {source/code/project evidence}
- Boundary/rollback: {why choice is bounded and reversible}
```

User delegation authorizes decisions, not invented facts. It never authorizes:

- fabricated backend/external API fields, credentials, secrets, provider
  behavior, or unavailable environment values;
- legal, compliance, business-owner, bank, store, or security approvals;
- weakening authentication, TLS, privacy, access control, or data protection;
- destructive target expansion, irreversible migration, or scope outside the
  requested outcome;
- contradicting explicit acceptance, constraints, or approved-plan content.

Use a specific external/tool/user blocker when missing evidence is factual.
Before returning that blocker, preserve the known request, exact directives and
explicit unknowns using the existing source-lock contract and `source_hash`.
This capture does not require a plan, graph, or approval. Do not invent provider facts.
When a material semantic gap remains:

- delegated planning present: stop dependent writes, pass locked source, exact
  directive, and requested continuation to Factory Planning; resume only from its
  approved plan;
- explicit no-plan present: respect it, do not create a plan, and return
  `NEEDS_PLANNING` explaining why direct execution is unsafe;
- no directive: return `NEEDS_PLANNING` normally.

If original request included implementation, parent orchestrator may continue
to Factory Implement automatically after delegated planning approval. Factory Planning
does not implement and Factory Implement does not plan.

## Approved Plan Tuple

For canonical `docs/plans/{plan_id}.md`, run Factory Planning validator in approved
phase. `status: approved` plus `approved_revision == revision` is sufficient
approval evidence. Compute content hash locally; never ask user to approve same
canonical revision again.

Before execution, record:

```yaml
plan_id: {canonical plan_id}
revision: {approved revision}
plan_hash: {SHA-256 of normalized approved content}
approval_state: approved
approval_evidence: canonical_plan_metadata | explicit_external_hash_approval
execution_scope: all | {CAP IDs or named bounded outcome already in plan}
```

`canonical_plan_metadata` is valid only for a canonical plan passing approved
validation. An equivalent external plan without canonical metadata requires
`explicit_external_hash_approval`; it must identify current content hash.
Generic permission to “continue” does not approve unknown external content.
Selected scope must already exist inside approved content.

For an external plan set `approval_evidence: explicit_external_hash_approval`
and supply `external_approval` with `state: approved`, `source_path`, raw-byte
`content_sha256`, exact `selected_scope`, `approved_by` and `evidence_ref`.
The parent records the real user's approval of those exact bytes and scope;
never manufacture approval or treat generic continuation as approval. The helper
checks the binding and required provenance fields, not the authenticity of a
message or the semantic sufficiency of the plan. The parent must inspect the
referenced approval before dispatch. Preserve the record in the locked source.
Canonical `docs/plans/` sources or frontmatter identifying a canonical plan
must use canonical validation; the external route cannot bypass it.

If tuple is missing, contradictory, stale, or names unapproved scope, return:

```text
BLOCKED_NO_APPROVED_PLAN
Evidence: {invalid or missing tuple fields}
Required: {exact approval artifact or user action}
Production writes: none
```

Do not repair tuple by changing plan content or inventing approval evidence.
Implementation request authorizes execution of locked scope; it is not another
semantic plan approval.

## Provenance and Normalized Hash

The source record keeps kind, execution_mode, ref/path or direct text, selected
scope and exact user directive. `hash` is SHA-256 of a deterministic JSON object
containing normalized content, kind, mode, selected scope and directive.
Normalize CRLF/CR to LF, strip trailing whitespace on each line and terminal
blank whitespace. No semantic claims or approval content are removed.
`content_hash` separately records SHA-256 of raw bytes for conservative drift
checking. `snapshot` preserves source text. Hashes serve different purposes;
reports use the semantic `hash`, not the content checksum.

Approved-plan sources require `kind: approved_plan`, `execution_mode:
approved_plan`, selected_scope and a real plan path. The runtime runs canonical plans through the plan
validator with `--phase approved`, or validates the explicit external approval
binding above; the parent verifies the selected CAP/outcome
and actual approval authorization too. Referenced plans must be resolved at
intake, never disguised as an unrelated direct ticket to skip validation.

## Source Lock

Lock these semantic claims at intake:

- observable outcome;
- included and excluded behavior;
- acceptance or verification contract;
- dependencies and blockers;
- explicit product, API, architecture, security, and compatibility constraints;
- approved-plan execution scope and approval tuple, when applicable.

Reality Check may correct technical guidance such as affected files, layers,
classes, existing helpers, exact tests, and edit order while preserving locked
claims. Source files, Factory Decompose tasks, and approved plans remain
read-only during execution.

Apply the shared information-lifetime rule: only checkout-current paths,
symbols, patterns, edit order, and commands enter the execution brief.

## Mutable Source and Drift

For a mutable source, including a local task or referenced plan:

1. read at intake and record semantic `hash`, raw `content_hash`, source snapshot and selected scope;
2. re-read immediately before every Developer production-write pass;
3. compare raw content hash; any byte drift requires conservative re-intake;
4. stop before writes when it differs.

Return:

```text
SOURCE_DRIFT
Source: {source_ref}
Old: {source timestamp and hash}
Current: {source timestamp and hash}
Changed semantic claims: {summary or unknown pending re-intake}
Production writes: none in current pass
```

Re-intake current source. If it remains self-contained, start a fresh source
lock and brief. If it creates a semantic-gap candidate, apply exact directive
routing and the Material Semantic Gap Gate.

## Execution Brief

Teamlead may write the assigned task-scoped execution brief after source intake
and code Reality Check. It is non-semantic execution preparation.

Required header and shape:

```yaml
run_id: {current run id}
source_hash: {current source hash}
execution_mode: single_task | approved_plan
source_kind: {kind}
source_ref: {ref}

# Locked source
- Outcome: {copied or faithful compact restatement}
- In scope: {source claims}
- Out of scope: {source claims}
- Acceptance: {source claims}
- Constraints and blockers: {source claims}

# Reality Check
- Paths and existing patterns: {verified evidence}
- Current technical anchors: {only behavior-relevant current references}
- Technical discrepancies: {source guidance -> code reality}

# Execution checklist
- Files or areas: {non-binding technical map}
- Edit order: {order}
- Verification commands: {commands}
- Technical risks: {risks that need no new semantic decision}

# Delegated execution decisions
- Choice: {bounded direct-execution choice only}
- Rationale: {source/code/project evidence}
- Boundary/rollback: {bounded and reversible boundary}
```

Write brief prose in the task/project language, otherwise the dialogue language.
Preserve required template headings. Preserve
identifiers, commands, paths, hashes, and verdict tokens exactly.

Allowed content: provenance, locked source snapshot, verified code evidence,
existing-pattern selection, edit checklist, verification commands, technical
risks, and bounded direct-execution choices authorized by source/no-plan scope.

Apply the shared anchor and bounded-check rules. Full signatures belong here
only when null/omission, serialization, replacement, or ordering affects source
behavior.

Forbidden content: invented outcome or acceptance, scope changes, choices not
covered by source or bounded direct-execution rules, fabricated facts/contracts,
question protocols, approval revision, or an independent decision log. The
brief cannot authorize work beyond source.

Freeze brief before Developer starts. Later technical deviations are reported
in implementation/test/review results and must remain inside source lock.

## Material Semantic Gap Gate

Classify `NEEDS_PLANNING` only when all conditions hold; exact directive decides
whether result is internal handoff or terminal response:

1. unresolved choice materially changes observable behavior, public contract,
   security posture, acceptance, scope, or requested task outcome;
2. locked source, verified code, and established project patterns do not select
   one answer;
3. alternatives have materially different non-local, irreversible, migration,
   compatibility, or ownership consequences;
4. choice cannot be handled as a bounded, local, reversible direct-execution
   choice without formal semantic planning.

If any condition fails, choose through project-pattern/minimality ladder, record
the reason when material, and continue. If all conditions hold, route by user
directive: delegated planning starts Factory Planning; explicit no-plan or absent
delegation returns terminal `NEEDS_PLANNING`. A missing fact is not automatically
a planning gap; return specific external, tool, approval, or user-input blocker.

Delegated roles report a `semantic_gap_candidate` with evidence. Teamlead alone
applies this gate and chooses local continuation, delegated Factory Planning handoff,
or terminal `NEEDS_PLANNING`. Do not discard authorized completed work. Stop
only production writes whose correctness depends on gap; independently complete
locked slice may continue when source already authorizes it.

A `semantic_gap_candidate` names evidence, unresolved choice, downstream impact,
and directive mode (`none | no_plan | delegated_planning`). It is investigation
evidence, not a terminal Done Signal.

Return exact shape:

```text
NEEDS_PLANNING
Source: {source_ref} ({execution_mode})
Evidence: {code/source conflict or missing claim}
Missing decision: {one concrete semantic decision}
Why execution cannot decide it: {downstream behavior/scope impact}
Directive: none | no_plan | delegated_planning
Routing: terminal gap | Factory Planning handoff | factual blocker
Suggested planning input: {files, logs, API/UI evidence}
Production writes: none | stopped; existing diff preserved
```

Route semantic work to `factory-planning`. After delegated Planning passes its
completion gate, Factory Implement resumes the same work only from a valid
`approved_plan` tuple. An independently authorized new self-contained `single_task`
source is a separate intake.

## Dynamic batch application

Apply this contract separately to every source/task in a fixed batch. Snapshot
and hash in workflow.json are per source; task/node/dispatch IDs disambiguate
reports. Referenced plan approval still requires validate_plan.py. Do not use one
source hash or mutable singleton brief for unrelated tasks. Re-intake invalidates
affected assignments/evidence and retains counters; it never silently approves
new semantics. The execution graph is technical preparation under
`.factory/workflow/orchestration.md`, not a second semantic plan.

Use `workflow.py reintake` with the revised graph, reason and actual source/user
authorization evidence after quiescing writers. It relocks sources, revalidates
approvals and invalidates old node evidence while preserving all counters. New
tasks need a separate run; source revision is not a retry-budget reset.
