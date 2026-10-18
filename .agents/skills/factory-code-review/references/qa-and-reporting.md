# QA and Reporting

QA reads source findings and parent tool failures. It challenges high-risk
PASS/NOT_APPLICABLE and proposed verdict in reasoning, not machine artifacts.
QA cannot erase findings silently.

## QA Output

```json
{
  "schema_version": "3",
  "review_id": "id",
  "mode": "branch | pr | feature",
  "base_sha": "sha or null",
  "head_sha": "sha",
  "scope_hash": "sha256",
  "code_verdict": "APPROVE | NEEDS_WORK | RETHINK",
  "semantic_gap": null,
  "added_findings": [{
    "finding_id": "QA-1",
    "gate_id": "RUN-BEHAVIOR",
    "path": "file.dart",
    "line": 10,
    "rule": "QA-discovered rule",
    "description": "concrete impact",
    "fix": "bounded correction",
    "severity": "high",
    "confidence": "high",
    "evidence": [{"kind": "source", "path": "file.dart", "line": 10, "side": "new"}]
  }],
  "severity_overrides": [{
    "finding_id": "RUN-1",
    "severity": "high",
    "reason": "evidence-backed correction"
  }],
  "manual_merges": [{
    "source_ids": ["RUN-1", "VER-2"],
    "reason": "same demonstrated defect",
    "finding": {
      "finding_id": "QA-1",
      "gate_id": "RUN-BEHAVIOR",
      "path": "file.dart",
      "line": 10,
      "rule": "merged rule",
      "description": "shared impact",
      "fix": "single bounded fix",
      "severity": "high",
      "confidence": "high",
      "evidence": [
        {"kind": "source", "path": "file.dart", "line": 10, "side": "new"}
      ]
    }
  }],
  "notes": []
}
```

- Severity override requires explanation.
- Added finding is QA provenance (`found_by: ["qa"]`) with its own source ID.
  It must use a current routed gate and pass normal finding path, evidence,
  severity, confidence, and fix validation. QA may challenge lens `PASS`.
- Finding IDs are globally unique. A QA addition colliding with a validated
  lens finding or earlier QA addition is excluded; original valid finding
  remains visible and pipeline becomes incomplete.
- Manual merge requires at least two valid source IDs and preserves them.
- Invalid merge leaves source findings intact and makes pipeline incomplete.
- `RETHINK` requires nonempty `semantic_gap`; other verdicts require null.
- Critical/High or executed tool failure prohibits `APPROVE`.

## Validator Boundary

Validator checks:

- manifest identity and authoritative scope/diff hash;
- exactly three unique lens outputs;
- exact universal/conditional gate coverage;
- gate statuses, reasons, and structured evidence;
- finding ownership, scoped path, added/deleted/binary evidence, fix,
  confidence, severity;
- exactly `static/tests/deps` parent results with raw command records;
- QA overrides/merges and verdict constraints;
- QA-added findings, global finding-ID collisions, and failing-command evidence;
- escaped current Markdown.

Validator does not infer intent/severity, derive exact commands, treat
Policy/Graph as gates, or defend against a writer controlling shared workspace.

Tool result may be `NOT_APPLICABLE` with nonempty reason and no commands.
`NOT_RUN` remains incomplete. Command records carry bounded stdout/stderr
excerpts and truncation flags. Validator JSON and collapsed report internals
retain only nonzero command records with argv, cwd, exit code, excerpts, and
truncation flags.

## Partial Truth

Structural error makes pipeline `INCOMPLETE`. Finding remains reportable when
its identity, ownership, path, evidence, and fields validate independently.
Malformed finding is excluded. Missing gate/lens/tool cannot erase valid
findings from other artifacts.

Renderer consumes validator-owned result only. All untrusted strings are
Markdown/HTML escaped and flattened to one line.
