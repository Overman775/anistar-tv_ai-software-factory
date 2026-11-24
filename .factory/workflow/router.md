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
| Low consequence, local/reversible, explicit behavior, reliable oracle; no auth/data loss/public contract/lifecycle/concurrency impact | Implementer authors the change and tests. Tester verifies. Coordinator accepts without independent approval when allowed. |
| Bounded moderate change with a clear oracle | Implementer, Tester and independent Judge. |
| Security, authorization, storage/migration, public API, playback/network trust, lifecycle/concurrency, weak oracle or required separation | Implementer, Tester and independent Judge. |
| Independent scopes benefit from specialization/context separation | One Implementer per assigned change, a Tester for affected behavior and final integration, and the required Judge. |

When eligibility is uncertain, choose the stronger composition. The coordinator records independent_review=true whenever the user or project requires independent review; the graph validator cannot infer risk or those instructions. Risk labels never waive user/project gates.
Add CodeExplorer for missing facts, BugHunter for unknown failure causes;
assign location search or investigation explicitly, with the needed result depth.
Skip a separate search when verified locations already answer the question;
read the cited current code before dependent edits. Semantic design belongs to
Planning's Architect. Use DocWriter for large or
multi-author documentation; authors handle small related edits. Add advisory
Judges only for uncovered risks; where independent review is required, one final Judge owns the integrated verdict. Advisory approval replaces neither required review nor test evidence.

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

Calibration: a specified UI label may qualify for focused Tester verification without a Judge; localization or
accessibility logic needs reassessment. Even a one-line auth fix requires negative access tests, verification by Tester and independent review. A playback preference is one
UI→storage→playback slice with end-to-end tests, not only layer mocks; split
Implementers only when scope/competence warrants it. Large features may combine
exploration, planning, slices and advisory review; this is no mandatory template.

## Initial profiles

Choose the team first. Start Implementer and Tester at their configured defaults. The supplied
defaults are `middle-implementer` and `tester`. Confirm model, harness, permissions and tools before
dispatch. Wait for a busy slot. An incompatible default blocks assignment.
Started task, node, logical agent and profile identities survive revise,
re-intake and physical replacement. Only a recorded correction changes profile.

## Named profiles and escalation

All profiles of a specialty share its procedure, contract and permissions.
Classify evidenced failures as quality, environment or requirements. Code and test defects belong to the assigned Implementer. Additional execution
of an existing check belongs to Tester. WRITES_READY is intermediate.
An attempt without usable output can report FAIL_CODE or FAIL_TEST with attempted
work, unmet requirement and evidence. Prediction, silence and transport delay
cannot count as a failed attempt.

Submit quality corrections through `correct` after confirming terminal status
and current applicability. The configured threshold and task/cause budget
govern escalation. Environment and requirements blockers retain their own
resolution paths. Keep logical lineage and budget on every transition.

Only the coordinator reads escalation policies and chooses diagnoses. Workers
return evidence and unresolved questions; they do not choose or spawn successors.
