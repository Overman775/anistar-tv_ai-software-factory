# Claude Code Adapter

Read [shared coordinator adapter rules](common.md) before dispatch.

Claude runtime source files:

- No project role wrappers; dispatch to built-in `general-purpose` with full profile instructions
- Settings/hooks: `.claude/settings.json`
- Canonical personas: `.factory/roles/*.md`
- Skills symlink: `.claude/skills -> ../.factory/skills`

## Tool Mapping

| Canonical action | Claude Code action |
|---|---|
| Spawn agent | use exposed `Agent` with built-in `general-purpose` and full profile assignment |
| Notify teamlead | `SendMessage(to: "teamlead", ...)` when available |
| Notify another agent | `SendMessage(to: "<agent>", ...)` |
| Continue agent/message | `SendMessage(to: "<agent>", ...)` when available |
| Track task state | `TaskCreate` / `TaskUpdate` when available |
| Read/write files | `Read`, `Write`, `Edit` |
| Ask user | `AskUserQuestion` if available; otherwise show the question in chat and wait |
| Project debug/runtime actions | verified installation mapping from selected project instructions |

## Delegated Checkpoints

Inspect whether the exposed messaging operation starts another turn or only
delivers a message. Do not infer continuation from delivery or import Codex tool
names. Distinguish agent handle, model turn and command session; observe each
outstanding operation through its supported mechanism before claiming completion.

Use live-handle progress and `SendMessage` when exposed. If Agent call blocks
parent or returns one-shot, validate contract artifact and Done Signal on
return. Missing progress/cancellation tools and silence are never failure.

## Rules

- No `.claude/agents/` files are generated or required.
- For native Implement, after claim use `workflow.py prepare-packet NODE --with-diagnostics`.
  Review diagnostics and send the complete `bootstrap` to the worker in the same
  workspace. Spawn and bind the actual handle/model immediately. The worker reads
  every chunk, observes the bind and confirms delivery. Wait for outstanding
  delivery confirmations before coordinator checks.
  Full inline `workflow.py packet NODE` remains an alternative.
  Planning/Decompose/Code Review use their owning skill’s `context.py` route
  and staging, without Implement claim/ledger. Deliver the complete packet.
- Read capability/MCP rules from the selected profile. Discover optional MCP tools
  through exposed `ToolSearch` and inspect their real schemas. Project servers
  are configured in the host MCP configuration.
  Keep source-project provider settings and unavailable integrations/plugins out.
  Without an exposed matching capability, use the applicable commands from the
  project profile command and testing documents.
- Require the worker to read `AGENTS.md`, the supplied worker adapter, role contract,
  Worker Rules and actual applicable project documents. Dispatch
  includes concrete paths, locked source/run identity, owned paths and expected
  output; an index or another role's summary is insufficient.
- Use the actual exposed wait/resume, interrupt and close operations. Continue
  the same role when supported and source/run identity matches; otherwise
  restore its checkpoint only after verifying no active writer. Retire handles
  when no close exists. Missing optional tools do not consume recovery attempts.
- Do not generate persistent agent definition files.
- For a canonical planning Question Gate, send a choice-only batch through
  `AskUserQuestion` when available. Show an `open` or mixed batch as text
  without inventing options. If structured input is unavailable, print the same
  batch in chat and wait.
- Agent topology and workflow policy come only from active skill/contract.
- Record requested/effective model and effort, provider alias resolution and
  user-authorized per-run overrides. An alias does not prove an official model
  version. Inspect environment overrides without importing personal provider
  settings; do not force a shared effort across roles or silently substitute an
  unavailable assignment. File validation does not prove an actual launch.

## Dynamic profiles

Read `.factory/factory.yaml` before dispatch. A profile selects instructions,
contract, model, capabilities and adapter; the adapter resolves native/ACP
runner and runtime instructions. Use actual supported Agent/team parameters and
confirm the assignment. If this host cannot select a configured model, report
unavailability or use an explicitly eligible configured profile; never relabel
a Claude model as a requested Codex model. ACP profiles use `acpx.md`.
Reserve through the shared ledger for implementation. Account for native host
capacity separately; no nested delegation, unknown-request retry or shared
writer/reviewer session. Three configured slots are a ceiling, not a guarantee.
