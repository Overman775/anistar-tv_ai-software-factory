# 🌐 Работа с сетью и HLS | AniStar TV

Dio получает HTML AniStar. DOM и JSON5 разбираются на устройстве без выполнения скриптов сайта. Native `video_player` обращается к CDN напрямую через Android Media3 или iOS AVFoundation. [ADR-0006](adr/0006-android-direct-anistar.md), [спецификации](specs/README.md).

## 1. Границы сетевого слоя

| Участник | Ответственность |
| :--- | :--- |
| `DioClient` | HTTP transport, таймауты, retry и безопасные логи. |
| `HtmlAnistarClient` | HTML, авторизация, сессия и DTO. App передаёт общий контракт `AnistarClient` через `anistarClientProvider`. |
| Feature Data | Маппинг DTO в domain и перевод ошибок в `Result`/`Failure` через `BaseRepository`. |
| `VideoPlayerController` | Native HLS из manifest URI и headers открытой playback session. |

Пробы зеркал используют отдельный Dio из той же фабрики без cookies и transport retry. Контракт и границы библиотек описаны в [ADR-0009](adr/0009-single-anistar-client-and-dio.md) и [ADR-0010](adr/0010-normalized-anistar-contract.md).

---

## 2. HTML и JSON5

`ANISTAR_MIRROR_URL` задаёт HTTPS origin. Значение по умолчанию для dev и prod — `https://v1.astar.pw/`. Задавайте переменную через `env/dev.json` или свой `env/prod.json` по `env/prod.example.json`.

Source запрашивает HTML как bytes. `HtmlDecoder` выбирает Windows-1251 или UTF-8 по Content-Type. Для карточек и пагинации используйте исходные идентификаторы, nullable-поля и ссылки. Метки года, режиссёра и автора используют исходные маршруты и request-local группу сортировки `xfsearch`. Порядок выдачи задаёт сайт. [Загрузка страниц](specs/03_page_loading.md), [фильтры](specs/09_catalog_filters.md), [карточка](specs/12_anime_details.md).

`PlaylistLiteral` выделяет сбалансированный массив `playlst` с учётом кавычек, escape и комментариев. Парсер JSON5 читает номер серии, качество и HLS из `files` её объекта. [Парсер](../infrastructure/anistar/lib/src/anistar_html_parser.dart), [контракт источника](specs/04_playback.md).

---

## 3. Репозитории и ошибки

