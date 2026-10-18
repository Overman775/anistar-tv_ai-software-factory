# 📝 App Logging Package | AniStar TV

`app_logging` настраивает Logger приложения, typed diagnostics, file output и observers для runner и потребителей.

## Использование

Используйте публичные библиотеки:

| Импорт | API |
| --- | --- |
| `package:app_logging/app_logging.dart` | `AppLogger`, `Logger`, typed-методы, file output и observers |
| `package:app_logging/providers.dart` | Контракт `loggerProvider` |

Runner инициализирует `AppLogger` и передаёт `Logger` в overrides. Прикладные классы получают его конструктором. Typed-методы добавляют владельца записи.

## Границы и условия использования

Не импортируйте `src/**`. Зависимости разрешаются корневым pub workspace. `DioLoggingInterceptor` принадлежит `networking`.

Debug/profile выводит все уровни в консоль и `FileLogOutput` для dev viewer. Release выводит в консоль только error и fatal. `ProductionFilter` применяется во всех runtime-режимах, чтобы profile/release не зависели от включённых assertions. `AppLogger.initForTest` отключает I/O.

`FlutterError.onError`, `PlatformDispatcher.onError` и `runZonedGuarded` в runner используют `AppLogger.reportUnhandled`: уровень fatal, пометка `[UNHANDLED]`, источник, исходное исключение и stack trace. Обработчики устанавливаются также при передаче logger в runner. Внешние crash/analytics SDK не подключены.

`FileLogOutput` владеет отдельным worker isolate. Записи выполняются последовательно. `destroy` ждёт завершения init и подтверждения записи оставшегося буфера. До готовности worker сохраняются последние 1000 сообщений. Для проверки файлового output можно передать `directory` в конструктор. Viewer читает только имена файлов внутри `logs`.

Не добавляйте HTML, cookies, токены, значения secure storage и подписанные CDN URL в сообщения.

## Как проверить

Из корня workspace запустите тесты пакета:

```bash
fvm flutter test test/infrastructure/app_logging
```

## Навигация

- [Структура проекта](../../docs/02_project_structure.md) — границы пакетов и обязанности runner.
- [Сеть и HLS](../../docs/04_network_and_playback.md) — граница сетевых логов и чувствительных данных.
- [Networking](../networking/README.md) — HTTP interceptor и transport.
