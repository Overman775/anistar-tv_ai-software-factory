# ADR-0005: Единое runtime-логирование

- **Статус:** Accepted
- **Дата:** 2026-07-19
- **Связи:** Уточнён в [ADR-0007](0007-neutral-core-and-infrastructure.md): пакет `app_logging` и владелец Dio interceptor.

## Контекст

Логи приложения, Dio, BLoC и роутера настраивались в разных местах. Это усложняло безопасное переключение между debug и release и мешало тестам.

## Решение

Использовать пакет `app_logging` с единой инициализацией `Logger`.

- В debug/profile выводить все уровни в консоль и file output для встроенного просмотрщика.
- В release выводить в консоль только error и fatal, без записи в файл.
- Использовать явный `ProductionFilter` для фильтрации по уровню независимо от assertions, включая profile и release.
- Предоставлять observers для BLoC и навигации. Dio interceptor принадлежит networking и использует тот же logger (уточнение ADR-0007).
- Тестовый bootstrap использует `AppLogger.initForTest()` без I/O.

## Последствия

Необработанные ошибки Flutter, PlatformDispatcher и guarded zone получают уровень fatal и маркер `[UNHANDLED]` с исходным исключением и stack trace. Сетевые ошибки Dio остаются на уровне error. Все HTTP-запросы, включая проверку зеркал отдельным клиентом без cookies, используют фабрику DioClient и общий logger. Firebase и внешняя аналитика не подключаются.

Единые форматы и уровни упрощают диагностику. Транспортные логи остаются безопасными. Диагностический экран доступен только в debug/profile. Инициализация логирования в тестовом bootstrap остаётся тихой благодаря `AppLogger.initForTest()` без I/O.

Application-код использует `app_logging` и не создаёт независимый `Logger`. Sensitive headers и query-параметры не добавляются в сообщения.
