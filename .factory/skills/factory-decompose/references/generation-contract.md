# Task Generation and Review Contract

## Source Gate

Input is one explicit approved Factory Planning plan. Run canonical validator before
creating staging files. Lock:

```json
{
  "plan_id": "payment-trust",
  "plan_revision": 2,
  "plan_hash": "sha256:...",
  "plan_content_hash": "sha256:...",
  "project_policy_sha256": "profile composition hash from project.py context",
  "plan_path": "docs/plans/payment-trust.md",
  "capability_ids": ["CAP-01"],
  "acceptance_ids": ["AC-01"]
}
```

`plan_content_hash` pins SHA-256 of exact approved bytes; `plan_hash` pins the
normalized content below. Record `plan_commit` when available as Git provenance.
When Git and the repository are accessible, the graph gate checks a supplied full
commit ID against the plan content. It does not infer intake-time provenance from
the current HEAD, which may have changed after the source lock was created.
Only CRLF/LF differences are equivalent for Git provenance; the separate content
hash still pins exact working-tree bytes. Do not guess or search history as part
of the gate. If Git provenance cannot be established, report it as
unverified rather than inventing a commit.
One canonical plan path remains; older approved bytes live in immutable Git
history. Existing source locks never adopt a replacement implicitly.
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

## Mechanical metadata projection

After authoring the structured envelopes and Markdown prose, run:

```bash
sh .factory/tooling/bin/python.sh .factory/gates/skills/decompose/prepare_metadata.py \
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

## Semantic Gap

```json
{
  "status": "NEEDS_PLANNING",
  "source": "task-decomposer",
  "gap_id": "PG-2-01",
  "affected_capabilities": ["CAP-01"],
  "evidence": ["Fact from approved plan or the project"],
  "reason": "Decision, that is missing"
}
```

Evidence contains facts, not a proposed semantic decision. Stop generation and
preserve last complete checkpoint. New approved plan revision requires full
regeneration; do not mix revisions.

## Graph Gate

```bash
sh .factory/tooling/bin/python.sh .factory/gates/skills/decompose/generate_task_graph.py \
  --staging-dir .factory/memory/staging/tasks/ \
  --source-lock .factory/memory/staging/decomposition-source.json \
  --output .factory/memory/staging/mermaid_graph.txt
```

Every reported violation is a hard block: missing/empty staging, source mismatch,
incomplete capability coverage, duplicate identity, missing Markdown, invalid
schema/metadata, dependency/deferred error, estimate above the applicable project size constraint, or cycle.
Graph is written only on `Graph gate: PASS`. Deterministic violations get one
decomposer fast-fix pass, then the full gate reruns.

## Reviewer Invocation

Start canonical `task-reviewer` only after `Graph gate: PASS`. Pass run identity,
approved plan, source lock, task tree, and graph. Reviewer persona owns the
semantic, architecture, actionability, language, and repair checks; spawn prompt
does not restate them.

After any repair, rerun the deterministic gate before focused semantic recheck.
Reviewer never reads hidden old pre-plan evidence as a second source.

## Acceptance continuity

Read [acceptance data](../../factory-implement/references/acceptance-data.md)
and [check execution](../../../contracts/common/check-execution.md).
Source `acceptance_ids` contains every AC declared by the approved plan. Its
`plan_hash` is `sha256:` plus SHA-256 of UTF-8 text with CRLF/CR normalized to LF,
trailing whitespace removed per line, and trailing whitespace removed at EOF.
`plan_path` resolves from the application working directory. The graph gate rereads
that file and rejects exact-byte hash/AC drift; approval still uses the canonical plan validator.

Every task carries `acceptance_ids`: only parent-plan ACs this task fully closes.
`contributes_to_acceptance_ids` optionally records parent ACs this functional task
helps deliver without closing. Functionality requires at least one closure or
contribution. A functional contributor with empty `acceptance_ids` must provide
non-empty `local_acceptance_criteria`, using canonical criterion objects:

```json
{
  "acceptance_ids": [],
  "contributes_to_acceptance_ids": ["AC-01"],
  "local_acceptance_criteria": [
    {"id": "AC-01", "applies_to": "global", "requirement": "Producer delivers its bounded output", "verification": "Check producer output"}
  ]
}
```

Local IDs belong to task namespace. In a graph retaining full parent-plan source
registry, runtime check refs use `local:AC-01`; preserve task `parent_plan_ref` and
contribution refs. A standalone `factory_decompose_task` source may instead use
`acceptance_origin: task_local`, local criteria as source registry and
`parent_plan_ref` plus contributions as provenance; runtime task `acceptance_ids`
then refers to that source-local registry. Neither form claims parent closure.
The intake mapping belongs to acceptance-data; generated envelope IDs stay local.
Mixed closer/contributor tasks may also declare local checks; parent closures
retain full original meaning. Preparatory/research tasks can have no parent ACs
but still need local completion conditions.

Every source AC must have a full closer; contributions never count as coverage.
Unknown IDs, missing local conditions, or uncovered full ACs block gate. For each
contributed AC, at least one full closer must depend transitively on all its
producers. This allows A's bounded functional result to pass before B verifies
indivisible end-to-end AC; no cyclic acceptance dependency is required.

Copy closure IDs to `- **Acceptance criteria:** AC-01` (`—` if empty), contributions
to `- **Contribution to plan criteria:** AC-01` (`—` if empty). Render local objects as
`### Local acceptance criteria` with `ID | Applicability | Criterion | Verification`.
Gate compares local table meaning and IDs the envelope. Retain parent criteria's
actual meaning in acceptance section and link plan; IDs alone prove no semantics.
Reviewer verifies bounded local acceptance, contributions and complete AC closer.

Common project gates and additional risk-based checks are not an AC quota and
are not removed when all source ACs are allocated. Old source locks/envelopes
must be regenerated; never edit the approved plan merely to satisfy this gate.

A preparatory task without a parent-plan AC must retain its parent-plan reference
and explicit local acceptance goal. It does not prove the parent capability
complete. Never add behavior or silently drop required ACs during decomposition.
