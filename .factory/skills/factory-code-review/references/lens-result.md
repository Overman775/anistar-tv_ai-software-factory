# Standalone lens result

For factory-code-review only. Read the assigned lens criteria in
`.factory/contracts/common/review-principles.md`, requested behavior, manifest,
authoritative diff/source and parent tool evidence. Do not run project checks
or return a verdict. Inspect the code and return the assigned lens JSON.

```json
{
  "schema_version": "4",
  "review_id": "id",
  "mode": "branch | pr | feature",
  "base_sha": "sha or null",
  "head_sha": "sha",
  "scope_hash": "sha256",
  "lens": "system-design | runtime-safety | verification-quality",
  "done_signal": "COMPLETE | FAILED",
  "gates": [{
    "gate_id": "owned gate",
    "status": "PASS | FINDING | NOT_APPLICABLE | NOT_RUN",
    "evidence": [{"kind": "source", "path": "file", "line": 10, "side": "new"}],
    "reason": "required for conditional NOT_APPLICABLE or any NOT_RUN"
  }],
  "findings": [{
    "finding_id": "stable lens ID",
    "gate_id": "owned gate",
    "path": "scoped/file.dart",
    "line": 10,
    "rule": "human-readable violated rule",
    "description": "concrete impact",
    "fix": "bounded correction",
    "severity": "critical | high | medium",
    "confidence": "high | medium",
    "evidence": [
      {"kind": "source", "path": "scoped/file.dart", "line": 10, "side": "new"},
      {"kind": "tool", "tool_id": "tests", "command_index": 0}
    ]
  }]
}
```

Evidence forms:

```json
{"kind": "source", "path": "file", "line": 10, "side": "new"}
{"kind": "source", "path": "deleted", "line": 7, "side": "old"}
{"kind": "tool", "tool_id": "static", "command_index": 0}
{"kind": "binary", "path": "asset.png"}
{"kind": "file_operation", "path": "scripts/start.sh", "operation": "mode", "old_mode": "100755", "new_mode": "100644"}
{"kind": "file_operation", "path": "scripts/start.sh", "operation": "rename", "old_path": "scripts/old.sh", "new_path": "scripts/start.sh"}
```

Diff evidence resolves to exact added/deleted hunk line. Feature evidence
resolves to current file line. Binary or file-operation finding uses `line: null`.
File-operation evidence requires exact paired mode or rename extended headers
in authoritative branch/PR diff. `path` is the section's destination path;
rename includes exact old/new names. Explain how the operation causes the
reported failure, including affected consumers. Feature mode has no operation
evidence. Tool evidence supplements source/binary/operation evidence; it cannot
replace finding location. Never invent a changed line or classify text as binary
for metadata-only changes.

Free findings use gate_id: null; they do not require a predefined criterion. `rule_id` is unsupported. Same line does not imply same finding.
Universal gates cannot use `NOT_APPLICABLE`.
`SYS-INTENT` uses requested behavior and acceptance criteria. If either intent
context is unavailable, return `NOT_RUN` with reason; never guess `PASS`.

## Missing requirements and supporting context

A missing/partial requirement may use `kind: missing-requirement`, path/line null,
nonempty investigation describing inspected implementation and the absent behavior,
and evidence of both kinds:

```json
[{"kind":"requirement","requirement_id":"AC1"},
 {"kind":"inspection","path":"lib/service.dart","line":12}]
```

Requirements resolve against captured context; inspection resolves against pinned
source_evidence (also usable for unchanged consumers). Ordinary code findings retain
a valid diff/current-source location and may add inspection evidence. No fabricated
line for an absent implementation. Semantic sufficiency is checked by Reviewer and QA.
If no grounded requirements are available, SYS-INTENT must be NOT_RUN.
