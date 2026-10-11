# 🌐 Выбор зеркала | AniStar TV

## 1. Допустимая область

Начальный HTTPS origin задаётся `ANISTAR_MIRROR_URL`, default — `https://v30.astar.bz/`. Автоматический поиск работает только для `vN.astar.bz`, N от 1 до 9999, без userinfo и нестандартного порта. Другие origins, включая localhost E2E, остаются фиксированными.

В Shared Preferences хранится только integer по ключу `anistar.mirror.astar.bz.version`. При запуске версия не ниже configured baseline и не выше 9999 становится текущей. Другой тип, слишком большая или более старая версия игнорируется. Само наличие cache не доказывает доступность.

## 2. Проверка доступности

На стартовом экране, перед проверкой сохранённой сессии, выполняется anonymous GET `/anime/`. Dedicated Dio не использует session interceptor, cookies или credentials. Connect/receive/send timeout каждого probe — по 4 секунды; redirects выключены, TLS-проверка включена.

Зеркало подтверждено только при HTTP 200, отсутствии cf challenge и успешном парсинге непустого каталога. HTML с ошибкой, реклама без пригодных карточек, пустая HTML и redirect не подтверждают зеркало. После успеха ensureAvailable не выполняет HTTP на каждом обращении.

## 3. Восстановление

Триггеры interceptor: connection/send/receive timeout, connectionError, HTTP 403/451/5xx, redirect как error response, cross-origin redirect в принятом response и `cf-mitigated: challenge` в response. Уже сформированная AnistarFailure не запускает новый поиск через onError.

Cancel, bad certificate, 401, 404 и 429 сами по себе не являются триггерами mirror recovery. HTML challenge без cf header может быть распознан парсером и показан как Failure; сейчас такой parse failure посреди сессии отдельно не запускает поиск. На startup probe та же непригодная HTML не подтверждает зеркало. Это границы текущей реализации, а не обещание распознавать любую страницу блокировки.

1. Recovery принимает только отказ текущего origin. Отказ CDN, другого домена или уже покинутого зеркала не меняет current.
2. Сначала повторно проверить каталог current. Если он здоров, оставить origin: отказ одной карточки/API не означает отказ сайта.
3. Если каталог не подтверждён, проверить current+1, +2, +3, +4 по порядку, не выходя за 9999. Это максимум пять probes вместе с текущим.
4. Первый подтверждённый номер сохраняется. Current обновляется и публикует change только после успешной записи; непроверенный кандидат не кешируется.
5. Исчерпание диапазона сохраняет прежнюю версию, возвращает AnistarFailure и устанавливает cooldown одну минуту. До его окончания новые поиски не запускаются; после него ручной запрос может повторить ограниченный цикл.

Одновременные вызовы делят одну in-flight операцию. Отсутствие интернета не отличимо от отказа всех зеркал и тоже заканчивается ограниченной ошибкой. Нет понижения версии, неограниченного сканирования или поиска другого доменного семейства. Location redirect не используется как доверенный адрес для переноса данных.

## 4. Смена origin

Change обновляет active mirror provider. NetworkConfig, Dio, source, repositories и session пересоздаются; старый transport закрывается. AuthController заново подтверждает сессию, protected router привязан к паре account/origin.

Cookies старого origin не копируются. Отдельная сохранённая сессия нового origin может быть восстановлена; при её отсутствии нужен вход. Исходный запрос не replay-ится на новом host, включая POST входа и GET изменения избранного. Generation/operation guards не позволяют старому ответу вернуть старый аккаунт/экран.

Это независимый бюджет от transport retry и [player refresh](04_playback.md). Нельзя пытаться исправить HLS 403 перебором зеркал в native CDN-клиенте.

## 5. Приёмка и источники

Должны сохраняться: один probe здорового mirror; переход с пропуском недоступной версии; cache следующего запуска; один поиск при параллельных вызовах; максимум четыре successors; cooldown; отсутствие записи при полном отказе; custom origin без discovery; отказ переноса credentials/cookies и replay.

- [Manager](../../infrastructure/anistar/lib/src/anistar_mirror_manager.dart), [interceptor](../../infrastructure/anistar/lib/src/anistar_mirror_interceptor.dart), [active mirror](../../infrastructure/anistar/lib/src/anistar_active_mirror.dart), [composition](../../lib/app/app_container.dart).
- [Поиск и cache](../../test/infrastructure/anistar/anistar_mirror_manager_test.dart), [POST 503 / redirect 302 и session isolation](../../test/app/mirror_switch_test.dart).

Отказы зеркал проверены Dio fixtures. Реальная блокировка и авторизованный live-переход на новое зеркало отдельно не воспроизводились. Android E2E использует фиксированный localhost, поэтому не считается end-to-end проверкой сканирования реальных зеркал.

StartupScreen показывает этап проверки доступности и сохраняет ошибку поиска с ручным повтором. После успешного поиска переходит к проверке сессии; форма входа появляется только для гостя. При signIn сохраняется ensureAvailable как защита доступности; успешный startup probe не дублируется, пока менеджер считает зеркало проверенным.
