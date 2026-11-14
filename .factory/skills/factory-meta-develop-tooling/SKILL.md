---
name: factory-meta-develop-tooling
description: "Create, fix or refactor the factory's executable tools, validators, adapters, launchers and their tests. Use for development of factory tooling itself, not application features or project policy configuration."
---

# Factory Meta Develop Tooling

Deliver the requested tooling change with checked contracts and explicit evidence.
For inspection-only requests, diagnose without writes.

## Scope and inputs

Identify the source checkout or installed factory being changed. Read its repository
instructions, task and applicable local rules. In Lab, select the exact variant;
never edit a mirror as a draft or synchronize variants implicitly.
An installed bundle does not imply permission to update its source or other copies.
Do not require an application profile merely to develop factory tooling.

Read [communication](../../contracts/common/communication.md) and
[discovery](../../contracts/common/code-discovery.md). Inspect affected callers,
tests, fixtures, configuration and exports before editing.

## Required context

Read [coding principles](../../contracts/common/coding-principles.md) for code,
[testing principles](../../contracts/common/testing-principles.md) for tests,
and [review principles](../../contracts/common/review-principles.md) for review.
One agent performing multiple activities reads each applicable contract.
Workflow-owned roles, coordinator handoffs and pinned-policy mechanisms apply when
working in that workflow; otherwise follow repository instructions and task authority.

For Python changes, read [Python tooling](references/python.md).
For factory-owned YAML changes, read [YAML tooling](references/yaml.md).
For setup and actual commands, read [tools](../../tooling/README.md).

## Change and verify

Reuse existing components and standard facilities before adding code or dependencies.
Fix the shared cause where semantics and assigned writes allow. Preserve unrelated
changes, input validation, error handling and required behavior.
Keep CLI entry points thin; loading a library must not start working operations.

Use existing runners and checks. Run checks relevant to changed behavior and callers;
use the aggregate tooling checker when available. Missing target checks remain
explicit gaps, not success. Do not invent commands, silently install dependencies
or weaken configuration to obtain a pass. Setup follows existing authorization.
Tests and dry run use disposable data; live integration evidence is separate.

If delegating, pass the target, task, allowed writes, applicable contracts,
language reference and required checks explicitly. Do not assume skill inheritance.
This skill does not create roles, grant permissions or require a new workflow.

## Result

Report changed behavior and files, checks with results, known failures and unverified
areas. Record the tested revision or source state, including uncommitted changes,
execution environment and exact commands with results. No separate report file required.
Distinguish implementation from verified readiness. Preserve contract changes
in the source-owned documentation and repair affected references. Before completion,
synchronize affected installed-bundle contracts, command examples and
[tooling documentation](../../tooling/README.md) with the verified implementation.
