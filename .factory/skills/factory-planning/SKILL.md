---
name: factory-planning
description: "Use for project semantic planning before implementation or decomposition when behavior, scope, architecture, API contracts, ownership, or expected outcomes are ambiguous; when several valid solutions exist; or when user asks for a plan/spec. Produces a human-readable revisioned plan with explicit approval or delegated planning authorization. Do not force planning for an ordinary self-contained ticket, bare do it yourself implementation request, or explicit no plan request. Triggers: factory-planning, plan feature, prepare implementation plan, clarify scope, plan and implement it yourself, prepare a plan without questions, plan the feature, prepare the plan, work out the solution, ambiguous task."
---

# Factory Planning

Use Planning for an explicit planning request or a material decision about behavior, boundaries, architecture, ownership or compatibility. A self-contained execution request can enter Implement directly.

## Entry

Read [project policy](../../contracts/common/project-policy.md) and resolve the coordinator's applicable instructions with `cli project context --process planning --audience coordinator`. Read the architecture and structure documents selected by the project profile in full. Read the other selected project documents before making decisions. Use the task/project language for the plan and the dialogue language for the owner. Preserve machine keys, exact identifiers and template headings.

```sh
.factory/tooling/bin/cli planning run init --request REQUEST --task "Authorized goal" --destination docs/plans/PLAN.md
.factory/tooling/bin/cli planning run status --run RUN
```

For an authorized replacement supply the previous public file's SHA-256 with `--previous`. Record any requested continuation and its authority at intake. A planning request alone ends at the approved plan.

## Working session

Use the status command and the returned role. Reserve the dispatch before starting a worker. Bind its observed handle with `planning run bind --run RUN --request REQUEST --dispatch TICKET --handle HANDLE`. Deliver the bound `packet` and its selected instructions. Use the same request ID to recover a lost mutation reply. For an uncertain worker, observe the original handle before issuing more work.

Architect owns semantic choices and proposes a candidate using the [plan contract](references/plan-contract.md) and [working session](references/session-contract.md). Use a bounded evidence question for CodeExplorer. Include the actual source location or explain which required source was unavailable. Record an unresolved owner choice and the answer against its original question. Workers return material to their assignment. The coordinator verifies the [planning gate](../../gates/skills/planning/gate.md), cites the basis and obtains approval of the reviewed revision. Only the coordinator publishes the agreed bytes to the named destination.

## Handoff

Return the path, plan ID, revision, approval reference and outstanding boundaries. A proposed execution sketch explains order and dependencies. The recipient needs its own task or execution authority to start work. Use `planning run history --run RUN` for prior decisions and publication receipts.
