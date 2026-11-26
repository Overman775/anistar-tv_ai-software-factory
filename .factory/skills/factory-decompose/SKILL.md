---
name: factory-decompose
description: "Use when Codex must split an approved Factory Planning plan into reviewed, human-readable project tasks with estimates and dependencies. Triggers: factory-decompose, split approved plan, create project tasks, estimates and dependencies, decompose approved plan, split the plan into tasks, task list. Raw requirements and semantic planning belong to factory-planning; implementation belongs to factory-implement; publication requires an explicit user request."
---

# Factory Plan Decomposition

Turn an approved Planning revision into task Markdown and a dependency graph. The approved plan is immutable. Read [project policy](../../contracts/common/project-policy.md) and the material selected by `cli project context --process decompose --audience coordinator`. Read applicable architecture and project documents selected by the project profile in full. Write task and epic prose in the task/project language, otherwise the dialogue language. Preserve technical identity, template headings and machine values.

## Entry

```sh
.factory/tooling/bin/cli decompose run init --request REQUEST --plan docs/plans/PLAN.md --destination tasks/BUNDLE --authorization OWNER_REFERENCE
.factory/tooling/bin/cli decompose run status --run RUN
```

Use an unoccupied destination. The intake binds the plan ID, revision, hash, requirements and project policy. An unresolved product decision goes back to Planning with the exact question. For a simple task or direct implementation of an approved plan, the caller can enter Implement directly.

## Assignment and evidence

Use the returned action and role. Claim once, bind the observed handle, and deliver `decompose run packet --run RUN --dispatch TICKET --handle HANDLE`. That packet includes the task source, selected worker instructions and existing evidence. TaskDecomposer owns task boundaries, estimates and dependencies under the [decomposition policy](references/decomposition-policy.md) and [task template](references/task-template.md). Preserve CAP and AC IDs, parent and dependency edges. Follow the [delivery contract](references/generation-contract.md#completion-handoff) for exact file bytes and hashes. After a disconnect consult the received and missing hashes on the same run.

TaskReviewer uses the [review contract](../../gates/skills/decompose/review-contract.md). Its first assignment reads the checked material. A repair assignment identifies the allowed files and original reviewer. A fresh verdict covers the complete corrected set. The [gate](../../gates/skills/decompose/gate.md) records the source, coverage, references, cycles, project checks and evidence. Only an independently approved bundle can be installed.

Return the public task directory, source tuple and run ID. A subsequent authorized Implement can consume that completed run. External tracker/PR publication needs an explicit request. [Output contract](references/output-contract.md)