Source и парсер возвращают данные либо бросают исключение. Клиент распознаёт HTTP 403 и challenge, парсер распознаёт защитную или повреждённую HTML-страницу. Repository сохраняет причину отказа в безопасной `Failure`. [Маппинг ошибок](01_architecture_principles.md#5-результаты-ошибки-и-навигация).

| Параметр transport | Значение |
| :--- | :--- |
| Connect / send timeout | 8 секунд. |
| Receive timeout | 20 секунд. |
| Retry | До двух повторов идемпотентного запроса при сетевых ошибках, HTTP 408/429/5xx. |
| Без transport retry | HTTP 403, POST и изменяющий GET. |

Повторы transport, поиск зеркала и refresh плеера имеют отдельные бюджеты. [HTTP-контракт](specs/03_page_loading.md).

---

## 4. Playback session

Перед открытием источника repository получает свежий player HTML. Из доступных потоков `360` и `720` выбирается запрошенный или, если его нет, наибольший для данной серии. HTML-адаптер формирует Referer для player page и читает optional expiry из `end`. Repository переносит подписанный URI целиком, включая `+`, запятые, path и query. Параметры подписи задаёт источник. [Playback session](specs/04_playback.md), [ADR-0010](adr/0010-normalized-anistar-contract.md).

```dart
VideoPlayerController.networkUrl(
  session.manifestUri,
  formatHint: VideoFormat.hls,
  httpHeaders: session.httpHeaders,
);
```

Передавайте `VideoFormat.hls` даже для адреса с суффиксом `.mp4`. Native transport разрешает ссылки манифеста и сегментов. Android передаёт им Referer. Cookies AniStar остаются в transport сайта. Для подтверждения native HLS на iOS Simulator нужен отдельный fixture E2E. [Контракт воспроизведения](specs/04_playback.md), [проверки](05_development_and_testing.md).

---

## 5. Восстановление и lifecycle

Инициализация controller ограничена 35 секундами. Общий бюджет на выбранный источник — один автоматический refresh для ошибок инициализации, воспроизведения и native команды. Refresh восстанавливает позицию и playing/paused state через controller нового источника. Ручной retry и явная смена серии или качества дают новый бюджет. Правила позиции, изменения маршрута и lifecycle определяет [спецификация воспроизведения](specs/04_playback.md).

Операция с устаревшим идентификатором не обновляет состояние. Player освобождает прежний controller до создания нового. Владельцы ресурсов описаны в [руководстве по DI](01_03_di_and_lifecycle.md#2-владение-ресурсами).

Transport пишет origin и только публичные paths из allowlist `NetworkConfig.loggablePaths`. Подписи могут находиться и в path, и в query. Query и остальные paths скрыты. Сообщения стороннего retry interceptor отключены. В диагностике плеера допустимы статус, host, серия и качество. Исключайте HTML, signed URL и `native errorDescription` из логов и UI. [Проверка живого аккаунта](05_02_live_testing.md).

---

## 6. Вход и сессия

Auth владеет режимом доступа. App передаёт `AnistarAuthRepository` через DI. AniStar выполняет DLE-вход с charset формы и подтверждает сессию по logout-ссылке текущего origin и cookies. HTTP-успех сам по себе не подтверждает вход. Пароль используется только для входа. Cookies и аккаунт хранятся одной защищённой записью на HTTPS origin. [Вход и сессия](specs/01_authentication.md).

Logout очищает сессию текущего origin локально. Generation защищает от поздних cookies. Истечение закрывает account-bound маршруты. HTTP 403 может означать отказ зеркала. Player HTML без маркеров входа не определяет сессию. Правила redirect, expiry, восстановления и ошибок хранилища описаны в спецификации.

На iOS flavor выбирает Keychain `accountName`. Bundle ID изолирует default Keychain group и preferences. Android backup отключён, чтобы cookies не восстановились отдельно от ключа шифрования. Исключайте пароль и печатные клавиши со страницы входа из логов. [Storage](../infrastructure/storage/README.md).

---

## 7. Избранное сайта

Feature использует общий авторизованный `AnistarClient`. Изменение начинается с проверки свежего статуса и завершается подтверждением сайта. Изменяющий GET исключён из transport retry. После ошибки повтор запускает пользователь. Локальное состояние относится к текущему аккаунту и origin. Критерии пустого списка, определения статуса и подтверждения записи описаны в [спецификации избранного](specs/02_favorites.md).

---

<a id="автоматический-выбор-зеркала"></a>

## 8. Автоматический выбор зеркала

Автоматический поиск действует для `https://vN.astar.pw/`. Остальные HTTPS origins, включая fixture, фиксированы. Менеджер сохраняет номер подтверждённой версии и проверяет каталог до restore или первого входа. Если ответ или ошибка запроса запускает восстановление, менеджер прежде всего перепроверяет каталог. Здоровый каталог сохраняет текущее зеркало. Условия восстановления, лимиты и cooldown определяет [спецификация зеркал](specs/05_mirrors.md).

При смене origin DI пересоздаёт транспорт, клиент, сессию и зависимые репозитории. Пароль, cookies и исходный запрос на новый origin не переносятся. CDN ошибки обрабатывает player refresh. Для интерактивной проверки показывайте отказ сайта. Доступность с одного IP не гарантирует доступ с другого. [Live-проверка](05_02_live_testing.md).

---

## 9. Отметки просмотра

Сайт отдаёт отметку `viewing` в `playlst` для аккаунта. После фактического начала воспроизведения `watch_history` записывает отметку через AniStar и подтверждает её свежим player HTML. Гостевой режим пропускает серверную запись. [Просмотренные серии](specs/07_watched_episodes.md).

---

## 10. Добавление сетевой операции

1. Добавьте типизированную операцию и DTO в `infrastructure/anistar/lib/src/contract/`.
2. Реализуйте запрос, парсинг и классификацию отказа внутри AniStar. Экспортируйте тип через применимую публичную библиотеку.
3. Расширьте domain repository фичи. В Data преобразуйте DTO внутри `BaseRepository.makeApiCall`. Для ожидаемой ошибки сайта используйте `mapAnistarErrors`.
4. Назначьте реализацию в [app container](../lib/app/app_container.dart). Presentation получает domain-результат.
5. Проверьте адаптер HTTP fixtures, а маппинг и repository — unit-тестом. Добавьте fixture E2E для сквозного пользовательского поведения, которое unit-тест не доказывает.
