# Agent Checkpoint Contract

Parent orchestrators use this shared contract to validate delegated handoffs and
preserve resumable state. It has no timer-based liveness mechanism and does not
infer failure from silence.

## Scope

Apply to every delegated role with a separate handle: investigation, planning,
decomposition, implementation, tests, review, and documentation.

For an in-session role pass without a separate handle, validate the same
contract-owned checkpoint and Done Signal when control returns.

## Core Rule

Silence is not failure. A role may spend several minutes reasoning, generating
content, or waiting on its own advancing tool call without emitting a message or
artifact.

- Do not count quiet or silent windows.
- Do not classify a running handle as stalled because no heartbeat arrived.
- Do not interrupt, close, reject, or replace a running handle because time
  elapsed or an artifact has not appeared yet.
- Runtime capability differences do not create role failure.

Parent-controlled waits may stay bounded so the parent can process user steering
and send concise updates. A wait timeout means only "no new event during this
poll"; repeated timeouts have no failure semantics.

## Worker handoff

Worker progress and results follow [assignment](worker-rules.md) and their role
contract. Give workers that contract, not this coordinator lifecycle procedure.

## Coordinator communication

Read [communication](communication.md). Write compact English assignments with
purpose, scope, inputs, constraints and expected result; preserve full packets.
Combine worker updates into useful user-facing progress in the dialogue language.
Surface material findings, decisions, blockers and questions; do not relay every
service message or repeat unchanged status. Keep required feedback and handoffs.

## Parent Wait Loop

1. Prefer event-based wait/handoff when exposed; otherwise inspect status as needed.
   A timeout does not authorize duplicate work or a repeated status narration.
2. Re-enter periodically only to stay responsive to user steering. Do not turn
   poll count or elapsed time into a liveness verdict.
3. Request one status/checkpoint when it is useful for user visibility or when
   the role itself reported a blocker. Do not send repeated timer-driven nudges.
4. Continue waiting while runtime reports the handle as running and no explicit
   cancellation condition exists.
5. Validate the role-owned artifact, contract headers, source lock, and Done
   Signal after the role returns.

Never run two writer roles concurrently against the same owned target.

## Allowed Interruption

Interrupt or close a running handle only when one of these conditions is true:

- user explicitly cancels, replaces, or redirects the delegated work;
- runtime reports a terminal tool/agent failure and requires cleanup;
- role reports an explicit blocker and parent must stop it before a different
  authorized path can proceed;
- duplicate-writer protection requires stopping the newer conflicting handle.

Before interruption, preserve source lock, user changes, and last valid
contract-owned artifact. Report what was stopped and why. Ordinary silence,
missing heartbeat, unchanged artifact, or generic `running` status never meet
this threshold.

## Completion and Failure

Successful handoff requires the role contract's Done Signal plus valid evidence
or artifact. A returned result with missing/invalid evidence is an invalid
handoff, not a timeout.

Role failure exists only when:

- runtime returns an explicit terminal failure;
- role returns its contract-defined blocked/failure signal;
- control returns with an invalid handoff that cannot be repaired from the last
  valid checkpoint.

## Recovery

Preserve source, diffs, and valid artifacts. Recovery starts only after explicit
failure or invalid returned handoff, never while the original role remains
running.

| Delegated work | Recovery after explicit failure/invalid handoff |
| :--- | :--- |
| Read-only investigation | Parent finishes the bounded investigation inline, or retries the same role once when role isolation is required. |
| Factory Planning Architect | Verify `planning-plan.md`, then parent may render/validate the same candidate inline from `planning-session.md`; do not start a concurrent second Architect. |
| Transactional writer | Resume/retry the same role once from source lock and last valid checkpoint. |
| Parallel focused reviewers | Retry only the failed focus once; never restart healthy focuses or synthesize missing findings. |

If allowed recovery also returns explicit failure or an invalid handoff, use
`BLOCKED_AGENT_FAILURE` with role, last valid stage, artifact, recovery attempted,
and exact resume action. This status never results from elapsed time or silence.

Recovery does not consume semantic revision, review-fix iteration,
decomposition repair iteration, compile retry, or test-fix counters because no
valid role result was produced. Track it separately as agent recovery.

## Same-Run Role Continuation

For dynamic Factory Implement, identity is run + logical agent, while each
assignment binds task/node/dispatch and immutable source hash. Reuse a suitable
session for related tasks/slices only after reading the new assignment and
checking specialization, permissions, instructions and context. Same source is
not required across explicitly locked assignments; source drift inside one
assignment still blocks. Reviewer never shares any author's session.

A new physical session increments its epoch and gets an explicit handoff: goal,
decisions, completed work, remaining findings/checks and current files. It has
no automatic memory. Preserve previous handle and all task/stage counters.
Confirm an old writer is terminal before replacing it. Unknown outcome remains
reserved until runtime/diff/artifacts are reconciled. `retired` bookkeeping is
not proof a host thread closed or a provider request stopped.

Planning/decomposition and other skills retain their own identity/continuation
boundaries. Role changes require a fresh physical session. At terminalization
close through a supported runtime operation; if absent record actual known
terminal status and any retained host capacity rather than inventing a close.

## Runtime Mapping

Use active `.factory/adapters/{runtime}.md` for concrete spawn, wait, follow-up,
status, interrupt, and close actions. Use only operations actually exposed by
the runtime. Tool inventory changes how the parent observes a role, not whether
silence is failure.

## Assignment delivery

Build full current role/process/stage packets through the context builder.
Do not inherit the parent transcript by default. Confirm actual host autoload and
inheritance; unavailable isolation remains an explicit limitation. Role changes
require a fresh physical session; preserve budgets and unresolved work.
