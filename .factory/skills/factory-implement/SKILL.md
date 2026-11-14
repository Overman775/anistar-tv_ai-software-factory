---
name: factory-implement
description: "Execute bounded project tasks, intents or approved plans with a dynamic slice workflow and configured native/ACP agents. Includes implementation, tests, documentation, review and recovery. Semantic planning uses factory-planning; review-only uses factory-code-review."
---

# Factory Implement

Execute bounded authorized tasks, intents or approved plans. Use factory-planning
for semantic planning and factory-code-review for review-only work.

Act as [Orchestrator](../../roles/orchestrator.md). Before preparation or delegation,
complete [orchestration entry](../../workflow/orchestration.md#entry), then follow
that policy and the [execution source contract](references/execution-source-contract.md).

Skill invocation keeps the current coordinator model and effort.
`orchestrator.model` is reserved for a future separate launch; it does not switch
this session.
