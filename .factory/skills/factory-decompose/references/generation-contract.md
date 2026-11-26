# Task Generation and Review Contract

## Source Gate

Read the approved plan and the selected project documents. The assignment carries the plan ID, approved revision, normalized hash and public destination. Task boundaries, dependencies, coverage and estimates follow the [decomposition policy](decomposition-policy.md). Use the [task template](task-template.md) and its [structured envelope](staging-contract.md#internal-envelope).

## Completion handoff

With the current run and dispatch, send each UTF-8 file via `decompose run deliver --run RUN --dispatch TICKET --request KEY --path RELATIVE_NAME --file FILE`. Separate workspaces may transport those exact bytes to the caller. Register the author's list with `decompose run manifest --run RUN --dispatch TICKET --request KEY --file MANIFEST`. The manifest can arrive before the last file. Status reports the missing names and digests. Keep the original ticket and acknowledge only the bytes actually received. If the author stopped before DONE, the coordinator can supply the independently checked path-to-SHA-256 map with `decompose run confirm-files --run RUN --request KEY --file HASHES --evidence BASIS`. The process checks the complete envelope/file set before coverage and independent review.

```json
{
  "status": "DONE",
  "staging_root": "worker/tasks",
  "task_count": 1,
  "blockers": [],
  "files": [
    {"path": "orders/task_result.json", "sha256": "<64 hex digits>"},
    {"path": "orders/01-orders.md", "sha256": "<64 hex digits>"}
  ]
}
```

## Semantic Gap

Report `SEMANTIC_GAP` with the missing product decision. Missing technical placement can usually be resolved from the accepted documents and one bounded targeted lookup.

## Acceptance continuity

Check the exact plan AC and CAP IDs, the named verification owners and all task dependencies. The process records the common and project gates on the delivered basis before issuing a read-only independent review.
