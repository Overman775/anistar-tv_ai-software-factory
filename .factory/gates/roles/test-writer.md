# Test Writer completion gates

## Evidence

- Report starts with current `run_id` and `source_hash`.
- For Implement, follow the result instructions supplied for the current stage.
  Describe changed files separately and verify snapshots after execution.
- Report test files and the next verification stage at a writes-only handoff.
- When the assignment requires test execution, `PASS` requires at least one
  successful direct test command and zero exit codes for executed checks. For an
  Implement work node with a `project-checks` reservation, include a successful
  assigned tests receipt; a missing result is not accepted. Report `cwd`, exact
  command, exit code, and a concise failure excerpt for direct commands.
- Exact source behavior covered, additional risk coverage, and any remaining
  gaps/blockers with reasons. Do not claim completion with missing mandatory checks.
- Execute assigned test commands directly when authorized, including unchanged
  existing tests when requested. Delegated command execution is not valid evidence.
  The assignment determines authority to run commands.
