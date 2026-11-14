# AniStar claude MCP mappings

## Project MCP Capabilities

The imported source-project handshake reported Dart `analyze_files`, `dtd`,
`get_runtime_errors`, `hot_restart`, and `hot_reload`; the profile MCP allowlist
selects the role-specific subset as instructions, not a technical tool filter. Claude tool names use `mcp__dart-fvm__<tool>` so the
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

## Historical action mapping

| List devices action | FVM shell command from the active skill |
| Connect debugger action | `mcp__dart-fvm__dtd` after inspecting its schema |
| Capture runtime errors action | `mcp__dart-fvm__get_runtime_errors` when exposed |
| Hot restart/reload action | `mcp__dart-fvm__hot_restart` / `mcp__dart-fvm__hot_reload` when exposed |
| Stop app action | Stop the owned FVM shell process |
