---
name: factory-project-configure
description: "Change or diagnose an existing project's factory policy: document delivery, rules, gates and typed decision definitions. Use for project configuration and applicability questions; factory runtime installation and model/adapter settings belong to Factory Install."
---

# Factory Project Configure

Turn the requested policy change into a connected, checked project configuration.
Read [editing contract](references/editing.md). Diagnose without writes when the
request asks only for explanation or inspection.

## Task-directed references

- Documents, instructions, recipients, selectors: [rules](references/rules.md).
- Commands, observations, review criteria, dependencies: [gates](references/gates.md).
- Questions, types, acceptance thresholds: [decisions](../../contracts/common/decisions.md).
- Validation and applicability preview: [verification](references/verification.md).

Read the current affected definitions and their consumers. Keep unaffected entries,
IDs and user edits. Add/edit YAML and Markdown directly; no custom editor required.
One request may need a rule, gate and decision together. Finish their connections
and checks as one change; do not leave a half-connected requirement as complete.
For renamed/removed definitions, repair affected references and check consumers.

Use source-backed project requirements. A rule's prose and a formal check serve
different purposes; add either or both when the requested behavior needs them.
Do not make a new decision merely because a path selector answers the question.
Runtime grants, model routing and common factory contracts remain outside project policy.
A request beyond the supported schema needs an explicit factory change, not invented fields.

## Completion

Use shared verification for the affected recipient/scenario and a contrasting
scenario when changing conditional applicability. Read the resulting materials;
valid YAML alone does not prove the intended rule reaches the intended agent.
New/changed check code needs relevant positive, negative and execution-error checks.
Use existing runners/contracts; no second acceptance mechanism.

Report changed behavior and files, scenario/check results, and unresolved blockers.
Preserve known pre-existing failures separately. A saved change with incomplete
verification remains unverified. Active runs retain their pinned policy; identify
re-intake needs rather than editing snapshots or historical results.
