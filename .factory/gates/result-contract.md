# Gate result

A gate controls one process transition. A script, validator or reviewer supplies
checks; the transition owner validates evidence and derives the gate result.
No gate-agent, automated/assessment gate taxonomy or extra review role exists.

Canonical output fields:

- gate_id, boundary, subject: exact gate, transition and run/work identity;
- policy_hash, artifact_hash: actual rules and inputs;
- status: PASS, FAIL or BLOCKED;
- checks: id, status, message, evidence (nonempty references).

A confirmed violation wins FAIL; otherwise missing/stale/unavailable evidence gives
BLOCKED; only all required PASS gives PASS. Retain every reason, including blockers
alongside failures. Unknown/duplicate check IDs cannot satisfy requirements.
The shared implementation is factory_tooling/gates/gate_contract.py; it does not authenticate
model output, assess semantic truth or grant execution permissions.

Generate the current core + project map (no commands are executed):

```bash
sh .factory/tools/python.sh .factory/tools/catalog.py
```

Core definitions come from the same catalog used by executors; project additions
come from gate_files. Project IDs cannot use the reserved factory- prefix.

Planning's validator without completion-review is machine preflight only: ok=true
can coexist with a BLOCKED completion gate awaiting coordinator review/approval.
Code Review's COMPLETE allows a finished local report even if code needs changes;
it never grants code acceptance or publication. Implement derives results only
after existing source/identity/receipt checks. Decompose's assembler alone opens
local task assembly after current independent review and fresh checks.
