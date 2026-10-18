# Claude Code Adapter

Claude runtime source files:

- Agent wrappers: `.claude/agents/*.md`
- Settings/hooks: `.claude/settings.json`
- Canonical personas: `.agents/agents/*.md`
- Skills symlink: `.claude/skills -> ../.agents/skills`

## Tool Mapping

| Canonical action | Claude Code action |
|---|---|
| Spawn agent | use `Agent`/team tool with configured subagent name |
| Notify teamlead | `SendMessage(to: "teamlead", ...)` when available |
| Notify another agent | `SendMessage(to: "<agent>", ...)` |
| Continue agent/message | `SendMessage(to: "<agent>", ...)` when available |
| Track task state | `TaskCreate` / `TaskUpdate` when available |
| Read/write files | `Read`, `Write`, `Edit` |
| Ask user | `AskUserQuestion` if available; otherwise show the question in chat and wait |
| List devices action | FVM shell command from the active skill |
| Connect debugger action | `mcp__dart-fvm__dtd` after inspecting its schema |
| Capture runtime errors action | `mcp__dart-fvm__get_runtime_errors` when exposed |
| Hot restart/reload action | `mcp__dart-fvm__hot_restart` / `mcp__dart-fvm__hot_reload` when exposed |
| Stop app action | Stop the owned FVM shell process |

## Project MCP Capabilities

The runtime handshake exposed Dart `analyze_files`, `dtd`,
`get_runtime_errors`, `hot_restart`, and `hot_reload`; wrappers grant only the
role-specific subset. Claude tool names use `mcp__dart-fvm__<tool>` so the
project FVM server does not collide with a user-level `dart-mcp-server`.
DCM uses `mcp__dcm__dcm_analyze` and, for developer formatting only,
`mcp__dcm__dcm_format`. Context7 uses `mcp__context7__resolve-library-id` and
`mcp__context7__query-docs` for developer, code-explorer and bug-hunter.
Architect, doc-writer and decomposition roles retain their original MCP scope.
Review roles receive analysis only; test-writer receives DCM analysis.

The probed Dart inventory does not expose `run_tests`, `dart_format`,
`dart_fix`, `list_devices`, `launch_app`, `get_app_logs`, `stop_app`, or
`list_running_apps`. Use the active skill's FVM/Melos commands for those
operations; inspect capabilities again after server changes. Do not replace
missing tools with unrestricted MCP access. Skills retain command ordering,
write ownership and test/build gates.

## Delegated Checkpoints

Use live-handle progress and `SendMessage` when exposed. If Agent call blocks
parent or returns one-shot, validate contract artifact and Done Signal on
return. Missing progress/cancellation tools and silence are never failure.

## Rules

- `.claude/agents/*.md` are wrappers only.
- Wrappers must read `.agents/agents/<agent>.md` before action.
- Wrapper tool lists retain native runtime tools. Discover optional MCP tools
  through exposed `ToolSearch` and inspect their real schemas. Project servers
  are configured in `.mcp.json`: `dart-fvm` (FVM Dart), `dcm`, and `context7`.
  Keep source-project provider settings and unavailable integrations/plugins out.
  Without an exposed matching capability, use the project's FVM/Melos shell commands from
  `docs/melos_tooling.md` and `docs/05_development_and_testing.md`.
- Require explicit reading of `AGENTS.md`, the active adapter, role contract,
  common checkpoint contract and actual applicable project documents. Dispatch
  includes concrete paths, locked source/run identity, owned paths and expected
  output; an index or another role's summary is insufficient.
- Use the actual exposed wait/resume, interrupt and close operations. Continue
  the same role when supported and source/run identity matches; otherwise
  restore its checkpoint only after verifying no active writer. Retire handles
  when no close exists. Missing optional tools do not consume recovery attempts.
- Do not duplicate canonical persona content in `.claude/agents/`.
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
