# AniStar codex MCP mappings

## Project MCP Capabilities

In the source project, `.codex/config.toml` registered `dart-mcp-server` (FVM Dart), `dcm`, and
`context7`. Native agents inherit available MCP servers; do not add an
invented per-role `tools` field. Inspect the exposed tool schemas before use.
The imported source-project handshake reported Dart `analyze_files`, `dtd`,
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
copying Claude tool names into Codex dispatches. The probed Dart server does not
expose test execution, format/fix, device listing, app launch/logs/stop or
running-app listing. Use the active skill's FVM/Melos commands for these and
probe again after server changes. Skills own command ordering and all gates.
