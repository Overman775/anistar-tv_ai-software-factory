# Reviewer Prompt

Dispatch exactly one canonical reviewer per lens:
`system-design`, `runtime-safety`, `verification-quality`.

```text
Perform AniStar TV review lens: {lens}.

Read manifest, authoritative diff/current source, parent tool results, then actual project documents relevant to lens.
An index or another role summary does not replace reading the applicable files.

Freely discover problems. Mandatory gates are minimum checklist, not search
boundary. In reasoning, attack high-risk PASS and NOT_APPLICABLE decisions.
Do not emit machine challenge phases/artifacts. Never claim tool execution.

Identity:
schema_version={schema_version}
review_id={review_id}
mode={mode}
base_sha={base_sha}
head_sha={head_sha}
scope_hash={scope_hash}

Scope files:
{scope_files}

Requested behavior:
{requested_behavior}

Acceptance criteria:
{acceptance_criteria}

Owned gates:
{owned_gates}

Return JSON only using schema below. No verdict.
```

```json
{
  "schema_version": "3",
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
    "rule_id": "optional known advisory rule ID",
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
```

Diff evidence resolves to exact added/deleted hunk line. Feature evidence
resolves to current file line. Binary finding uses `line: null`. Tool evidence
supplements source/binary evidence; it cannot replace finding location.

Free-form findings omit `rule_id`. Same line does not imply same finding.
Universal gates cannot use `NOT_APPLICABLE`.
`SYS-INTENT` uses requested behavior and acceptance criteria. If either intent
context is unavailable, return `NOT_RUN` with reason; never guess `PASS`.

## AniStar reading routes

- `system-design`: read `docs/01_architecture_principles.md` and
  `docs/02_project_structure.md` fully, affected specifications selected through
  `docs/specs/README.md`, relevant decisions through `docs/adr/README.md`, and
  owning package READMEs. Trace contracts and consumers, DI and real layer
  boundaries; do not infer correctness from file placement alone.
- `runtime-safety`: read `docs/03_codestyle_and_rules.md` and affected behavior
  specifications. Select the concrete domain additions in `check-registry.md`:
  network/session, client transport, TV/mobile/motion, repositories and logging.
  Check late async answers, disposal, transport,
  cookies/origin transitions and sanitized logging.
- `verification-quality`: read `docs/05_development_and_testing.md`, acceptance
  specifications, related tests and helpers in root `test/`; Android E2E reads
  `integration_test/README.md` and `tool/e2e/README.md`. Commands come from
  `docs/melos_tooling.md`; use fresh run evidence supplied with the task. Check oracle
  strength and regressions for behavior, rather than implementation mirroring.
  Assess UI, accessibility and localization evidence for the affected behavior
  under `VER-CHANGE-SAFETY`, using existing AniStar contracts and capabilities.


Read-only reviewers receive concrete document paths and the original intent.
Do not inherit another lens verdict. Respect runtime concurrency: run the three
independent lenses sequentially or in waves when fewer slots are available.
