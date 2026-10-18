# Codex Adapter

Codex runtime source:

- wrappers: `.codex/agents/*.toml`
- hooks/config, when configured: `.codex/hooks.json`, `.codex/config.toml`
- canonical personas: `.agents/agents/*.md`

## Tool Mapping

| Canonical action | Codex action |
|---|---|
| Spawn canonical role | `spawn_agent` |
| Wait/status | `wait_agent`, `list_agents` |
| Message/continue | `send_message`, `followup_task` |
| Interrupt | `interrupt_agent` |
| Close agent | not available in MultiAgentV2 |
| Read/search | shell tools via portable commands |
| Manual edit | `apply_patch` |
| Shell | `exec_command` |
| User choice | `request_user_input` when exposed; otherwise chat and wait |
| Task state | `update_plan` in parent when exposed; otherwise parent-held or skill-owned state |
| Dart debug | exposed Dart/Flutter MCP actions; otherwise logs/user navigation |
| Team create/delete | not available |
| Report to lead | final subagent response |

## Project MCP Capabilities

`.codex/config.toml` registers `dart-mcp-server` (FVM Dart), `dcm`, and
`context7`. Native role wrappers inherit available MCP servers; do not add an
invented per-role `tools` field. Inspect the exposed tool schemas before use.
The runtime handshake confirmed Dart `analyze_files`, `dtd`,
`get_runtime_errors`, `hot_restart`, and `hot_reload`; DCM `dcm_analyze` and
`dcm_format`; Context7 `resolve-library-id` and `query-docs`.

Preserve the source role boundaries: developer may analyze/format and query
Context7; code-explorer may analyze/query Context7; bug-hunter may additionally
connect tooling, inspect runtime errors and reload/restart. Review roles use
Dart/DCM analysis only; test-writer uses DCM analysis. Architect, doc-writer and
decomposition roles gain no additional MCP categories. Server inheritance does
not expand a persona's write ownership.

Codex uses server ID `dart-mcp-server`; Claude uses `dart-fvm` and explicit
`mcp__dart-fvm__…` allowlists. DCM and Context7 use IDs `dcm` and `context7`
in both clients; inspect the runtime's actual qualified names instead of
copying Claude tool names into Codex wrappers. The probed Dart server does not
expose test execution, format/fix, device listing, app launch/logs/stop or
running-app listing. Use the active skill's FVM/Melos commands for these and
probe again after server changes. Skills own command ordering and all gates.

## Delegation

Inspect the actual `spawn_agent` schema before dispatch. TOML files alone do not
prove named-role discovery or an `agent_type` parameter exists. When supported,
use a unique task name and canonical `agent_type`; the registered wrapper owns
model/reasoning. Otherwise read the role wrapper and pass its explicit `model`
and `model_reasoning_effort` as `model` and `reasoning_effort`. In the exposed
MultiAgentV2 runtime, these overrides require `fork_turns="none"`; provide all
scope, inputs, output, constraints and concrete document paths explicitly.
Never silently inherit the parent model as a role match.

A user-authorized per-run model/effort override takes precedence. Record the
requested and effective assignment and override; unavailable assignments block
that route instead of silently substituting another model or effort.

Agent count, labels, ordering, and retry policy come from active skill/contract,
not this adapter. Never assume an extra child slot beside lead.

## Rules

- Canonical `.agents` instructions stay runtime-neutral and wrapper-free.
- Verify tool inventory; do not invent tools from another runtime.
- Subagents read `.codex/agent-adapter.md`, this adapter, then canonical persona.
- Dispatch requires reading `AGENTS.md`, the persona, role contract, common
  checkpoint contract and actual applicable project documents before dependent
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
