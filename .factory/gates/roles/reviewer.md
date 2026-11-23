# Reviewer completion gates

## Protocol

Inspect authoritative diff/current source freely, then account for every
minimal owned gate once. Challenge high-risk PASS and `NOT_APPLICABLE` in
reasoning; do not emit challenge phases or machine artifacts.

Use the supplied [lens result schema](../../skills/factory-code-review/references/lens-result.md).
Additional findings may use gate_id null; no advisory registry is required.
Reviewer never reports tool execution.

## Done Signal

Return standalone lens JSON with `"done_signal": "COMPLETE"`. Explicit failed
handoff uses `"done_signal": "FAILED"`. Never return a verdict; parent QA owns
verdict. Output matches dispatch schema exactly.
