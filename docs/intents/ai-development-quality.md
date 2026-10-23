# Качество разработки с ИИ: линтеры, тесты и DCM Free

## Зачем

Текущие правила Analyzer и DCM смешивают проверки корректности с правилами
стиля, которые могут заставлять разработчика или ИИ делать косметические
переписи и дробить код. При этом некоторые пользовательские сценарии и
адаптеры не имеют достаточных поведенческих проверок, а отчёты DCM Free
показывают сложные участки и несовпадения публичного API. Уровни HIGH и VERY
HIGH описывают метрики сложности и поддерживаемости. Отчёты не подтверждают
критические runtime-дефекты.

Нужно сохранить строгие проверки ошибок, типов, асинхронного кода, жизненного
цикла и архитектуры, закрывать значимые поведенческие пробелы и снижать риски
локальными изменениями. Цель — проверять поведение, а не добиваться процента
покрытия. Удобство чтения и ревью людьми остаётся важным. Влияние профиля lint
на скорость и качество разработки с ИИ пока не измерялось.

## Чего хочу

Этот intent объединяет предложения по профилю Analyzer и DCM, тестовому
покрытию и участкам, отмеченным отчётами DCM Free. Он фиксирует предложения и
сам по себе не разрешает внедрять настройки, тесты или изменения кода.

### Профиль Dart Analyzer и DCM

Согласовать профиль обычного Dart/Flutter Analyzer и DCM, который поощряет
полезные проверки и оставляет косметические или спорные изменения на усмотрение
автора.

В рамках уже сделанной настройки удалены только пять DCM Pro-параметров у
`avoid-non-null-assertion`, `double-literal-format`, `member-ordering`,
`prefer-extracting-callbacks` и `prefer-single-widget-per-file`; сами 77 Free
правил сохранены. Это выполненный контекст, а не новое обязательство изменения.

Для DCM предложены к отключению 13 правил:

| Приоритет | Правила |
| :--- | :--- |
| Сначала | `prefer-moving-to-variable`, `avoid-duplicate-test-assertions`, `prefer-single-widget-per-file`, `prefer-extracting-callbacks`, `avoid-empty-build-when`, `member-ordering`, `prefer-conditional-expressions`, `newline-before-return`, `avoid-returning-widgets` |
| Позже | `double-literal-format`, `binary-expression-operand-order`, `no-boolean-literal-compare`, `avoid-returning-value-from-cubit-methods` |

Отключение `no-boolean-literal-compare` предполагает сохранение обычного
Dart-правила `no_literal_bool_comparisons`; обе проверки совпадают для обычного
`bool`, а nullable-случай пропускают. `avoid-returning-value-from-cubit-methods`
избыточно только при сохранении `avoid-cubits`. `avoid-returning-widgets`
включено в предложение отключить глобальное требование: небольшой private
helper может быть короче отдельного класса. Это не подтверждает равную
производительность любых вариантов. Самостоятельные Widgets и владельцев State,
focus, controllers и lifecycle нужно сохранять там, где они нужны.
`prefer-match-file-name` остаётся на обсуждении.

Для DCM предложены к добавлению десять правил:
`avoid-assignments-as-conditions`, `avoid-conditions-with-boolean-literals`,
`avoid-casting-to-extension-type`, `avoid-empty-spread`,
`avoid-misused-set-literals`, `prefer-iterable-of`,
`prefer-correct-test-file-name`, `avoid-incorrect-image-opacity`,
`provide-image-semantic-label` и `prefer-immediate-return`. Последнее правило
может убрать локальную переменную, которая нужна только для немедленного
`return`; сохранять именованные snapshots, которые нужны далее.

Отдельно отложены `always-remove-listener`, `missing-test-assertion` и
`prefer-commenting-analyzer-ignores`. Для первого нужно проверить владение и
вызовы `dispose`; единичный пример не подтвердил утечку. Второе требует
распознавать assertion helpers. Третье частично пересекается с
`document_ignores`. Также отложены низкоприоритетные правила читаемости
`prefer-first`, `prefer-last` и `prefer-enums-by-name`. В предложениях не
возвращаются настройки правил, доступные только в DCM Pro.

