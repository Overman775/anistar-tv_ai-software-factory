# Final Assembly and Handoff Contract

## Common Gate

Before assembly:

1. Re-run Factory Planning validator with `--phase approved`.
2. Compare current plan hash with `decomposition-source.json`.
3. Require every task envelope to carry same `plan_id`, revision, and hash.
4. Require complete capability coverage, passing dependency graph, and approved
   task review.
5. Verify unique task IDs and filenames; filename is safe basename without
   `/`, `\`, or `..`, in format `NN-slug.md`. `NN` exactly matches final
   `-NN` sequence of task ID; for example, `orders-list-core-01` becomes
   `01-orders-list-core.md`.

Any mismatch returns `SOURCE_DRIFT` or `BLOCKED_NO_APPROVED_PLAN`. Assemble no
partial set.

Final task Markdown is human-readable source for development and optional publication. It has
no schema-v2 object, JSON task envelope, or machine-readable technical contract.
Staging JSON exists only for deterministic validation and may be removed after
successful assembly.

## Epic

When reviewed result has two or more tasks, require stable ASCII
`publication_id`. Move tasks to `docs/tasks/{publication_id}/{filename}`
without renaming.

Create `docs/tasks/epic_{publication_id}.md`:

````markdown
# Эпик: {name}

- **Источник плана:** [{plan_id} revision {N}]({relative plan path})
- **Ожидаемый результат:** {summary}
- **Оценка:** {min}–{max} ч
- **Ветки:** {только если пользователь согласовал стек; база и цель по `docs/vcs_guidelines.md`}

## Критерии готовности эпика
- ...

## Граф задач
{mermaid_graph}

## Задачи
| ID | Назначение | Результат | Модуль | Оценка | Родительская задача | Зависит от | Заблокировано |
|---|---|---|---|---|---|---|---|

## Состав публикации

```json
{
  "schema_version": 1,
  "kind": "epic",
  "id": "{publication_id}",
  "title": "{name}",
  "outcome": "{summary}",
  "tasks": [
    {
      "id": "{task.id}",
      "file": "docs/tasks/{publication_id}/{task.filename}"
    }
  ]
}
```
````

This small JSON block is publication composition for Publisher, not technical
implementation contract. It contains only epic/task identity and file paths.

## Standalone

When reviewed result has exactly one task with maximum estimate 16 hours, save
as `docs/tasks/{scope}/{filename}`. Do not create fake epic or publication
manifest.

## Transactional Move

Assemble into temporary sibling paths, validate final set, then atomically
rename. Keep last complete staging checkpoint until final paths pass validation.
Interrupt must not remove last valid draft or approved planning artifact.

## Handoff

FactoryDecompose stops after local files. It never:

- publishes tasks externally;
- starts implementation;
- changes approved plan;
- asks for a second semantic approval.

Possible next actions chosen by user:

- inspect/edit decomposition;
- publish only on an explicit user request through the available integration;
- execute a task via `factory-implement`;
- execute approved plan directly via `factory-implement` instead of decomposition.
