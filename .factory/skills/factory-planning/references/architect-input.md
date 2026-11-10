# Architect assignment input

Use the supplied planning-session.md as read-only source/decision evidence:
source lock, confirmed facts and evidence levels, user-confirmed/delegated decisions,
contradictions, bounded unknowns, directive mode and requested continuation.
It is not an approved downstream plan. The coordinator owns questions, discovery
loop, approval and publication. Do not load its full session procedure.
If discovery exit is explicitly recorded and evidence is consistent, render one
candidate without repeating discovery. Otherwise return the concrete missing fact
or contradiction. Write only `.factory/memory/staging/planning-plan.md.candidate` under the plan
contract, using its validator and unchanged live target for --previous. Return
candidate path; coordinator alone checks and promotes. Never replace live target. Never edit the working session or approval copy.
