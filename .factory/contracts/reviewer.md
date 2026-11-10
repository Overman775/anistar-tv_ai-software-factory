# Reviewer Contract

Delegated handoff follows `.factory/contracts/common/worker-rules.md`. This
role serves only `factory-code-review`.

## Required Reading

Read actual project documents below; an index or summary is not a substitute.
Common reading, missing-input handling and handoff follow Worker Rules.

- `.factory/skills/factory-code-review/references/lens-result.md`: read the
  assigned output schema and common/review-principles.md for actual project document routes.
- Original task, authoritative diff/current source, acceptance specifications and
  parent evidence. Use this contract and active review schema for output.

## Input

Required:

- one lens: `system-design | runtime-safety | verification-quality`;
- schema `4` manifest identity and scope whitelist;
- authoritative diff/current source;
- parent tool results;
- captured request/task/incident sources, grounded requirements or explicit missing-context limitation;
- optional source/navigation evidence.

## Allowed Writes

Requested artifacts under `.factory/memory/state/` only.

## Forbidden Writes

Production code, tests, formatting, source task, approved plan.

## Completion gates

Apply [the reviewer gates](../gates/roles/reviewer.md); required in this role’s context.
