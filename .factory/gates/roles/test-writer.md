# Test Writer completion gates

## Evidence

- Report starts with current `run_id` and `source_hash`.
- For Implement, follow the [result contract](../../contracts/common/implement-result.md)
  for scope snapshots. Describe changed files separately; verify snapshots after execution.
- Test files plus direct commands with `cwd`, exact command, exit code, and a
  concise failure excerpt.
- `PASS` requires at least one direct test command and zero exit codes.
- Exact source behavior covered, additional risk coverage, and any remaining
  gaps/blockers with reasons. Do not claim completion with missing mandatory checks.
- Execute delegated test commands directly, including unchanged existing tests
  when requested. Delegated command execution is not valid evidence.
