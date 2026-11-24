# Выбор зеркала | AniStar TV

Спецификация определяет проверку доступности зеркал `astar.pw`, ограниченный поиск после отказа и смену активного origin. Discovery действует только для поддерживаемого домена; остальные origins остаются фиксированными.

## Термины и ответственность

- **Термины:** [доступ, аккаунт и зеркало](../01_01_domain_glossary.md#1-доступ-аккаунт-и-зеркало).
- **Владелец:** [AniStar](../01_02_feature_responsibilities.md#2-композиция-и-инфраструктура) — discovery и активное зеркало.
- **Участники:** app связывает origin с зависимостями; auth и фичи-потребители обновляют состояние в своей области ответственности.

## Допустимые зеркала и cache

Начальный HTTPS origin задаётся `ANISTAR_MIRROR_URL`, default — `https://v1.astar.pw/`. Автоматический поиск работает только для `vN.astar.pw`, где N от 1 до 9999, без userinfo и нестандартного порта. Другие origins, включая localhost E2E, остаются фиксированными.

В Shared Preferences хранится только integer по ключу `anistar.mirror.astar.pw.version`. При запуске версия не ниже configured baseline и не выше 9999 становится текущей. Другой тип, слишком большая или более старая версия игнорируется. Ключ прежней серии `anistar.mirror.astar.bz.version` не читается и не удаляется; его значение не влияет на новую серию. Наличие cache не доказывает доступность зеркала.

## Проверка доступности

Для зеркал vN перед проверкой сохранённой сессии выполняется анонимный GET `/anime/`. Фиксированный origin пропускает probe. Отдельный Dio работает без session interceptor, cookies, credentials и transport retry. Connect, receive и send timeout каждого probe составляют по 4 секунды. Redirects выключены, TLS-проверка включена. Стартовый экран описан в [визуальной системе](11_visual_system.md) и [спецификации входа](01_authentication.md).

Зеркало подтверждается только при HTTP 200, отсутствии cf challenge и успешном парсинге непустого каталога. HTML с ошибкой, реклама без пригодных карточек, пустая HTML и redirect не подтверждают зеркало. После успеха `ensureAvailable` не выполняет HTTP при каждом обращении.

## Поиск после отказа

Interceptor запускает recovery при connection/send/receive timeout, connectionError, HTTP 403/451/5xx, redirect как error response, cross-origin redirect в принятом response и `cf-mitigated: challenge` в response. Уже сформированная AnistarFailure не запускает новый поиск через onError.

Канонический redirect карточки внутри текущего HTTPS origin обрабатывает адаптер чтения detail по [контракту загрузки страниц](03_page_loading.md#detail-и-серии). Для такого ответа не требуется проверка зеркала. Redirect на другой origin остаётся поводом проверить зеркало без повтора запроса по адресу из `Location`.

Cancel, bad certificate, 401, 404 и 429 сами по себе не запускают mirror recovery. HTML challenge без cf header может быть распознан парсером и показан как Failure. Сейчас такой parse failure посреди сессии отдельно не запускает поиск. На startup probe такая непригодная HTML не подтверждает зеркало. Это границы текущей реализации; они не обещают распознавать любую страницу блокировки.

1. Recovery принимает только отказ текущего origin. Отказ CDN, другого домена или уже покинутого зеркала не меняет current. Сначала повторно проверяется каталог current. Если он здоров, origin сохраняется: отказ одной карточки/API не означает отказ сайта, поиск прекращается.
2. Если каталог current не подтверждён, проверяются `current+1`, `+2`, `+3`, `+4` по порядку, не выходя за 9999. Это максимум пять probes вместе с current.
3. Сохраняется первый подтверждённый номер. Непроверенный кандидат не кешируется. Current должен обновиться после успешной записи. Событие change публикуется только при смене origin. Менеджер ждёт завершения `SharedPreferencesStorage.set`, но обёртка игнорирует `false` от `setInt`. При таком отказе смена в текущем процессе возможна без подтверждённого сохранения для следующего запуска.
4. Если диапазон исчерпан, сохраняется прежняя версия, возвращается AnistarFailure и устанавливается cooldown на одну минуту. До окончания cooldown новые поиски не запускаются; после него ручной запрос может повторить ограниченный цикл.

Одновременные вызовы делят одну in-flight операцию. Отсутствие интернета не отличимо от отказа всех зеркал и тоже заканчивается ограниченной ошибкой. Нет понижения версии, неограниченного сканирования или поиска другого доменного семейства. Location redirect не используется как доверенный адрес для переноса данных.

## Смена origin и границы повтора

Change обновляет active mirror provider. NetworkConfig, Dio, source, repositories и session пересоздаются. Старый transport закрывается. AuthController заново подтверждает сессию. Protected router привязан к паре account/origin.

Cookies старого origin не копируются. Отдельная сохранённая сессия нового origin может быть восстановлена; при её отсутствии нужен вход. Исходный запрос не replay-ится на новом host, включая POST входа и GET изменения избранного. Generation/operation guards не позволяют старому ответу вернуть старый аккаунт/экран.

Поиск зеркал имеет отдельный бюджет от transport retry и [player refresh](04_playback.md). Нельзя исправлять HLS 403 перебором зеркал в native CDN-клиенте.

StartupScreen показывает этап проверки доступности и сохраняет ошибку поиска с ручным повтором. После подтверждения зеркала он переходит к проверке сессии. Дальнейший переход задаёт [контракт входа](01_authentication.md#старт-и-экран-входа). При signIn сохраняется `ensureAvailable` как защита доступности. Успешный startup probe не дублируется, пока менеджер считает зеркало проверенным.

## Источники и границы подтверждения

- [Конфигурация](../../infrastructure/anistar/lib/src/anistar_mirror_config.dart), [manager](../../infrastructure/anistar/lib/src/anistar_mirror_manager.dart), [interceptor](../../infrastructure/anistar/lib/src/anistar_mirror_interceptor.dart), [active mirror](../../infrastructure/anistar/lib/src/anistar_active_mirror.dart), [composition](../../lib/app/app_container.dart).
- [Допустимые origins](../../test/infrastructure/anistar/anistar_mirror_config_test.dart), [поиск и cache](../../test/infrastructure/anistar/anistar_mirror_manager_test.dart), [redirect карточки, сбой POST и session isolation](../../test/app/mirror_switch_test.dart).

Отказы зеркал проверены Dio fixtures. Реальная блокировка и авторизованный live-переход на новое зеркало отдельно не воспроизводились. Android E2E использует фиксированный localhost, поэтому не является end-to-end проверкой сканирования реальных зеркал.