Для Dart Analyzer предложены к отключению восемь правил:
`flutter_style_todos`, `prefer_foreach`, `require_trailing_commas`,
`use_late_for_private_fields_and_variables`,
`always_put_control_body_on_new_line`,
`curly_braces_in_flow_control_structures`,
`avoid_multiple_declarations_per_line` и `prefer_asserts_with_message`.
`prefer_expression_function_bodies`, `join_return_with_assignment` и
`cascade_invocations` предлагается сохранить: они могут убирать лишнюю
обвязку и повторение receiver. Не создавать каскад, если он меняет порядок
вычислений, `await` или nullable behavior. `omit_local_variable_types`
предлагается заменить на `omit_obvious_local_variable_types`: явный тип полезен
для сложного выражения, но не должен требоваться повсюду.

Также предлагается включить `unnecessary_this` и `prefer_int_literals`.
Первое удаляет только ненужный `this.`; сохранять его при shadowing и
initializing formals. Второе допускает `1` вместо `1.0` в контексте `double`,
но не изменение типа, например `var value = 1.0` на `var value = 1`.

Первыми предложены три новых Dart-правила: `no_dynamic_casts`, `switch_on_type`
и `unnecessary_ignore`. Кандидат `async_return_with_no_await` отложен до
отдельного разбора каждого срабатывания, обработки исключений, порядка
завершения операций и подтверждения регрессиями. Наличие срабатываний само по
себе не подтверждает ошибку; массовое автоисправление не входит в намерение.

Другие отложенные предложения для Dart:

- `unnecessary_unawaited` не добавлять ради косметики; сохранять существующие
  явные маркеры fire-and-forget.
- `specify_nonobvious_local_variable_types` не добавлять из-за широкого охвата.
- `use_primary_constructors`, `use_declaring_parameters` и
  `unnecessary_type_name_in_constructor` не вводить пакетом ради массовой смены
  синтаксиса.
- `unnecessary_async` не включать как экспериментальное правило.
- `no_raw_types` рассматривать как отдельную миграцию строгой проверки raw types,
  а не как вторую дублирующую проверку.
- `simple_directive_paths` оставить необязательной очисткой путей на будущее.

Также не предлагается включать `empty_container_bodies`,
`initialize_in_field_declaration`, `unnecessary_const_in_enum_constructor` и
`unnecessary_primary_constructor_body`. Это отложенные или не рекомендованные
добавления, а не запрет использовать соответствующий синтаксис.

Остаются выключенными `no-magic-number`, `prefer-static-class`,
`avoid-late-keyword`, `avoid-top-level-members-in-tests`, `avoid-substring`,
`prefer-async-await` и `avoid-nested-records`.
Предложения не требуют включать их: широкие запреты могут создавать шум или
мешать контекстным исключениям, а некоторые правила дублируют предпочитаемый
стиль либо навязывают форму без подтверждённой пользы.

### Сокращение синтаксической обвязки

Цель — сокращать ненужный код и контекст после форматирования, если это
сохраняет поведение и понятность. Меньше строк само по себе не гарантирует
меньше токенов; влияние профиля на скорость и качество работы ИИ не измерялось.
Dart formatter остаётся источником layout с `page_width: 120` и
default automatic trailing-comma management.

Общий критерий компактности кода и приоритетов анализа зафиксирован в
[ADR-0011](../adr/0011-compact-code-analysis-policy.md); конкретные предложения
этого intent остаются предложениями.

