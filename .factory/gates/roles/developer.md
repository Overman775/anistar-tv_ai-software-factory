# Developer completion gates

## Evidence

- Source kind/path/hash checked.
- Files changed and commands run.
- Affected consumers, behavior needing verification, and remaining work outside
  assigned writes. Report evidence and paths; do not prescribe invented test outcomes.
- Every preflight check required by assigned process records `cwd`, exact command,
  and exit code. Developer fixes failures in owned files before returning
  `IMPLEMENTED`; unrelated pre-existing failures are identified explicitly.
- Reports start with `run_id` and `source_hash`.
- Exact directive mode is reported. Explicit no-plan authorizes only bounded
  direct choices; delegated planning routes material choices to parent.
- `NEEDS_PLANNING` names exact behavior/scope/architecture/API/acceptance gap,
  supplies evidence for the coordinator’s Material Semantic Gap Gate and reports directive mode.
  Teamlead decides terminal gap versus delegated Factory Planning handoff.
