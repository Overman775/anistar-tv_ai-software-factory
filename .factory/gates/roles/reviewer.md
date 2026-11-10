# Reviewer completion gates

## Protocol

Inspect authoritative diff/current source freely, then account for every
minimal owned gate once. Challenge high-risk PASS and `NOT_APPLICABLE` in
reasoning; do not emit challenge phases or machine artifacts.

Standalone JSON carries matching `schema_version`, `review_id`, `mode`,
`base_sha`, `head_sha`, and `scope_hash`. Gates use `PASS | FINDING |
NOT_APPLICABLE | NOT_RUN`. PASS/FINDING requires structured evidence;
NOT_APPLICABLE/NOT_RUN requires reason. Findings preserve stable ID, optional owned criterion, rule, impact, bounded fix,
confidence, severity and evidence. Code defects keep scoped path/line. Missing
requirements use requirement plus investigation evidence and null location.
Additional findings may use gate_id null; no advisory registry is required. Reviewer never reports tool execution.

## Done Signal

Return standalone lens JSON with `"done_signal": "COMPLETE"`. Explicit failed
handoff uses `"done_signal": "FAILED"`. Never return a verdict; parent QA owns
verdict. Output matches dispatch schema exactly.
