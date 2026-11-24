# Decompose staging and envelope

## Mechanical metadata projection

After authoring the structured envelopes and Markdown prose, run:

```bash
.factory/tooling/bin/cli decompose metadata \
  .factory/memory/staging/tasks .factory/memory/staging/decomposition-source.json \
  --checkpoint UNIQUE_CHECKPOINT_ID
```

The helper checks the source and staging digests and target paths, saves the
complete staging tree in a new checkpoint, and writes derived headers and totals via atomic sibling files. It
returns only paths and counts; author prose remains. Use one authorized writer.
The helper does not lock out concurrent writers. On interruption or failure,
reconcile partial staging against its checkpoint before retrying with a new ID.
Run the normal graph and independent review gates after the helper. It does not
authorize assembly or substitute for semantic review.

## Transactional staging

Write internal envelopes and drafts through temporary sibling paths, validate,
then atomically rename. Keep last complete checkpoint under
`.factory/memory/staging/checkpoints/`. Interrupt or failed retry must not delete
last valid draft. Cleanup may remove only artifacts owned by current run after
final assembly succeeds.

## Internal Envelope

Each scope writes
`.factory/memory/staging/tasks/{scope}/task_result.json`:

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

Missing file is generation failure, not empty scope. Formatting/save mismatch
gets one fast-fix retry. Semantic mismatch returns `NEEDS_PLANNING`.
