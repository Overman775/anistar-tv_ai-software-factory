# 📚 Документация | AniStar TV

## Руководства

| Документ | Содержание |
| --- | --- |
| [🏛️ Архитектура](01_architecture_principles.md) | Принципы, границы слоёв, DI и навигация |
| [📂 Структура проекта](02_project_structure.md) | Workspace, пакеты, features и runner |
| [📏 Code Style](03_codestyle_and_rules.md) | Именование, Dart, асинхронность и TV UI |
| [🌐 Сеть и HLS](04_network_and_playback.md) | HTTP, HTML/JSON5, ошибки и native playback |
| [🧪 Разработка и тестирование](05_development_and_testing.md) | Окружения, команды, тесты и диагностика |

- [AI-инструменты](07_ai_tooling.md): выбор Factory-скиллов, этапы, артефакты и восстановление процесса.
- [Melos tooling](melos_tooling.md): локальные запуск, генерация, обслуживание, тесты и сборки.
- [Git и версии](vcs_guidelines.md): Conventional Commits и явная подготовка версии.

## Спецификации

[📋 Контракты функций](specs/README.md): вход/сессия, избранное, страницы/пагинация, native playback, зеркала, TV-взаимодействие, просмотренные серии и анимации. Здесь инварианты, ошибки, границы реализации и связанные тесты для дальнейшей разработки.

Направление UI для новых изменений: [ADR-0008 — YouTube для телевизоров как ориентир взаимодействия](adr/0008-youtube-tv-interaction-reference.md).

## Пакеты и решения

- [⚙️ Core](../infrastructure/core/README.md)
- [🌐 Networking](../infrastructure/networking/README.md)
- [💾 Storage](../infrastructure/storage/README.md)
- [📝 App Logging](../infrastructure/app_logging/README.md)
- [📺 AniStar](../infrastructure/anistar/README.md)
- [🎨 UI Kit](../lib/packages/ui_kit/README.md)
- [🧭 Architecture Decision Records](adr/README.md)

## История изменений

[CHANGELOG](../CHANGELOG.md): изменения по выпускам; текущая разработка — в разделе «Не выпущено».

## Проверки

- [Состояние проверок](06_verification.md): критерии готовности, результаты и пределы live-проверки.

Быстрый старт: [README](../README.md).
