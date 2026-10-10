# 📺 AniStar Package | AniStar TV

Прямой HTTP/HTML/JSON5 адаптер сайта.

## 1. Публичные библиотеки

| Импорт | API |
| --- | --- |
| `package:anistar/anistar.dart` | AnistarSource, AnistarAuthService, AnistarSession, зеркало, DTO и AnistarFailure |
| `package:anistar/parsing.dart` | HtmlDecoder, AnistarHtmlParser и AnistarAuthHtml |
| `package:anistar/providers.dart` | Провайдеры source, auth service, cookie session и Dio с session interceptor |

Внешний код не импортирует src/**. Зависимости разрешаются корневой pub workspace.

---

## 2. Ответственность и lifecycle

AnistarSource получает Dio конструктором. Пакет владеет зеркалом, HTML-заголовками, charset, каталогом, карточкой и playlst. Ошибки сайта распознаются здесь; DTO преобразуются в domain внутри feature repositories.

AnistarSession хранит cookies и аккаунт одной зашифрованной записью через SecureStorage. Session interceptor добавляется к общему Dio; при dispose удаляется. Пароль используется только в POST формы. Правила входа: [Сеть и сессия](../../docs/04_network_and_playback.md#6-вход-и-сессия).

JSON5 разбирается как данные. Скрипты не исполняются; браузер и прокси не запускаются. HTML и подписанные CDN URL не записываются в сообщения логов.

---

## 3. Проверки

Тесты запускаются из корня:

```bash
fvm flutter test test/infrastructure/anistar
```

Границы пакетов: [Структура проекта](../../docs/02_project_structure.md).

AnistarMirrorManager хранит только номер `vN.astar.bz` в Shared Preferences. Проверяет каталог один раз перед входом/restore и ограниченно ищет следующие версии при отказе сайта. Смена origin пересоздаёт bindings и сессию; запросы и cookies на новый домен не переносятся. Контракт: [Сеть и HLS](../../docs/04_network_and_playback.md#автоматический-выбор-зеркала).
