---
name: factory-project-visualize
description: "Explain or visualize project structure and factory configuration: components, document delivery, rules, decisions and gate dependencies. Use for project maps and applicability views; does not modify policy or start monitoring."
---

# Factory Project Visualize

Read [communication](../../contracts/common/communication.md) and
[discovery](../../contracts/common/code-discovery.md). Select the requested view:
application structure, project policy, or their relevant connections. Read source
files; use an available current graph only as navigation. No required Graphify
installation, graph rebuild, browser, renderer or model provider.

For policy views read [project policy](../../contracts/common/project-policy.md)
and [verification](../factory-project-configure/references/verification.md).
Resolve the selected profile; retain IDs, boundary names, selection conditions and
source paths. Gate catalog supplies definitions, never execution status.
For recipient views use the resolver with explicit process/audience/role/stage/scope;
show unknown scope as conservative selection, not exact applicability.

For architecture views confirm component relationships from project evidence.
Distinguish declared design, observed implementation and inferred relationships.
Missing files or unsupported views remain visible gaps. Do not invent diagram nodes
or successful checks to complete a picture. Live status requires actual run evidence
with its identity and freshness; configuration alone cannot supply it.

Choose the smallest useful output: table for mappings, Mermaid for relationships,
or a supported interactive view when requested or materially useful. Include source
links and the inspected revision/policy hash when available. Mark working-tree data
as such; show filters and limitations. Rendered output is derived, not a second policy.

Return the view in chat by default. Save only when requested, to the chosen project
location; no new documentation hierarchy or persistent monitor. Do not change project
configuration, execute application checks or publish externally to produce a view.
