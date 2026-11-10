# Shared worker adapter rules

Use the resolved profile's read/edit/commands/web and MCP allowlist; the host's
actual permissions are the upper bound. Do not emulate disallowed access through
shell or another tool. Role ownership can narrow profile capabilities further.
`enforcement: instructions` is behavioral policy, not OS isolation; `required`
needs supported enforcement and must not be silently downgraded.
Inspect actual exposed tools; do not invent names or infer available servers from
configuration alone. Installations vary. Follow the supplied qualified names and current tool schemas.
No nested delegation, model fallback, provider setup or session management.
Return the assigned artifact/result to the coordinator through your final reply;
only use an explicitly provided handoff channel. Read actual mandatory project
files. Missing tools/permissions are concrete blockers, never PASS.
