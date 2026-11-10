# Short title of the expected outcome

- **ID:** {functional ID, e.g. orders-list-core-01}
- **Plan source:** {`plan_id`, `revision` and link to the approved plan}
- **Covers capabilities:** {CAP-01, CAP-02}
- **Acceptance criteria:** {AC-01, AC-02; or — if the task does not fully close a plan criterion}
- **Contribution to plan criteria:** {AC-01, AC-02; or —; contribution does not mean closure}
- **Purpose:** Functionality
- **Epic/Feature:** {feature name, e.g. Order list}
- **Scope:** {owning module or package, e.g. catalog}
- **Affected layers:** {e.g. `domain`, `data`, `presentation`}
- **Estimate:** {range, e.g. 6–8 h}
- **Parent task:** {ID of the preceding task in the branch stack or —}
- **Depends on:** {task IDs or —}
- **Blocked by:** {Figma / Swagger / backend / external setup or —}
- **Assignee:** {agreed assignee or —} *(optional)*
- **Project:** {`project_name`, e.g. `requests`} *(optional)*

Conditional fields: keep only the block matching the purpose:

- **Technical preparation — consumers (`consumers`):** {task IDs}
- **Research — question (`research_question`):** {what must be learned}
- **Research — timebox (`timebox_hours`):** {hours}
- **Research — expected outcome (`expected_result`):** {answer, decision or measurement}

> Allowed values: **Functionality**, **Technical preparation**,
> **Research**. Choose one.

`Scope`: one primary package/module `[a-z0-9][a-z0-9_-]*`. A module need not have
its own package manifest. List other components only in architectural context.
`affected_layers` is optional in the shared contract; project extensions may impose their own requirements.

Specify `Assignee` only with an actual assignment and an available task system.

Ordinary prose follows task/project language, otherwise the dialogue language.
If translation does not change technical identity, use natural words in the
chosen language. Exact template headings and machine values remain unchanged.

---

## 1. Context and expected outcome

*Why is the task needed? What verifiable outcome should the user, developer or team receive?*

> Example: "The user sees a loaded or empty order list."

## 2. Task scope (`implemented`)

*For each independent scenario, specify applicable trigger, boundary, significant
inputs/outputs, state or effect owner, success and empty outcomes, failure, retry,
no-op, unaffected neighbors and verification. Do not split work by layers or fill
items to meet a quota: detail follows risk and contract type.*

*Apply the shared implementation-detail contract. Exact existing symbols
are optional; replace unverified names with boundary descriptions. A full
signature is needed only when its details change behavior.*

1. ...
2. ...
3. ...

## 3. Deferred work (`deferred`)

- **Behavior:** {not implemented yet or —}
  - **Closing task:** {ID of the follow-up task}
  - **Temporary behavior:** {safe stub, generic error or —}

Every mandatory deferred behavior needs a closing task. Do not merge the epic
into `main` until mandatory `deferred` items are closed.
`OUT_OF_SCOPE`, `SEPARATE_TASK`, `EXTERNAL` and post-research work
(`research`) are not `deferred`.

## 4. Architectural context

*Where are changes expected? Which architectural constraints must remain?
Describe boundaries and contracts without dictating the developer's implementation.*

- **Scope:** {e.g. `lib/packages/features/catalog`}
- **Affected layers:** {`domain` / `data` / `presentation`}
- **Reuse:** {existing repositories, BLoC, UIKit components, API clients}
- **Constraints:** {DI, navigation, API contract, feature isolation}
- **Critical decisions:** {D-ID, decision and verification/constraint from the approved
  Factory Planning plan or —}
- **Verified facts and external conditions:** {behaviorally significant facts from
  solution structure and applicable EXT-IDs with handling or —}

Carry only `D-*` where `Applicability` intersects task capabilities
or contains `global`. Take facts from solution structure and evidence,
`EXT-*` from boundaries, only when they actually constrain task work or acceptance.
Do not copy the entire ledger or invent a missing requirement. Describe current
code anchors as references unless the approved plan makes exact identity part
of architecture or a compatibility contract.

## 5. Verification and acceptance

*Checks must match the declared outcome and affected layers.*

- **Verifiable outcome after PR:** {specific observation, run or check from the approved capability}

- [ ] All behavior in `implemented` is implemented.
- [ ] Temporary and deferred behavior is listed in `deferred`.
- [ ] Main and specified boundary scenarios are checked.
- [ ] For a state-changing operation or command, check applicable success,
      invalid input or no-op, failure and retry, including no external call on no-op.
- [ ] Relevant behavior and contract checks pass.
- [ ] UI, if affected, matches applicable project specifications
      and the supplied design, if any.
- [ ] Applicable project-profile checks pass; commands and their order are preserved.
- [ ] Task can be safely integrated under the agreed project VCS policy.

### Local acceptance criteria

*Required for functional contribution without full closure of the parent AC.
Local IDs belong to the task; runtime checks use `local:AC-01`.*

| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | global | {bounded outcome of this task} | {outcome verification} |

*Remove this block if there are no local criteria. The assigned closing task,
dependent on all producers, verifies the full plan AC.*

### QA checks after PR

*Checks on real environments, devices or data. They do not block development
readiness when explicitly dependent on QA, backend or external environment.*

- [ ] {scenario / environment / device or —}

For a task going directly to `main`, full epic readiness criteria apply:
mandatory `deferred` closed; no temporary stubs, fixtures, prototypes or
`UnimplementedError`; API verified; comprehensive review complete.
Permanent fallback behavior belongs in `implemented` and needs acceptance criteria.

## 6. Designs, API and documentation

- **Contract type:** {`backend_api` / `platform_plugin_api` / `storage` / `local_contract` / `external_contract` / `none`}
- **Figma:** {link to a specific frame or —}
- **Contract / API:** {endpoint, callback, channel, storage key, local interface, link or —}
- **Documentation:** {requirements, Wiki, ADR or —}
- **Data mode:** {real API / generated client and stub / fixture / —}

Preserve exact URLs without losing the address. Differences limited to trailing `/`,
percent encoding or Markdown escaping are normalized automatically.
Do not repeat the full signature here or the state flow from section 2:
keep a brief contract description and links.

---

Plan criteria retain IDs and meaning. In acceptance, distinguish this task's
outcome, a combined outcome of several tasks and local readiness of preparatory
work. Name the task that verifies combined behavior.
Mandatory project checks remain separate; additional risk-based checks are
allowed and do not require plan revision without a behavior change.
