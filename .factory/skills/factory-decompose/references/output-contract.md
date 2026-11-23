# Final Assembly and Handoff Contract

Only the coordinator invokes the assembler. Tasks and review are prepared first;
the assembler repeats common/project checks and verifies current reviewer evidence.
Never replace this with manual copying or reuse an old PASS after changes.

## Review request

Run the graph and project checks and bind the real author/reviewer assignment identities:

```bash
sh .factory/tooling/bin/python.sh .factory/gates/skills/decompose/assemble.py review-request \
  --staging-dir .factory/memory/staging/tasks \
  --source-lock .factory/memory/staging/decomposition-source.json \
  --request .factory/memory/staging/review-request.json \
  --author-done .factory/memory/staging/decomposer-done.json \
  --evidence-dir .factory/memory/staging/decompose-evidence \
  --run-id RUN --assignment-id REVIEW_ASSIGNMENT \
  --author-id AUTHOR --reviewer-id REVIEWER
```

Save the actual author's Done Signal as JSON outside task staging and supply it
unchanged. The command checks the staging root, exact file paths and byte digests,
task count and absence of blockers before running the graph. For a synthetic
exercise, provenance remains explicitly synthetic. A missing historical signal
requires retrieving the original or collecting a fresh handoff from its author.

Replace identity placeholders with actual assignments. The author and reviewer differ.
The configured default profiles are used when no profile options are supplied.
For a non-default assignment add `--decomposer-profile NAME` or
`--reviewer-profile NAME` to this command. Later assembly reads the selection
from the request.
A failed or blocked check is reported to the coordinator and writes no new request;
do not use a request left from an earlier attempt.
On success, pass `decompose-evidence/graph.md` to the reviewer.
Pass the request and printed request_hash under the
[review contract](../../../gates/skills/decompose/review-contract.md).
Record the returned report as review-result.json outside task inputs.
For a reviewer repair, preserve the initial request and save the same reviewer's
fresh Done Signal for the entire repaired staging tree in the same shape as the
author's. Create a new request path and assignment ID. Use
`--previous-request PATH --repair-done PATH` in place of `--author-done` and
keep the run, author, reviewer and profile identities. Recheck the full repaired
set. A decomposer fast-fix instead supplies a fresh author's Done Signal.

## Transactional final assembly

```bash
sh .factory/tooling/bin/python.sh .factory/gates/skills/decompose/assemble.py assemble \
  --staging-dir .factory/memory/staging/tasks \
  --source-lock .factory/memory/staging/decomposition-source.json \
  --request .factory/memory/staging/review-request.json \
  --review .factory/memory/staging/review-result.json \
  --evidence-dir .factory/memory/staging/decompose-evidence \
  --bundle-id TASK_BUNDLE
```

Use a safe lowercase bundle ID. Destination is docs/tasks/{bundle_id}/. Existing
bundles are never overwritten. All files are prepared in a temporary sibling
and the directory is renamed atomically; staging remains recoverable.
One task produces its Markdown only. Multiple tasks also produce epic.md with
source provenance, task links, graph and publication-composition JSON. The small
publication composition is for a later Publisher, not technical
implementation contract.

Task Markdown contains no internal task_result.json envelope. The authoritative
gate-result.json records current identities, hashes and every required condition.
FAIL/BLOCKED prohibits assembly. A PASS grants only creation of local task files;
it does not mean that copying succeeded if the filesystem later rejects the write.

## Handoff

Stop after local files. Never publish externally, start implementation or alter
the approved plan automatically. The user chooses whether to inspect tasks,
request external publication or explicitly start factory-implement. No second
semantic approval is required when assembling the already reviewed plan/tasks.

Review bindings created before the current policy hash require a new review request and
independent review. The binding includes workspace `AGENTS.md` and required coordinator
and the instruction files selected for the actual Decompose worker profiles.
It also covers the staging contract used for a repair. They cannot be migrated as approvals. Output protection remains separate.
