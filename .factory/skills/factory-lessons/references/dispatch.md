# Dispatch Teacher

After successful archival or resumption, read `cli workflow next` in the run checkout.
Dispatch the `after_archive.event_id` when its status is `ready`. After cleanup,
recover the run’s event from `cli lessons pending` and its packet. For a confirmed
retro finding or manual intake, dispatch only its returned event ID.
When resuming other authorized lesson work, recover its ID from `cli lessons pending`. For each ID
read `cli lessons route EVENT` for its persisted operation and pinned owner text.
Pass [Capture](capture.md) for capture, [Edit](edit.md) for edit, and [Refresh](refresh.md)
for audit or delete. The waiting list is for owner
follow-up. Record a cited answer with `cli lessons reply EVENT REFERENCE ANSWER`, then reconcile that event’s original assignment. Retune supplies its own procedure.

Coordinator: run `.factory/tooling/bin/cli lessons teacher-launch EVENT` in the assigned checkout.
Launch the worker only when the result grants `spawn` or `prepare_acp`. On `reconcile`, inspect the
existing assignment. Bind the observed handle with `lessons teacher-launch EVENT --bind DISPATCH HANDLE`.
Pass DISPATCH to the worker for `--dispatch` on publish, delete, wait-owner and complete.
If a launch response was lost, verify the worker's status. If it has stopped, use
`lessons teacher-launch EVENT --stopped DISPATCH EVIDENCE` and claim with the returned `--ticket`.
For Retune outside an event, inspect the profile with `lessons teacher-launch`. Follow the returned
adapter instructions, its capacity rules, and the exact model ID and effort.
For Codex native use a fresh generic worker with `model` set to the returned
model ID, `reasoning_effort` set to its effort, and `fork_turns="none"`.
Pass the checkout, AGENTS.md, persona, role contract, worker instructions, profile
permissions, Teacher completion gates, common Worker Rules and the assigned
worker reference selected by the entry skill. Keep coordinator intake, dispatch
instructions and other worker procedures out of the assignment. Honor the configured capabilities, MCP allowlist and enforcement.
Pass the event ID and pinned owner
instructions for event work, or the cited cases and owner instructions for Retune.
The assigned Teacher executes the procedure directly, without recursive dispatch.

For a concrete review finding from Capture, Refresh or a worker report, queue a targeted
`user INCIDENT SOURCE OBSERVATION --edit ID` using the original incident, a stable
review reference for that event and card, and the reported symptom or failed
example. Mark the observation as an editorial review and include the query and
expected action. Register the follow-up before closing its originating review event
when still pending, then dispatch Edit with the usual profile. On replay reuse
the same inputs. A remaining miss after the targeted repair is a reported
limitation. Stop processing that ID for this drain and report it for follow-up.

One completed workflow run produces one Capture assignment. Pass its single
event ID to one Teacher for all packet incidents, including linked retro notes.
Do not launch a worker per task or per note. For a demonstrated reuse observed outside the workflow,
`cli lessons capture-case RUN NODE DISPATCH OBSERVATION` remains an explicit intake.
Include how the current result was verified.

Wait for the worker result and verify the durable decision. Record the actual
worker handle and requested model/effort in the handoff. If the config has no
Teacher profile, or the host cannot launch the configured worker with these settings,
report the blocker and leave outstanding events pending. Do not silently substitute
the coordinator or a host default.
