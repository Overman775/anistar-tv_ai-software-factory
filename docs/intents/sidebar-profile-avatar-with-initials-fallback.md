# Аватар профиля в левом меню с инициалами при отсутствии картинки

## Зачем

Сейчас в блоке пользователя в левом меню после авторизации отображаются
инициалы, хотя у пользователя есть изображение в профиле. Нужно показывать
его профильную картинку.

## Чего хочу

В авторизованной зоне загружать и отображать изображение из профиля
пользователя в блоке аккаунта левого меню. Если в профиле картинки нет,
показывать инициалы, как сейчас.

## Что важно сохранить

Сохранить существующие имя пользователя, действия аккаунта и расположение
блока в левом меню. Изображение должно соответствовать текущему аккаунту.
Отображение инициалов остаётся запасным вариантом при отсутствии картинки.
Гостевой режим по [спецификации входа](../specs/01_authentication.md)
не показывает аватар. Геометрия и управление меню сохраняют
[TV-контракт](../specs/06_tv_interaction.md) и
[ADR-0008](../adr/0008-youtube-tv-interaction-reference.md).

## Контекст в текущем коде

Сейчас это ограничение всего пути данных, а не только отрисовки.
[`AnistarClient.restore/signIn`](../../infrastructure/anistar/lib/src/contract/anistar_client.dart)
возвращают `String?`/`String` с именем аккаунта; отдельного контракта профиля
или URI аватара нет.
[`AnistarAuthService`](../../infrastructure/anistar/lib/src/anistar_auth_service.dart)
читает HTML каталога `/anime/` при входе и восстановлении, но использует его
для проверки сессии. Имя берётся из введённого логина или сохранённой записи.
[`AnistarAuthHtml`](../../infrastructure/anistar/lib/src/anistar_auth_html.dart)
распознаёт форму входа и logout-ссылку текущего origin, изображение не извлекает.
[`AnistarSession._persist`](../../infrastructure/anistar/lib/src/anistar_session.dart)
сохраняет аккаунт и cookies в зашифрованной записи, без данных аватара.

На границе feature
[`AnistarAuthRepository`](../../lib/packages/features/auth/data/anistar_auth_repository.dart)
оборачивает эти строки в `Result` через `BaseRepository`.
[`AuthenticatedAccess`](../../lib/packages/features/auth/domain/auth_access.dart)
содержит только `account`; [`AuthController`](../../lib/packages/features/auth/auth_controller.dart)
создаёт это состояние после входа/restore.
[`createAppOverrides`](../../lib/app/app_container.dart) связывает auth repository
с общим `anistarClientProvider`, а [`HomeRoute`](../../lib/app/app_routes.dart)
передаёт `authAccessProvider.account` как `accountName` в оболочку.
Это затрагивает границы infrastructure → feature data/domain → app → presentation,
если источник действительно предоставит изображение; конкретный новый контракт
пока не выбран. Владельцы HTML, DI и UI определены
[архитектурой](../01_architecture_principles.md) и
[README AniStar](../../infrastructure/anistar/README.md).
`AuthController` уже отбрасывает результаты старых операций, а сессия привязана
к origin. Эти существующие границы важны для требования показывать картинку
текущего аккаунта: одних корректных пикселей в виджете недостаточно, чтобы
подтвердить соответствие изображения пользователю после выхода или смены зеркала.

[`CatalogNavigationRail`](../../lib/packages/features/catalog/presentation/widgets/catalog_navigation_rail.dart)
передаёт только имя в
[`AccountIdentity`](../../lib/packages/features/common/presentation/widgets/account_identity.dart).
Этот виджет выводит заглавные первые символы максимум двух частей имени
и сохраняет полное имя в Semantics. Он также используется мобильной оболочкой
[`MobileHomeShell`](../../lib/packages/features/home/presentation/mobile/mobile_home_shell.dart),
поэтому изменение общего компонента имеет область влияния шире левого меню.

В [UI Kit](../../lib/packages/ui_kit/README.md) уже есть
[`AppNetworkImage`](../../lib/packages/ui_kit/lib/src/widgets/app_network_image.dart):
кеширование, ограничение decode по размеру/DPR, placeholder и `errorWidget`.
Он получает готовый URL и не разбирает профиль; передача auth headers через его
текущий API не предусмотрена. Его существующие состояния загрузки и ошибки
сами по себе не определяют желаемое поведение аватара.

Существующие [auth fixtures](../../test/mocks/anistar/auth_fixture_adapter.dart)
содержат `memberAuthHtml` только со ссылками профиля и выхода, без изображения.
[Auth-тесты](../../test/infrastructure/anistar/anistar_auth_test.dart) проверяют
сессию и logout marker;
[тесты изображений](../../test/packages/ui_kit/widgets/app_network_image_test.dart)
— общий fallback, decode и замену постера;
[проверка меню](../../test/app/typography_scaling_test.dart) — размещение имени
и действий. Они не подтверждают извлечение аватара, его соответствие аккаунту
после смены сессии или ветку «изображения нет». Это пробел покрытия, а не
результат свежего прогона: в рамках уточнения intent тесты не запускались.

## Что пока неясно

Реальная авторизованная разметка профиля не исследована: доступа к живому
аккаунту в этой проверке не было. Не подтверждены селектор и адрес изображения,
доступность картинки без cookies/Referer, а также способ отличить отсутствие
личной картинки от стандартного аватара сайта. Наличие картинки в профиле
сообщено пользователем; доступность её URL в текущих данных приложения этим
не подтверждается.

Нужно определить отображение на время загрузки и при ошибке картинки;
инициалы согласованы только для отсутствующего изображения. Поведение при
обновлении аватара и необходимость отдельного запроса профиля пока открыты.
Живая проверка и её границы регулируются
[руководством тестирования](../05_development_and_testing.md#9-проверка-с-живым-аккаунтом),
а cookies, origin и безопасные логи —
[сетевым руководством](../04_network_and_playback.md).
