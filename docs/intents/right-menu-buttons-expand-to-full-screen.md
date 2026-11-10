# Баг: кнопки в правом меню растягиваются на весь экран

## Зачем

По наблюдению пользователя, в гостевом режиме после долгого нажатия на карточку
открывается меню справа. Кнопка «Войти и добавить в избранное» в этом меню
растягивается на весь экран вместо обычного размера кнопки.

## Чего хочу

- Разобраться в причине растягивания и исправить размер кнопки «Войти
  и добавить в избранное» в меню, открываемом долгим нажатием на карточку
  без авторизации.
- Кнопка должна оставаться обычной кнопкой внутри правой панели, с размером
  по её содержимому и оформлению, без растягивания на весь экран.
- Проверить кнопки во всех меню, открывающихся справа, и исправить аналогичное
  растягивание, если оно встречается в других действиях или состояниях.

## Что важно сохранить

Сохранить открытие меню долгим нажатием, назначение действий и существующий
сценарий входа для добавления в избранное. Исправление размеров не должно
мешать чтению текста, нажатию и управлению фокусом.

## Что пока неясно

Нужно подтвердить, в каких профилях интерфейса и правых меню воспроизводится
ошибка: пользователь сообщил о гостевом сценарии, остальные требуют проверки.

## Технический контекст

### Что подтверждено исходниками

- В [CatalogScreen._favoriteActions](../../lib/packages/features/catalog/presentation/screens/catalog_screen.dart)
  и результатах [SearchScreen](../../lib/packages/features/search/presentation/search_screen.dart)
  удержание карточки приводит к `showFavoriteActions` → `FavoriteActionsSheet` →
  `showAppActionSheet`. Проверять нужно общий сценарий, а не только главную.
- В гостевой ветке [FavoriteActionsSheet.build](../../lib/packages/features/favorites/presentation/favorite_actions_sheet.dart)
  (`!authAccess.canUseAccount`) `AppButton` передаётся непосредственно как
  `AppActionSheet.child`. Точная подпись сейчас — «Войти, чтобы добавить
  в избранное»; callback вызывает `AuthController.requestSignIn`.
  Ветка аккаунта помещает действие в `ListView`; загрузка, ошибка чтения,
  добавление, удаление и busy проходят через `_content` этого же виджета.
- [AppActionSheet.build / showAppActionSheet](../../lib/packages/ui_kit/lib/src/widgets/app_action_sheet.dart)
  выбирают по профилю устройства правую `TvSideSheet` либо нижнюю mobile-панель.
  Обе компоновки помещают `child` в `Expanded` внутри `Column`.
  [TvSideSheet.build](../../lib/packages/ui_kit/lib/src/widgets/tv_side_sheet.dart)
  задаёт панели всю доступную высоту и ширину `AppSizes.sideSheet` — 440 logical
  pixels. Полноэкранная высота самой TV-панели соответствует контракту.
- [AppButton.build](../../lib/packages/ui_kit/lib/src/widgets/app_button.dart)
  задаёт минимальную высоту 56 для TV / 48 для touch, но не ограничивает её
  сверху. `Row(mainAxisSize: MainAxisSize.min)` управляет шириной содержимого,
  а не отменяет ограничения высоты от родителя.

### Причина и границы уверенности

С высокой уверенностью по исходникам гостевую кнопку растягивает сочетание
прямого `AppButton` и `Expanded`: кнопка получает обязательную высоту всей
оставшейся области панели. У авторизованной ветки `ListView` оставляет высоту
кнопки содержимому. Та же цепочка ограничений есть в нижней mobile-панели;
это основание проверить её, но не подтверждение воспроизведения на телефоне.

Сообщение пользователя о растягивании «на весь экран» пока не уточнено снимком
или измерением. Код объясняет заполнение области панели по высоте, но не выход
TV-кнопки на всю ширину экрана. Реальное устройство, viewport и состояние
профиля остаются неизвестны. Фактический render layout в этой проработке
не измерялся; причина ещё требует воспроизведения. Выбор места исправления
в feature или общем компоненте здесь не фиксируется.

