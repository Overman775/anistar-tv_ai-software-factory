# Functional-first Decomposition Policy

Define task boundaries, estimates, dependency topology, and temporary behavior
from one approved Factory Planning plan.

## Ownership

Decomposition owns ticket structure. It never revises plan semantics.

| Factory Planning owns | FactoryDecompose owns |
| :--- | :--- |
| Goal, behavior, scope boundary, solution shape, decisions, contract fingerprint, acceptance meaning, risks, QA boundary, capability IDs | Task IDs, vertical slices, purpose, owning module, affected layers, estimate, dependencies, blockers, `implemented`/`deferred` allocation, task Markdown |

Approved plan remains immutable. If honest slicing requires new behavior,
architecture/API/product choice, acceptance meaning, or a capability missing
from plan, return `NEEDS_PLANNING`.

## Capability Coverage

Build an explicit internal mapping before task files:

| Capability | Tasks | Coverage |
| :--- | :--- | :--- |
| `CAP-01` | `orders-list-core-01` | complete |

Every plan capability resolves to one of:

- `complete`: implemented by listed tasks;
- `external`: no code task, plan names owner and handling;
- `out_of_scope`: explicitly excluded by approved plan.

No capability may silently disappear. A task may cover several capabilities.
A capability may split across tasks only for real size, path, state, operation,
or verification boundaries. Task IDs never appear back in planning plan.

## Core Principle and Size

> Plan is unit of semantic agreement. Task is unit of convenient, verifiable development.

- Target task size: about 8 hours.
- Cohesive task up to 16 hours is allowed.
- Split larger work by behavior, path, state, operation, or verification seam.
- Keep loading/loaded/empty/error/retry together when one cohesive outcome fits.
- Domain, Data, Presentation, native platform, and tests may belong to one task.
- Never use `Setup -> Domain -> Data -> Logic -> UI` slicing.

Plan may recommend `direct`, `decompose`, or `either`; recommendation is advice.
When user explicitly invokes FactoryDecompose, decompose approved capabilities even
if direct execution was recommended.

## Output Shape

Output shape follows reviewed task count, not planning metadata:

- exactly one task up to 16 hours -> standalone task file;
- two or more tasks -> epic publication package.

FactoryDecompose owns stable `publication_id` for epic output. Planning never stores
publication ID or promised task count. If one approved outcome honestly exceeds
16 hours, split it into independently verifiable tasks when plan semantics stay
unchanged. Return `NEEDS_PLANNING` only when split exposes a missing semantic
decision, not merely because output becomes an epic.

## Task Purpose

| Visible label | `purpose` | Meaning |
| :--- | :--- | :--- |
| Функциональность | `functionality` | Implement or change behavior. |
| Техническая подготовка | `technical_preparation` | Prepare known foundation with named consumers. |
| Исследование | `research` | Resolve an approved unknown within a timebox. |

Integration is not separate purpose. Technical preparation requires
`consumers`. Research requires `research_question`, `timebox_hours`, and
`expected_result`. Do not invent research to avoid a planning gap.

## Decomposition Order

1. Read approved outcome, capabilities, decisions, acceptance, and QA boundary.
2. Map capabilities to observable vertical results.
3. Select task purpose and owning scope.
4. Estimate complete result including deterministic tests.
5. Split only when size or independent verification requires it.
6. Map affected components and layers after boundaries stabilize.
7. Allocate `implemented` and mandatory temporary `deferred` behavior.
8. Add `depends_on`, `parent_task`, and task-local `blocked_by`.
9. Verify capability coverage and both readiness levels.

## Owning Scope and Layers

- `scope`: one owning package/module matching `[a-z0-9][a-z0-9_-]*`.
- Other packages/components belong in architecture context.
- `affected_layers`: `domain`, `data`, `presentation`, `navigation`, `di`,
  `api`, `tests`.
- Layers describe impact; they never create task order.
- Reality Check may correct affected layers and filenames without semantic
  replanning.

## Typed Contract Grounding

Each task selects one primary contract type:

- `backend_api`;
- `platform_plugin_api`;
- `storage`;
- `local_contract`;
- `external_contract`;
- `none`.

Data-layer impact does not imply Swagger. Copy only behavior-shaping fingerprint
from approved plan: endpoint/callback/channel/key, field path, type/nullability,
validation/default, and affected capability. Missing semantic fingerprint that
prevents honest acceptance returns `NEEDS_PLANNING`.

Preserve source URL targets. Deterministic comparison may normalize trailing
slash, percent-encoding, parentheses, and Markdown escaping.

## Shared Implementation Detail

Follow `.agents/contracts/common/implementation-detail.md` only after
capability coverage and vertical task boundaries stabilize. This prevents
current code placement from shaping semantic slices.

Run it as one plan-level pass grouped by owning module or contract surface;
reuse evidence across tasks. Add only slice-relevant detail from the applicable
risk profile. The shared contract owns lookup limits, anchor/signature depth,
deduplication, and technical-versus-semantic gap routing. It adds no new task
schema, implementation symbols, or machine technical contract.

## Dependencies and Branch Stack

- `depends_on`: technical or delivery prerequisite.
- `parent_task`: previous branch in stack, not architecture-layer order.
Branching follows `docs/vcs_guidelines.md`. AniStar TV uses `main`; a branch
stack is optional and requires explicit base/target agreement. When using a
stack, task-to-feature merges preserve SHAs; a completed logical change may
use squash into `main`. Task generation does not create branches or authorize
commits, merges, or publication.

Dependency cycle is hard failure. External fact binds only tasks whose work or
acceptance truly depends on it; partial external resolution keeps resolved and
unresolved subfacts separate.

## Implemented and Deferred

`implemented` contains behavior delivered by current task.

`deferred` means mandatory behavior of current epic temporarily completed by a
known later task. Every entry requires:

- `completed_by`: existing task ID;
- safe `temporary_behavior`;
- explicit implementation in completing task.

`OUT_OF_SCOPE`, `SEPARATE_TASK`, `EXTERNAL`, optional ideas, and unknown work
after research are not `deferred`.

`UnimplementedError` is allowed only on a deterministically unreachable path in
selected verification mode. Remove temporary behavior before epic or standalone
merge to `main`.

## Developer Acceptance and QA

Keep two visible lists:

1. Developer acceptance: deterministic implementation and tests inside PR.
2. QA checklist: device, real environment, production data, rotation, rollout,
   or external-system checks.

QA work does not inflate developer estimate unless developer must implement its
mechanics. A QA dependency may remain after Developer Readiness is ready when
plan explicitly says so.

Mutation/command tasks include applicable observable effects:

- success;
- invalid/no-op, including no external call;
- failure/retry.

## Readiness

### Task ready for epic

- declared `implemented` complete;
- code builds;
- relevant deterministic checks pass;
- every `deferred` links to completing task.

### Epic or standalone ready for `main`

- mandatory behavior complete;
- no unresolved `deferred`, temporary fixture/stub/prototype, or reachable
  `UnimplementedError`;
- production integration checks required by plan complete;
- comprehensive review complete.

## Fast Fix vs Planning Gap

Machine-only fast fixes need no user approval:

- filename/escaping/format;
- missing copied constraint already present in plan;
- internal JSON/Markdown mismatch;
- affected-layer correction;
- dependency reference typo where intended target is unambiguous.
- replacement of an unconfirmed non-semantic code anchor with contract-level wording.

Return `NEEDS_PLANNING` for:

- missing or conflicting behavior/scope;
- new architecture, API, security, or product choice;
- acceptance meaning not derivable from approved plan;
- capability coverage that requires invented work;
- split requires new semantic boundary or acceptance meaning.
