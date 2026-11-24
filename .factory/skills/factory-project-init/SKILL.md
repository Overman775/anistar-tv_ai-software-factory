---
name: factory-project-init
description: "Connect a new or existing application to the installed factory: discover project requirements and create or complete its project profile. Use for initial project setup; use factory-project-configure for later policy changes."
---

# Factory Project Init

Produce a minimal usable project profile from actual project sources. Factory
installation belongs to [Factory Install](../factory-install/SKILL.md).
Read [editing contract](../factory-project-configure/references/editing.md).
No workflow graph or valid pre-existing project profile required for discovery.

## Inputs and result

Use the requested application root, existing factory.yaml/project selection,
project instructions, documentation and real command definitions. Discover missing
paths; ask only about material choices unresolved by those sources.

Keep a valid existing profile and stable IDs. Complete the requested gaps;
repeated init does not reset settings or duplicate rules. For a new profile,
use project/project.yaml unless the project selects another supported local path.
Set factory.yaml.project relative to .factory; preserve other runtime settings.

Use [project.example.yaml](../../project/project.example.yaml) as a shape reference.
Copy only applicable entries and their required files. Replace illustrative paths,
commands and requirements with observed project values. No placeholder gates,
invented requirements or copied example confidence thresholds. Mark background
as `usage: reference` and use the default `usage: policy` for requirements.
An empty application may start with a valid project ID alone; report absent domain
requirements. Missing optional catalogs/rules/gates/decisions do not require scaffolds.

Load only needed authoring details:
- Documents/instructions: [rules](../factory-project-configure/references/rules.md).
- Checks/review obligations: [gates](../factory-project-configure/references/gates.md).
- Judgment definitions: [decisions](../../contracts/common/decisions.md).

Validate through [shared verification](../factory-project-configure/references/verification.md).
After YAML edits, when the prepared development tools are available, run the
registered public stages (REPORT_DIR must be outside the candidate workspace):

```sh
.factory/tooling/bin/cli tooling check --stage yaml-lint --stage yaml-contracts --report-dir "$REPORT_DIR" --json
```

Choose a fresh external report directory. For a bounded target write scope, run
this command from a disposable external copy of the actual candidate with its
prepared dependencies, selected profile and linked inputs, as shared verification
requires. Read both stage results and logs. Standalone yamllint on selected files,
private `_check_files` calls, or a two-file subset do not replace either full stage.
A missing tool or stage failure stays explicit; do not silently omit the stage.

The stages inspect the checker's owned YAML discovery set, not only edited files.
`yaml-contracts` loads factory.yaml's selected profile and its linked definitions;
a profile under project/ is also discovered by its ID regardless of filename.
An alternate selected filename does not justify skipping the public stages.
Do not claim that a stage validates undiscovered files or recipient delivery:
add the selected-profile loading and real target/contrast preview from shared
verification. Report unrelated existing stage failures without changing their
files outside scope or presenting a private subset as full-stage PASS.
Report selected profile, sources, changed files, verified configuration and remaining
setup. For each relevant check state executed PASS, executed failure with its
command/exit and cause, or not run with reason. Missing dev tools and failed
invocations must remain explicit even when profile loading or preview succeeds.
State separately profile readiness, application check results and whether live
workflow acceptance was observed.
Do not install application dependencies, start development, or create a run merely
to finish setup. Existing authorization may cover follow-up work; do not infer it.
