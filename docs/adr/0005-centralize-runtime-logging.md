# 🧭 ADR-0005: Единое runtime-логирование

- **Статус:** Accepted
- **Дата:** 2026-07-19
- **Уточнено:** [0007](0007-neutral-core-and-infrastructure.md): app_logging и владелец Dio interceptor.

## Контекст

Логи приложения, Dio, BLoC и роутера настраивались в разных местах. Это усложняло безопасное переключение между debug и release и мешало тестам.

## Решение

Используем package `app_logging` с единой инициализацией `Logger`. В debug/profile все уровни выводятся одновременно в консоль и file output для встроенного просмотрщика. В release в консоль выводятся только error и fatal, без записи в файл. Явный `ProductionFilter` обеспечивает фильтрацию по уровню независимо от assertions, включая profile/release. Package предоставляет observers для BLoC и навигации. Dio interceptor принадлежит networking и использует тот же logger (уточнение ADR-0007). Тестовый bootstrap использует `AppLogger.initForTest()` без I/O.

## Последствия

Необработанные ошибки Flutter, PlatformDispatcher и guarded zone маркируются `[UNHANDLED]` на уровне fatal с исходным исключением и stack trace. Сетевые ошибки Dio остаются на уровне error. Все HTTP-запросы, включая проверку зеркал отдельным клиентом без cookies, используют фабрику DioClient и общий logger. Firebase и внешняя аналитика не подключаются.

**Положительные:** единые форматы и уровни, безопасные транспортные логи, диагностический экран только в debug/profile, тихие тесты.

**Ограничение:** application-код использует `app_logging`, а не создаёт независимый `Logger`; sensitive headers и query-параметры не добавляются в сообщения.
