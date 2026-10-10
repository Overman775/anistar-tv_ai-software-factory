# ADR-0007: Нейтральный Core и отдельная инфраструктура

- **Статус:** Accepted
- **Дата:** 2026-10-10
- **Уточняет:** [0004](0004-use-riverpod-for-app-di.md), [0005](0005-centralize-runtime-logging.md).
- **Сохраняет:** прямой Android-доступ [0006](0006-android-direct-anistar.md) и границы UI Kit.

## Контекст

В старом Core одновременно находились Either/Failure, Dio, BaseRepository, storage и HTML-парсер AniStar. Общий barrel связывал feature domain с transport и сайтом. Провайдеры app импортировались из presentation.

## Решение

- Core содержит только Pure Dart Result, Failure и UnknownFailure; package-зависимостей нет.
- Networking владеет HTTP, BaseRepository, NetworkFailure и transport logging.
- Storage и app_logging владеют своими сервисами; anistar владеет HTML/JSON5, зеркалом, DTO и ошибками сайта.
- Публичные библиотеки явные; чужой src/** не импортируется. Infrastructure не знает app/features.
- Feature providers объявляют repository interfaces; app_container связывает реализации через overrides.
- Сервисы получают зависимости конструкторами. HTTP lifecycle принадлежит networking; native controller принадлежит State плеера.
- App и features остаются в корневом проекте. Infrastructure и ui_kit разрешаются pub workspace с одним lockfile.

## Последствия

Domain отделён от transport и сайта. Правила AniStar меняются в адаптере, без расширения нейтрального Core. Публичные API и зависимости проверяются architecture-тестами; DI-тест проверяет binding и закрытие HTTP.

Melos и дополнительные API Core не требуются при текущем размере проекта. Инфраструктурные тесты находятся в корневом test/infrastructure и запускаются одним flutter test.

Основание: подход Core/infrastructure из rc-mobile-app. Структура: [руководство](../02_project_structure.md). Проверки: [результаты](../06_verification.md).