### Другие панели с тем же общим контейнером

Просмотрены production-вызовы `showAppActionSheet` / `showTvSideSheet`:

| Панель / действия | Компоновка содержимого | Наличие той же причины по исходникам |
| --- | --- | --- |
| [Избранное аккаунта](../../lib/packages/features/favorites/presentation/favorite_actions_sheet.dart): добавить, удалить, обновить статус, закрыть | `ListView` | Прямой передачи всей высоты кнопке нет |
| [CatalogSortSheet](../../lib/packages/features/catalog/presentation/widgets/catalog_sort_sheet.dart): варианты, применить, отмена | `SingleChildScrollView` → `Column` | Не обнаружено |
| [PlayerChoicesDialog](../../lib/packages/features/player/presentation/widgets/player_choices_dialog.dart): серии, качество | `ListView` с `TvChoiceTile` и `itemExtent` | Не обнаружено |
| [showAppConfirmation / _AppConfirmation](../../lib/app/app_confirmation.dart): выход из приложения, подтверждение выхода из аккаунта | `ListView` с двумя `AppButton` | Не обнаружено |
| [MobileHomeShell._account](../../lib/packages/features/home/presentation/mobile/mobile_home_shell.dart): выйти из аккаунта, открыть логи | `ListView` с `ListTile` | Не обнаружено; это mobile-панель |

Это ограниченная проверка общей причины, а не визуальное подтверждение всех
состояний. Других production-панелей с непосредственным `AppButton` в `child`
этого контейнера не найдено.

### Контракты и проверка гипотезы

Сохраняются [ADR-0008](../adr/0008-youtube-tv-interaction-reference.md),
[TV focus / удержание / возврат](../specs/06_tv_interaction.md),
[mobile-панели и доступность](../specs/10_mobile_interaction.md),
[визуальная геометрия](../specs/11_visual_system.md) и
[публичный контракт UI Kit](../../lib/packages/ui_kit/README.md).
Высоту нельзя фиксировать ценой обрезания длинной подписи или системного
увеличения текста. Требуемую ширину кнопки — по содержимому либо по доступной
ширине панели — ещё следует уточнить; источник дефекта указывает на высоту.
Вход и подтверждение изменения избранного сохраняют
[контракт избранного](../specs/02_favorites.md).

В [favorites_golden_test.dart](../../test/packages/features/favorites/favorites_golden_test.dart)
снимки правой панели на 960×540 и 1280×720 создаются только с
`AuthenticatedAccess`. В [favorites_test.dart](../../test/packages/features/favorites/favorites_test.dart)
есть отказы и подтверждённые изменения аккаунта, но нет проверки геометрии
гостевой панели.
[app_action_sheet_test.dart](../../test/packages/ui_kit/widgets/app_action_sheet_test.dart)
проверяет focus, закрытие и выбор mobile-панели; его TV-пример тоже передаёт
кнопку напрямую, но размеры не проверяет.
[app_button_test.dart](../../test/packages/ui_kit/widgets/app_button_test.dart)
покрывает busy, disabled и крупный текст, а не ограничения внутри панели.

Для подтверждения нужен гостевой сценарий с fake repository: открыть панель
удержанием, дождаться перехода и сравнить прямоугольники кнопки и области
содержимого. Кнопка должна оставаться внутри панели и занимать высоту текста,
отступов и платформенного минимума, а не весь оставшийся viewport. Значимы
TV 960×540 / 1280×720 и mobile portrait / короткий landscape с текстом 200%,
без overflow. Сопоставление с аккаунтной веткой отделит общий дефект контейнера
от ошибки гостевой композиции; focus, Back и вызов входа проверяются вместе
с геометрией.

Точечные существующие тесты запускаются командой
`fvm flutter test test/packages/features/favorites/favorites_test.dart test/packages/ui_kit/widgets/app_action_sheet_test.dart test/packages/ui_kit/widgets/app_button_test.dart --reporter=failures-only`.
Этот запуск сам по себе не закроет отсутствующую гостевую регрессию. В рамках
обогащения intent тесты, golden-обновления, live-сценарии и эмуляторы не запускались.
