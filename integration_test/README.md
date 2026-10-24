# Интеграционные наборы Android и iOS Simulator | AniStar TV

TV- и mobile-наборы проверяют важные пользовательские сценарии на Android с локальными HTTP/HLS fixtures. Отдельный опциональный набор проверяет iOS runner на выбранном Simulator. Эти наборы дополняют unit/widget-проверки и не заменяют их.

## Наборы и entry points

| Набор | Entry point | Назначение |
| --- | --- | --- |
| TV fixtures | `app_e2e_test.dart` | Пульт, focus, удержание кнопок, боковые панели и native playback на Android TV |
| Mobile fixtures | `mobile_e2e_test.dart` | Touch, ввод в Flutter-поля, вкладки и панели, scroll/pull refresh, Back, поворот Android, native playback, сессия и восстановление ошибок |
| iOS fixtures | `ios_e2e_test.dart` | Запускает общие touch-сценарии на iPhone Simulator через native player/storage; результаты появятся только после отдельного запуска |
| TV live | `direct_android_test.dart` | Явно запускаемая проверка реального сайта и CDN с тестовым аккаунтом |
| Сеть и вход | `network_smoke_test.dart` | Явно запускаемая live-проверка сети и входа без изменения избранного |
| TV motion | `navigation_motion_test.dart` | Отдельная проверка нативного renderer TV-переходов |

