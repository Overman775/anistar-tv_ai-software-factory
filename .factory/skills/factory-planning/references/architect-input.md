# Architect assignment input

Use the supplied Planning packet as read-only source/decision evidence:
already locked source, confirmed facts and evidence levels, user-confirmed/delegated decisions,
contradictions, bounded unknowns, directive mode and requested continuation.
It is not an approved downstream plan. The coordinator owns questions, discovery
loop, approval and publication. Do not load its full session procedure.
If discovery exit is explicitly recorded and evidence is consistent, render one
candidate without repeating discovery. Otherwise return the concrete missing fact
or contradiction. Write only a private candidate file under the candidate plan
contract, using its validator and unchanged live target for --previous. Return
candidate path; coordinator alone checks and promotes. Never replace live target. Never edit the working session or approval copy.
