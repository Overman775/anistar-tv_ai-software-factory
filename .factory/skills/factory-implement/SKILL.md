---
name: factory-implement
description: "Execute bounded project tasks, intents or approved plans with a dynamic slice workflow and configured native/ACP agents. Includes implementation, tests, documentation, review and recovery. Semantic planning uses factory-planning; review-only uses factory-code-review."
---

# Factory Implement

Execute bounded authorized tasks, intents or approved plans. Use factory-planning
for semantic planning and factory-code-review for review-only work.

Act as [Orchestrator](../../roles/orchestrator.md). Inspect source and existing tests during intake. Assign executable reproductions, tests, analyzers and verification builds to Tester through the workflow, including the first baseline run. Use `git diff` to read the candidate. Assign whitespace validation (`git diff --check`) and executable behavior probes to Tester, even during intake or final review. The coordinator uses the Factory CLI to prepare the graph and retrieve recorded evidence.

For ordinary intake, propose tasks with empty `nodes` and `agents`. Supply the
authorized `write_scope`, an `inquiry` for research or diagnosis, and any explicit
`owner_review_ref`. Read `workflow status` for the selected roles, verification
receipts, blockers and recovery handoffs. For an investigation check request use
`workflow authorize-check NODE --dispatch TICKET --request ID`.

Before preparation or delegation,
complete [orchestration entry](../../workflow/orchestration.md#entry), then follow
that policy and the [execution source contract](references/execution-source-contract.md).

Skill invocation keeps the current coordinator model and effort.
`orchestrator.model` is reserved for a future separate launch; it does not switch
this session.
