# Project configuration verification

Use the [factory environment](../../factory-install/references/integration.md#interpreter).
Commands below run from application root. Native Windows: replace
`.factory/tooling/bin/cli` with `.\.factory\tooling\bin\cli.cmd`.
Missing runtime: report validation pending; setup follows Factory Install within
authorized scope. Initial file inspection does not require Python.

YAML edits follow [YAML tooling](../../factory-meta-develop-tooling/references/yaml.md).
After authorized development setup, the shared checker exposes `--stage yaml-lint`
and `--stage yaml-contracts`. Run both after YAML changes when the development
tools are available. Inspect each stage exit/result; a command that starts and
fails because yamllint is missing is a failed attempt caused by unavailable tooling,
not a skipped or successful stage. Do not install missing development tools without
authorization; report the concrete missing module and validation still pending.
A runtime-only environment still supports the profile
validation below; missing dev tools remain an explicit gap, not a reason to skip it.


## Validation within a bounded write scope

Catalog/context/workflow commands can write `.factory/diagnostics/journal.sqlite3`;
read-only intent does not make their CLI invocation side-effect free. Inspect
command metadata first. If the task permits only specific policy/report files,
use the shared Python readers/resolvers with bytecode disabled (`python -B`) where
they are read-only. Run any necessary journal-producing CLI checks against a
disposable external copy of the actual edited candidate, preserving the selected
profile, documents, definitions and relative layout. Inspect the resulting material
and identify this as candidate-copy validation, not live workflow acceptance.
Do not use a different fixture, waive target scope, or remove existing target
journals/caches. Report a validation blocker if the required inputs cannot be copied
or checked within scope. Temporary external copies may be removed after inspection.
Application checks need a concrete basis in the task or project policy and must
preserve the authorized write scope. Report their results separately from profile
validation; they do not prove recipient delivery or live workflow acceptance.

## Definition validation and map

```bash
.factory/tooling/bin/cli catalog --config .factory/factory.yaml
```

Loads the selected profile through the common validator, connected local files,
gates and decisions; emits core/project gate definitions. Does not execute checks,
validate every unselected application document, or prove command availability.
Inspect new/changed declared paths separately. No new validator per skill.

## Recipient preview

Replace the example process/role/stage/path with the requested scenario:

```bash
.factory/tooling/bin/cli project --config .factory/factory.yaml --workspace . context --process implement --audience coordinator --scope services/api/billing/service.py
.factory/tooling/bin/cli project --config .factory/factory.yaml --workspace . context --process implement --audience worker --role implementer --stage work --scope services/api/billing/service.py
```

Repeat --scope for exact affected paths; omit only for explicitly unknown scope.
Read selected instructions and their provenance. context checks/gates are definition
catalogs, not the filtered executable check set. A successful context query covers
that scenario only; omitted stage does not preview every stage.

Standalone code-review requires an accepted baseline snapshot via `cli project`
review-policy and context --policy-snapshot. Follow
[the baseline contract](../../../contracts/common/project-policy.md#checks-and-change-control).
A working-tree map may describe candidate configuration; it is not accepted review policy.

## Implement check selection

For a task JSON with nonempty scope and any required typed policy_decisions:

```bash
.factory/tooling/bin/cli project --config .factory/factory.yaml checks TASK.json
.factory/tooling/bin/cli project --config .factory/factory.yaml checks TASK.json --final
```

Use actual task inputs or explicitly labeled fixtures. Missing/uncertain required
decisions block selection; do not fabricate accepted answers for a real task.
--final includes final obligations. Selection runs no commands and creates no
runtime receipt. Other processes retain their own applicability/acceptance tools.

## Completion evidence

State changed paths/IDs, checked scenarios, command results and blockers. Separate:
profile/schema consistency; delivery/applicability; executed project checks; live
run acceptance. Preserve exact failures and pre-existing unrelated problems.
No common PASS can be inferred from only one of these layers.

For every relevant validation, distinguish executed PASS, executed failure (with
command/exit and cause), and not run (with reason). An earlier failed invocation
remains part of the evidence even when a corrected invocation succeeds. Always
state whether configuration loading and recipient delivery were verified, which
application checks actually ran, and whether live workflow acceptance was observed.
No live run is required merely to configure a profile. Do not describe an unrun
application check or unavailable YAML stage as verified.
