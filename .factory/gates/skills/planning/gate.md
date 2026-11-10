# Planning gate

Architect returns only `planning-plan.md.candidate`; live target stays unchanged.
Architect self-checks. Orchestrator independently checks
behavior, full capability coverage, decisions, architecture/ownership, typed
contracts, external handling, readiness, QA separation, downstream usability,
and section-role deduplication. Run deterministic validation last. Semantic gaps
return to the same working session without revision; machine-only defects get
one internal repair and full preflight rerun.
Before promoting the current candidate, record its semantic-preflight outcome,
checked contract and coverage, and any blocking gaps in an existing message,
checkpoint, or report; machine validation alone is not that outcome.

Machine preflight alone does not open planning.complete. The completion result
requires plan-contract, plan-review and approval. After reviewing the final plan
and recording authorized approval, the coordinator writes a report with exactly
plan_hash (digest of plan text), policy_hash (from preflight gate_result),
coordinator_id, verdict (APPROVE/NEEDS_WORK/BLOCKED), evidence (nonempty references)
and approval_evidence (actual user authorization references). Obtain hashes from
the validator output; never invent approval or provenance.
Run validate_plan.py --phase approved --plan PATH --completion-review REPORT.
Only its completion PASS permits the skill's final handoff. Without the report,
the command remains a preflight and the completion gate stays BLOCKED.
