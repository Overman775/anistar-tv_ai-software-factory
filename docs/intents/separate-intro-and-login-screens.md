# Разделить интро и форму входа на два экрана

## Зачем

Начальный выбор способа входа и форма авторизации должны быть двумя
отдельными экранами. Пользователь сначала выбирает, войти в аккаунт или
продолжить без входа; поля формы на этом шаге не нужны.

## Чего хочу

- Сделать отдельный экран интро с двумя кнопками: «Войти» и «Продолжить
  без входа». Форму входа на интро не показывать.
- По кнопке «Войти» на интро переходить на отдельную страницу с формой входа.
  Это переход между экранами, а не раскрытие формы внутри интро.
- По кнопке «Продолжить без входа» открывать приложение в гостевом режиме.
- Кнопка «Войти» в левом меню приложения должна вести сразу на новую страницу
  формы входа, без промежуточного интро.
- Проверить остальные переходы и ссылки на вход: действия, предлагающие
  авторизоваться из приложения, должны открывать непосредственно форму входа.
  Обновить маршруты и их использование с учётом разделения экранов.
- После выхода из аккаунта и истечения сессии показывать интро.
- Back из формы возвращает на экран, с которого открыли вход: к интро
  либо в исходный контекст приложения.
- «Продолжить без входа» показывать только на интро.

## Текущий технический контекст

[App](../../lib/app/app.dart) после `AuthStartupStage.complete` показывает
`LoginScreen`, если доступ из `authAccessProvider` имеет `canBrowse == false`; до этого работает
`StartupScreen`. Форма уже содержит поля и `login_guest`. В
[`LoginScreen`](../../lib/packages/features/auth/presentation/login_screen.dart)
гостевая кнопка вызывает `enterAnonymous()`, а при `canCancel: true` —
`cancelSignIn()`. Отдельного интро сейчас нет.

[`AuthController`](../../lib/packages/features/auth/auth_controller.dart) владеет
`UnknownAccess`, `UnauthenticatedAccess`, `AnonymousAccess` и
`AuthenticatedAccess`; отсутствие сессии само по себе не включает гостя.
`requestSignIn()` действует только для гостя и устанавливает `loginRequested`.
[`AuthenticatedApp._syncLogin`](../../lib/app/authenticated_app.dart) наблюдает
этот флаг и открывает `LoginScreen(canCancel: true)` через
`Navigator.push(MaterialPageRoute)`. Это отдельная страница поверх гостевого
контекста, но не именованный маршрут GoRouter.

[`AppRouter`](../../lib/app/app_router.dart) начинает с `AppRoutes.home`
(`/home`); auth redirect, `LoginRoute` и параметра адреса возврата нет.
[Typed routes](../../lib/app/app_routes.dart) принадлежат App. Ключ
`AuthenticatedApp` включает тип доступа, аккаунт и зеркало: успешный вход
пересоздаёт router, поэтому нынешнее сохранение контекста при отмене не означает
возврат туда же после входа.

Существующие потребители открытия формы:

| Поверхность | Связь с Auth |
| --- | --- |
| TV-меню главной и вложенных экранов | `HomeRoute` через `HomeScreen`, а также `_RouteShell` передают `requestSignIn` в [`TvRouteShell.onSignIn`](../../lib/packages/features/home/presentation/screens/tv_route_shell.dart) |
| Мобильный аккаунт | [`MobileHomeShell._account`](../../lib/packages/features/home/presentation/mobile/mobile_home_shell.dart); callback также передаётся через [`_AppMobileRouteShell`](../../lib/app/app_mobile_route_shell.dart) |
| Запрос гостем раздела избранного | [`HomeScreen`](../../lib/packages/features/home/presentation/screens/home_screen.dart) вызывает `onSignIn`, включая входящий `HomeDestination.favorites` |
| Избранное карточки и панель действий | [`FavoriteButton`](../../lib/packages/features/favorites/presentation/favorite_button.dart), [`FavoriteActionsSheet`](../../lib/packages/features/favorites/presentation/favorite_actions_sheet.dart) напрямую вызывают `requestSignIn` |

Скрытие гостевой кнопки карточки описано отдельным
[intent](hide-guest-favorite-login-button.md); перечисление потребителей не
расширяет его область. [`prototype/app.js`](../../prototype/app.js), функция
`login()`, тоже совмещает форму и гостевую кнопку: готового интро в референсе нет.

## Что важно сохранить

Сохранить существующие авторизацию, гостевой доступ и смысл действий,
для которых требуется вход. Разделение экранов не должно ломать переходы
из левого меню и других мест приложения.

По [Auth-контракту](../specs/01_authentication.md) проверка зеркала и restore
предшествуют выбору доступа; ошибка запуска не открывает гостевой каталог.
Отмена отправленного входа ждёт подтверждённой очистки сессии; при сбое форма
остаётся открытой для retry. Запрещённое аккаунтное действие после входа
автоматически не повторяется. Сохранить различие отказа credentials и сетевой
ошибки при очистке пароля.

Текущие положения спецификации о форме сразу после отсутствия/потери сессии
и гостевой кнопке внутри формы расходятся с согласованным намерением выше.

[Архитектура](../01_architecture_principles.md) оставляет доступ у Auth,
маршруты у App. Требования к фокусу и управлению задают
[ADR-0008](../adr/0008-youtube-tv-interaction-reference.md),
[TV](../specs/06_tv_interaction.md) и [mobile](../specs/10_mobile_interaction.md).
Внешний вид задан [визуальной системой](../specs/11_visual_system.md).
Generated routes не редактируются вручную по
[правилам](../03_codestyle_and_rules.md).

Текущие [`startup_test.dart`](../../test/packages/features/auth/startup_test.dart),
[`auth_test.dart`](../../test/packages/features/auth/auth_test.dart) и
[`guest_access_test.dart`](../../test/packages/features/auth/guest_access_test.dart)
покрывают restore, ошибки, гостевой выбор, отмену и expiry; widget-проверки ожидают
форму без интро. [`login_screen_golden_test.dart`](../../test/packages/features/auth/login_screen_golden_test.dart)
фиксирует совмещённый экран. Раздельные интро/форма и переходы ко всем
перечисленным потребителям пока не покрыты.
[Мобильный fixture E2E](../../integration_test/mobile_e2e_test.dart) проверяет
возврат к поиску после отмены; [`E2eHarness.login`](../../integration_test/support/e2e_harness.dart)
ожидает `login_submit` сразу после запуска. Это существующие зависимости
сценариев, а не свежие результаты прогонов; границы проверок заданы в
[руководстве](../05_development_and_testing.md).

## Что пока неясно

- Какой элемент получает фокус после возврата к экрану, открывшему форму,
  включая случай открытой панели действий?
- Как предоставить повтор очистки отменённого входа после ошибки, когда
  гостевой кнопки на форме больше нет? Сейчас это её дополнительная роль.
- После успешного входа сохранять нынешний переход на `/home` или возвращать
  исходный экран без автоматического повторения защищённого действия?
  Имена маршрутов и способ передачи такого адреса пока не определены.