Entry points fixture-наборов запускаются через скрипты из [`tool/e2e`](../tool/e2e/README.md#запуск-runners). Там описаны AVD, команды, предварительные проверки, side effects, cleanup и отчёты. Live-процедура и её ограничения приведены в [руководстве по разработке и тестированию](../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

Общие fixtures, transport и storage используют harness из `support/e2e_harness.dart`. Touch helpers находятся в `support/mobile_controls.dart`, remote helpers — в `support/remote_controls.dart`. Runner определяет системный профиль нативно и использует фактический viewport. Наборы не принуждают UI к TV/mobile-профилю или искусственному размеру.

## Стратегия и покрытие

Подход сверен с официальной документацией Flutter 11.10.2026. Flutter рекомендует много быстрых unit/widget-тестов и достаточное число интеграционных проверок важных пользовательских сценариев: последние медленнее и дороже в сопровождении. Таблица показывает границы наборов, а не требование переносить каждую widget-проверку на Android. [Рекомендации Flutter](https://docs.flutter.dev/testing/overview), [integration_test](https://docs.flutter.dev/testing/integration-tests).

| Область | TV fixtures: 14 сценариев | Mobile fixtures: 9 сценариев | Что проверять на нижнем уровне |
| --- | --- | --- | --- |
| Вход и сессия | Пульт, отказ входа, encrypted restore после нового клиента, expiry, logout | Touch и ввод в Flutter-поля, отказ входа, restore, expiry, logout | Валидация полей, состояния auth, parser/cookies |
| Гость и отправленный поиск (HTTP fixtures) | Выбор гостя пультом, submit через IME, выдача → detail/native playback, Back восстанавливает запрос и результаты, отмена входа сохраняет гостевой контекст; нет account mutations | Выбор гостя касанием, submit кнопкой, выдача → detail/native playback, Back восстанавливает запрос и результаты, отмена входа сохраняет гостевой контекст; нет account mutations | Parser/source протокол, сохранение маршрута и выдачи, auth/capability gates |
| Каталог и маршруты | D-pad, focus restore, pagination, scroll, Back | Scroll, скрытие шапки, сохранение позиции вкладки и Back. Pull refresh главной сохраняет карточки при отказе сети. Также проверяется pull refresh пустого/заполненного избранного и деталей/серий. | Геометрия, размеры, text scaling, golden, жесты, ожидание запроса, повтор, гонка пагинации и локальные переходы |
| Жанры и сортировка | Фильтр из жанров и metadata, paginated request, отмена draft | Touch sheets, применение и отмена draft | Все варианты сортировки/фильтров, reducer и repository |
| Избранное | Серверная мутация, новый клиент, отказ и explicit retry, удаление и empty state | Touch mutation, отказ/recovery, удаление и empty-state return | Все состояния кнопок/панелей и ошибки repository |
| Плеер | Native HLS 720/360, HTTP headers, seek/hold release, pause, выбор качества/серии, Back, watched state | Native HLS, drag по timeline, Back отменяет quality sheet, смена качества/серии, реальный поворот Android, Back | Комбинации controls, disabled states, layout и ускоренные state transitions |
| Жизненный цикл | Playback/background/resume/completion и настоящий Android screen flag, повторный вход/выход | Playback/background/resume и screen flag, dispose после Back | Retention paused state, intent и lifecycle logic |
| Восстановление | Catalog retry, единственный refresh expired HLS, остановка automatic retry loop | Touch catalog retry и остановка native retry loop | Все transport/parser/retry edge cases |

Совпадение областей на двух платформах намеренное. Touch и D-pad проходят через разные интерфейсы и маршруты фокуса. Widget-окружение само по себе не подтверждает работу native video, secure storage, HTTP headers и renderer. `navigation_motion_test.dart` дополняет widget-проверки Android decoder/renderer. Live-наборы проверяют совместимость с внешним сайтом и не заменяют детерминированные fixtures.

Android TV/mobile входят в обязательный `test:e2e`. iOS fixture E2E запускается отдельно командой `fvm dart run melos run test:e2e:ios -- <simulator-UDID> <dev|prod> [mobile|tv]`; flavor обязателен, профиль по умолчанию — `mobile`. В профиле `mobile` runner вызывает общие touch-сценарии с native storage/player, без Flutter fakes. Успешная сборка не подтверждает их выполнение: пока E2E не запускался, результаты для iOS runtime, Keychain и HLS не заявляются.

Для локальной диагностики задайте отдельному runner-у `--plain-name` или
`--name`. Прямой Bash вызов сохраняет исходные аргументы. Через Melos задайте
`ANISTAR_TEST_SELECTORS_JSON` как непустой JSON-массив селектора и его значения,
например `["--plain-name","search submits"]`. Melos 7.8.1 не сохраняет границы
аргументов с пробелами при передаче через shell. Фильтр помечает отчёт как
`scope=filtered`; успешный результат — `PARTIAL PASS`. Он не заменяет полный
`fvm dart run melos run test:e2e`, который последовательно запускает оба набора
без фильтра. Параметры runners и структуру отчётов см. в
[E2E tooling](../tool/e2e/README.md#запуск-runners) и
[руководстве по разработке и тестированию](../docs/05_development_and_testing.md#5-интеграционные-тесты-android-tv-и-телефона).

Опциональный `tv` запускает только компоновочную диагностику на выбранном iPad Simulator. Runner задаёт TV profile через test-only define; производственное приложение не выбирает TV по ширине. Эта проверка не подтверждает поддержку iPad, tvOS или Apple TV remote.

Четыре ранее известные TV golden-регрессии находятся в отдельном наборе. Во время E2E-аудита не исправляйте их обновлением эталонов.

## Правила новых сценариев

1. Добавлять E2E для важного пути через несколько подсистем или для риска на границе с Android. Локальную вариацию виджета добавлять в `test/`. Для нового E2E указывать, какую дополнительную уверенность он даёт.
2. Начинать fixture-сценарий с `configure(reset: true)` и fresh launch. Сохранение сессии/повторный клиент разрешены внутри сценария, который именно это проверяет. Не рассчитывать на результат предыдущего теста.
3. Регистрировать fixture/live journeys через `E2eHarness.testCase`: приложение unmount, lifecycle, orientation и system UI восстанавливаются в `finally` внутри тела теста. Обычный `tearDown` не подходит для pumping после завершения тела. Закрывать независимые fixture/live клиенты через `addTearDown` либо `try/finally`.
4. В TV-проверках взаимодействия использовать D-pad/Select/Back и проверять фактический focus до активации. Не назначать focus программно и не заменять пульт tap. На телефоне использовать настоящие tap/drag/IME. Не вызывать callbacks виджетов напрямую. Ввод текста через `enterText` остаётся тестовой подготовкой и не проверяет Android-клавиатуру.
5. Для действия использовать стабильный key либо явную семантику/focus label. Текст допустим для проверки пользовательского результата и выбора fixture-значения при фиксированной локали.
6. Ожидать конкретное состояние через bounded `waitFor`. Framework exception должна завершать ожидание сразу. В таймауте указывать шаг и полезную диагностику. При `paused` кадры отключены. В таком состоянии native controller/channel проверять bounded polling без `pump`. `resumed` восстанавливать в `finally` до любого frame-based ожидания или unmount. Оставлять временное окно только для проверки отсутствия retry-loop, удержания кнопки, idle controls или остановки видео. В этих проверках время является предметом проверки.
7. Не применять `pumpAndSettle` ко всему приложению с video/loading-анимациями. Этот метод ждёт окончания всех кадров и может зависеть от бесконечной анимации. Flutter рекомендует понимать, какие кадры нужны. [Документация API](https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html).
8. Проверять результат действия. Проверять состояние UI вместе с controller/fixture request/state там, где это подтверждает работу нескольких подсистем. Не ограничиваться наличием текста и не требовать точного времени playback на эмуляторе. Использовать обоснованный допуск.
9. Не лечить flaky test автоматическим повторным запуском или увеличением всех задержек. Сохранять seed и артефакты первого падения. Исправлять finder, ожидание либо product defect. Пример запуска с другим seed приведён в [руководстве runners](../tool/e2e/README.md#e2e-reports).
10. Проверять платформы на разных AVD и сохранять результат каждого набора. Отсутствие завершённых native events означает ошибку. Успешная сборка APK сама по себе не означает успешный E2E. Последовательность запуска и обработка сбоя описаны в [руководстве runners](../tool/e2e/README.md#запуск-runners).

## Границы текущих проверок

Основной Android набор использует один существующий телефон и один Android TV AVD с реальным системным профилем и viewport. Отдельный iOS запуск использует один уже booted Simulator и выбранный flavor. Ни один набор не является матрицей всех устройств и версий ОС. Более узкие/широкие экраны и масштаб текста покрываются widget/golden-тестами.

Lifecycle в сценарии подаётся через Flutter binding. Player и Android screen flag при этом настоящие.

Видимость системной клавиатуры Search проверяет host-side ADB oracle, подключённый только к TV fixture runner. Fixture server публикует его очищенный снимок через `GET /__test/native-ime`: `available`, `querySucceeded`, `status` (`visible`, `hidden`, `transition`, `error` или `unavailable`) и `currentEditorMatches`. Host читает `dumpsys input_method` и полный `dumpsys window`, который содержит global focus и InputMethod window; снимок не содержит сырой вывод. Ожидание завершается ошибкой при недоступном или ошибочном снимке. Состояние `visible` принимается для текущего редактора AniStar, а `hidden` проверяет скрытое состояние.

Flutter `viewInsets` и `MediaQuery.viewInsets` не являются oracle для TV IME: оба могут оставаться нулевыми при видимой нативной клавиатуре. Вызов или mock `TextInput.show` также не доказывает видимость. Проверка опирается на состояние нативных окон ОС.

Этот набор не подтверждает нажатие системного Home, process death или permission dialogs. `integration_test` ограничен при взаимодействии с native UI. Если появится такое требование, нужен отдельный native driver/набор. Flutter finder не подтверждает такое покрытие. [Ограничения Flutter](https://docs.flutter.dev/testing/overview).

## Навигация

[Запуск runners, fixtures и отчёты](../tool/e2e/README.md), [команды и полный контекст проверки](../docs/05_development_and_testing.md#5-интеграционные-тесты-android-tv-и-телефона).
