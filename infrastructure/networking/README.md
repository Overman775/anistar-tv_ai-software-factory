# 🌐 Networking Package | AniStar TV

HTTP transport, общий маппинг ошибок и lifecycle клиентов.

## 1. Публичные библиотеки

| Импорт | API |
| --- | --- |
| `package:networking/networking.dart` | DioClient, HttpClient, NetworkConfig, BaseRepository и NetworkFailure |
| `package:networking/providers.dart` | Провайдеры транспорта и конфигурации |

Внешний код не импортирует src/**. Зависимости разрешаются корневой pub workspace.

---

## 2. Ответственность и lifecycle

App передаёт NetworkConfig и logger. Networking создаёт клиентов и закрывает их через ref.onDispose.

BaseRepository.makeApiCall переводит исключения в Result / Failure. Таймауты и transport retry принадлежат этому пакету; зеркало, HTML-заголовки и правила отказа AniStar принадлежат anistar. DioLoggingInterceptor использует Logger из app_logging.

---

## 3. Проверки

Тесты запускаются из корня:

```bash
fvm flutter test test/infrastructure/networking
```

Границы пакетов: [Структура проекта](../../docs/02_project_structure.md).
