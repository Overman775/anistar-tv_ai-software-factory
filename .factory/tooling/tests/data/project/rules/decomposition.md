# AniStar decomposition reading

Both roles read full `docs/01_architecture_principles.md` and
`docs/02_project_structure.md`, plus `PRODUCT.md` and
`docs/05_development_and_testing.md`. Select affected specifications through
`docs/specs/README.md`, decisions through `docs/adr/README.md`, and owning
package READMEs through `docs/README.md`. Pass concrete paths to both roles. Architecture is a quality gate, not an optional
context optimization. Bounded lookup limits apply to feature-code exploration,
not to these canonical architecture sources.

Branching follows `docs/vcs_guidelines.md`; main is the baseline, no automatic branch creation.

## AniStar task metadata

Keep the existing project vocabulary: domain, data, presentation, navigation, di,
api, tests. List the affected layers in each task; a vertical task may cross layers.
Discover actual boundaries in the canonical sources above, not from this list.
Keep the existing estimated maximum of 16 hours per task; split a larger task by
verifiable outcome. This is an estimate convention, not an agent execution timeout.
The project gate checks these metadata constraints only. TaskReviewer still checks
architecture, coherent scope, testability and coverage of approved requirements.
Run the common graph validator after edits and immediately before final assembly;
it also runs the project gate. Never publish after a failed or stale result.
