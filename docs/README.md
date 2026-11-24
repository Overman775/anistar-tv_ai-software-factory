# 📚 Документация | AniStar TV

Начните с документа по своей задаче. Описание приложения и быстрый запуск находятся в [главном README](../README.md).

## Действующие контракты и руководства

| Задача | Что читать |
| :--- | :--- |
| Понять назначение и ограничения приложения | [Продукт](../PRODUCT.md) |
| Изменить поведение фичи | [Глоссарий](01_01_domain_glossary.md), [ответственность фич](01_02_feature_responsibilities.md) и [спецификация своей фичи](specs/README.md) |
| Изменить TV/мобильный интерфейс | [ADR-0008](adr/0008-youtube-tv-interaction-reference.md), [контракты интерфейса](specs/README.md#интерфейс), [визуальный прототип](../prototype/index.html) и [handoff](../prototype/DESIGN-HANDOFF.md). Код приложения находится в `lib/` |
| Найти правило архитектуры или размещения кода | [Архитектурные принципы](01_architecture_principles.md), [структура проекта](02_project_structure.md), [реестр ADR](adr/README.md) |
| Связать зависимости и определить владельца ресурса | [DI и жизненный цикл](01_03_di_and_lifecycle.md) |
| Проверить требования к Dart, асинхронности и TV UI | [Правила кода](03_codestyle_and_rules.md) |
| Разобраться с сетью, сессией или HLS | [Сеть и воспроизведение](04_network_and_playback.md) |
| Подготовить окружение приложения | [AniStar Install](../.agents/skills/anistar-install/SKILL.md) |
| Выбрать проверку и запустить полный gate | [Разработка и тестирование](05_development_and_testing.md), [команды Melos](melos_tooling.md) |
| Проверить раскладку или обновить эталон | [Widget-тесты и goldens](05_01_widget_and_golden_tests.md) |
| Проверить реальный сайт или CDN | [Live-проверки AniStar](05_02_live_testing.md) |
| Запустить E2E или настроить его входы | [Тестовые сценарии](../integration_test/README.md), [E2E runners и фикстуры](../tool/e2e/README.md) |
| Установить Git hooks или запустить сканеры | [Git hooks и проверки безопасности](git_hooks_and_security.md) |
| Подготовить сборку или выпуск | [Android-подпись](android_signing.md), [Git и версии](vcs_guidelines.md) |
| Поручить работу агентам | [AI Software Factory](07_ai_tooling.md), [локальные инструменты Graphify](../tool/graphify/README.md) |
| Написать руководство, ADR, спецификацию, intent или README | [Шаблоны документов](templates/README.md) |

## Публичные интерфейсы пакетов

| Пакет | Что искать |
| :--- | :--- |
| [Core](../infrastructure/core/README.md) | `Result`, `Failure`, границы зависимостей |
| [Networking](../infrastructure/networking/README.md) | HTTP transport, `BaseRepository`, interceptors и lifecycle |
| [Storage](../infrastructure/storage/README.md) | Preferences, secure storage и передача зависимостей |
| [App Logging](../infrastructure/app_logging/README.md) | Инициализация логов, observers и файловый output |
| [AniStar](../infrastructure/anistar/README.md) | `AnistarClient` и нормализованный контракт |
| [UI Kit](../lib/packages/ui_kit/README.md) | Тема, компоненты, focus, анимации и ресурсы |

## Исходные намерения, планы и задачи

Открывайте эти материалы для контекста конкретного изменения. Действующее поведение ищите в спецификациях, решения — в ADR.

- [Намерения изменений](intents/README.md).
- [Редизайн AniStar TV, редакция 3](plans/prototype-redesign-2026-11-12.md) · [эскиз workflow](plans/prototype-redesign-2026-11-12.workflow.md) · [эпик и 20 задач](tasks/prototype-redesign-2026-11-12/epic.md) · [подготовка выпуска](tasks/redesign-release-preparation/21-redesign-version-changelog.md).
- [Исправление TV-навигации, ленты и визуальных состояний, редакция 3](plans/tv-navigation-and-catalog-bugfixes.md).
- [Общие профили полноэкранных goldens, редакция 1](plans/golden-screen-profiles.md).
