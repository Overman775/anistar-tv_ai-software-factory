# Agent Contracts

Contracts describe what each canonical agent may read, write, return, and refuse.
They are runtime-independent. Adapters decide which concrete tool performs an
action.

Contract vocabulary:

- `input`: required context.
- `allowed_writes`: files or areas the agent may modify.
- `forbidden_writes`: files or areas the agent must not modify.
- `done_signal`: allowed completion states.
- `evidence`: proof required before success claims.

## Layout

- `common/agent-checkpoint.md`: delegated handoff, checkpoint, Done Signal, and
  recovery rules shared by every role.
- `common/implementation-detail.md`: detail boundaries shared by Factory Planning,
  Factory Decompose, and Factory Implement.
- Root role contracts such as `architect.md`, `developer.md`, `dev-reviewer.md`,
  and `reviewer.md`: permissions, evidence, and completion states for one
  canonical role.
