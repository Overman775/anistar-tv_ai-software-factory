# Documents and rules

Shape and examples: [project.example.yaml](../../../project/project.example.yaml).
Ownership and delivery: [project policy](../../../contracts/common/project-policy.md).

## Authoring decisions

- Existing project document: catalog under documents and reference its ID, or use
  project_file for a direct application-relative file. Catalog category is metadata.
- New project-specific instruction: write a focused file near the profile; connect
  through rule.file. A file or Markdown link alone does not deliver context.
- Each rule chooses exactly one source: file, project_file or documents. Combine
  documents sharing recipient/conditions; split when responsibility or applicability differs.
- Put each rule in coordinator or worker. Same material for both groups needs two
  distinct IDs. IDs are unique across groups; for.roles is worker-only.
- for dimensions combine with AND; values within a dimension use OR. Omitted
  dimensions impose no restriction. Empty selector lists are invalid. Use paths_any
  or path_regex, never both. * stays in a directory; ** crosses directories.
- Conditions use existing process/role/stage identities. Backend scope does not
  imply a backend role; a vertical slice can require several domains' materials.
- usage defaults to policy: pinned normative material. reference is background,
  not a way to make mutable acceptance requirements. Unknown scope includes path rules
  conservatively; preview exact affected paths before claiming targeted delivery.

file paths start at the profile directory. documents.path and project_file start
at application root. Declared files are local: no absolute paths, .. escape or
symlink traversal. Documentation can contain external citations; these are not
profile file imports. Unselected catalog documents are not automatically read.

Use the resolver to check the intended recipient and a relevant exclusion case.
Inspect rule provenance as well as deduplicated document delivery. Do not copy
review criterion selectors into reading rules unless the reading requirement
independently justifies the same condition. No mandatory file names, categories,
layers, hours or documentation framework are imposed on the project.
