# Cleanup

Permanent `.factory/memory/history/` and planning/decomposition `.factory/memory/staging/`
are outside implementation cleanup. Keep active, blocked and unknown work.

After actual worker termination, archive the completed/cancelled run, capture any
required packet/read evidence, then invoke `workflow.py clean`. Do not delete a
packet when its individual worker finishes: downstream work may need run state.
The command requires verified history and removes its exact workflow.json and all
registered helper artifacts after validating every cleanup path. It never recursively
removes directories or deletes unregistered files.
Reject symlinks, directories, traversal, foreign paths and ambiguous ownership.
Unknown files remain. Do not delete application code, tests, docs, source tasks,
approved plans, another skill's state or any history record.

For an old `pipeline.md`, do not translate or delete it automatically. Reconcile
its original run and use that version's ownership/terminalization procedure.
Starting the new ledger over legacy state is blocked. A stale lock similarly
requires confirming its owning process has stopped; elapsed time is insufficient.

If history writing, runtime termination or exact deletion fails, report the
remaining path/reason and preserve resumability. No `rm -rf`, wildcard deletion,
recursive pruning, or cleanup of another run to make a new start succeed.
