# Refactor guidance

Preserve externally observable behavior. Record invariants and existing
checks before edits. Implementer may mechanically adapt imports/setup/mocks but
must preserve assertions, expected values, scenarios and goldens. Use independent
review for behavior-sensitive changes. If behavior must change, return to source
intake/planning rather than disguising it as refactor. Tester verifies the preserved behavior.

Use `.factory/workflow/orchestration.md`, shared gates, state and finalize contracts.
