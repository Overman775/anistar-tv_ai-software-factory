# 📚 Документация | AniStar TV

Выберите документ по вопросу, с которым работаете. Описание приложения и быстрый запуск находятся в [главном README](../README.md).

## Руководства для разработки

| Что нужно выяснить | Документ |
| :--- | :--- |
| Как разделены слои, зависимости и DI | [Архитектурные принципы](01_architecture_principles.md) |
| Где разместить код и как связаны пакеты | [Структура проекта](02_project_structure.md) |
| Какие правила соблюдать в Dart, асинхронном коде и TV UI | [Code Style](03_codestyle_and_rules.md) |
| Как взаимодействуют transport, сайт, сессия и native playback | [Сеть и HLS](04_network_and_playback.md) |
| Как выбрать проверки, собрать приложение и разобраться в сбое | [Разработка и тестирование](05_development_and_testing.md) |
| Как поручить работу агентам и проверить их результат | [AI Software Factory](07_ai_tooling.md) |
| Какую команду использовать для запуска, генерации или обслуживания | [Melos tooling](melos_tooling.md) |
| Как работать с ветками, коммитами и версией приложения | [Git и версии](vcs_guidelines.md) |

## Продукт, контракты и решения

| Вопрос | Источник |
| :--- | :--- |
| Для кого приложение, какие у него возможности и ограничения | [Описание продукта](../PRODUCT.md) |
| Как должна работать конкретная функция | [Спецификации](specs/README.md) |
| Почему выбрана архитектура и какие ограничения приняты | [Реестр ADR](adr/README.md) |

Для изменений интерфейса отправная точка — [ADR-0008](adr/0008-youtube-tv-interaction-reference.md) и связанные с ним TV- и мобильные контракты.

## Намерения изменений

- [Удобная перемотка и явный выбор качества в плеере](intents/player-seek-and-quality.md).
- [Общий компонент выделения карточек и серий в UI Kit](intents/shared-card-focus-in-ui-kit.md).
- [Единый стиль отметок и понятные подписи на карточках](intents/card-badges-and-captions.md).
- [Три колонки серий на TV и одна серия в ряд на телефоне](intents/episode-grid-tv-and-mobile.md).
- [Немного уменьшить шрифты на главной и странице сериала](intents/readable-smaller-typography.md).

## Согласованные планы

- [Карточки, серии и управление плеером — revision 1](plans/ui-player-intents-2026-10-19.md).

## Задачи реализации

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
| [Android integration tests](../integration_test/README.md) | Сценарии TV/mobile, правила написания тестов и границы покрытия |
| [E2E tooling](../tool/e2e/README.md) | Запуск Android runners, окружение, fixtures, media и отчёты |
| [Graphify tooling](../tool/graphify/README.md) | Локальный патч извлечения, его применение и проверка |

## Написание документации

[Указатель шаблонов](templates/README.md) помогает выбрать формат руководства, ADR, спецификации, intent или README. Подробные инструкции и заготовки находятся там же. Ссылайтесь на документ, который описывает правило, вместо копирования его в соседние README.
