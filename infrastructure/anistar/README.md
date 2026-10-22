# 📺 AniStar Package | AniStar TV

`anistar` — прямой HTTP/HTML/JSON5 адаптер сайта для сетевых feature repositories. Их единственная зависимость от сайта — контракт `AnistarClient`.

## Использование

Выбирайте библиотеку по роли:

| Импорт | API |
| --- | --- |
| `package:anistar/anistar.dart` | `AnistarClient`, общие DTO, параметры и `AnistarClientException` |
| `package:anistar/html.dart` | `HtmlAnistarClient`, `AnistarSession` и настройка зеркала |
| `package:anistar/parsing.dart` | `HtmlDecoder`, `AnistarHtmlParser` и `AnistarAuthHtml` |
| `package:anistar/providers.dart` | Единый `anistarClientProvider`, cookie session и Dio с session interceptor |

Riverpod создаёт один клиент на активный origin в корневом `ProviderScope`. Репозитории получают `anistarClientProvider` через app composition. Клиент не разрешает зависимости сам и не является статическим singleton. `HtmlAnistarClient` получает Dio и `AnistarSession` конструктором и объединяет загрузку/разбор данных с авторизацией.

## Границы и условия использования

Не импортируйте `src/**`. Зависимости разрешаются корневым pub workspace. `AnistarSource` и `AnistarAuthService` — внутренние реализации, их не экспортирует основной barrel. Feature repositories преобразуют DTO в domain.

Пакет владеет зеркалом, HTML-заголовками, charset, каталогом, карточкой, playlist и распознаванием ошибок сайта. Смена зеркала пересоздаёт клиент, Dio и origin-bound session. Networking закрывает Dio, provider сессии закрывает сессию. Клиент не закрывает общие ресурсы повторно. См. [ADR-0009](../../docs/adr/0009-single-anistar-client-and-dio.md).

`AnistarSession` хранит cookies и аккаунт одной зашифрованной записью через `SecureStorage`. Session interceptor добавляется к общему Dio и удаляется при dispose. Пароль используется только в POST формы. Правила входа: [Сеть и сессия](../../docs/04_network_and_playback.md#6-вход-и-сессия).

`AnistarClientException.category.invalidCredentials` применяется только к явному отказу учётных данных после POST формы входа. Сетевые сбои, неожиданный HTML и прочие ошибки запроса сохраняют отдельную категорию; presentation не определяет причину по тексту сообщения.

JSON5 разбирается как данные. Скрипты не исполняются. Браузер и прокси не запускаются. HTML и подписанные CDN URL не записываются в сообщения логов.

`AnistarMirrorManager` хранит только номер `vN.astar.bz` в Shared Preferences. Он проверяет каталог один раз перед входом/restore и ограниченно ищет следующие версии при отказе сайта. Смена origin пересоздаёт bindings и сессию. Запросы и cookies на новый домен не переносятся. Контракт: [Автоматический выбор зеркала](../../docs/04_network_and_playback.md#8-автоматический-выбор-зеркала).

Нормализованный контракт заменяем через `FakeAnistarClient` и DI override. Это не подтверждает совместимость с ещё неизвестным REST API: будущий адаптер должен сохранять ID/slug/filter paths/pages и поддерживать существующие операции либо потребует отдельного согласования. См. [ADR-0010](../../docs/adr/0010-normalized-anistar-contract.md).

## Нормализованный контракт

Summary и details — отдельные конечные DTO. Обязательны id, slug и title. Summary сохраняет nullable poster, year, rating, favorite status, жанровую подпись, description, update message и publication date; getter `genres` разбивает жанровую подпись по запятым. Details сохраняет nullable poster, year, description, voiceover, series info, director, favorite status, rating, update message и publication date, а также отдельные списки жанров, фильтров и частей. `AnistarCatalogFilterDto` сохраняет исходный path и optional image URI; `AnistarAnimePartDto` сохраняет подпись и исходный URI, а поддержанные id/slug оставляет nullable. Отсутствующие значения не делают карточку ошибочной. Favorite null означает неизвестный статус; false и true означают подтверждённый статус. Рейтинг от 0 до 10 включительно сохраняется; некорректный рейтинг нормализуется в null. Коллекции DTO защищены копиями.

`AnistarEpisodeDto` содержит номер в рамках аниме и список `AnistarVideoSourceDto`: числовой height, исходный manifestUri, неизменяемые headers и optional expiresAt для конкретного источника. HTML-адаптер собирает Referer и читает end. Неподдерживаемый expiry становится null. `mediaId` остаётся внутренней parsed-моделью и используется `markWatched` без дополнительной загрузки плейлиста перед записью. DLE cookies, подтверждение сортировки и проверки encoded paths/origin также принадлежат HTML.

Ссылки фильтра года и режиссёра поступают из карточки как исходные href. Публичная проверка `v31.astar.bz` от 2026-10-22 подтвердила для них группу сортировки `xfsearch`, путь страницы 2 и CP1251 percent-encoding с `+`. Не формируйте путь по видимому имени и не декодируйте его перед запросом. Сортировка должна оставаться request-local и изолированной от cookies аккаунта и других фильтров. Публичные наблюдения и границы подтверждения приведены в [спецификации фильтров](../../docs/specs/09_catalog_filters.md); состав метаданных и частей — в [спецификации загрузки страниц](../../docs/specs/03_page_loading.md).

Все async-операции адаптера нормализуют ожидаемые отказы в `AnistarClientException` с категориями timeout, connection, server и request; login POST может дополнительно вернуть `invalidCredentials` только при явном отказе учётных данных. Публичная ошибка не содержит Dio, cookies или response body. Неожиданные отказы остаются отдельными безопасными ошибками и становятся `UnknownFailure` в репозитории. Feature data переводит ожидаемую ошибку через `mapAnistarErrors` перед единственной обёрткой `Result`.

## Как проверить

Из корня workspace запустите тесты пакета:

```bash
fvm flutter test test/infrastructure/anistar
```

## Навигация

- [Сеть и HLS](../../docs/04_network_and_playback.md) — вход, сессия, зеркало и playback.
- [Фильтры каталога](../../docs/specs/09_catalog_filters.md) — подтверждённые год/режиссёр href и сортировка AniStar.
- [Карточка аниме](../../docs/specs/12_anime_details.md) — метаданные, части и правило выбора серии.
- [Архитектура](../../docs/01_architecture_principles.md) — контракты и границы слоёв.
- [Структура проекта](../../docs/02_project_structure.md) — зависимости между пакетами.
- [ADR-0009](../../docs/adr/0009-single-anistar-client-and-dio.md) и [ADR-0010](../../docs/adr/0010-normalized-anistar-contract.md) — клиент сайта и нормализованный контракт.
