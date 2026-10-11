# 📺 AniStar Package | AniStar TV

Прямой HTTP/HTML/JSON5 адаптер сайта.

## 1. Публичные библиотеки

| Импорт | API |
| --- | --- |
| `package:anistar/anistar.dart` | AnistarClient, DioAnistarClient, AnistarSession, зеркало, DTO и AnistarFailure |
| `package:anistar/parsing.dart` | HtmlDecoder, AnistarHtmlParser и AnistarAuthHtml |
| `package:anistar/providers.dart` | Единый anistarClientProvider, cookie session и Dio с session interceptor |

Внешний код не импортирует src/**. Зависимости разрешаются корневой pub workspace.

---

## 2. Ответственность и lifecycle

AnistarClient — единственная зависимость сетевых feature repositories от сайта. DioAnistarClient получает Dio и AnistarSession конструктором и объединяет загрузку/разбор данных с авторизацией. AnistarSource и AnistarAuthService — внутренние реализации, основной barrel их не экспортирует. Пакет владеет зеркалом, HTML-заголовками, charset, каталогом, карточкой и playlst. Ошибки сайта распознаются здесь; DTO преобразуются в domain внутри feature repositories.

Riverpod создаёт один клиент на активный origin в корневом ProviderScope; все репозитории получают anistarClientProvider через app composition. Клиент не разрешает зависимости сам и не является статическим singleton. Смена зеркала пересоздаёт клиент, Dio и origin-bound session. Dio закрывает networking, сессию — её provider; клиент не закрывает общие ресурсы повторно. Решение: [ADR-0009](../../docs/adr/0009-single-anistar-client-and-dio.md).

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
