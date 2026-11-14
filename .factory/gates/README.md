# Gates

Factory-owned completion conditions. Project additions: [project gates](../project/gates/README.md).

- [Common verification](common/verification-rules.md): acceptance, mandatory project checks, additional evidence.
- Roles: [Developer](roles/developer.md), [TestWriter](roles/test-writer.md),
  [Generalist](roles/generalist.md), [Judge](roles/judge.md), [Reviewer](roles/reviewer.md).
- Skills: [Planning](skills/planning/gate.md), [Decompose](skills/decompose/gate.md),
  [Implement](skills/implement.md), [Code Review](skills/code-review/gate.md).

Role contracts retain permissions, inputs and identity. Their gate files own the
extracted completion/evidence conditions. Context resolver loads common verification
and only the assigned role's gate; no directory sweep. Skill coordinators read their
gate at the linked workflow step. Existing Python validators remain the enforcement
mechanism where implemented; Markdown alone cannot enforce semantic judgment.

Project YAML cannot override these conditions. A folder name does not schedule a
check or assign a role. Project `at` selects a supported transition; current graph
assigns its executor. Required checks still run through the existing runner.

A gate with its own code is one directory: gate.md plus its validator/helpers.
Planning, Decompose and Code Review follow this layout. Implement uses shared
runtime enforcement and remains one Markdown file. Project bundles use gate.yaml
plus check.py beside it; no per-gate README or duplicate validator is required.

## Current map and results

Use [the common result contract](result-contract.md) and
`sh .factory/tooling/bin/python.sh .factory/tooling/bin/catalog.py` to inspect actual core
and configured project gates. Definitions and executor ownership, not this index,
are the machine source of the map. gate.md describes the human obligations.
