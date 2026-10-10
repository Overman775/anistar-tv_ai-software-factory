# 🔐 Вход и сессия | AniStar TV

## 1. Контракт

App должен открывать protected router только после подтверждения аккаунта. Состояния: проверка → гость / подтверждённый аккаунт / ошибка. При ошибке восстановления запись сохраняется для ручного retry, но каталог не открывается. Пароль не сохраняется; сохранённая сессия проверяется без повторного POST.

Владельцы: AuthController / AuthRepository — feature Auth; AnistarAuthService, AnistarAuthHtml, AnistarSession и interceptor — infrastructure/anistar; SecureStorage — infrastructure/storage. Нейтральный networking не знает DLE.

## 2. Вход

1. Trim применяется только к логину. Пустые логин или пароль отклоняются до запроса. Пароль передаётся без trim.
2. Перед входом подтверждается доступность [зеркала](05_mirrors.md). Затем прежняя сессия текущего origin очищается; операция запоминает generation.
3. GET `/anime/` загружает форму. Форма должна содержать `input[name=login_password]` и иметь `method=post`; ближайший родитель form определяет action. Отсутствующая/изменённая форма — ошибка протокола.
4. Action разрешается относительно URL страницы и должен принадлежать текущему HTTPS origin, без userinfo. Пароль нельзя отправлять на другой домен.
5. Сохраняются hidden inputs с name; значения дополняются `login_name`, `login_password`, `login=submit`. Тело — application/x-www-form-urlencoded, не JSON.
6. Charset тела определяется Content-Type формы: Windows-1251/CP1251 либо UTF-8. Пробел кодируется `+`, остальные байты — percent encoding. Символ, непредставимый в CP1251, приводит к ошибке до POST; заменять его вопросительным знаком нельзя.
7. POST передаёт Referer страницы формы. POST не имеет автоматического transport retry.
8. Успех требует ссылки текущего origin с query `action=logout` и непустого cookie header для страницы каталога. HTTP 200, произвольный текст «успешно» или отсутствие формы сами по себе успех не подтверждают. Имя аккаунта в записи берётся из введённого логина; отдельное сопоставление имени по HTML сейчас не выполняется.
9. Cookies и имя аккаунта сохраняются одной encrypted записью. Ошибка записи отменяет подтверждение входа и очищает cookies в памяти. UI открывает каталог только после успешного сохранения.

## 3. Redirect и ограничения

Автоматическое следование redirects выключено. Поддерживаются 301/302/303 внутри origin: следующий запрос — GET, тело POST не повторяется. Допустимы максимум три перехода; четвёртый redirect завершает попытку ошибкой. 307/308 не используются для переноса тела.

Cross-origin redirect может запустить поиск нового зеркала. Исходный POST не повторяется; новая сессия подтверждается отдельно. Неизвестный action/redirect нельзя считать разрешением переслать credentials.

## 4. Хранение и восстановление

Ключ: `anistar.session.v1.<Uri.encodeComponent(origin.origin)>`. JSON record содержит version=1, origin, account и host/domain cookies. Зеркала и порты изолированы. Android backup выключен, чтобы запись cookies не восстанавливалась отдельно от ключа шифрования.

Cookie jar применяет domain/path/secure policy; дополнительно исключаются истёкшие Secure cookies. Cookies прикрепляются только к текущему HTTPS origin. На чужом origin header Cookie удаляется; native HLS не получает cookies сайта.

Restore и изменения session сериализованы. Повреждённый JSON, несовпадающий origin/version или некорректные cookies удаляют повреждённую запись. Ошибка Secure Storage не маскируется под отсутствие аккаунта.

Если записи нет, клиент остаётся гостем. Если она есть, GET каталога должен подтвердить logout marker. Явная гостевая форма очищает сессию. Ни logout marker, ни гостевая форма не найдены — ошибка проверки с сохранением записи. Ошибка сети также не удаляет запись.

## 5. Expiry, выход и гонки

| Событие | Ожидаемое поведение |
| --- | --- |
| Гостевая форма вместо authenticated HTML | Удаление записи, событие expired, закрытие protected router и player |
| HTTP 403 | Не доказывает expiry; обрабатывается как возможный отказ зеркала |
| Player HTML без login/logout marker | Не используется как доказательство гостевой сессии |
| Logout | Локальное удаление записи текущего origin и cookies в памяти; серверный logout не вызывается |
| Не удалось удалить запись | Ошибка; UI не объявляет успешный выход |
| Ответ старой generation | Не сохранять cookies и не подтверждать вход |
| Старый signIn после expiry/смены repository | AuthController operation guard не позволяет восстановить старый аккаунт |

При смене origin router идентифицируется аккаунтом и зеркалом; состояние навигации предыдущего зеркала не переносится даже при одинаковом имени аккаунта. Logout текущего origin не удаляет записи других зеркал.

## 6. Приёмка и источники

Должны сохраняться: отказ неверного пароля; CP1251 кириллица; restore без POST; expiry; локальный logout; отказ storage; изоляция cookies; запрет replay POST при смене зеркала; игнорирование позднего ответа.

- [Auth service](../../infrastructure/anistar/lib/src/anistar_auth_service.dart), [session](../../infrastructure/anistar/lib/src/anistar_session.dart), [interceptor](../../infrastructure/anistar/lib/src/anistar_session_interceptor.dart).
- [Протокол и storage-регрессии](../../test/infrastructure/anistar/anistar_auth_test.dart), [UI gate](../../test/packages/features/auth/auth_test.dart), [смена origin](../../test/app/mirror_switch_test.dart), [Android E2E](../../integration_test/app_e2e_test.dart).

Live-вход и restore с тестовым аккаунтом подтверждены Android E2E на 10 октября 2026 года. Миграция данных установленной Secure Storage v10-сборки отдельно не подтверждена; не трактовать успешный вход или fixture restore как проверку этой миграции.

При поиске logout ссылки игнорировать javascript:, mailto:, data:, malformed URI/query, чужой host/port, cleartext HTTP и URI с userInfo. Нельзя читать `Uri.origin` у произвольного href: Dart бросает StateError для схем без HTTP-origin. Регрессия обязана включать такие ссылки перед реальной logout ссылкой в member HTML. Живой аккаунт и запуск: [разработка и тестирование](../05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

## 7. TV focus

После подтверждения сессии логин отображается в раскрытом левом меню; там же доступен выход из аккаунта. Форма входа остаётся отдельным экраном до protected router. Такое разделение закреплено в [ADR-0008](../adr/0008-youtube-tv-interaction-reference.md).

Если подтверждённой сессии нет, начальный focus экрана входа получает логин; после отказа входа — очищенное поле пароля. При закрытой экранной клавиатуре Down переводит логин → пароль → «Войти», Up из пароля возвращает логин. Действия экранной клавиатуры Next/Done переходят в пароль / отправляют форму. Управление и проверки описаны в [TV-взаимодействии](06_tv_interaction.md#6-вход-с-пульта).
