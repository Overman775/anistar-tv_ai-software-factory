# Maintain the lesson catalog

Use `.factory/tooling/bin/cli lessons` in the assigned checkout. Read `packet EVENT` and compare the request, current cards and source evidence.

For a reported retrieval or application failure, review the implicated card against the actual query or example. If a correction is warranted, hand the ID and failing example to the coordinator for targeted Edit with the original symptom or example. Leave the originating review pending for the coordinator to close after queuing the edit. For a catalog audit, review the rest only within the requested scope.

For an explicit deletion, compare delete_snapshot with the current card first. If the revisions match, run `delete EVENT --revision HASH` using the pinned revision. If the card changed,
show the owner what changed and
run `wait-owner EVENT QUESTION` before sending the question. Only a new owner message may authorize deleting the
current version. On reply the coordinator registers newly authorized work before closing the old request.
A retry after removal uses the revision from the original attempt. If the card
is already absent on resumption, report that and complete the event.
If other cards name this ID in `replaced_by`, show their IDs and ask the owner
how to resolve those links. Park the event with `wait-owner EVENT QUESTION` and keep the cards intact. Park unresolved revision conflicts before asking the owner.
Run `complete EVENT` after successful removal. Automatic maintenance can propose
deletion; only an explicit user deletion request authorizes it. A missing retro
source alone is insufficient grounds to remove its lesson.

Update the surviving lesson first. Mark an obsolete lesson with its own revision
and `replaced_by` pointing to the surviving active ID. Preserve sources and
allowed counterexamples. Keep project findings local. Promote a distinct portable
procedure as a factory lesson only when it has a recognizable trigger and test.
For a skill change, compare current and proposed wording on the same retained
cases and send the proposal through normal review. Complete the event after all
intended changes are durable.

Publish updates through `publish EVENT - --revision HASH` with the complete
lesson JSON and without runtime-owned sources or edits. If the evidence calls for
a procedure change, return the cited cases to the coordinator for Retune.
