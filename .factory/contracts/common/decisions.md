# Decisions

Coordinator owns accepted decisions. An assigned agent may evaluate a question;
pass this contract, exact definition, current inputs and policy with its assignment.
No service required. No definitions means no evaluation; independent checks remain.

## Definitions

Definitions live in project decision_files or inline decisions, never both.
Each has id, question, type and optional min_confidence in [0,1]. Omitted threshold
means no numeric floor; not permission to accept missing data. Explicit types:

- predicate: yes/no condition; optional criteria with quoted "true"/"false" descriptions.
- choice: choices list of unique string value + description pairs; at least two.
- score: 2–10 ordered levels, each with unique label + description; indices start at 0.

Ask one judgment per question. Describe observable criteria; distinguish choices
and adjacent levels. IDs do not replace full questions. Thresholds belong to the
question's acceptance policy; tune on labeled project examples and error costs.

## Accepted answers

Record project applicability answers by definition ID in task.policy_decisions. Initial profile Choice answers belong to their Implement node in profile_selection; see the workflow contract. All typed answers need
nonempty reason (actual evidence/paths) and source (agent identity or provider/model).
Exact shapes; probability maps cover every choice or level and sum to 1:

```yaml
needs-e2e:
  probability: 0.9
  source: agent:coordinator
  reason: "Changed checkout flow in src/checkout.py; evaluated current diff."
change-category:
  choice: fix
  probabilities: {fix: 0.9, feature: 0.05, other: 0.05}
  confidence: 0.85
  source: agent:coordinator; Jev choice formula
  reason: "Restores documented checkout behavior; no new operation."
issue-severity:
  score: 1.1
  probabilities: {"0": 0.0, "1": 0.9, "2": 0.1}
  confidence: 0.85
  source: agent:coordinator; Jev score formula
  reason: "Checkout fails in one browser; another browser completes the task."
```

Examples illustrate formats, not evidence for a real task.

Predicate probability is P(true), not confidence. Acceptance uses confidence
abs(2*p - 1); p=0.5 remains UNKNOWN. min_confidence=0.4 accepts p<=0.3 or p>=0.7.
Accepted p>0.5 means true; p<0.5 means false. This is a symmetric policy, not
separate yes/no thresholds. No rounding near the middle into an accepted answer.

Choice must select the unique maximum-probability option; ties remain UNKNOWN.
Score equals sum(index * probability); preserve fractional values and distribution.
Choice/score confidence is a separate [0,1] estimate, not the selected probability.
Preserve the evaluator's confidence and identify its source/metric; do not silently
substitute another provider's formula. For agent estimates use the Jev conventions:
choice (max(p)-1/n)/(1-1/n); score max(0,1-sum(p_i*abs(i-m))/D), where m is the
first most probable level and D=sum(abs(i-(n-1)/2))/n. These summarize estimated
distributions; they do not establish calibration or correctness.

Below min_confidence, missing facts, inability to estimate, refusal or tool error:
report the blocker outside policy_decisions. Coordinator gathers evidence or assigns
reassessment. Never invent probabilities, reasons or source attribution to pass a
threshold. Agent estimates remain agent estimates; no external service is required.
Confidence never replaces evidence, check results, permissions or publication approval.

Checks can reference predicate only. Choice/score answers do not automatically select checks, roles or actions; an explicit consumer may validate and use them. No expression DSL.
The shared validator returns id, type, value, confidence, source and reason for
every accepted type; batch validation returns these results by ID. Consumers use
validated values. Revisions validate both answer sets against pinned definitions; re-intake validates the previous answers against the previous definitions and new answers against the refreshed definitions.
Keep the original estimates in policy_decisions; derived results do not replace evidence.
All supplied answers are validated, including unused ones. Missing answers are
allowed until a consumer requires them. Unresolved dependent work stays blocked.

Reassess significant input/policy changes; preserve history. Active runs cannot
remove answers or weaken true to false. Choice/score value changes after significant input or policy revision need explicit re-intake;
same-value reassessment may update evidence/confidence. Required checks remain.
Policy/threshold changes require re-intake. Every predicate answer requires
probability, source and reason, including definitions with an implicit predicate
type. Legacy boolean answers and string-only definitions are rejected. No migration.

No provider adapter, automatic fallback or API call is implemented.
