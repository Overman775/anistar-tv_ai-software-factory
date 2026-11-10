# Native Implement packet

For a native file bootstrap, run its `read_command` in `read_shell` and the stated
shared workspace.
Read one returned chunk per tool result; follow `next` until all ordinals are visible.
Do not concatenate all chunks into one tool output that may truncate. Each call checks
identity, digest, config and source; stop on failure. If the last chunk says reserved,
repeat its command until bound/running. Execute `confirm_command` in the same
shell after receiving all chunks and before assigned writes or commands. Stop and
report a failed read or confirmation. Save observable read outputs when requested.
