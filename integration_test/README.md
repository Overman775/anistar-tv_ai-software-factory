# Интеграционные наборы Android

| Набор | Entry point | Команда | Существующий AVD по умолчанию |
| --- | --- | --- | --- |
| TV fixtures | `app_e2e_test.dart` | `bash scripts/e2e-tv.sh` | `anistar_tv_e2e` |
| Mobile fixtures | `mobile_e2e_test.dart` | `bash scripts/e2e-mobile.sh` | `anistar_mobile_e2e` |
| Обе платформы последовательно | Оба entry point | `bash scripts/e2e-all.sh` | Два разных AVD |

Команды выполняются из корня проекта. Выбор идёт по имени запущенного AVD; `ANISTAR_TV_AVD` и `ANISTAR_MOBILE_AVD` позволяют выбрать другие существующие конфигурации. Явный ID передаётся аргументом, например `bash scripts/e2e-mobile.sh emulator-5554`. Проверяются готовность Android и настоящий системный профиль, а для TV — hardware D-pad. Runtime runner сам определяет профиль и размер экрана.

TV-сценарии проверяют пульт, фокус, удержание кнопок, боковые панели и native playback. Mobile-сценарии проверяют touch и ввод в Flutter-поля, нижние вкладки и панели, scroll/pull refresh, Back, реальный поворот Android, native playback, сессию и восстановление ошибок. Каждый случай получает отдельное состояние loopback HTTPS fixture. Общие сетевые/сессионные helpers находятся в `support/e2e_harness.dart`, способы ввода — в `support/remote_controls.dart` и `support/mobile_controls.dart`.

Основной запуск через scripts включает локальный server, adb reverse, отчёты, SDK/lockfile preflight и cleanup. В корне также находятся отдельно запускаемые диагностические entry points: `direct_android_test.dart` — TV live (`bash scripts/e2e-tv.sh live`), `network_smoke_test.dart` — live сеть/вход без изменения избранного, `navigation_motion_test.dart` — нативный renderer TV-переходов. Live требует локальных credentials и не входит в общий offline-прогон.

Отчёты каждой платформы и общего запуска: `build/e2e/…/summary.json`, `junit.xml`, Flutter JSON events, Flutter/Android/HTTP logs. Ошибка первой платформы сохраняется, после неё выполняется вторая. Отсутствующие/оборванные native events не дают успешный отчёт.