| Решение | Правила и границы |
| :--- | :--- |
| Разрешить короткий guard и однострочное тело | Предложить `always_put_control_body_on_new_line: false` и явный `curly_braces_in_flow_control_structures: false`. Последний lint наследуется также из `core.yaml`, поэтому нужно явное переопределение. `false` разрешает краткую запись, но не запрещает скобки. Сохранять блоки при нескольких statements, нужном scope и неоднозначном вложенном `if`/`else`. Пример: `if (!isReady) return;`. Для `if`/`else` formatter может оставить несколько строк. |
| Убрать обязательную пустую строку перед `return` | Отключить `newline-before-return`: это убирает lint-требование, а не лексические пробелы. Отключение не удаляет существующие пустые строки; доступного Free-правила, которое требует их удаления, нет. |
| Отдать запятые formatter | Предложить `require_trailing_commas: false`; не добавлять обратное правило, запрещающее запятые, и не менять ширину formatter ради искусственного сжатия. |
| Не требовать однотипных объявлений в отдельных строках | Предложить `avoid_multiple_declarations_per_line: false`. Не объединять разные обязанности и выражения с побочными эффектами автоматически. |
| Не требовать сообщения для каждого assert | Предложить `prefer_asserts_with_message: false`. Сохранять сами проверки, полезные сообщения, причины падения и пояснения тестов. |
| Сохранить правила для коротких выражений | Оставить `prefer_expression_function_bodies`, `join_return_with_assignment`, `cascade_invocations`, `prefer_if_elements_to_conditional_expressions`, `use_null_aware_elements`, `prefer_conditional_assignment`, `prefer_if_null_operators` и `use_super_parameters`. Например, `if (value == null) value = fallback;` может стать `value ??= fallback;`, а `value == null ? fallback : value` — `value ?? fallback`. `prefer_if_elements_to_conditional_expressions` упрощает сбор nullable-элементов, а `use_null_aware_elements` допускает краткую запись такого элемента. Forwarding constructor parameters могут использовать `super` parameters. Не менять вычисления и порядок побочных эффектов ради краткости. |
| Убирать только избыточный синтаксис | Сохранять `unnecessary_parenthesis`, `unnecessary_brace_in_string_interps`, `unnecessary_new`, `unnecessary_const` и `unnecessary_to_list_in_spreads`: например, `(value)` → `value`, `${name}` → `$name`, `new Child()` → `Child()`, `const child = const Child();` → `const child = Child()` и `...items.toList()` → `...items`. Скобки в `if (...)` обязательны; это не избыточные скобки выражения. |
| Не навязывать форму ternary или цикла | Оставить `prefer-conditional-expressions` в списке отключения: его вложенные ternary конфликтуют с `avoid-nested-conditional-expressions`, а Pro-настройка недоступна. Простой `?:` остаётся допустимым стилем. Также оставить `prefer_foreach` в списке отключения: замена цикла может изменить число вычислений receiver; не менять async loops, `break` или `continue`. |
| Сохранять полезный смысловой контекст | Не удалять assertions, сообщения, типы, keys, BLoC-контракты, lifecycle/resource guards или async safeguards ради символов. Не кэшировать повторное чтение состояния после `await` или пользовательского события без проверки контракта. |

