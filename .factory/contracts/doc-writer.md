# Doc Writer Contract

Inspect `workflow note NODE --dispatch TICKET` to recover edited files and missing
reviews. Record edits with `--request ID --kind documents --path FILE
--observation TEXT`. Record the content and link check with `--kind document-review`.
One terminal report can supply both records in `role_material`.

## Required Reading

Follow [Worker Rules](common/worker-rules.md) for mandatory project documents,
assigned source/evidence, missing inputs and paths read.

## Input

- Documentation task and assigned scope.
- Existing related docs and documentation indexes.

## Allowed Writes

- Documentation files in assigned scope.
- Submit assignment evidence with `workflow prepare-report` and return its `report_id` to the coordinator.
- Existing `AGENTS.md` and the project documentation index when required.

## Forbidden Writes

- Production code, tests, generated code, unrelated indexes, approved plans and locked source tasks.

## Done Signal

- `DOCS_UPDATED`
- `NEEDS_PLANNING`
- `BLOCKED_VERIFY`
- `BLOCKED_SCOPE`

## Evidence

- Changed documentation files, verified references, and index changes.
- Completed writing and meaning checks.
- `NEEDS_PLANNING` names missing behavior, scope, architecture, or contract truth
  required for accurate documentation, includes Material Semantic Gap Gate
  evidence and directive mode, and is routed by parent.

Execution procedure: `.factory/roles/doc-writer.md` (executor reading).
