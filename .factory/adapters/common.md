# Shared coordinator adapter rules

## Project MCP capabilities

Resolve configured capability aliases against actual host discovery. Use only
the selected profile grants; unavailable required capabilities block dispatch.
Factory connection setup belongs to `skills/factory-install/`; application-specific
server names and historical probes belong to the project profile.

## Profile capabilities without role wrappers

The dispatch packet includes the resolved profile. `capabilities` selects read,
edit, commands and web usage; `mcp` is a portable allowlist of server.tool names
(aliases map to this host's verified server IDs). Other MCP calls are forbidden by
instruction. Tool access cannot exceed the host's actual permissions. Disallowed
web/MCP/edit actions must not be emulated through shell or another allowed tool.
Role contracts can narrow permissions further; capability true never overrides
role ownership. `commands: true` still obeys project-checks reservation.

`enforcement: instructions` means behavioral rules, not technical isolation.
The shipped generic adapters cannot guarantee per-agent filtering across shell,
MCP and built-in tools. `enforcement: required` therefore blocks dispatch with
BLOCKED_CAPABILITIES. Do not silently downgrade it. A future sandbox/tool-filter
mapping requires implementation and validation, not a YAML claim of support.
For example edit:false with commands:true is not a read-only sandbox.

## Context ownership

This document is coordinator-only. Deliver the configured worker_instructions
through the shared context builder, not this setup/dispatch procedure. Native
and ACP must use the same role/process/stage selection. Avoid full parent-history
inheritance by default, including same-model dispatch. If the user explicitly
requires inheritance, record it as an exception and do not claim context isolation.
Inspect auto-loaded AGENTS/skills and real host behavior; document unsupported
filtering instead of assuming a compact packet clears previous context.
