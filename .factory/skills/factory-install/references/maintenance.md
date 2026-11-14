# Update, repair and diagnosis

Diagnosis inventories without mutating installed settings. The disposable dry run
is allowed as a local probe; external doctor commands may have side effects, inspect
before invoking. Distinguish missing executable, wrong PATH/interpreter, incompatible
version, authentication failure, quota and unavailable host capability.

Repair the failing component only; retain working compatible dependencies. Repeating
an unchanged failing installer is not repair. Continue independent authorized work
while an interactive login/trust step waits for the user. Never request secrets in chat.

For update, identify current and target bundle/dependency versions and local edits.
Read upstream compatibility notes; do not substitute arbitrary latest. Finish/stop
active runs before replacing files they use. Existing ledgers do not hot reload or
migrate automatically. Compare the previous bundle, local copy and candidate when
available; if the baseline is unavailable, report uncertainty and preserve edits.

Preserve project settings, runtime profiles, host config, unrelated skills and
credentials. Never copy live state or virtualenv from another machine. Back up
replaced owned files/settings; remove obsolete owned files only after checking
local changes. Preserve a partial result and recovery instructions if a step fails.
No automatic updater or transactional rollback is claimed.

Repeat relevant verification after changes: dry run for factory/Python changes,
host discovery after skill wiring, selected transport after adapter/client changes,
corpus checks after ignore changes. Newly excluded components are not silently
reinstalled. Report actual versions, remaining blockers and restart requirements.

## Legacy layout migration

Identify the installed version and baseline before touching `.agents/`. Finish or
cancel active workflows, archive them and run that version’s clean operation before
migration. Verify archive JSON
and referenced evidence are readable. Compare baseline, local copy and candidate;
show additions, replacements, moves, deletions and conflicts. Preserve modified
files, project profile and runtime values, MCP and permissions, gates and decisions.
Unknown ownership or occupied targets are conflicts, never overwrite them. Show
configuration changes separately. Remove old files only when their ownership and
unchanged content are established.

Before mutation create a dated backup outside the destination paths containing every
affected file and symlink and record original paths and hashes. Move `.ai-pipeline`
to `.factory/memory` without changing archived bytes or run IDs; never create an
old-root symlink. Preserve referenced evidence and resolve archived relative
`.ai-pipeline/` references using `factory.runtime.memory.resolve_evidence(workspace, path)`
when viewing them; do not rewrite archives or hashes. If a reference cannot be resolved, report
the missing evidence. Reject an existing destination or active run until resolved.
Keep the backup until verification completes. On interruption, stop writers, restore
all affected paths and links from that backup, verify hashes, then retry the inventory
and comparison. A repeated install recognizes `.factory/` and preserves memory.
