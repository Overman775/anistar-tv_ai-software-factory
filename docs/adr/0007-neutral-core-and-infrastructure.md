# ADR-0007: Нейтральный Core и отдельная инфраструктура

- **Статус:** Accepted
- **Дата:** 2026-10-10
- **Связи:** Уточняет [ADR-0004](0004-use-riverpod-for-app-di.md) и [ADR-0005](0005-centralize-runtime-logging.md). Сохраняет прямой Android-доступ из [ADR-0006](0006-android-direct-anistar.md) и границы UI Kit.

## Контекст

В старом Core одновременно находились Either/Failure, Dio, BaseRepository, storage и HTML-парсер AniStar. Общий barrel связывал feature domain с transport и сайтом. Провайдеры app импортировались из presentation.

## Решение

- Core содержит только Pure Dart `Result`, `Failure` и `UnknownFailure`. Package-зависимостей нет.
- Networking владеет HTTP, `BaseRepository`, `NetworkFailure` и transport logging.
- Storage и app_logging владеют своими сервисами. Пакет anistar владеет HTML/JSON5, зеркалом, DTO и ошибками сайта.
- Публичные библиотеки явные. Чужой `src/**` не импортируется. Infrastructure не зависит от app/features.
- Feature providers объявляют repository interfaces. `app_container` связывает реализации через overrides.
- Сервисы получают зависимости конструкторами. HTTP lifecycle принадлежит пакету networking. Native controller принадлежит State плеера.
- App и features остаются в корневом проекте. Infrastructure и ui_kit разрешаются pub workspace с одним lockfile.

## Альтернативы

Прежний Core объединял нейтральные типы, transport, storage и детали AniStar в одном пакете и общем barrel. Такая структура связывала feature domain с transport и сайтом. Других рассмотренных вариантов исходный ADR не содержит.

## Последствия

Domain отделён от transport и сайта. Правила AniStar меняются в адаптере без расширения нейтрального Core. Architecture-тесты проверяют публичные API и зависимости. DI-тест проверяет binding и закрытие HTTP.

При текущем размере проекта Melos и дополнительные API Core не требуются. Инфраструктурные тесты находятся в корневом `test/infrastructure` и запускаются одним `flutter test`.

Структура проекта описана в [руководстве](../02_project_structure.md). Порядок проверок приведён в разделе [проверки и сборка](../05_development_and_testing.md#2-проверки-и-сборка).
