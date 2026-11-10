# Router

The parent uses this policy to select roles, team composition and profiles;
it is not a separate agent. Load the `router` path from `factory.yaml`, the sole
catalog of models, profiles, eligible roles, adapters and limits.
[Orchestration](orchestration.md) governs execution, acceptance, sessions and
history. Scripts validate and record decisions; the parent makes them.

## Select the team

Start with vertical slices of observable behavior, then tasks and agent steps.
Preserve Decompose IDs; direct tasks get run-local IDs, not product tickets.
Backend/frontend layers may share one slice, not separate product acceptance.

Assess error consequences, uncertainty, independent verification, coupling,
context size and capabilities. Choose the smallest sufficient team, never by
line count or by asking the user to select a workflow mode.

| Conditions | Composition |
| --- | --- |
| Low consequence, local/reversible, explicit behavior, reliable oracle; no auth/data loss/public contract/lifecycle/concurrency impact | Generalist implements, tests as applicable and self-checks: SELF_REVIEW, never independent APPROVE. |
| Bounded moderate change, clear oracle, no required independent test authorship | Generalist + independent Judge. |
| Security, authorization, storage/migration, public API, playback/network trust, lifecycle/concurrency, weak oracle or required separation | Developer + TestWriter + independent Judge. |
| Independent scopes benefit from specialization/context separation | Several Developers within/across slices; separate tests, integration and final Judge. |

When eligibility is uncertain, choose the stronger composition. The coordinator records independent_review=true whenever the user or project requires independent review; the graph validator cannot infer risk or those instructions. Risk labels never waive user/project gates. Solo/combined quality and savings are unproven.
Add CodeExplorer for missing facts, BugHunter for unknown failure causes;
assign location search or investigation explicitly, with the needed result depth.
Skip a separate search when verified locations already answer the question;
read the cited current code before dependent edits. Semantic design belongs to
Planning's Architect. Use DocWriter for large or
multi-author documentation; authors handle small related edits. Add advisory
Judges only for uncovered risks; where independent review is required, one final Judge owns the integrated verdict. Eligible solo work ends in SELF_REVIEW PASS. Advisory approval replaces neither required review nor test evidence.

## Assign and revise

Choose only profiles allowed for the role in YAML. Resolve the adapter, load its
instructions and apply capabilities/MCP policy; no persistent native wrappers.
Verify actual model, permissions, tools and runtime. Honor explicit model/harness
requirements; if no eligible profile satisfies them, report a blocker.

Record outcome, risk, required checks and composition reason per task/slice in
the graph; bind each logical agent to role and profile. Reassess when facts change
risk, capabilities or context, or a profile becomes unavailable. Diagnose repeated
failures before adding roles. A fallback must be an eligible configured profile;
record its reason and effective assignment under orchestration's revision rules.
Busy slots require waiting, not model substitution. Reassignment changes neither
approval boundaries nor retry budgets.

Calibration: a specified UI label may qualify for Generalist; localization or
accessibility logic needs reassessment. Even a one-line auth fix requires separate
code/tests/review and negative access tests. A playback preference is one
UI→storage→playback slice with end-to-end tests, not only layer mocks; split
Developers only when scope/competence warrants it. Large features may combine
exploration, planning, slices and advisory review; this is no mandatory template.

## Initial profile decisions

Choose the team first. For each Developer or TestWriter node, evaluate the group's
`initial_profile_decision` against the assignment, constraints and its Choice
definition. Record a separate `profile_selection` with task/node IDs, decision ID
and the complete Decisions answer on that node. Choose the configured default absent
reason for another option. Test complexity is assessed separately from code work;
independent evidence establishes expected behavior. A known example or helper can
support junior, but is not required. An unknown file path alone does not require
senior. Missing material requirements or access need clarification or a blocker;
`no-eligible-profile` means all options are known incompatible, and blocks dispatch.
Do not substitute a profile for a busy slot; wait. Explicit model, harness,
permission and tool requirements
apply before initial dispatch and before correction. An incompatible correction
target is a blocker; do not spend the budget or silently substitute.

For changed assignment inputs, reassess affected pending nodes using current facts.
A pre-dispatch profile change requires revise, a reason, fresh answer and a new
logical agent; after any reservation use correct for a failed assignment. Technical
revision after correct retains the initial choice and records current suitability in
the revision reason. Source or decision-policy changes require authorized re-intake.
Choice confidence is not worker success probability; model quality and savings are
not established by these policies.

## Named profiles and escalation

Choose the specialty/team before the model. Use `profiles.<role>.default` for normal
assignments; choose junior for bounded, clear, low-risk work and senior for
technical complexity or risk. Names do not prove quality. Generalist retains
its existing eligibility; adding junior Developers does not change team rules.
All profiles of a specialty share its procedure, contract and permissions.

For a failed assignment, classify quality, complexity, environment or requirements.
Attribute a code defect to Developer and a test defect to TestWriter. FAIL_CODE
is not a TestWriter failure. WRITES_READY is intermediate until assigned verification.
Do not interpret tool calls, a waiting timeout or silence as failed attempts.

For Developer/TestWriter profiles with escalation, submit a task-scoped `correct`
decision through workflow helpers. Quality uses configured failure thresholds and
remaining task/cause budgets. Complexity can move early with terminal evidence;
environment/requirements stop for the actual blocker. Human is the terminal target.
Never change the cause, profile name, logical agent or run merely to reset a budget.
Honor explicit model/tool requirements; unavailable targets block, not silently
fall back. Verify candidate tools, model and permissions before dispatch.

Only the coordinator reads escalation policies and chooses diagnoses. Workers
return evidence and unresolved questions; they do not choose or spawn successors.
