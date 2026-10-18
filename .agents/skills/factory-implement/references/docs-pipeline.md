# Docs Pipeline

Docs workflow updates project documentation only.

Summary:

```text
source gate -> DocWriter -> user checkpoint -> capture -> cleanup
```

## Step 1: Source Gate

Classify `single_task` or `approved_plan`; record source provenance/hash. Apply
Source Sufficiency Gate. Documentation audience, promised behavior, public
contract, or scope ambiguity is classified through exact directive routing and
the Material Semantic Gap Gate. Unverified truth remains a blocker, not
something delegation can invent.

## Step 2: DocWriter

Spawn canonical `doc-writer`.

Prompt:

```text
Documentation task: {task}.
Source: {source_ref}; hash: {source_hash}.
Use existing docs style and source-locked scope. Avoid duplicated content.
Update only existing AGENTS.md and/or docs/README.md indexes that contain a docs
index, and only when docs are created, moved, or renamed.
If requested truth is not established by source/code, return BLOCKED_VERIFY
instead of inventing it. Return NEEDS_PLANNING only with Material Semantic Gap
Gate evidence and directive mode; parent routes terminal gap or delegated
planning.
Return DOCS_UPDATED, NEEDS_PLANNING, BLOCKED_VERIFY, or BLOCKED_SCOPE.
```

## Step 3: User Checkpoint

Present changed docs and validation. Ask: approve, see changes, revise, cancel.
Revision loop max two and must stay inside source lock.

## Step 4: Capture and Cleanup

Close teammate, capture source/mode/files/validation summary, mark completed or
cancelled with `resumable: false`, then use `shared-cleanup.md`. Never delete
project documentation as runtime state.
