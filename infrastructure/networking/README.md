# 🌐 Networking Package | AniStar TV

HTTP transport, общий маппинг ошибок и lifecycle клиентов.

## 1. Публичные библиотеки

| Импорт | API |
| --- | --- |
| `package:networking/networking.dart` | DioClient, NetworkConfig, BaseRepository и NetworkFailure |
| `package:networking/providers.dart` | Провайдеры транспорта и конфигурации |

Внешний код не импортирует src/**. Зависимости разрешаются корневой pub workspace.

---

## 2. Ответственность и lifecycle

App передаёт NetworkConfig и logger. Все HTTP-запросы Dart-кода приложения используют DioClient; networking закрывает общий клиент через ref.onDispose. Проверка зеркал использует отдельный Dio из той же фабрики, без cookies и retry; его закрывает AnistarMirrorManager. HTML-парсер получает байты страниц через общий Dio. Видеопоток загружает нативный video_player своим транспортом.

BaseRepository.makeApiCall переводит исключения в Result / Failure. Таймауты и transport retry принадлежат этому пакету; зеркало, HTML-заголовки и правила отказа AniStar принадлежат anistar. DioLoggingInterceptor использует Logger из app_logging и стоит после session/header interceptors. Для добавления interceptors используется DioClient.addInterceptors.

В dev видны запросы, ответы, ошибки, номера запросов, длительность, HTTP-статусы и тип/размер ответа. URL показывает только origin и известные публичные endpoints AniStar; остальные paths, query, credentials и тела не выводятся. Cookies и неизвестные headers скрываются. Отмена запроса имеет уровень debug, транспортные ошибки — error; в release проходят только ошибки.

---

## 3. Проверки

Тесты запускаются из корня:

```bash
fvm flutter test test/infrastructure/networking
```

Границы пакетов: [Структура проекта](../../docs/02_project_structure.md).
