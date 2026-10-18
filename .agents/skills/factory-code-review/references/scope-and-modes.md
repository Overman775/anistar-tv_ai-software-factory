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
  "schema_version": "3",
  "review_id": "unique id",
  "mode": "branch | pr | feature",
  "target": "resolved target",
  "base_sha": "40 hex chars or null for feature",
  "head_sha": "40 hex chars",
  "scope_files": ["sorted/relative/path.dart"],
  "source_sha256": {"sorted/relative/path.dart": "sha256 for feature"},
  "diff_file": ".ai-pipeline/state/review.diff",
  "diff_sha256": "sha256 or null for feature",
  "scope_hash": "sha256"
}
```

`scope_hash` is SHA-256 of compact sorted-key JSON containing `mode`, `target`,
`base_sha`, `head_sha`, `scope_files`, `diff_sha256`, plus `source_sha256` in
feature mode.

Branch/PR diff contains one unique `diff --git` section per scoped path.
Feature requires `base_sha`, `diff_file`, `diff_sha256` null and exact
`source_sha256` keys/current bytes for every scoped file. Source drift makes
pipeline incomplete and invalidates feature evidence.

## Parent Tools

Parent chooses commands; validator checks results, not exact plan:

```bash
python3 .agents/skills/factory-code-review/scripts/run_tool_checks.py \
  --manifest .ai-pipeline/state/review-manifest.json \
  --tool-id static \
  --command '{"argv":["fvm","dart","run","melos","run","analyze"],"cwd":"."}'
```

Repeat for `tests` and `deps`. When impossible:

```bash
python3 .agents/skills/factory-code-review/scripts/run_tool_checks.py \
  --manifest .ai-pipeline/state/review-manifest.json \
  --tool-id tests \
  --not-run-reason "exact blocker"
```

When tool family does not apply:

```bash
python3 .agents/skills/factory-code-review/scripts/run_tool_checks.py \
  --manifest .ai-pipeline/state/review-manifest.json \
  --tool-id deps \
  --not-applicable-reason "scope has no dependency change"
```

`NOT_APPLICABLE` is complete evidence. `NOT_RUN` means applicable work could not
run and blocks completeness. Command stdout/stderr is capped to 24 KiB excerpts
with truncation flags.


## Large Scope

- Zero files: stop.
- Above 400 changed lines: recommend split.
- Above 800 changed lines: recommend decomposition unless user accepts.
- Feature above 50 files or 3000 lines: ask continue/narrow.
