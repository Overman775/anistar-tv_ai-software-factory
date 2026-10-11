# 📝 App Logging Package | AniStar TV

Единая конфигурация Logger, typed diagnostics, file output и observers.

## 1. Публичные библиотеки

| Импорт | API |
| --- | --- |
| `package:app_logging/app_logging.dart` | AppLogger, Logger, typed-методы, file output и observers |
| `package:app_logging/providers.dart` | Контракт loggerProvider |

Внешний код не импортирует src/**. Зависимости разрешаются корневой pub workspace.

---

## 2. Ответственность и lifecycle

Runner инициализирует AppLogger и передаёт Logger в overrides. Прикладные классы получают его конструктором; typed-методы добавляют владельца записи.

Debug/profile выводит все уровни в консоль и FileLogOutput для dev viewer. Release выводит в консоль только error и fatal. ProductionFilter применяется во всех runtime-режимах, чтобы profile/release не зависели от включённых assertions. AppLogger.initForTest отключает I/O. Dio interceptor принадлежит networking.

FlutterError.onError, PlatformDispatcher.onError и runZonedGuarded в runner используют AppLogger.reportUnhandled: уровень fatal, пометка [UNHANDLED], источник, исходное исключение и stack trace. Обработчики устанавливаются также при передаче logger в runner. Внешние crash/analytics SDK не подключены.

FileLogOutput владеет отдельным worker isolate. Записи выполняются последовательно;
destroy ждёт завершения init и подтверждения записи оставшегося буфера. До готовности
worker сохраняются последние 1000 сообщений. Для проверки файлового output можно
передать directory в конструктор. Viewer читает только имена файлов внутри logs.

Не добавляйте HTML, cookies, токены, значения secure storage и подписанные CDN URL в сообщения.

---

## 3. Проверки

Тесты запускаются из корня:

```bash
fvm flutter test test/infrastructure/app_logging
```

Границы пакетов: [Структура проекта](../../docs/02_project_structure.md).
