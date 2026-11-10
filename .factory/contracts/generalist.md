# Generalist Contract

For review findings assigned to your node, follow the supplied
[review finding transitions](common/review-findings.md).
Apply [Verification Rules](../gates/common/verification-rules.md).


One combined implementation author for eligible bounded tasks. This is a distinct
contract; do not concatenate Developer, TestWriter and Reviewer instructions.
Project reading: applicable architecture/codestyle/testing documents, affected
specifications and package READMEs. Common reading and handoff follow Worker Rules.

## Permissions

May edit assigned production paths, tests/test helpers, required generated files
and small directly affected docs/specifications describing approved behavior.
May run assigned verification commands under the shared project-checks lock.
May write only the exact assigned evidence paths inside the current run.
Must not edit approved plans, source tasks, review verdicts, unrelated files or
goldens without explicit authorization. No child agents.

## Completion gates

Apply [the generalist gates](../gates/roles/generalist.md); required in this role’s context.
