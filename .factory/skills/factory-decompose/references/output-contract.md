# Final Assembly and Handoff Contract

Only the coordinator invokes the assembler. Tasks and review are prepared first;
the assembler repeats common/project checks and verifies current reviewer evidence.
Never replace this with manual copying or reuse an old PASS after changes.

## Review request

After graph preflight, bind the real author/reviewer assignment identities:

```bash
sh .factory/tooling/bin/python.sh .factory/gates/skills/decompose/assemble.py review-request \
  --staging-dir .factory/memory/staging/tasks \
  --source-lock .factory/memory/staging/decomposition-source.json \
  --request .factory/memory/staging/review-request.json \
  --evidence-dir .factory/memory/staging/decompose-evidence \
  --run-id RUN --assignment-id REVIEW_ASSIGNMENT \
  --author-id AUTHOR --reviewer-id REVIEWER
```

Replace identity placeholders with actual assignments; author and reviewer differ.
Pass the request and printed request_hash under the
[review contract](../../../gates/skills/decompose/review-contract.md).
Record the returned report as review-result.json outside task inputs.
A repair requires a newly bound request and confirmation of the final set.

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
