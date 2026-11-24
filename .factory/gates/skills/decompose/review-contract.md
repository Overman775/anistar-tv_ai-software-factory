# TaskReviewer evidence

Coordinator runs `cli decompose assemble review-request` as preflight; it runs the graph gate
and project checks. Start TaskReviewer only after the request succeeds. Do not run
a separate preflight in the normal route.
Bind run_id, assignment_id, author_id and reviewer_id to the actual host assignments;
the reviewer must differ from the author. The request is coordinator-owned. Pass
its exact bytes, printed request_hash and task paths to TaskReviewer. Do not ask
the model to invent a digest or identity. Identity fields are provenance records,
not cryptographic proof of which model authored text.

The reviewer returns exactly these schema keys, with no extra report field
(including `project_documents_read`). Cite actual project document read paths in
relevant `criteria[].evidence` and, if pertinent, `findings[].evidence`:

```json
{
  "request_hash": "<printed hash of request>",
  "run_id": "<from request>",
  "assignment_id": "<from request>",
  "reviewer_id": "<from request>",
  "role": "task-reviewer",
  "verdict": "APPROVE",
  "criteria": [
    {"id": "plan-coverage", "status": "PASS", "message": "<actual conclusion>", "evidence": ["<plan/task paths and locations>"]},
    {"id": "task-cohesion", "status": "PASS", "message": "<actual conclusion>", "evidence": ["<task paths and locations>"]},
    {"id": "architecture", "status": "PASS", "message": "<actual conclusion>", "evidence": ["<project policy/task paths>"]},
    {"id": "verification", "status": "PASS", "message": "<actual conclusion>", "evidence": ["<AC and verification paths>"]}
  ],
  "findings": []
}
```

Use NEEDS_WORK for confirmed issues and BLOCKED for missing knowledge or inability
to review. Criteria use PASS/FAIL/BLOCKED. Findings contain unique id, boolean
blocking, message and nonempty evidence list. Empty findings is allowed only when
there are none. APPROVE with a blocking finding does not open the gate.

After the bounded repair, return a separate Done Signal using the
[completion handoff shape](../../../skills/factory-decompose/references/generation-contract.md#completion-handoff)
for all repaired and unchanged staged tasks. The coordinator preserves the prior
request and supplies the separate repair signal when rebinding. Review after repairs binds a newly prepared request to the final task bytes and
policy. Focused recheck may reuse the same permitted assignment, but must confirm
the complete final set. Do not edit the request or source lock. Coordinator records
the actual returned report outside staging; it must never fabricate approval.