[Подробные команды и сценарии](../docs/05_development_and_testing.md#5-интеграционные-тесты-android-tv-и-телефона), [fixtures и отчёты](../tool/e2e/README.md).

## Стратегия и покрытие

Подход сверен с официальной документацией Flutter 11.10.2026. Flutter рекомендует много быстрых unit/widget-тестов и достаточное число интеграционных проверок важных пользовательских сценариев: последние медленнее и дороже в сопровождении. Поэтому ниже перечислены границы наборов, а не требование переносить каждую widget-проверку на Android. [Рекомендации Flutter](https://docs.flutter.dev/testing/overview), [integration_test](https://docs.flutter.dev/testing/integration-tests).

| Область | TV fixtures: 13 сценариев | Mobile fixtures: 8 сценариев | Что проверять на нижнем уровне |
| --- | --- | --- | --- |
| Вход и сессия | Пульт, отказ входа, encrypted restore после нового клиента, expiry, logout | Touch и ввод в Flutter-поля, отказ входа, restore, expiry, logout | Валидация полей, состояния auth, parser/cookies |
| Каталог и маршруты | D-pad, focus restore, pagination, scroll, Back | Scroll, скрытие шапки, сохранение позиции вкладки, Back; pull refresh главной с сохранением карточек при отказе сети, пустого/заполненного избранного и деталей/серий | Геометрия, размеры, text scaling, golden, жесты, ожидание запроса, повтор, гонка пагинации и локальные переходы |
| Жанры и сортировка | Фильтр из жанров и metadata, paginated request, отмена draft | Touch sheets, применение и отмена draft | Все варианты сортировки/фильтров, reducer и repository |
| Избранное | Серверная мутация, новый клиент, отказ и explicit retry, удаление и empty state | Touch mutation, отказ/recovery, удаление и empty-state return | Все состояния кнопок/панелей и ошибки repository |
| Плеер | Native HLS 720/360, HTTP headers, seek/hold release, pause, выбор качества/серии, Back, watched state | Native HLS, drag по timeline, Back отменяет quality sheet, смена качества/серии, реальный поворот Android, Back | Комбинации controls, disabled states, layout и ускоренные state transitions |
| Жизненный цикл | Playback/background/resume/completion и настоящий Android screen flag, повторный вход/выход | Playback/background/resume и screen flag, dispose после Back | Retention paused state, intent и lifecycle logic |
| Восстановление | Catalog retry, единственный refresh expired HLS, остановка automatic retry loop | Touch catalog retry и остановка native retry loop | Все transport/parser/retry edge cases |

Совпадение областей на двух платформах намеренное: touch и D-pad проходят через разные интерфейсы и маршруты фокуса. Native video, secure storage, HTTP headers и renderer нельзя подтвердить только подменённым widget-окружением. Отдельный `navigation_motion_test.dart` дополняет widget-проверки Android decoder/renderer; live-наборы проверяют совместимость с внешним сайтом и не заменяют детерминированные fixtures.

## Правила новых сценариев

1. Добавлять E2E для важного пути через несколько подсистем или для риска на границе с Android. Локальную вариацию виджета добавлять в `test/`; новый E2E должен объяснять, какую дополнительную уверенность он даёт.
2. Начинать fixture-сценарий с `configure(reset: true)` и fresh launch. Сохранение сессии/повторный клиент разрешены внутри сценария, который именно это проверяет. Не рассчитывать на результат предыдущего теста.
3. Регистрировать fixture/live journeys через `E2eHarness.testCase`: приложение unmount, lifecycle, orientation и system UI восстанавливаются в `finally` внутри тела теста. Обычный `tearDown` не подходит для pumping после завершения тела. Закрывать независимые fixture/live клиенты через `addTearDown` либо `try/finally`.
4. В TV-проверках взаимодействия использовать D-pad/Select/Back и проверять фактический focus до активации. Не назначать focus программно и не заменять пульт tap. На телефоне использовать настоящие tap/drag/IME; не вызывать callbacks виджетов напрямую. Ввод текста через `enterText` остаётся тестовой подготовкой, а не проверкой Android-клавиатуры.
5. Для действия использовать стабильный key либо явную семантику/focus label. Текст допустим для проверки пользовательского результата и выбора fixture-значения при фиксированной локали.
6. Ожидать конкретное состояние через bounded `waitFor`; framework exception должна завершать ожидание сразу. В таймауте указывать шаг и полезную диагностику. При `paused` кадры отключены: native controller/channel проверять bounded polling без `pump`, а `resumed` восстанавливать в `finally` до любого frame-based ожидания или unmount. Временное окно оставлять для проверки отсутствия retry-loop, удержания кнопки, idle controls или остановки видео — там время является предметом проверки.
7. Не применять `pumpAndSettle` ко всему приложению с video/loading-анимациями. Этот метод ждёт окончания всех кадров и может зависеть от бесконечной анимации; Flutter рекомендует понимать, какие кадры нужны. [Документация API](https://api.flutter.dev/flutter/flutter_test/WidgetTester/pumpAndSettle.html).
8. Проверять результат действия: состояние UI вместе с controller/fixture request/state там, где это подтверждает работу нескольких подсистем. Не ограничиваться наличием текста и не требовать точного времени playback на эмуляторе; использовать обоснованный допуск.
9. Не лечить flaky test автоматическим повторным запуском или увеличением всех задержек. Сохранять seed и артефакты первого падения; исправлять finder, ожидание либо product defect. Для иной перестановки задавать `ANISTAR_TEST_SEED`, например `ANISTAR_TEST_SEED=20261011 bash scripts/e2e-all.sh`.
10. Запускать платформы последовательно на разных проверенных AVD, сохранять оба результата и считать отсутствие завершённых native events ошибкой. Успешная сборка APK сама по себе не означает успешный E2E.

## Границы текущих проверок

Основной набор использует один существующий телефон и один Android TV AVD с реальным системным профилем и viewport. Более узкие/широкие экраны и масштаб текста покрываются widget/golden-тестами. Это не матрица всех устройств и версий Android.

Lifecycle в сценарии подаётся через Flutter binding; player и Android screen flag при этом настоящие. Нажатие системного Home, process death, системная клавиатура и permission dialogs этим не подтверждаются. `integration_test` имеет ограничения на взаимодействие с native UI; при появлении такого требования нужен отдельный native driver/набор, а не утверждение о покрытии на основании Flutter finder. [Ограничения Flutter](https://docs.flutter.dev/testing/overview).

Live-запуск требует отдельного тестового аккаунта, сети и явно выбранного режима. Его результаты отмечаются отдельно; не запускать изменения реального избранного в качестве скрытого retry offline-тестов. Четыре ранее известные TV golden-регрессии находятся в отдельном наборе и не исправляются обновлением эталонов во время E2E-аудита.
