# Project policy editing

Shared by Init and Configure. Read [communication](../../../contracts/common/communication.md),
[discovery](../../../contracts/common/code-discovery.md) and
[project policy](../../../contracts/common/project-policy.md). Load topic references
only for affected work. These installed files suffice; Lab specifications are not
runtime dependencies.

## Ownership and inputs

factory.yaml.project selects one YAML relative to .factory. Follow that pointer;
do not assume the bundled AniStar profile describes the consuming application.
Project profile owns documents, rules, gates and decision definitions. factory.yaml
owns models, adapters and tool grants. Only Init's requested profile connection
needs a project-pointer edit. Common roles/processes/acceptance remain factory-owned.

Project instructions and requirements supply policy. Examples supply syntax and
illustrations, not authority. Find actual docs, package scripts and test commands
before adopting entries. Reuse existing documents by reference; avoid copies of
architecture or business requirements in rules. Project prose may use its language;
machine keys/IDs retain their contract.

An agent chooses discovery and editing order. No mandatory multi-agent workflow,
fixed interview or full lifecycle for a small configuration change. Use shared
readers/validators; do not reimplement selection, policy hashes or gate acceptance.
These three project skills are entrypoints, not new runtime processes, roles or
stage names. Do not add their names to rules.for.processes.

## Connected edits

Preserve unrelated settings, working-tree changes and stable IDs. Read the diff
where Git is available. Add required connections along with new definitions;
remove/rename only with affected references repaired. No automatic commit or publish.

Active work uses pinned policy. Changes apply through a new intake, never a hot
reload or rewritten snapshot. Check the relevant run state before claiming a
change applies to ongoing work. Preserve earlier evidence; follow that process's
re-intake contract when requested. Configuring a future run does not authorize
cancelling, migrating or repairing an active run.

Unknown schema fields, missing required files or unavailable validation remain
explicit blockers. Useful independent inspection can continue. A partial edit
is not a successful configuration; report exact remaining work.
