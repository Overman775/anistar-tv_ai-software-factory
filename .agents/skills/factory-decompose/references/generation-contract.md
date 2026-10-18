# Task Generation and Review Contract

## Source Gate

Input is one explicit approved Factory Planning plan. Run canonical validator before
creating staging files. Lock:

```json
{
  "plan_id": "payment-trust",
  "plan_revision": 2,
  "plan_hash": "sha256:...",
  "plan_path": "docs/plans/payment-trust.md",
  "capability_ids": ["CAP-01"]
}
```

`capability_ids` is non-empty and contains every declared `CAP-*` exactly once.

Missing, invalid, draft, or stale plan returns `BLOCKED_NO_APPROVED_PLAN`.
Raw requirements or a semantic gap return `NEEDS_PLANNING`. Do not call
Architect or create a local pre-plan.

## Decomposer Invocation

Start canonical `task-decomposer` with only run identity, approved plan path,
source-lock path, and unfinished checkpoint when resuming. Its persona owns
slicing, architecture sources, implementation detail, task template, language,
and semantic-gap rules. Do not duplicate those instructions in spawn prompt.

The decomposer first creates internal capability coverage, then all tasks. It
may group or split capabilities according to decomposition policy. Unlike old
FactoryDecompose, it does not copy a pre-approved task map one-to-one.

Implementation detail adds no internal-envelope fields. It improves human task
Markdown and uses existing architecture/evidence fields; graph validation remains structural.

## Internal Envelope

Each scope writes
`.ai-pipeline/staging/tasks/{scope}/task_result.json`:

```json
{
  "schema_version": 2,
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
      "filename": "01-web-view-payment-trust.md",
      "title": "Проверяемый результат",
      "purpose": "functionality",
      "scope": "payment_trust",
      "outcome": "Наблюдаемый результат",
      "affected_layers": ["domain", "data", "presentation", "tests"],
      "contract_type": "backend_api",
      "implemented": ["Поведение текущего среза"],
      "deferred": [],
      "parent_task": null,
      "depends_on": [],
      "blocked_by": [],
      "estimate": {"min_hours": 6, "max_hours": 8, "confidence": "medium"}
    }
  ]
}
```

Only `**/task_result.json` with top-level `schema_version: 2` is accepted.
Single-task/list payloads, inferred filenames, and legacy schemas are rejected.
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

## Semantic Gap

```json
{
  "status": "NEEDS_PLANNING",
  "source": "task-decomposer",
  "gap_id": "PG-2-01",
  "affected_capabilities": ["CAP-01"],
  "evidence": ["Факт из approved plan или проекта"],
  "reason": "Решение, которого не хватает"
}
```

Evidence contains facts, not a proposed semantic decision. Stop generation and
preserve last complete checkpoint. New approved plan revision requires full
regeneration; do not mix revisions.

## Graph Gate

```bash
python3 .agents/skills/factory-decompose/scripts/generate_task_graph.py \
  --staging-dir .ai-pipeline/staging/tasks/ \
  --source-lock .ai-pipeline/staging/decomposition-source.json \
  --output .ai-pipeline/staging/mermaid_graph.txt
```

Every reported violation is a hard block: missing/empty staging, source mismatch,
incomplete capability coverage, duplicate identity, missing Markdown, invalid
schema/metadata, dependency/deferred error, estimate above 16 hours, or cycle.
Graph is written only on `Graph gate: PASS`. Deterministic violations get one
decomposer fast-fix pass, then the full gate reruns.

## Reviewer Invocation

Start canonical `task-reviewer` only after `Graph gate: PASS`. Pass run identity,
approved plan, source lock, task tree, and graph. Reviewer persona owns the
semantic, architecture, actionability, language, and repair checks; spawn prompt
does not restate them.

After any repair, rerun the deterministic gate before focused semantic recheck.
Reviewer never reads hidden old pre-plan evidence as a second source.
