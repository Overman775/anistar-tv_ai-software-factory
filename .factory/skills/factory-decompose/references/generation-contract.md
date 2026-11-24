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
  "project_policy_sha256": "profile composition hash from cli project context",
  "plan_path": "docs/plans/payment-trust.md",
  "capability_ids": ["CAP-01"],
  "acceptance_ids": ["AC-01"]
}
```

`plan_content_hash` pins SHA-256 of exact approved bytes; `plan_hash` pins the
normalized content below. Record `plan_commit` when available as Git provenance.
After the coordinator establishes approval, prepare the record from the application
working directory, then save the output as the source lock:

```bash
.factory/tooling/bin/cli decompose source-lock \
  --plan docs/plans/payment-trust.md --config .factory/factory.yaml
```

The command prints JSON to stdout and validates the approved plan structure; it
does not establish approval. Save successful output to
`.factory/memory/staging/decomposition-source.json`. It does not infer a commit;
add `plan_commit` only when its provenance is known. Existing explicit source
locks remain valid. Planning's `plan_hash` uses a different representation and
must not be copied into this record.
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

Read the [staging and envelope contract](staging-contract.md) before writing task files.

## Completion handoff

After saving and rereading the complete staging files, return `status: DONE`,
the staging root path, total task count, and blockers (an empty list when none).
Include a manifest of every `task_result.json` and every task Markdown file:
each entry has its relative path under the staging root and SHA-256 of its exact
saved bytes. Include no other files. Use safe relative paths without traversal.
This manifest is the Done Signal; it does not replace the graph gate or review.
For example, a shared-filesystem response has this shape (digests shown
symbolically; actual values are lowercase hexadecimal SHA-256):

```json
{
  "status": "DONE",
  "staging_root": ".factory/memory/staging/tasks",
  "task_count": 1,
  "blockers": [],
  "files": [
    {"path": "orders/task_result.json", "sha256": "<64 hex digits>"},
    {"path": "orders/01-orders.md", "sha256": "<64 hex digits>"}
  ]
}
```

When the coordinator can read the same files, return paths and digests only, not
file contents. When filesystems are separate, also deliver each manifest file's
exact bytes encoded as base64 in the handoff. The coordinator restores them at
the same relative paths under its staging root before checking them. If transport
cannot deliver all bytes, report a blocker instead of `DONE`.
For this case add `content_base64` to each `files` entry; the other fields and
checks are identical. Decode without text or newline conversion.

The coordinator saves the returned JSON and supplies it to `review-request --author-done`.
The preflight checks that every listed file exists, its bytes match its digest,
the manifest exactly covers the staged envelopes and their referenced Markdown,
and the total matches the task lists. Reject missing, extra, changed, unreadable,
unsafe or incomplete files and any blockers as an invalid handoff. Do not infer
success from a path or count alone. Then run the same deterministic graph gate on
the restored or shared files; its source, schema and coverage checks still apply.
Recheck the manifest after any transfer and before the gate. A decomposer fast-fix
returns a fresh completion handoff; reviewer repairs follow the review contract.

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

The coordinator runs the [review request](output-contract.md#review-request) to validate the graph
and project checks and bind the reviewer in one step. On success the graph is
`decompose-evidence/graph.md`. For standalone graph validation, use the command
in the [decompose gate](../../../gates/skills/decompose/gate.md).

Every reported violation is a hard block: missing/empty staging, source mismatch,
incomplete capability coverage, duplicate identity, missing Markdown, invalid
schema/metadata, dependency/deferred error, estimate above the applicable project size constraint, or cycle.
The graph is written only when core graph validation passes; start review only when
the complete review request succeeds. Deterministic task violations get one
decomposer fast-fix pass, then the full gate reruns. For `BLOCKED / SOURCE_DRIFT`
(exit 2), stop and repeat intake before task validation.

## Reviewer Invocation

Start canonical `task-reviewer` only after the review request succeeds (exit 0
and JSON response). Pass run identity,
approved plan, source lock, task tree, and graph. Reviewer persona owns the
semantic, architecture, actionability, language, and repair checks; spawn prompt
does not restate them.

After any repair, the coordinator prepares a new review request before focused
semantic recheck; it reruns the deterministic gate.
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
