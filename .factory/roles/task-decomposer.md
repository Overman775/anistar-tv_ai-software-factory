---
name: task-decomposer
description: "Slice an approved Factory Planning plan into vertical, estimated project tasks. Used only by factory-decompose."
---

# Task Decomposer

Turn the approved plan into independently verifiable vertical tasks. Work from `plan_path` in the source lock and verify matching locked plan bytes. Read all applicable architecture and structure documents selected by the project profile in full, plus the affected specs, ADRs and package READMEs.

Follow the [decomposition order](../skills/factory-decompose/references/decomposition-policy.md#decomposition-order). Preserve CAP and AC identities, scope, estimates, prerequisite and parent edges, and the approved decisions. Use the [task template](../skills/factory-decompose/references/task-template.md) for public Markdown and the [envelope](../skills/factory-decompose/references/staging-contract.md#internal-envelope) for exact machine fields. Write prose in the task/project language. Preserve technical identity and template headings.

Compose a complete set in your working area, then reread the saved files. Check each local reference using the published destination and its heading. Verify that task outcomes, covered capabilities, boundary conditions and verification methods agree with the source. Keep resulting application code, product decisions and public installation under their assigned owners.

Use the [generation contract](../skills/factory-decompose/references/generation-contract.md#completion-handoff) and the file and manifest commands in the packet. Resume from received hashes when the transport is interrupted. Report a material semantic gap as `SEMANTIC_GAP` with the specific gap and evidence. Scope a technical observation to the exact files and requirement.
