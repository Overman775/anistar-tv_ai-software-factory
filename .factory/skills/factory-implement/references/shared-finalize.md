# Finalize

1. Accept every task/slice after its required evidence; dependent slices use the
   accepted base. For multiple tasks require a final integration task covering
   combined changed scope and cross-slice behavior. No required deferred item
   may remain. Revalidate latest source and final integration hashes.
2. Confirm every dispatched writer is actually terminal. Cancel/close using real
   runtime operations where available; bookkeeping retirement alone is not proof
   of termination. Unknown outcomes block completion and cleanup.
3. Update docs/specs before final checks/review. If indexed inputs changed and
   Graphify is configured, parent refreshes once after writers. Report an absent
   optional graph refresh honestly. If refresh changes in-scope product bytes,
   refresh required evidence. Delegates do not refresh the graph independently.
4. Record concise result, actual profiles/models, original/final graph, changes
   of assignments and reasons, checks with file scope/hash, findings/retries,
   user decisions, outstanding work and measured usage (`null` if unknown).
5. Save additional required evidence under the run's history directory. Then
   `workflow.py archive completed "<summary>"` publishes verified terminal history and returns its path.
   Record the run ID together with the returned workflow database path.
   On failure retain state. Keep secrets out of summaries and additional evidence. The journal retains raw transport output, which may already contain sensitive data.
6. After successful archival, dispatch the [final Teacher review](../../../workflow/orchestration.md#teacher-at-run-completion)
   once for the run. A retro already held for this run contributes its recorded notes.
   Use [cleanup](shared-cleanup.md). Report history path and remaining temporary
   files if any. History stays until explicit deletion.
7. Do not automatically stage, commit, push, publish, merge or release. These
   retain separate user authorization. An ordinary authorized docs update needs
   no extra docs checkpoint.

For cancellation stop new dispatch, resolve all live/unknown writers, preserve
user code and write `archive cancelled` before cleanup. Blocked runs stay
resumable, never masquerade as completed because retry allowance is exhausted.
