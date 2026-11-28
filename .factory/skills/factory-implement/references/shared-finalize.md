# Finalize

1. Accept every task/slice after its required evidence; dependent slices use the
   accepted base. For multiple tasks require a final integration task covering
   combined changed scope and cross-slice behavior. No required deferred item
   may remain. Revalidate latest source and final integration hashes.
   If the current source changed the locked outcome or checks, keep completion
   blocked until the owner's applicable authorization is recorded and the
   revision is bound by `workflow reintake`.
   Run the required checks again on the accepted revision and final file
   hashes. Retain the actual logs. Keep the run resumable if the accepted
   source or required evidence cannot be established.
2. Confirm every dispatched writer is actually terminal. Cancel/close using real
   runtime operations where available; bookkeeping retirement alone is not proof
   of termination. While any writer's outcome is unknown, stop new dispatch and
   changes to the affected work. Reconcile the process, session and dispatch;
   unknown outcomes block completion and cleanup.
3. Update docs/specs before final checks/review. If indexed inputs changed and
   Graphify is configured, parent refreshes once after writers. Report an absent
   optional graph refresh honestly. If refresh changes in-scope product bytes,
   refresh required evidence. Delegates do not refresh the graph independently.
4. Record a self-contained conclusion naming completed work, check results and
   limitations. Include actual profiles/models, original/final graph, changes
   of assignments and reasons, checks with file scope/hash, findings/retries,
   user decisions, outstanding work and measured usage (`null` if unknown).
   For a check's Python version use the retained command result's
   `reported_runtime` or a version printed by that check itself. The receipt's
   `environment.factory_python` (legacy `environment.python`) is the Factory
   interpreter. If the check's version is unavailable, state that explicitly.
5. Save additional required evidence under the run's history directory. Then
   `cli workflow archive completed "<summary>"` publishes verified terminal history and returns its path.
   Record the run ID together with the returned workflow database path.
   For either terminal outcome, before cleanup check `cli workflow status --json`
   for the current run ID and terminal status, and confirm the archive with
   `cli workflow verify-history RUN_ID --json`. If the archive response was
   lost, retry the same outcome and summary to recover the path. A mismatch
   blocks cleanup. SQLite retains the run graph, workflow event records, report
   links, inventory and hashes, and original registered artifact and transport bytes.
   On failure retain state. For either outcome, keep secrets out of summaries
   and additional evidence. Include only relevant excerpts from role sessions
   by default. Full transcripts require an explicit request. Registered raw
   transport is retained separately and may already contain sensitive data.
6. After successful archival, dispatch the [final Teacher review](../../../workflow/orchestration.md#teacher-at-run-completion)
   once for the run. A retro already held for this run contributes its recorded notes.
   Before cleanup, record the actual post-archive Teacher profile, model and outcome
   when observed. In the final user-facing report include all profiles and models
   actually used, including the post-archive Teacher. State when its result is
   unconfirmed. Keep the archived conclusion immutable.
   Use [cleanup](shared-cleanup.md). Report history path and remaining temporary
   files if any. History stays until explicit deletion.
7. Do not automatically stage, commit, push, publish, merge or release. These
   retain separate user authorization. An ordinary authorized docs update needs
   no extra docs checkpoint.

For cancellation stop new dispatch, resolve all live/unknown writers, preserve
unfinished work and write `archive cancelled`. Verify status and history as
described above before cleanup. Blocked runs stay
resumable, never masquerade as completed because retry allowance is exhausted.
