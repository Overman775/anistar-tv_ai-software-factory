# Codex worker adapter

Use available read/search tools, apply_patch for permitted edits, and exec_command
for assigned shell commands. Commands still require the applicable reservation.
Follow the assignment's verified MCP mapping for this host. Do not assume
test/device/app-launch tools exist; use authorized project commands when needed.
Keep returned command session IDs and wait for actual completion. A yielded call
or silence is not failure. Report to the parent via the final subagent response.


Follow the shared worker adapter rules supplied in this assignment.
