# Implement result and stage boundaries

Read [Implement handoff evidence](implement-handoff.md) for required fields, snapshots and write-stage evidence.

For a command-capable assignment follow the supplied check-execution contract.
Final role Done Signals apply only after its assigned verification completes.
Review requires an independent APPROVE for PASS; known FAIL/BLOCKED stage results
must agree with outcome. Report discovered defects and evidence; tracked reviewer
IDs use review-findings when supplied. Never omit an unresolved defect to get PASS.

Project boundary gates arrive in project_policy.gates. Return all selected check
results; missing or stale runner receipts prevent PASS. Runtime derives gate_results;
do not invent them. Gate success never replaces final verification/acceptance.
For review, answer each selected project_policy.review_criteria in review_checks:
{id, result: PASS|NOT_APPLICABLE, evidence}; NOT_APPLICABLE also needs reason.
Defects use existing findings and non-APPROVE verdicts; never hide them with N/A.

## Verification awaiting approval

On a verify node, use outcome `BLOCKED` and stage_result `APPROVAL_REQUIRED` only
when the single failed check needs the approval action named in project rules.
Include its real runner receipt in checks and add approval_request with action,
execution_id, evidence and files. Files maps exact candidate paths to SHA-256
digests of the inspected bytes. Include paths outside the current task only where
the project check explicitly permits approval of those paths. Evidence identifies the candidate and
explains why the failure requires only an external decision. Run the other
required commands and keep their receipts current. Commands downstream of the
failed check through declared dependencies wait until verification resumes. Send the request to the
coordinator before applying any candidate. Ordinary failures follow correction.

## Dependency handoff

Summarize consequential decisions and reasons, constraints, unverified behavior and
open questions; distinguish facts from hypotheses. Preserve exact paths, interfaces
and evidence references in existing fields without repeating checks. Keep full logs in artifacts. Tester returns all required checks in the canonical
result. The assignment packet carries a short verification summary with failure
details and the immutable `report_ref`. Preserve actionable findings, their IDs,
known limitations and incomplete work in the existing structured report fields.
Use `report_ref` if the short summary is insufficient to decide a correction or review.

Use `cli workflow read-report REF.json` with the exact `report_ref` object when
full predecessor evidence is needed. The helper checks content and dispatch
identity and supports archived references. Read every supplied mandatory
instruction and keep consequential caveats in the next handoff. Prior PASS
is historical; verify current files. Author explanations never replace requirements
as the test oracle.


An actual unsuccessful attempt without a usable artifact may return FAIL with
FAIL_CODE or FAIL_TEST and `unsuccessful_attempt` containing nonempty
`attempted_work`, `unmet_requirement` and `evidence`. Describe what was attempted
and what remains unfulfilled. Use actual observations or artifact references.
