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
invented requirements or copied example confidence thresholds.
An empty application may start with a valid project ID alone; report absent domain
requirements. Missing optional catalogs/rules/gates/decisions do not require scaffolds.

Load only needed authoring details:
- Documents/instructions: [rules](../factory-project-configure/references/rules.md).
- Checks/review obligations: [gates](../factory-project-configure/references/gates.md).
- Judgment definitions: [decisions](../../contracts/common/decisions.md).

Validate through [shared verification](../factory-project-configure/references/verification.md).
Report selected profile, sources, changed files, verified configuration and remaining
setup. Distinguish profile readiness from application checks and live execution.
Do not install application dependencies, start development, or create a run merely
to finish setup. Existing authorization may cover follow-up work; do not infer it.
