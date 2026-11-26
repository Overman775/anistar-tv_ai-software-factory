# TaskReviewer evidence

Read the approved plan, the checked task set and the selected project documents. Use the bound packet's `review_request` and its canonical hash, run ID, assignment ID and reviewer identity. Return findings with their precise paths and tested basis. The coordinator records the actual worker response through `decompose run report`.

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

After an explicitly authorized repair, deliver the changed files and the complete [manifest](../../../skills/factory-decompose/references/generation-contract.md#completion-handoff). Review the checked final set on the new ticket.
