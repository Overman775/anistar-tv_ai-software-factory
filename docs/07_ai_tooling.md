# 🤖 AI Software Factory | AniStar TV

## 1. Выбор процесса

Назовите скилл в запросе агенту. Опишите ожидаемое поведение, существенные отказы, границы работы и способ проверки. Правила приложения и документы по задаче перечислены в [AGENTS.md](../AGENTS.md).

| Задача | Скилл |
| :--- | :--- |
| Подготовить фабрику или восстановить её инструменты | [`factory-install`](../.factory/skills/factory-install/SKILL.md) |
| Настроить окружение приложения, обновить Flutter или pub | [`anistar-install`](../.agents/skills/anistar-install/SKILL.md), [`anistar-flutter-update`](../.agents/skills/anistar-flutter-update/SKILL.md) |
| Согласовать существенное поведение, границы или архитектуру | [`factory-planning`](../.factory/skills/factory-planning/SKILL.md) |
| Разбить согласованный план на проверяемые задачи | [`factory-decompose`](../.factory/skills/factory-decompose/SKILL.md) |
| Выполнить понятную задачу, исправление или утверждённый план | [`factory-implement`](../.factory/skills/factory-implement/SKILL.md) |
| Проверить изменения ветки, PR или фичи | [`factory-code-review`](../.factory/skills/factory-code-review/SKILL.md) |
| Оценить существующий код или собрать отмеченный техдолг | [`factory-code-audit`](../.factory/skills/factory-code-audit/SKILL.md), [`factory-code-debt`](../.factory/skills/factory-code-debt/SKILL.md) |
| Подготовить PR, разобраться с checks или выполнить порученный merge | [`factory-pr`](../.factory/skills/factory-pr/SKILL.md) |
| Улучшить работу самой фабрики по итогам сессии | [`factory-meta-retro`](../.factory/skills/factory-meta-retro/SKILL.md) |

Для карты связей кода используйте [Graphify](../tool/graphify/README.md), для UI/UX — [Impeccable](../.agents/skills/impeccable/SKILL.md). Доступность skills и MCP зависит от среды. Context7 помогает сверять внешние API библиотек.

## 2. План и исполнение

Понятную локальную задачу можно сразу передать в Implement. Для существенного выбора Planning предлагает решение, границы и критерии приёмки. Подтверждение относится к конкретной редакции плана. Запрос «сам спланируй и реализуй» может делегировать принятие решения и разрешить продолжить порученную реализацию. При явном «без плана» действуют ограничения прямого исполнения. Точные условия описаны в [контракте источника Implement](../.factory/skills/factory-implement/references/execution-source-contract.md).

Утверждённый план из `docs/plans/` можно передать в Implement целиком либо декомпозировать на задачи в `docs/tasks/`. Новое существенное продуктовое решение требует отдельного согласования. См. [планы и задачи проекта](README.md#исходные-намерения-планы-и-задачи).

[Конфигурация фабрики](../.factory/factory.yaml) задаёт профили и адаптеры. [Маршрутизатор](../.factory/workflow/router.md) определяет состав команды, [профиль AniStar TV](../.factory/project/project.yaml) — применимые правила и проверки, [оркестрация](../.factory/workflow/orchestration.md) — исполнение, приёмку и восстановление.

## 3. Приёмка и возобновление

Сопоставьте результат с исходными критериями и диффом. Проверьте отказы, исключения и свежесть свидетельств. Для команд и границ fixture, live, goldens и устройств используйте [Melos](melos_tooling.md) и [руководство тестирования](05_development_and_testing.md). Для отдельного ревью см. [требования к отчёту и статусам](../.factory/skills/factory-code-review/references/qa-and-reporting.md).

Коммит, push, публикация PR или комментария, merge и release требуют явного поручения. Объём live-проверок также задаётся явно. См. [AGENTS.md](../AGENTS.md) и [правила VCS](vcs_guidelines.md).

Журнал Implement в `.factory/memory/workflow.sqlite3` хранит запуски, исходные пакеты, отчёты и логи. Дополнительные артефакты перед архивацией попадают в `.factory/memory/history/<run-id>/`. Архив доступен через `list-artifacts` и `export-artifact`. При блокировке укажите статус, причину и свидетельство. Возобновление, остановка и очистка описаны в [руководстве workflow](../.factory/workflow/README.md).
