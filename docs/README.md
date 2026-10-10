# 📚 Документация | AniStar TV

## Руководства

| Документ | Содержание |
| --- | --- |
| [🏛️ Архитектура](01_architecture_principles.md) | Принципы, границы слоёв, DI и навигация |
| [📂 Структура проекта](02_project_structure.md) | Workspace, пакеты, features и runner |
| [📏 Code Style](03_codestyle_and_rules.md) | Именование, Dart, асинхронность и TV UI |
| [🌐 Сеть и HLS](04_network_and_playback.md) | HTTP, HTML/JSON5, ошибки и native playback |
| [🧪 Разработка и тестирование](05_development_and_testing.md) | Окружения, команды, тесты и диагностика |

## Спецификации

[📋 Контракты функций](specs/README.md): вход/сессия, избранное, страницы/пагинация, native playback, зеркала, TV-взаимодействие и просмотренные серии. Здесь инварианты, ошибки, границы реализации и связанные тесты для дальнейшей разработки.

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
