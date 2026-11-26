# Decompose delivery

## Transactional staging

A delivery records exact bytes and their relative name under the assignment in SQLite. The worker may author in its own temporary directory. Use the hashes returned by the process to identify missing bytes on resume. Only the public task Markdown and its generated companion files are installed in the requested destination.

## Internal Envelope

Deliver each scope envelope under `{scope}/task_result.json`:

```json
{
  "source_plan": {
    "plan_id": "payment-trust",
    "revision": 2,
    "hash": "sha256:..."
  },
  "capability_coverage": [
    {
      "capability_id": "CAP-01",
      "task_ids": ["web-view-payment-trust-01"],
      "coverage": "complete"
    }
  ],
  "summary": "...",
  "total_min_hours": 6,
  "total_max_hours": 8,
  "tasks": [
    {
      "id": "web-view-payment-trust-01",
      "acceptance_ids": ["AC-01"],
      "filename": "01-web-view-payment-trust.md",
      "title": "Verifiable outcome",
      "purpose": "functionality",
      "scope": "payment_trust",
      "outcome": "Observable outcome",
      "affected_layers": ["domain", "data", "presentation", "tests"],
      "contract_type": "backend_api",
      "implemented": ["Current slice behavior"],
      "deferred": [],
      "parent_task": null,
      "depends_on": [],
      "blocked_by": [],
      "estimate": {"min_hours": 6, "max_hours": 8, "confidence": "medium"}
    }
  ]
}
```

Each `**/task_result.json` must be an envelope with a `tasks` list and the fields
above. Single-task/list payloads, version tags and inferred filenames are rejected.
Regenerate tagged inputs using the current envelope and task fields.
Internal schema never appears in final task Markdown.

Gate every envelope:

- source tuple exactly matches locked source;
- `tasks` is non-empty;
- each capability has exactly one disposition;
- referenced task IDs exist;
- every task belongs to at least one `complete` capability when source has
  `CAP-*` declarations;
- core visible Markdown identity, provenance, capability list, purpose, module,
  and estimate agree with staging values;
- filenames are safe, unique basenames in format `NN-slug.md`, where `NN`
  exactly matches final `-NN` sequence of task ID; for example,
  `orders-list-core-01` becomes `01-orders-list-core.md`.

