# Architect Candidate Plan Contract

This is the candidate-writing subset of [the canonical plan contract](plan-contract.md).
The coordinator owns the working session, promotion, approval and publication.

## Plan ownership

Include goal, observable outcome, scope, non-goals, stable `CAP-{NN}`
capabilities, behavior and exceptions, solution shape and owners, decisions,
unknowns, risks, readiness, QA intent and handoff recommendation. Never include
task or slice IDs, estimates, ticket dependencies, publication IDs or task-local
fields. Decompose derives those without changing approved semantics.

## Durable plan boundary

Keep behavior, ownership, contract gist, constraints and acceptance that must
survive internal refactoring. Delivery slices belong to Decompose; current paths,
symbols, edit order and commands belong to Implement. Do not perform implementation
detail lookup for a plan-only request.

## Candidate state and previous revision

Use exactly the metadata keys and values in the template below; do not add
question budgets, counters, publication metadata, task counts or estimates.
A draft candidate is `PLAN_READY`, `draft`,
and `approved_revision: none`. For the first presented candidate use revision 1.
After presentation, a semantic change increments revision once and resets approval.
For drafts, formatting, spelling and machine-only repairs preserve revision and
approval state. Approved bytes are immutable; only an explicitly user-authorized
requirements change starts a new draft revision from an approved plan. The coordinator
preserves the approved snapshot and approval evidence in an immutable Git commit
before replacing the canonical path; never rewrite approved history.
The coordinator classifies the change. Preserve stable IDs and compare every later
candidate with the unchanged live target using the validator `--previous`. For a
coordinator-classified nonsemantic change, also pass
`--change-kind nonsemantic --change-evidence "{specific rationale}"` using the
coordinator's evidence. If
classification or required evidence is missing, return to the coordinator; do not
classify the change yourself. Classification does not prove unchanged meaning.
Return
contradictions or missing facts to the coordinator without replacing the target.
Never publish or approve a plan. Record advance delegation under `Source and
context` as `Planning authorization: explicit_user_delegation — "{exact directive}"`;
otherwise use the template's awaiting-approval wording. Delegation cannot invent
external facts or authorize weaker protection. Handoff recommendation alone never
authorizes continuation.

A semantic change includes behavior, scope, outcome, solution shape, decision,
contract gist, boundary, readiness, verification, source conclusion or handoff
recommendation. Preserve stable capability, decision and acceptance IDs across
revisions. Approval-only changes belong to the coordinator.

For a semantic revision, compare the candidate with the approved predecessor
against the authorized change scope. Preserve behavior and decisions outside
that scope, including negative, no-op and failure paths; retaining an ID alone
does not preserve its meaning. If locked source contradicts the approved
predecessor outside that scope, return the concrete conflict to the coordinator
as a gap for resolution instead of choosing either version in the candidate.

Use the [shared plan content and canonical template](plan-content.md).
