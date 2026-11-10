# Project gates

Explicit definitions loaded by `gate_files` in [project.yaml](../project.yaml).

| File | Boundary / usual executor |
| --- | --- |
| [roles/authors.yaml](roles/authors.yaml) | implement.work — Developer, TestWriter or Generalist |
| [roles/judge.yaml](roles/judge.yaml) | implement.verify — final verification by Judge |
| [skills/decompose/gate.yaml](skills/decompose/gate.yaml) | decompose.complete — общий валидатор вызывает проектную проверку |
| [skills/code-review.yaml](skills/code-review.yaml) | implement.review + code-review.complete — Judge or standalone Review |

Shared author checks have one definition, not one copy per role. Names organize
files; `at` and the workflow graph determine execution. All Implement checks remain mandatory
at final verify; Decompose checks stay within decomposition. Reviewer cannot run commands; standalone Review coordinator owns
tool evidence. [Factory gates](../../gates/README.md) remain mandatory independently.

Each file contains only `gates: [...]`. Paths in `gate_files` are relative to the
profile. Command cwd, inputs and scope selectors remain relative to the application.
No glob, recursive include, implicit directory loading or last-file-wins override.
IDs must be unique across the combined policy. Empty gate_files is valid; a declared
file must exist and contain a nonempty list. Inline gates are supported for small
profiles, but cannot be mixed with gate_files.

All connected files enter the policy hash and accepted Review snapshot. They are
not copied wholesale into worker prompts. Edit the accepted policy before a new
intake; do not weaken conditions during an active run.

Portable examples with timeouts, dependencies, path filters and observations:
[authors](../examples/gates/roles/authors.yaml),
[verification](../examples/gates/roles/judge.yaml),
[review](../examples/gates/skills/code-review.yaml), connected from
[project.example.yaml](../project.example.yaml). Adapt commands before use.

Gate results follow [the common contract](../../gates/result-contract.md).
Inspect the generated map with `sh .factory/tools/python.sh .factory/tools/catalog.py`.
Custom Decompose scripts print structured status/message/evidence; malformed output
or execution error blocks the transition. Project checks never replace core/review.
