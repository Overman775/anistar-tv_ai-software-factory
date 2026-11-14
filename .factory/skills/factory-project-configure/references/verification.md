# Project configuration verification

Use the installed interpreter: [Python setup](../../../tooling/README.md#python-setup).
Commands below run from application root. Native Windows: replace
`sh .factory/tooling/bin/python.sh` with `.\.factory\tooling\bin\python.cmd`.
Missing runtime: report validation pending; setup follows Factory Install within
authorized scope. Initial file inspection does not require Python.

YAML edits follow [YAML tooling](../../factory-meta-develop-tooling/references/yaml.md).
After authorized development setup, the shared checker exposes `--stage yaml-lint`
and `--stage yaml-contracts`. A runtime-only environment still supports the profile
validation below; missing dev tools remain an explicit gap, not a reason to skip it.

## Definition validation and map

```bash
sh .factory/tooling/bin/python.sh .factory/tooling/bin/catalog.py --config .factory/factory.yaml
```

Loads the selected profile through the common validator, connected local files,
gates and decisions; emits core/project gate definitions. Does not execute checks,
validate every unselected application document, or prove command availability.
Inspect new/changed declared paths separately. No new validator per skill.

## Recipient preview

Replace the example process/role/stage/path with the requested scenario:

```bash
sh .factory/tooling/bin/python.sh .factory/tooling/bin/project.py --config .factory/factory.yaml --workspace . context --process implement --audience coordinator --scope services/api/billing/service.py
sh .factory/tooling/bin/python.sh .factory/tooling/bin/project.py --config .factory/factory.yaml --workspace . context --process implement --audience worker --role developer --stage work --scope services/api/billing/service.py
```

Repeat --scope for exact affected paths; omit only for explicitly unknown scope.
Read selected instructions and their provenance. context checks/gates are definition
catalogs, not the filtered executable check set. A successful context query covers
that scenario only; omitted stage does not preview every stage.

Standalone code-review requires an accepted baseline snapshot via project.py
review-policy and context --policy-snapshot. Follow
[the baseline contract](../../../contracts/common/project-policy.md#checks-and-change-control).
A working-tree map may describe candidate configuration; it is not accepted review policy.

## Implement check selection

For a task JSON with nonempty scope and any required typed policy_decisions:

```bash
sh .factory/tooling/bin/python.sh .factory/tooling/bin/project.py --config .factory/factory.yaml checks TASK.json
sh .factory/tooling/bin/python.sh .factory/tooling/bin/project.py --config .factory/factory.yaml checks TASK.json --final
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
