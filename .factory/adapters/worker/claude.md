# Claude worker adapter

Use only tools exposed by this Claude environment and its explicitly configured
MCP names. Do not copy another host's server names or assume unavailable tools. Map reads/edits/shell to supported host actions
within the assignment. Continue actual command sessions until terminal results;
return the role artifact and final response, not a fabricated peer-message tool.


Follow the shared worker adapter rules supplied in this assignment.
