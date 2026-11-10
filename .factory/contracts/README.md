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

- `common/communication.md`: recipient language, Telegraphic and artifact fidelity; shared by coordinators and workers.

- `common/agent-checkpoint.md`: delegated handoff, checkpoint, Done Signal, and
  recovery rules for coordinators only; workers receive common/worker-rules.md.
- `common/implementation-detail.md`: detail boundaries shared by Factory Planning,
  Factory Decompose, and Factory Implement.
- Root role contracts such as `architect.md`, `developer.md`, `judge.md`,
  and `reviewer.md`: permissions, evidence, and completion states for one
  canonical role.

## Dynamic assignments

Generalist has its own code/tests/self-check contract. Developer/TestWriter
remain separate when selected. Each delegated role may write its exact assigned
report under the current run state, in addition to role-specific product paths.
Never share a singleton report across agents. The dynamic assignment envelope
and final JSON evidence schema are defined by `common/implement-result.md` and `common/check-execution.md`.

Cross-cutting criteria, mandatory project gates and additional checks —
[Verification Rules](../gates/common/verification-rules.md). Contract shared by
Planning, Decompose and Implement; native/ACP receive shared principles; process diagrams belong to skills.

- [common/decisions.md](common/decisions.md): coordinator and assigned evaluator contract; not mandatory reading for unrelated workers.
- `common/worker-rules.md`: shared worker obligations and handoff.
- `common/implement-result.md`: Implement result envelope and stage boundaries.
- `common/check-execution.md`: reserved command execution/results, conditional on assignment.
- `common/review-principles.md`: shared review principles, without standalone dispatch/schema.
- [common/code-discovery.md](common/code-discovery.md): project search and source confirmation for every worker.
- `common/coding-principles.md`: code-author principles for Developer and Generalist.
- `common/testing-principles.md`: test-author principles for TestWriter and Generalist.
- `../gates/common/verification-rules.md`: mandatory checks and evidence requirements.
Shared principles grant no role permissions. Context builder delivers applicable
files once per worker, across all profiles/transports; no concatenated role contracts.
Role contracts own interfaces; role files own execution procedures. Do not give
workers the coordinator checkpoint, router, orchestration or full workflow README.

Project ownership and coordinator intake: [project-policy.md](common/project-policy.md).
