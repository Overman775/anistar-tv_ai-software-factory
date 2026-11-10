# Decompose gate

```bash
python3 .factory/gates/skills/decompose/generate_task_graph.py \
  --staging-dir .factory/memory/staging/tasks/ \
  --source-lock .factory/memory/staging/decomposition-source.json \
  --output .factory/memory/staging/mermaid_graph.txt
```

Any reported source, coverage, schema, Markdown, identity, dependency,
deferred, estimate, or cycle violation blocks graph and assembly. Deterministic
errors return to decomposer for one fast-fix pass, then the complete gate reruns.
They do not invoke planning or require user approval.

The graph validator also runs project decompose.complete commands after its common
checks. Re-run immediately before final assembly and after any artifact change.
Require the current policy/artifact hashes and PASS receipt; a saved old PASS is
not reusable. Missing/failed/timed-out project checks block assembly. Scripts
receive normalized tasks/envelopes on stdin and must not edit artifacts. They are
trusted project code, not a sandbox; preserve existing execution permissions.

Graph validation is preflight, not permission to complete. Final assembly uses
`assemble.py`: prepare a bound request, obtain an independent TaskReviewer report,
then revalidate and create the local task bundle. Missing/stale evidence is BLOCKED;
a confirmed violation is FAIL. All required conditions must PASS.
See [review contract](review-contract.md) and
[output procedure](../../../skills/factory-decompose/references/output-contract.md).
Assembly never starts implementation or publication.
