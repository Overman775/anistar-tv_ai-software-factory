---
name: factory-implement
description: "Execute bounded project tasks, intents or approved plans with a dynamic slice workflow and configured native/ACP agents. Includes implementation, tests, documentation, review and recovery. Semantic planning uses factory-planning; review-only uses factory-code-review."
---

# Factory Implement

Execute bounded authorized tasks, intents or approved plans using the configured
workflow. Use factory-planning for semantic planning and factory-code-review for
review-only work. A request to plan only must go to Planning or stop without an
Implement run, assignments or product edits.

## Scope

Execute only authorized outcomes. Direct self-contained tasks need no ceremonial
plan. Planning owns product decisions and immutable approved plans; Decompose
owns published vertical tasks. A run may contain a fixed batch of sources.
Apply [execution source contract](references/execution-source-contract.md) per
source. Technical graph preparation is not a new semantic approval gate.

New unrelated requests start another run. A follow-up also records its bounded
new delta; it does not inherit completed gate verdicts. The parent coordinates;
small edits go to a Generalist, not a hidden root-only editing exception.

## Entry

Save `sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py config` output as
JSON in OS temporary storage. Keep it through `init`; do not send it to workers.
Use `sh .factory/tooling/bin/python.sh .factory/tooling/bin/workflow.py read-instructions
SNAPSHOT PATH...` for mandatory Implement factory instructions. Paths are
relative to `.factory/`. Use the returned content, including for rereading this
skill. The command verifies and returns the same bytes. Read the Orchestrator
contract and role, communication and project policy, execution source contract,
configured router and orchestration policy. Read their applicable Implement instruction links with the same command.
Other process handoffs follow their own entry instructions. Resolve project materials as directed by the role. At `init`, pass the
same snapshot. On changed bytes, stop and reload the snapshot and instructions.
The current session model and effort remain in effect. `orchestrator.model` is
reserved for a future separate launch; it does not switch this session.
