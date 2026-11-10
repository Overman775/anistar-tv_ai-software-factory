# Codex Adapter

Read [shared coordinator adapter rules](common.md) before dispatch.

Codex runtime source:

- no project role wrappers: use a generic spawned agent with the selected profile
- hooks/config, when configured: `.codex/hooks.json`, `.codex/config.toml`
- canonical personas: `.factory/roles/*.md`

## Tool Mapping

| Canonical action | Codex action |
|---|---|
| Spawn canonical role | `spawn_agent` |
| Wait for an event | `wait_agent` |
| Inspect status when needed | `list_agents` |
| Message a running agent | `send_message` |
| Start the next turn in an idle session | `followup_task` |
| Interrupt | `interrupt_agent` |
| Close agent | not available in MultiAgentV2 |
| Read/search | shell tools via portable commands |
| Manual edit | `apply_patch` |
| Shell | `exec_command` |
| User choice | `request_user_input` when exposed; otherwise chat and wait |
| Task state | `update_plan` in parent when exposed; otherwise parent-held or skill-owned state |
| Project debug | verified project/runtime actions; otherwise logs/user navigation |
| Team create/delete | not available |
| Report to lead | final subagent response |

## Delegation

Use the actual exposed tool semantics. `send_message` does not start a new turn
in an idle agent; `followup_task` resumes it. A delivered message is not evidence
of resumed work. A timeout is not a failure or permission to dispatch again.
Distinguish logical agent, physical agent handle, model turn and shell command
session ID. A returned turn does not prove an outstanding command ended or the
physical session released host capacity. Preserve command handles until completion.

Read `.factory/factory.yaml`; resolve role → profile → adapter. The adapter entry
owns harness, runner, connection and instructions; the profile owns role files,
model, capabilities, MCP allowlist and enforcement. For native use a generic
spawned agent, never assume a registered named role. For Implement, after claim use `workflow.py prepare-packet NODE` and send its
complete short bootstrap, including `read_command`, to the native worker sharing
this exact workspace. Spawn, then bind the returned actual handle/model. The worker
reads every chunk before work and waits for running bind; do not wait for its work
before binding. `workflow.py packet NODE` remains an inline alternative when its
full contents can be delivered. A filename or digest alone is not delivery.
Planning/Decompose/Code Review use their owning skill’s `context.py` assignment
route and staging; do not add Implement claim/ledger to those processes.
Use the configured exact model/effort through actual supported spawn fields.
An ACP adapter routes to its configured instruction file and ACP helper.

Inspect actual tools before dispatch. In MultiAgentV2 explicit model/reasoning
requires `fork_turns="none"`; send the full assignment and required document paths.
If inheritance is explicitly selected/required by the user, record it honestly.
Apply the configured native cap to unresolved dispatches across roles, excluding
the parent. Separately observe the host's actual open-thread limits and tool
semantics; finished threads count only when the host says they do. `retired` is
not a runtime close, and absence of a close tool alone does not prove exhaustion.
Verify terminal writers and track unresolved dispatches before sending; never
blindly retry an unknown spawn or exceed an observed host limit.

Each logical agent/assignment has unique identity, source, ownership and output.
Continue a suitable session for related work only under the checkpoint contract.
A reviewer never shares its author's session. No nested delegation by default.
Fallback uses only an eligible configured alternative and never overrides an
explicit model/harness request. Record requested/effective model and effort.

## Rules

- Canonical `.factory` instructions stay runtime-neutral and wrapper-free.
- Verify tool inventory; do not invent tools from another runtime.
- Subagents receive configured worker_instructions and their canonical persona; this file is coordinator-only.
- Dispatch requires reading `AGENTS.md`, the persona, role contract, common
  assignment contract and actual applicable project documents before dependent
  action. Pass concrete paths, locked source/run identity, allowed writes and
  expected contract output; an index or another role's summary is insufficient.
- Use only exposed continuation, status and interrupt operations. If no close
  operation exists, retire the handle in terminal bookkeeping. Missing optional
  tools, elapsed time and silence are not failure; validate the contract's Done
  Signal and artifact before advancing or recovering the same role.
- Do not invent Claude-style tools such as `SendMessage` or `TaskUpdate`.
- Map choice-only planning Question Gate to `request_user_input` only when
  exposed. Render open/mixed questions in chat and wait; never invent options.
- Never add workflow policy, role topology, or semantic decisions in adapter.
