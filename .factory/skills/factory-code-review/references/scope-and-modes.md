# Scope and Modes

## Branch

Resolve verified base and immutable head, persist exact three-dot diff:

```bash
git rev-parse {VERIFIED_BASE_REF}
git rev-parse HEAD
git diff {BASE_SHA}...{HEAD_SHA}
```

## PR

Use authoritative GitHub PR metadata/diff. Persist immutable base/head SHA,
complete diff, and exact changed paths. Truncated/collapsed diff is `NOT_RUN`.

## Feature

Resolve requested path to sorted nonempty current files. Feature mode has no
branch diff and uses current-source evidence. Use explicit feature scope for
uncommitted current source, including intended untracked files; hash those bytes.
Feature mode does not represent deleted files or a staged/unstaged patch. Never
reset or stash user work to create scope.

## Manifest

```json
{
  "schema_version": "4",
  "review_id": "unique id",
  "mode": "branch | pr | feature",
  "target": "resolved target",
  "base_sha": "40 hex chars or null for feature",
  "head_sha": "40 hex chars",
  "scope_files": ["sorted/relative/path.dart"],
  "source_sha256": {"sorted/relative/path.dart": "sha256 for feature"},
  "diff_file": ".factory/memory/state/review.diff",
  "diff_sha256": "sha256 or null for feature",
  "scope_hash": "sha256"
}
```

`scope_hash` is SHA-256 of compact sorted-key JSON containing `mode`, `target`,
`base_sha`, `head_sha`, `scope_files`, `diff_sha256`, plus feature source hashes, captured context, assignments, command plan and contextual source evidence.
The authoritative field list is canonical_scope_hash in review_contracts.py.

Branch/PR diff contains one unique `diff --git` section per scoped path.
Preserve full extended headers, including `old mode`/`new mode` and
`rename from`/`rename to`; metadata-only sections are reviewable. Scope uses
section destination paths, including renamed destinations. Operation evidence
matches both exact mode values or old/new names from that authoritative section;
a scoped filename alone proves no operation. Changed-line and binary evidence
retain their separate rules. Incomplete/inconsistent operation pairs invalidate
the diff. A rename may also have a mode change or text hunks.
Feature requires `base_sha`, `diff_file`, `diff_sha256` null and exact
`source_sha256` keys/current bytes for every scoped file. Source drift makes
pipeline incomplete and invalidates feature evidence.

## Execution

Use [the run contract](run-contract.md) to prepare exact commands and assignments.
PR description is required context, not proof. Capture it even when empty; associate
it with head_sha and read linked source tasks using project instructions.

## Large Scope

- Zero files: stop.
- Above 400 changed lines: recommend split.
- Above 800 changed lines: recommend decomposition unless user accepts.
- Feature above 50 files or 3000 lines: ask continue/narrow.

## Accepted project policy

Before calculating scope_hash, attach the complete accepted `project_policy`
snapshot produced by `project.py review-policy --revision FULL_BASE_SHA`. Branch/PR
source is `git:<base_sha>`; feature needs an explicit prior accepted snapshot.
The snapshot hash is part of scope_hash. Helpers reject missing/corrupt policy.
Pass the snapshot and exact scope_files in Reviewer assignments; rules and documents
come from accepted bytes even when the diff changes the profile.
