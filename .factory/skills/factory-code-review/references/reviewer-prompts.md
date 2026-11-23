# Reviewer Prompt

Dispatch exactly one canonical reviewer per lens:
`system-design`, `runtime-safety`, `verification-quality`.

Create and package assignments with the commands in [the skill](../SKILL.md).
The executor receives [lens-result.md](lens-result.md) and
common/review-principles.md, not this coordinator reference.

## Criteria and document routes

Read `.factory/contracts/common/review-principles.md` for the assigned lens.
Read-only reviewers receive concrete paths and original intent, never another
lens verdict. The coordinator runs three independent lenses sequentially or in
waves when fewer runtime slots are available.

Use names and criterion questions from the prepared assignment. AcceptanceReviewer owns SYS-INTENT and verification quality. Read PR description and captured task/incident sources, treat their assertions as claims to verify.
