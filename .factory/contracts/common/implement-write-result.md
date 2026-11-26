# Implement write handoff

Read [Implement handoff evidence](implement-handoff.md) for required fields, snapshots and write-stage evidence.

Report discovered defects and evidence. Use review-findings when supplied.
Never omit an unresolved defect to get PASS.

Submit `write_result` with owned code paths, scoped regression files or assigned check IDs, and changed documents or `docs_current`. For incremental delivery use `workflow handoff NODE --dispatch TICKET --request ID` with `--code`, `--test`, `--docs` or `--docs-current`. Read the same command without a request to see missing evidence.
