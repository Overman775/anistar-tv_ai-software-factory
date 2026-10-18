# 🌐 Networking Package | AniStar TV

`networking` предоставляет Dart HTTP transport, общий маппинг ошибок и lifecycle клиентов для инфраструктурных адаптеров.

## Использование

Подключайте API через публичные библиотеки:

| Импорт | API |
| --- | --- |
| `package:networking/networking.dart` | `DioClient`, `NetworkConfig`, `BaseRepository` и `NetworkFailure` |
| `package:networking/providers.dart` | Провайдеры транспорта и конфигурации |

App передаёт `NetworkConfig` и logger. Все HTTP-запросы Dart-кода приложения используют `DioClient`. Пакет закрывает общий клиент через `ref.onDispose`. Добавляйте interceptors через `DioClient.addInterceptors`.

`BaseRepository.makeApiCall` переводит исключения в `Result` / `Failure`. Таймауты и transport retry принадлежат этому пакету.

## Границы и условия использования

Не импортируйте `src/**`. Зависимости разрешаются корневым pub workspace.

Проверка зеркал использует отдельный Dio из той же фабрики без cookies и retry. `AnistarMirrorManager` закрывает этот клиент. HTML-парсер получает байты страниц через общий Dio. Нативный `video_player` загружает видеопоток своим транспортом.

Зеркало, HTML-заголовки и правила отказа AniStar принадлежат `anistar`. `DioLoggingInterceptor` использует Logger из `app_logging` и стоит после session/header interceptors.

В dev видны запросы, ответы, ошибки, номера запросов, длительность, HTTP-статусы и тип/размер ответа. URL показывает только origin и известные публичные endpoints AniStar. Остальные paths, query, credentials и тела не выводятся. Cookies и неизвестные headers скрываются. Отмена запроса имеет уровень debug, транспортные ошибки — error, а в release проходят только ошибки.

## Как проверить

Из корня workspace запустите тесты пакета:

```bash
fvm flutter test test/infrastructure/networking
```

## Навигация

- [Сеть и HLS](../../docs/04_network_and_playback.md) — transport, сайт, сессия и native playback.
- [Структура проекта](../../docs/02_project_structure.md) — границы пакетов.
- [App Logging](../app_logging/README.md) — уровни логирования и file output.