У `always_put_control_body_on_new_line` и фигурных скобок нет доступного
обратного Free-правила, которое требует убрать перенос или скобки. Отключение
lint снимает требование, но не гарантирует обратный формат. Это согласуется с
[исключением для скобок](https://dart.dev/tools/linter-rules/curly_braces_in_flow_control_structures),
[правилом переноса control body](https://dart.dev/tools/linter-rules/always_put_control_body_on_new_line)
и [форматтером Dart](https://dart.dev/tools/dart-format).

При реализации intent сверить весь [Code Style](../03_codestyle_and_rules.md) с
итоговым согласованным профилем Analyzer/DCM и принципами
[ADR-0011](../adr/0011-compact-code-analysis-policy.md). Добавить только
практические соглашения, которых не хватает людям и ИИ. Проверить, например,
когда при выводе типа полезна явная аннотация, когда временная переменная
фиксирует смысловой snapshot изменяющегося состояния и где проходят границы
ответственности inline callback, helper и `Widget` с учётом lifecycle. Это
кандидаты для проверки, а не новые требования; сохранять полезные типы и
контракты. Зафиксировать только согласованные долговечные правила: принятый ADR
не означает, что внедрены все предложения по lint.

### Поведенческие проверки

В первую очередь проверять поведение, для которого сейчас нет достаточного
тестового подтверждения:

- **Поиск:** передачу запроса, страницы и отмены в `AnistarSearchRepository`,
  преобразование ответа, включая несовпадение номера страницы, пустой успешный
  ответ и ожидаемые и неожиданные ошибки. Текущие тесты HTML-клиента и BLoC не
  выполняют этот адаптер. См. [репозиторий поиска](../../lib/packages/features/search/data/anistar_search_repository.dart),
  [тесты HTML-клиента](../../test/infrastructure/anistar/anistar_search_test.dart)
  и [тесты экрана поиска](../../test/packages/features/search/presentation/search_screen_test.dart).
- **Просмотр логов:** загрузку, пустое состояние, выбор и содержимое файла,
  ошибки и повтор, обновление, прокрутку, dispose, Back и вызов системного
  share. Существующие тесты BLoC и файлового репозитория уже проверяют их
  контракты. Новые проверки должны дополнить их на уровне
  [виджета](../../lib/packages/features/log_viewer/presentation/widgets/log_viewer_view.dart),
  не дублируя [тесты BLoC](../../test/packages/features/log_viewer/presentation/bloc/log_viewer_bloc_test.dart)
  и [файлового репозитория](../../test/packages/features/log_viewer/file_log_repository_test.dart).
- **Хранилище настроек:** значения `bool`, `int`, `double`, `String` и
  `List<String>`, значение по умолчанию при несовпадении типа, неподдерживаемое
  значение и операции удаления, проверки наличия, очистки и повторной
  инициализации. Проверять обёртку через тестовое хранилище плагина в
  [SharedPreferencesStorage](../../infrastructure/storage/lib/src/shared_preferences_storage.dart),
  не считая это проверкой нативной записи на диск.
- **Запуск приложения:** успешные TV- и mobile-настройки ориентации и системного
  интерфейса, подготовку зависимостей и монтирование приложения на локальных
  подменах в [runner](../../lib/runner/runner.dart), без обращений к живому
  сайту. Существующий [direct test](../../test/runner/runner_test.dart)
  проверяет отказ при настройке ориентации. Успешный путь стоит проверять, если
  это возможно без нового production seam.

Затем дополнять поведенческие проверки поиска и экрана аниме: выбор и удаление
запроса, очистку всей истории, long press, фокус и remote-навигацию, завершение
загрузки, переходы к связанным частям и сериям, отмену и ошибку выхода, фокус
виртуализированных строк и устаревшие асинхронные ответы. Основной routed-путь
мобильной оболочки уже покрыт существующими тестами. Поиск и история уже имеют
golden-сценарии, а `test:coverage` исключает golden-тесты. Поэтому отсутствие
этих строк в LCOV не означает, что сценарии совсем не проверяются. Добавлять
поведенческие проверки ожидания и завершения загрузки, не копируя snapshots.
Условия тестовых наборов описаны в [Melos tooling](../melos_tooling.md).

Для сетевых повторов проверять успешный retry идемпотентного запроса, предел
попыток и отмену через локальный adapter. Существующие
[сетевые тесты](../../test/infrastructure/networking/network_clients_test.dart)
проверяют конфигурацию, интерцепторы, отключение retry и отсутствие повтора
для POST. Обработчики `AppBlocObserver` имеют меньший приоритет, чем
пользовательские сценарии и передача данных.

### Участки из отчётов DCM Free

Метрики DCM Free отмечают сложность или число параметров, а не подтверждённые
runtime-дефекты. Не ставить цель обнулить уровни HIGH/VERY HIGH, не менять
thresholds или exclusions ради результата и не превращать preview 22 метрик
или package-level DOT в оценку дефектов либо архитектурный вывод. Из 35
срабатываний 29 относятся к production, шесть — к integration tests; lint
analyze не обнаружил нарушений действующих 77 Free-правил. Эти результаты
объясняют контекст предложения, но не являются гарантией отсутствия ошибок.

1. **Сначала проверить поведение TV-навигации.** Для
   [`_AnimeScreenState._handleNavigation`](../../lib/packages/features/anime/presentation/screens/anime_screen.dart)
   и [`CatalogScreenState._onCatalogStateChanged`](../../lib/packages/features/catalog/presentation/screens/catalog_screen.dart)
   сначала дополнить отсутствующие сценарии из раздела
   [поведенческих проверок](#поведенческие-проверки), затем рассматривать
   локальное упрощение, если оно помогает сопровождению. Разделение выбора
   цели и применения focus/scroll — кандидат, а не требование создавать новые
   классы или методы. Сохранять порядок событий и guards, `KeyDown`,
   `KeyRepeat`, `KeyUp`, границы и неполные ряды, возврат focus, `mounted`,
   текущий route и generation safeguards по
   [TV-контракту](../specs/06_tv_interaction.md) и [ADR-0008](../adr/0008-youtube-tv-interaction-reference.md).

2. **Упростить сетевой и HTML-разбор только при реальной пользе.** Для
   [`HtmlAnistarClient._safe`](../../infrastructure/anistar/lib/src/html_anistar_client.dart),
   [`AnistarSearchHtml.form`](../../infrastructure/anistar/lib/src/anistar_search_html.dart),
   [`AnistarSearchSource.search`](../../infrastructure/anistar/lib/src/anistar_search_source.dart)
   и [`AnistarHtmlParser._parts`](../../infrastructure/anistar/lib/src/anistar_html_parser.dart)
   можно рассмотреть небольшие функции, которые устраняют дублирование или
   упрощают ветвления. Для `form` отдельно учитывать оба срабатывания: сложность
   и пять параметров. Не вводить wrapper только ради порога параметров.
   Сохранять категории и сообщения ошибок, `stackTrace`, различение ожидаемых
   и неожиданных ошибок, отмену, HTTPS и same-origin, отсутствие повторов POST,
   сокрытие credentials/HTML/signed URL, а также обработку формы, action и
   charset. Использовать существующие fixtures и
   [тесты ошибок клиента](../../test/infrastructure/anistar/anistar_client_errors_test.dart),
   [тесты клиента](../../test/infrastructure/anistar/anistar_client_test.dart)
   и [тесты поиска](../../test/infrastructure/anistar/anistar_search_test.dart).

3. **Сделать API экспортов минимально полным.** Для `ParsedEpisode` проверить
   достаточность [`parsing.dart`](../../infrastructure/anistar/lib/parsing.dart)
   как отдельного parser entrypoint; тип содержит HTML mutation metadata и не
   должен попадать в общий `anistar.dart` или transport-independent API. Для
   FlutterGen проверить четыре конкретных типа, используемых через
   [`assets.dart`](../../lib/packages/ui_kit/lib/assets.dart):
   `$AssetsFontsGen`, `$AssetsIconsGen`, `$AssetsImagesGen` и
   `AssetGenImageAnimation`. Добавлять их только через поддерживаемый barrel
   или генератор. Изменение генератора допустимо лишь при понятном поддерживаемом
   API; generated source вручную не редактировать.

4. **Рассматривать остальные complexity findings по месту.** Изменять эти
   участки только при понятной пользе для чтения, сопровождения или проверки
   поведения:

   - Anime: `_AnimeScreenState._buildFuture`, `AnimeHero.build` и
     `_MobileAnimeContentState.build` —
     [`anime_screen.dart`](../../lib/packages/features/anime/presentation/screens/anime_screen.dart),
     [`anime_hero.dart`](../../lib/packages/features/anime/presentation/widgets/anime_hero.dart)
     и [`mobile_anime_content.dart`](../../lib/packages/features/anime/presentation/widgets/mobile_anime_content.dart).
   - Auth и Catalog: `_LoginScreenState.build`, `CatalogBloc._onStarted`,
     `CatalogScreenState._buildState` и `CatalogScreenState.build` —
     [`login_screen.dart`](../../lib/packages/features/auth/presentation/login_screen.dart),
     [`catalog_bloc.dart`](../../lib/packages/features/catalog/presentation/bloc/catalog_bloc.dart)
     и [`catalog_screen.dart`](../../lib/packages/features/catalog/presentation/screens/catalog_screen.dart).
   - Остальная навигация и оболочки: `GenresScreenState._navigate`,
     `_MobileHomeShellState.build` и `_PlayerOverlayState._handleNavigation` —
     [`genres_screen.dart`](../../lib/packages/features/catalog/presentation/screens/genres_screen.dart),
     [`mobile_home_shell.dart`](../../lib/packages/features/home/presentation/mobile/mobile_home_shell.dart)
     и [`player_overlay.dart`](../../lib/packages/features/player/presentation/widgets/player_overlay.dart).
   - Поиск и UI Kit: `SearchScreenState._formKey`, `AppTheme._createTheme` и
     `AppNetworkImage.build` —
     [`search_screen.dart`](../../lib/packages/features/search/presentation/search_screen.dart),
     [`app_theme.dart`](../../lib/packages/ui_kit/lib/src/theme/app_theme.dart)
     и [`app_network_image.dart`](../../lib/packages/ui_kit/lib/src/widgets/app_network_image.dart).

   Для `AppIconType.fromMaterial` в
   [`app_icon.dart`](../../lib/packages/ui_kit/lib/src/widgets/app_icon.dart)
   оставить явный switch-справочник совместимости `IconData` и `AppIconType`.
   Не переписывать его ради CYCLO. В `AnimeHero`, мобильных карточках и других
   UI/build-методах выделять части только при отдельной ответственности и
   понятном владельце State, focus или controller. Не дробить UI ради метрики.

5. **Сохранить ясные сигнатуры.** Не упаковывать параметры в config-объекты
   только ради порога 4. Это относится к `AnistarAuthService._signIn` и
   `AnistarAuthService._page` в
   [`anistar_auth_service.dart`](../../infrastructure/anistar/lib/src/anistar_auth_service.dart),
   `AnistarSearchHtml.form` в
   [`anistar_search_html.dart`](../../infrastructure/anistar/lib/src/anistar_search_html.dart),
   `E2eHarness.configure`, `E2eHarness.launch` и `E2eHarness.waitFor` в
   [`e2e_harness.dart`](../../integration_test/support/e2e_harness.dart),
   `RemoteControls.activate` в
   [`remote_controls.dart`](../../integration_test/support/remote_controls.dart),
   `showAppConfirmation` в
   [`app_confirmation.dart`](../../lib/app/app_confirmation.dart),
   `createAppOverrides` в [`app_container.dart`](../../lib/app/app_container.dart),
   `_openEpisode` в [`app_routes.dart`](../../lib/app/app_routes.dart),
   `SearchScreenState._cardFocused` в
   [`search_screen.dart`](../../lib/packages/features/search/presentation/search_screen.dart),
   `AppFocusStyle.decoration` в
   [`app_focus_style.dart`](../../lib/packages/ui_kit/lib/src/theme/app_focus_style.dart)
   и `MediaCard._textHeight` в
   [`media_card.dart`](../../lib/packages/ui_kit/lib/src/widgets/media_card.dart).
   Менять сигнатуру, только если найден более ясный контракт или повторно
   используемая группа параметров.

6. **Относиться к сложности E2E как к отдельной уборке тестов.** В
   [`app_e2e_test.dart`](../../integration_test/app_e2e_test.dart) и
   [`mobile_e2e_test.dart`](../../integration_test/mobile_e2e_test.dart)
   допустимо отдельно рассмотреть группировку сценариев при сохранении всех
   assertions и сценариев. Высокая сложность `main` не является runtime-багом
   приложения и не делает это первым приоритетом.

7. **Уточнить судьбу неиспользуемых файлов.** Для
   [`AnimeMetadataChip`](../../lib/packages/features/anime/presentation/widgets/anime_metadata_chip.dart)
   и [`FavoriteRibbon`](../../lib/packages/features/catalog/presentation/widgets/favorite_ribbon.dart)
   проверить ссылки, продуктовый смысл и запланированных потребителей. Удалять
   только после подтверждения, что компоненты больше не нужны. Сохранить
   [`parsing.dart`](../../infrastructure/anistar/lib/parsing.dart): это
   документированная parser-библиотека, используемая тестами; test-only
   использование не является основанием для удаления.

Проверка exports и unused-files — подсказка к полноте API и потребителям, а не
свидетельство runtime-сбоя. `check-unused-l10n` неприменим без подходящего
localization class; package-level DOT остаётся картой связей с ограниченными
выводами. Эти проверки не создают самостоятельную работу по изменению
локализации или архитектуры.

Сохранять реализацию только при конкретной пользе для упрощения, исправления
дефекта или полноты API и подтверждённом сохранении поведения. Будущую работу
проверять подходящими регрессиями и проектными gates из
[Melos tooling](../melos_tooling.md): `check` → fixture `test:e2e` →
`build:android:prod:apk`. Нулевые HIGH не являются критерием приёмки.

## Что важно сохранить

- Строгие проверки типов `strict-casts`, `strict-inference` и
  `strict-raw-types`, а также `avoid-dynamic` и `avoid_dynamic_calls`.
- Проверки асинхронных операций `unawaited_futures` и `discarded_futures`,
  контекста Flutter `use_build_context_synchronously`, подписок и ресурсов
  `cancel_subscriptions` и `close_sinks`.
- `document_ignores` и действующую политику `cannot-ignore`. Вместе с отключением
  DCM-правила удалять его подавления. Отдельно проверять и удалять устаревшие
  или неэффективные ignore, даже если правило остаётся включённым. Сохранять
  повторные `expect` и повторное чтение состояния после `await` или
  пользовательских событий.
- BLoC ownership, неизменяемость и sealed-типы событий и состояний, обработку
  событий, архитектурные границы, Flutter render/lifecycle, доступность,
  утверждения в тестах и повторное чтение состояния.
- Остальные действующие правила DCM, в том числе правила, ориентированные на
  людей или пока не имеющие срабатываний. Повторные `true`, уже унаследованные
  из `flutter_lints` или `lints`, можно убрать при сохранении resolved rules и
  закреплённых версий. Не терять overrides со значением `false` и настройки
  severity или `cannot-ignore`.
- Не переписывать автоматически позднюю инициализацию, callbacks, `buildWhen`
  или раскладку виджетов/файлов только из-за удаления lint.
- Повторно использовать существующие тесты BLoC и файлового репозитория. Для
  поиска и истории расширять поведенческие тесты, не копировать golden-снимки.
- Для тестов сети использовать публичный `DioClient` и локальный adapter. Не
  проверять private evaluator, не обращаться к реальной сети и не полагаться
  на реальные задержки retry.
- Не менять exclusions, thresholds или golden-эталоны ради покрытия. Не
  вводить цель 100%: line coverage не подтверждает качество assertions, branch
  coverage, native-поведение или полноту E2E.
- Отсутствие файла в LCOV без executable-line denominator само по себе не
  означает пробел. Barrels, интерфейсы, enum/typedef/constant-модели, entry
  points и пустой `RouteObserver` не требуют тестов только ради метрики.
  Нулевой hit у `AuthInvalidCredentialsFailure` также не доказывает пробел:
  существующие auth-тесты проверяют сообщение и фокус при этой ошибке.
- Сначала выяснить, нужны ли ещё `AnimeMetadataChip` и `FavoriteRibbon`, у
  которых не найдено ссылок за пределами объявлений. Этот intent не разрешает
  удаление кода.
- TV-навигация должна сохранить порядок обработки событий и проверок,
  `KeyDown`/`KeyRepeat`/`KeyUp`, границы и частичные ряды, возврат к прежнему
  focus, а также `mounted`, текущий route и generation safeguards по
  [контракту взаимодействия TV](../specs/06_tv_interaction.md) и
  [ADR-0008](../adr/0008-youtube-tv-interaction-reference.md). Не вводить общий
  navigation framework.
- Обработка ошибок должна сохранять `stackTrace`, различать ожидаемые и
  неожиданные ошибки, сохранять отмену, проверять HTTPS и same-origin, не
  повторять POST и не записывать credentials, HTML или signed URL в логи.
  Основой регрессий служат существующие
  [тесты ошибок клиента](../../test/infrastructure/anistar/anistar_client_errors_test.dart),
  [тесты клиента](../../test/infrastructure/anistar/anistar_client_test.dart)
  и [тесты поиска](../../test/infrastructure/anistar/anistar_search_test.dart).
- Не экспортировать HTML mutation metadata через общий `anistar.dart` и не
  редактировать generated code вручную. `parsing.dart` — документированная
  библиотека parser tests; её test-only использование не является основанием
  для удаления.
- Не включать все метрики и не менять thresholds или exclusions ради отчёта.
  Не переписывать таблицу совместимости `AppIconType.fromMaterial` и не
  упаковывать named parameters в фиктивные config-объекты только ради порога.
  Сложность integration-тестов рассматривать отдельно от runtime-кода и не
  удалять assertions ради снижения метрики.
- Структурный DOT использовать только как карту связей. Результат проверки
  l10n считать неприменимым: сейчас нет подходящего класса локализации для
  проверки.

Текущие ограничения и пояснения к профилю собраны в
[правилах кода](../03_codestyle_and_rules.md),
[архитектурных принципах](../01_architecture_principles.md) и
[Melos tooling](../melos_tooling.md). Правила Analyzer и DCM находятся в
[analysis_options.yaml](../../analysis_options.yaml); версия DCM закреплена в
[dcm_global.yaml](../../dcm_global.yaml).

## Что пока неясно

- Какие срабатывания `async_return_with_no_await` требуют изменения поведения,
  а какие намеренно сохраняют порядок операций или обработку ошибок?
- Подтвердят ли регрессионные проверки безопасность любого изменения после
  анализа async-срабатываний?
- Оставить ли `prefer-match-file-name` включённым после отдельного обсуждения?
- Как оценивать удобство чтения и ревью людьми после изменения профиля?
  Влияние на скорость и качество разработки с ИИ пока неизвестно.
- Можно ли проверить успешный запуск с локальными подменами через существующие
  seams или для этого потребуется отдельный production seam?
- Используется ли альтернативная, не routed-ветка `MobileHomeShell`? Это нужно
  выяснить до добавления для неё отдельного набора поведенческих проверок.
- Проверка вызова share через platform fake подтвердит вызов плагина. Для
  проверки системного диалога или поведения ОС нужен отдельный уровень теста.
- Какие локальные изменения упростят навигацию и обработку сетевых/HTML-ветвей,
  сохранив зафиксированные контракты?
- Какой минимальный публичный API нужен для `ParsedEpisode` и четырёх типов
  FlutterGen, и поддерживает ли его текущий barrel или генератор?
- Нужны ли `AnimeMetadataChip` и `FavoriteRibbon` продукту или их следует
  удалить в отдельной работе?
