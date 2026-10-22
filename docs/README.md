# 📚 Документация | AniStar TV

Выберите документ по вопросу, с которым работаете. Описание приложения и быстрый запуск находятся в [главном README](../README.md).

## Руководства для разработки

| Что нужно выяснить | Документ |
| :--- | :--- |
| Как проверить, установить или обновить окружение проекта с выбором компонентов | [Factory Install](../.agents/skills/factory-install/SKILL.md) |
| Как разделены слои, зависимости и DI | [Архитектурные принципы](01_architecture_principles.md) |
| Где разместить код и как связаны пакеты | [Структура проекта](02_project_structure.md) |
| Какие правила соблюдать в Dart, асинхронном коде и TV UI | [Code Style](03_codestyle_and_rules.md) |
| Как взаимодействуют transport, сайт, сессия и native playback | [Сеть и HLS](04_network_and_playback.md) |
| Как выбрать проверки, собрать приложение и разобраться в сбое | [Разработка и тестирование](05_development_and_testing.md) |
| Как поручить работу агентам и проверить их результат | [AI Software Factory](07_ai_tooling.md) |
| Какую команду использовать для запуска, генерации или обслуживания | [Melos tooling](melos_tooling.md) |
| Как работать с ветками, коммитами и версией приложения | [Git и версии](vcs_guidelines.md) |
| Как настроить локальную Android production-подпись и сборку без ключа | [Android-подпись](android_signing.md) |
| Где посмотреть адаптивный UI-прототип и handoff-документ | [Прототип](../prototype/index.html), [DESIGN-HANDOFF](../prototype/DESIGN-HANDOFF.md) |

## Продукт, контракты и решения

| Вопрос | Источник |
| :--- | :--- |
| Для кого приложение, какие у него возможности и ограничения | [Описание продукта](../PRODUCT.md) |
| Как должна работать конкретная функция | [Спецификации](specs/README.md) |
| Почему выбрана архитектура и какие ограничения приняты | [Реестр ADR](adr/README.md) |

Для изменений интерфейса отправная точка — [ADR-0008](adr/0008-youtube-tv-interaction-reference.md) и связанные с ним TV- и мобильные контракты.

Общие UI-правила и карта дизайна собраны в [визуальной системе](specs/11_visual_system.md); поведение поиска описывает [спецификация 13](specs/13_search.md), а полной карточки аниме — [спецификация 12](specs/12_anime_details.md). Прототип в `../prototype/` служит визуальным справочником; приложение реализуется в `lib/`.

## Намерения изменений

- [Удобная перемотка и явный выбор качества в плеере](intents/player-seek-and-quality.md).
- [Общий компонент выделения карточек и серий в UI Kit](intents/shared-card-focus-in-ui-kit.md).
- [Единый стиль отметок и понятные подписи на карточках](intents/card-badges-and-captions.md).
- [Три колонки серий на TV и одна серия в ряд на телефоне](intents/episode-grid-tv-and-mobile.md).
- [Немного уменьшить шрифты на главной и странице сериала](intents/readable-smaller-typography.md).
- [Новые идентификаторы приложения и запуск на iOS](intents/app-identifiers-and-ios-launch.md).

## Согласованные планы

- [Полный редизайн приложения по прототипу — revision 3](plans/prototype-app-redesign-2026-10-22.md).
- [Карточки, серии и управление плеером — revision 1](plans/ui-player-intents-2026-10-19.md).
- [Идентификаторы приложения и запуск iOS — revision 6](plans/app-identifiers-and-ios-launch.md).

## Предложения для выбора

- [CI/CD: проверки PR, Android gate, версии и GitHub Releases](plans/ci-cd-proposal-2026-10-19.md) — анализ и варианты, внедрение не согласовано.

## Задачи реализации

- [Полный редизайн приложения по прототипу — эпик и 18 задач](tasks/epic_prototype-app-redesign-2026-10-22.md).
- [Карточки, серии и управление плеером — эпик и шесть задач](tasks/epic_ui-player-intents-2026-10-19.md).

## Пакеты

README пакетов описывают публичные входы, условия использования и проверки в пределах своего пакета.

| Пакет | Что искать в README |
| :--- | :--- |
| [Core](../infrastructure/core/README.md) | Нейтральные Result и Failure, границы зависимостей |
| [Networking](../infrastructure/networking/README.md) | HTTP transport, BaseRepository, interceptors и lifecycle |
| [Storage](../infrastructure/storage/README.md) | Preferences, secure storage и передача runtime-экземпляров |
| [App Logging](../infrastructure/app_logging/README.md) | Инициализация логирования, уровни, observers и файловый output |
| [AniStar](../infrastructure/anistar/README.md) | AnistarClient, публичные библиотеки и нормализованный контракт данных |
| [UI Kit](../lib/packages/ui_kit/README.md) | Тема, компоненты, focus, анимации и ресурсы приложения |

## Тестовые наборы и инструменты

| Материал | Назначение |
| :--- | :--- |
| [Integration tests](../integration_test/README.md) | Android TV/mobile и отдельный iOS Simulator fixture E2E |
| [E2E tooling](../tool/e2e/README.md) | Запуск Android/iOS runners, окружение, fixtures, media и отчёты |
| [Graphify tooling](../tool/graphify/README.md) | Локальный патч извлечения, его применение и проверка |

## Написание документации

[Указатель шаблонов](templates/README.md) помогает выбрать формат руководства, ADR, спецификации, intent или README. Подробные инструкции и заготовки находятся там же. Ссылайтесь на документ, который описывает правило, вместо копирования его в соседние README.
