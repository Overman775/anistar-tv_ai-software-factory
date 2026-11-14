# YAML tooling

Use the shipped configuration and [checker](../../../tooling/README.md#yaml-checks).
Owned `.yaml` and `.yml` files include factory settings, project profiles, gates,
decisions, examples, pinned fixtures and factory skill metadata. Vendor skills,
environments, caches and run output are outside scope.

- Use two-space indentation and indented block sequences. Preserve meaningful key
  order, comments, regexes, command arguments and multiline scalar contents.
- Use `true` and `false` for booleans; quote ambiguous strings such as `"yes"` or
  `"on"`. Duplicate mapping keys fail. A valid null remains permitted by its contract.
- Do not require sorted keys, a document-start marker or a hard line-length limit.
  Narrow lint exceptions need a reason; do not disable checks for an entire file tree.
- `yaml-lint` runs pinned yamllint with an explicit configuration. It checks syntax
  and style, not factory semantics. Checks never reformat files automatically.
- `yaml-contracts` reuses runtime/configuration and project-policy validators.
  Gate/decision files must be explicitly composed through a checked profile's
  `gate_files`/`decision_files`; reading or hashing a rule file does not validate it.
  Unknown contracts fail explicitly. Only `skills/factory-*/agents/openai.{yaml,yml}`
  receives the harness syntax-only exemption, not a claim of harness validation.
- Fixture YAML is checked in a disposable installed layout. Validation runs no
  configured project commands, models or network operations and preserves source.
  Owned directory/YAML symlinks fail discovery. Fixture overlays reject source and
  destination symlinks and escaping destinations before copying any fixture files.

Run both stages after YAML edits; use the full checker for affected tooling changes.
For style-only edits, compare parsed values before/after. Test meaningful failures
such as duplicate keys, unknown fields, missing definitions and invalid references.
JSON Schema and editor integrations are optional; avoid a second conflicting contract.

GitHub workflow YAML belongs to repository CI. The Lab additionally checks it with
actionlint 1.7.12, with optional ShellCheck/Pyflakes integrations explicitly disabled.
This binary is not required by an installed factory; checks do not download it.
