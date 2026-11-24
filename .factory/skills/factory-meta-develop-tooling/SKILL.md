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
Follow [interpreter setup](../factory-install/references/integration.md#interpreter).
Use the project launcher's `help --json` catalog and `COMMAND --help` for command
arguments and supported modes.

## Public CLI commands

Register every new command in the project CLI. Keep text `--help` and JSON help
in sync through the shared parser. Describe when to use the command, required
inputs, effects and output. Give a runnable example. An agent can inspect the
command with `cli COMMAND --help --json` without supplying inputs or running it.

Define arguments, including their `help=` text, in the feature's parser. For a new
handler add `command(name, build_parser, run)` to the appropriate group in
[routes()](../../tooling/factory/cli.py). Use `parser_command` when `run` also takes
the parser. For a subcommand handled by an existing feature parser, extend that
parser and its handler. The shared CLI supplies `--help` and `--json`.

Add one `details(...)` entry for the canonical command in its
[help family](../../tooling/factory/cli_metadata/). Give its purpose,
prerequisites, effects and example arguments. The renderer supplies the launcher
and command path. Use `""` for an example that takes no arguments. Include
`writes=` for affected state, `external=` for external calls or processes, and
`default_output=` if execution defaults to a format other than the group's text
or the leaf's JSON. Aliases share the canonical entry. For a working example, see
[`pr recent-notes`](../../tooling/factory/cli_metadata/operations.py) and its
[handler](../../tooling/factory/github/fetch_recent_notes.py).

Every command must also support `cli COMMAND --json` for execution. Write one
UTF-8 JSON value to stdout on completion. Send progress to stderr. Use the shared
CLI error format and exit codes. Preserve a gate's structured verdict.

Offer `--dry-run` when an agent can usefully preview a change or a job before
committing to it. Use the command's real inputs and validation, show the planned
effects, and stop before writes, dispatch or attempt consumption. Recheck the
preconditions on execution. Read-only queries need no preview.

Through the project launcher, check text and JSON help, the entry in
`cli help --json`, and a successful and a rejected JSON invocation. Parse stdout
and check the exit code. Where `supports_dry_run` is true, test `--dry-run --json`
on disposable data and verify the plan and absence of side effects.

## Python architecture

Trace the use case from its CLI or Python entry point. When an operation depends on
domain state, put its rule on the smallest domain model that has the facts to decide.
Reuse that model across callers. Test an allowed transition and a rejected one,
including the state after rejection. Keep locking and persistence in the caller.
For replaceable I/O, select the implementation at the entry point and pass the
smallest existing contract the use case needs. A repository Protocol can serve
as the port. A pure calculation can stay a function.

For a storage change, identify which writes must survive or roll back together
and what the caller should observe on retry. Use these guarantees to choose the
transaction boundary and its tests. See the [Python examples and contract tests](references/python.md#application-and-storage-boundaries)
for the patterns adopted in ADR 0018.

## Change and verify

Reuse existing components and standard facilities before adding code or dependencies.
Fix the shared cause where semantics and assigned writes allow. Preserve unrelated
changes, input validation, error handling and required behavior.
Keep CLI entry points thin; loading a library must not start working operations.

Use existing runners and checks. Run checks relevant to changed behavior and callers;
use the aggregate tooling checker when available. Missing target checks remain
explicit gaps, not success. Do not invent commands, silently install dependencies
or weaken configuration to obtain a pass. Setup follows existing authorization.
Tests use disposable data; live integration evidence is separate.

If delegating, pass the target, task, allowed writes, applicable contracts,
language reference and required checks explicitly. Do not assume skill inheritance.
This skill does not create roles, grant permissions or require a new workflow.

## Result

Report changed behavior and files, checks with results, known failures and unverified
areas. Record the tested revision or source state, including uncommitted changes,
execution environment and exact commands with results. No separate report file required.
Distinguish implementation from verified readiness. Preserve contract changes
in the source-owned documentation and repair affected references. Before completion,
synchronize affected installed-bundle contracts, CLI help and command examples
with the verified implementation.
