# Native Implement packet

For a native file bootstrap, run its `read_command` in `read_shell` and the stated
shared workspace.
Read one returned chunk per tool result; follow `next` until all ordinals are visible.
Do not concatenate all chunks into one tool output that may truncate. Each call checks
identity, digest, config and source; stop on failure. If the last chunk says reserved,
repeat its command until bound/running; only then start assigned writes or commands.
Read all chunks even when the final call reports `ready_for_work`. Save observable
read outputs when requested; a file, digest or self-report alone does not prove delivery.
