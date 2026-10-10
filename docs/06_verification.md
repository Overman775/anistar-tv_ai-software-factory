# ✅ Состояние проверок | AniStar TV

Дата: 10 октября 2026 года. Scope: Android / Android TV, прямой AniStar HTTP и онлайн HLS.

## 1. Критерии готовности

- Каталог, карточки и серии разбираются на устройстве без браузера и parser-сервера.
- Native player запускает HLS 360p/720p с Referer, поддерживает seek, паузу, смену качества/серии и Back.
- Вход сохраняет cookies в Android Secure Storage; пароль не сохраняется. Выход и expiry закрывают protected router.
- Избранное читается и изменяется на сайте; UI обновляется после подтверждения. Локального постоянного списка нет.
- Формат, analyzer, DCM, unit/widget, goldens и Android E2E проходят. APK содержит текущие AOT libraries.

## 2. Автоматические проверки

Flutter 3.47.7 stable, Dart 3.13.5, DCM 1.39.2. Команды: [Разработка и тестирование](05_development_and_testing.md).

| Проверка | Результат |
| --- | --- |
| Формат, analyzer, DCM | Passed после TV UX-правок; 205 Dart-файлов |
| Unit/widget/architecture | 141 passed после TV UX-правок; seed 20261010 |
| Golden comparison | 16 passed после TV UX-правок; точное сравнение, 960×540 и 1280×720 |
| HTTPS fixture | 6 Python-тестов passed |
| APK freshness checker | 8 Python-тестов passed |
| Release APK | Passed после E2E; текущие AOT libraries подтверждены для трёх ABI |

Android E2E выполнен после обновления SDK: API 36 ARM64, TV profile, Chrome отключён. **9 сценариев прошли после TV UX-правок при seed 20261010.** Repository, parser, session storage и native player не подменялись; тест задавал localhost HTTPS origin, certificate trust и logger.

| Сценарий | Проверено |
| --- | --- |
| Вход и сессия | Неверный пароль, вход, новый runner, encrypted restore без POST, expiry, выход |
| Каталог и пагинация | Windows-1251, реклама 9493, следующая страница и видимая карточка |
| Native playback | 720p/360p, nested manifests, relative/absolute TS, Referer, seek/pause, серии и Back |
| Восстановление | Один автоматический refresh, остановка повторов, ручной retry |
| Избранное | Held OK / касание, plus/minus с cookie и Referer, звезда, вкладка, новый runner, изменение другим клиентом |
| Отказ избранного | HTTP 200 с error не меняет UI; свежий статус и ручной retry |
| TV focus | Up на текущую вкладку, пустое избранное, возврат к той же карточке, отмена chooser и последующие pause/seek |

## 3. Живой AniStar

Прямой Dart HTTP и native HLS 360p/720p проверены на зеркале `v30.astar.bz` в Android emulator до добавления login gate. Проверены запуск, продвижение позиции, seek, пауза, качество, серия и Back. Это подтверждает transport/playback, но не авторизованный пользовательский путь текущего приложения.

Форма входа и явный отказ при несуществующем логине получены прямым HTTP. Текущий DLE-скрипт избранного также получен напрямую: он использует GET с `fav_id`, `action`, `skin`, `alert`. Подробный контракт: [Сеть и HLS](04_network_and_playback.md).

**Успешный live-вход и запись избранного подтверждены 10 октября 2026 года** после получения тестового аккаунта; подробности исправления и повторного прогона — в разделе 9. Ранние проверки до предоставления credentials подтверждали только локальный HTTPS fixture.

Физический TV, аппаратный декодер и физический пульт отдельно не проверены. CI/CD не используется; все указанные проверки локальные. Интерактивная CAPTCHA не обходится; доступность зеркала зависит от IP/сети. Естественное суточное истечение ссылки не ожидалось: отказ и refresh воспроизводятся fixture.

## 4. Очистка проекта

Удалены старый generated API/OpenAPI, генератор parser-клиента, отдельный экспериментальный клиент, браузерные и offline-пробы, исследования для прежнего scope и завершённые планы работ. Действующие руководства и ADR сохранены; результаты сведены в этот документ.

Fixtures, golden baselines, Android branding и quality tooling входят в текущие проверки. Generated build outputs и кеши можно удалить; для работы достаточно `fvm flutter pub get`. Граф обновляется через `graphify update .`.

## 5. Обновление SDK и пакетов

Flutter **3.44.0 → 3.47.7 stable**, Dart **3.12.0 → 3.13.5**. Релиз Flutter от 8 октября проверен через `fvm releases` и [официальный changelog](https://raw.githubusercontent.com/flutter/flutter/stable/CHANGELOG.md). FVM закрепляет точную версию; все семь pubspec согласованы с Dart 3.13 и новым Flutter. Kotlin Gradle Plugin **2.2.20 → 2.4.21 stable**: поддерживает AGP 9.0.1 / Gradle 9.1.0 по [матрице Kotlin](https://kotlinlang.org/docs/gradle-configure-project.html).

Обновлено 79 существующих зависимостей lockfile, добавлены пять новых: `material_ui`, `cupertino_ui`, `flutter_localizations`, `jni_util`, `listen`. Изменившиеся прямые зависимости приложения и workspace:

| Пакет | Было | Стало |
| --- | --- | --- |
| `analyzer` | 12.1.0 | 13.3.0 |
| `build_runner` | 2.15.1 | 2.16.1 |
| `cached_network_image` | 3.4.1 | 4.0.4 |
| `dio` | 5.10.0 | 5.11.1 |
| `equatable` | 2.1.0 | 3.0.0 |
| `flutter_riverpod` | 3.3.2 | 3.4.3 |
| `flutter_secure_storage` | 10.3.1 | 11.2.0 |
| `go_router` | 17.3.0 | 18.0.2 |
| `go_router_builder` | 4.3.1 | 4.5.0 |
| `html` | 0.15.6 | 0.15.7 |
| `logger` | 2.7.0 | 2.8.0 |
| `material_ui` | — | 1.6.0 |
| `share_plus` | 13.2.1 | 13.3.1 |
| `shared_preferences` | 2.5.5 | 2.5.6 |
| `skeletonizer` | 2.1.3 | 3.0.0 |
| `video_player` | 2.13.0 | 2.14.1 |
| `yaml` | 3.1.3 | 3.1.4 |

Остальные прямые пакеты уже были на последних stable-релизах; их constraints подняты до фактически проверенных версий. Версии SDK-пакетов определяет Flutter, workspace-пакеты остаются локальными. `dependency_overrides` не добавлены.

### Ограничения resolver

`flutter_test` в stable SDK закрепляет `test_api 0.7.12` и `matcher 0.12.20`. Совместимый `bloc_test` использует `test 1.31.1`, который требует `analyzer <14`. Поэтому последние совместимые dev-пакеты — **analyzer 13.3.0** и **build_runner 2.16.1**; latest 14.5.0 / 2.16.2 конфликтуют с тестовым стеком SDK. Прямой запрос latest проверен resolver и отклонён. Это ограничение нельзя исправить повышением constraints без замены тестового стека или overrides.

Также остаются связанные transitive-пакеты `_fe_analyzer_shared`, `source_gen`, `test`, `test_api`, `test_core`, `package_config`, `cli_util`, `cross_file` и `material_color_utilities`. Для всех остаточных outdated-пакетов current = upgradable = resolvable. Не все transitive latest совместимы с последним stable SDK и опубликованными constraints зависимостей.

### Совместимость

- Приложение, UI Kit и тестовые оболочки используют единый `material_ui`, как [go_router 18](https://pub.dev/packages/go_router/changelog) и [cached_network_image 4](https://pub.dev/packages/cached_network_image/changelog). Typed routes сгенерированы новым builder.
- Для [Equatable 3](https://pub.dev/packages/equatable/changelog) variant входит в `props` событий/состояний log viewer. Регрессия проверяет различие initial/loading и равенство одинакового содержимого.
- [Secure Storage 11](https://pub.dev/packages/flutter_secure_storage/changelog) удаляет старые алгоритмы и `encryptedSharedPreferences`. Клиент уже использовал современные defaults v10; deprecated API не использовались. Текущий encrypted restore проверяется E2E; отдельная миграция данных установленной v10-сборки не тестировалась.
- Android сохраняет `android.builtInKotlin=false` / legacy DSL для совместимости плагинов; app module использует built-in Kotlin явно. Последний `share_plus` ещё применяет legacy KGP. Не включаем built-in Kotlin глобально, пока все плагины не мигрируют ([руководство Flutter](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin)).
- APK checker адаптирован к Flutter 3.47: сравнивает исходный AOT, отдельный JNI staging, merge и stripped library внутри APK. Проверяет совпадение набора ABI; регрессии покрывают обе структуры SDK и устаревший staging.
- Проверены [migration guides Flutter 3.47](https://docs.flutter.dev/release/breaking-changes): в приложении нет `describeEnum`, `Semantics(header: true)` и собственных GPU/shader-компенсаций.
- Из analyzer-конфигурации убраны только три deprecated lint: `unnecessary_await_in_return`, `avoid_private_typedef_functions`, `one_member_abstracts`. Dart рекомендует [удалить первый](https://dart.dev/tools/linter-rules/unnecessary_await_in_return), [второй](https://dart.dev/tools/linter-rules/avoid_private_typedef_functions) и [третий](https://dart.dev/tools/linter-rules/one_member_abstracts); strict-mode и действующие правила сохранены.
- Просмотрены все восемь golden diff: изменения 0.03–0.64% затрагивают растеризацию скруглённых рамок. Текст, расположение, focus и badge сохранены. Эталоны закреплены для нового SDK; допуск сравнения не ослаблен.

Локальный [скилл обновления](../.agents/skills/anistar-flutter-update/SKILL.md) адаптирован из RC Mobile App без Melos, iOS и CI/CD. Неиспользуемые заготовки GitHub workflows удалены; команды локальных проверок сохранены.

## 6. Текущая сборка

[app-prod-release.apk](../build/app/outputs/flutter-apk/app-prod-release.apk): 59 667 092 байт, Flutter 3.47.7 / Kotlin 2.4.21, три ABI: `armeabi-v7a`, `arm64-v8a`, `x86_64`.

SHA-256: `6491cfeb334d8607b01579fe1778bc5290e564ce7af9a87f20f5c68d357d1e8b`.

APK соответствует состоянию `196a200`, до изменения шапки и порядка серий. Отдельная release-сборка после этих изменений не выполнялась. Промежуточные библиотеки проверены freshness checker после release-сборки с исправлениями входа, UI и TV UX. APK сохранён; повторная проверка требует сохранённых build intermediates либо новой сборки.

Иконка и TV баннер обновлены через imagegen; экспортированы все пять density-вариантов и adaptive icon. Размеры проверены, баннер просмотрен в 320×180. В новом release APK через `aapt` подтверждены `AniStar TV`, `android:icon`, `android:banner` и LEANBACK launcher; freshness check прошёл для трёх ABI. Внешний вид в launcher физического TV отдельно не проверен. Экспорт: [Разработка и тестирование](05_development_and_testing.md#8-иконка-и-android-tv-баннер).

## 7. Поиск зеркал

Критерии: сохранение только номера версии; доступное текущее зеркало не запускает перебор; не более четырёх следующих версий; cooldown минуты после исчерпания; один поиск для параллельных запросов; произвольные origins фиксированы; новый origin создаёт отдельную сессию без переноса cookies и повторов POST/избранного.

Семь unit-тестов проверили подтверждение каталога, `v30 → v32`, сохранение/следующий запуск, границы и cooldown, challenge/посторонний HTML, отказ отдельного endpoint/CDN, некорректный cache и custom origin. Два composition-теста подтвердили смену HTTP/session providers после POST 503 и cross-origin 302 без replay и переноса cookies. Контракт описан в [Сеть и HLS](04_network_and_playback.md#автоматический-выбор-зеркала). Реальная блокировка AniStar и live-вход после смены домена не воспроизводились.

После обработки redirect повторно прошли формат, analyzer, DCM, 124 unit/widget/architecture-теста, 8 goldens, Android E2E (8 сценариев, API 36 ARM64, seed 20261010, Chrome отключён) и release freshness check для трёх ABI. Сбой зеркал проверялся Dio fixtures; emulator E2E использовал фиксированный localhost origin.

## 8. Просмотренные серии

Проверена текущая страница плеера `10938`: `trackEpisodes` и `logVideoViewing` сохраняют историю в браузерном localStorage; HTTP-запрос для отметки в исследованном коде отсутствует. Реализован локальный аналог приложения с чтением boolean `viewing` из HTML, отметкой после успешного native play, галочкой/Semantics в карточке и подписью в выборе серии. История разделена по аккаунтам и аниме, сохраняется в preferences, переживает смену зеркала и перезапуск. Серверная/межустройственная синхронизация не подтверждена и не реализована. Контракт: [Просмотренные серии](specs/07_watched_episodes.md).

После изменения прошли формат, analyzer, DCM, 133 unit/widget/architecture-теста и 8 goldens (seed 20261010). Новые проверки покрывают конкурентное сохранение, восстановление, смену аккаунта во время записи, отказ чтения/записи, отсутствие отметки при неудачной native инициализации, отсутствие повторных записей при смене качества, переключение серии, галочки и Semantics.

Android E2E: 8 сценариев прошли на API 36 ARM64 с отключённым Chrome. Дополнен существующий сценарий native 720/360 HLS: две начатые серии дают две галочки после Back, затем история восстанавливается после пересоздания полного клиента/ProviderScope с реальными preferences. Шесть Python-тестов fixture server также прошли. Runner сообщил нефатальную ошибку uninstall базового package ID в teardown после успешных сценариев; это не ошибка приложения или теста истории. Live-проверка авторизованной истории реального аккаунта не проводилась.

Release APK с отметками просмотра собран успешно; freshness checker подтвердил соответствие AOT/JNI staging/merge/stripped libraries и APK для всех трёх ABI. Размер и SHA-256 указаны выше.

## 9. Исправление live-входа

Тестовый аккаунт позволил воспроизвести отказ на настоящем сайте. HTTP POST выдавал cookies и member HTML, но `AnistarAuthHtml.logoutUri()` вызывал `Uri.origin` для ссылки `javascript:` в меню. Dart выбрасывал StateError, а repository возвращал безопасную общую ошибку входа. Исправление отбрасывает посторонние схемы, malformed URI/query, чужой host/port и userInfo перед подтверждением logout. Member fixtures теперь включают javascript ссылку; добавлена регрессия всех этих вариантов.

Android live E2E с отключённым Chrome прошёл на API 36 ARM64: ввод логина/пароля через форму, каталог, пересоздание приложения и encrypted restore без повторного POST, карточка/серии `10938`, изменение избранного и его проверка на сайте, native HLS 720p/360p, remote seek и пауза/resume, качество и серия, галочки и их восстановление после второго пересоздания, logout. Избранное возвращено в исходное состояние; CAPTCHA не требовалась. Этот прогон подтверждает текущее зеркало/IP, а не все возможные сети.

Credentials хранятся локально вне Git. Команда и правила повторной проверки: [разработка и тестирование](05_development_and_testing.md#9-проверка-с-живым-аккаунтом). Пароль, cookies и подписанные URL в этот отчёт не включены.

После исправления формат, analyzer и DCM прошли без замечаний; 134 unit/widget/architecture-теста и 8 goldens прошли с seed 20261010.

Восемь fixture Android E2E и шесть Python-тестов сервера прошли после добавления javascript ссылки в member HTML. Дополнительно прошёл отдельный live-сценарий с настоящим аккаунтом.

Обычный release APK пересобран с исправлением входа; freshness checker прошёл для трёх ABI. Размер и SHA-256 обновлены в разделе 6. Integration entry point и файл credentials при этой сборке не использовались.

## 10. UI Android TV

Исправлена прокрутка при focus: контекст передаётся от конкретной карточки, а не от всей SliverGrid. Возврат к первой карточке возвращает начало каталога. Scroll view ограничен областью под AppBar, карточки больше не рисуются поверх вкладок. На 960×540 уменьшены верхние отступы, чтобы focus-масштабирование первой строки помещалось целиком.

Скелетоны каталога и карточки повторяют расположение заголовка, постера, текста, кнопки и сетки. Hero height и число столбцов серий общие с ready; учитываются горизонтальные отступы. Формы используют один shimmer-контейнер, поддерживают системное отключение анимации и исключены из Semantics.

Экран входа оформлен общей темой, добавлены видимость пароля и индикатор отправки. У вкладок повышен контраст выбранной подписи и добавлена отдельная focus-рамка; все стили текста используют Inter. Длинные названия/метаданные ограничены строками, описание учитывает доступную высоту и масштаб текста; последняя видимая строка получает многоточие. Error icon фонового изображения hero скрыт. Контракт — [TV-взаимодействие](specs/06_tv_interaction.md).

Проверки после правок: format, analyzer и DCM без замечаний; 135 unit/widget/architecture и 16 goldens прошли с seed 20261010. Восемь новых golden-снимков проверяют loading каталога/карточки, длинное содержимое карточки и вход на 960×540 и 1280×720. Baselines просмотрены; сравнение точное. Регрессия focus проверяет рамку самой карточки при возврате из нижнего ряда.

На API 36 ARM64 с отключённым Chrome повторно прошли все восемь fixture E2E-сценариев, включая вход/сессию, избранное, HLS, управление пультом и watched history.

После последней правки описания повторно прошёл live E2E с локальный тестовый аккаунт: вход, encrypted restore без нового POST, сайтное избранное с восстановлением исходного статуса, HLS 720p/360p, seek/пауза, смена серии, история после перезапуска и logout. CAPTCHA не потребовалась. Credentials переданы только integration test через локальный файл вне Git.

Release APK пересобран после live E2E; freshness checker подтвердил текущий AOT для трёх ABI. Размер и SHA-256 обновлены в разделе 6. Файл credentials и integration entry point в release не передавались.

## 11. UX управления пультом

Критерии готовности: все найденные проблемы воспроизводятся тестом до исправления; стрелки/OK проходят путь без касаний; текущий выбор виден; Back возвращает управление предыдущему экрану без смены потока; retry доступен сразу после ошибки; проверки и обычная release-сборка проходят.

| Проблема | Результат исправления |
| --- | --- |
| Восстановление сессии отключало поля раньше autofocus | После проверки focus получает логин |
| После отказа входа focus терялся; Down редактировал курсор | Focus возвращается в очищенный пароль; Up/Down ведут между полями и кнопкой |
| Up из первого ряда выбирал соседнюю вкладку, затем Right мог вести на logout | Up явно ведёт на текущую вкладку, независимо от геометрии native layout |
| Пустое избранное теряло выбранную вкладку | Focus остаётся на вкладке; Left + OK возвращают главную, Down ведёт к карточкам |
| Ошибка статуса избранного оставляла retry без focus | OK повторяет чтение свежего статуса |
| Поздняя серия не показывалась при открытии списка | Выбранная серия видна сразу; стрелки прокручивают строки |
| OK после отказа видео не нажимал видимую кнопку retry | Focus переходит на «Повторить» и возвращается видео после восстановления |

Проверены выбор серии 20 из 24, прокрутка до последней и OK, отмена chooser через Back с последующими pause/seek без нового controller, восстановление focus после автоматического/ручного retry. Уже работавшие короткий/длинный OK, сетка каталога, прокрутка к карточке и освобождение плеера после Back остались в регрессиях.

Format, analyzer и DCM прошли без замечаний; 141 unit/widget/architecture и 16 goldens прошли с seed 20261010. Два baseline входа обновлены и просмотрены: изменение — focus логина; остальные golden-снимки совпали. Контракт и ручной smoke: [TV-взаимодействие](specs/06_tv_interaction.md), [разработка и тестирование](05_development_and_testing.md#5-e2e-и-smoke-на-android-tv).

На API 36 ARM64 с отключённым Chrome прошли девять fixture Android E2E и шесть Python-тестов HTTPS сервера. Вход fixture теперь отправляется стрелкой Down и OK вместо касания «Войти»; отказ HLS повторяется через OK. Новый E2E проверил текущую вкладку, пустое избранное, возврат к той же карточке, отмену chooser и последующие pause/seek на том же native controller.

Повторно прошёл live Android E2E с тестовым аккаунтом: вход, encrypted restore, сайтное избранное с возвратом исходного статуса, HLS 720p/360p, seek/пауза, серии, история и logout. Обычный release APK пересобран после E2E без credentials и integration entry point; freshness checker прошёл для трёх ABI. Размер/SHA-256 обновлены в разделе 6. Физический TV и его экранная клавиатура отдельно не проверены.

Обычный release APK установлен и запущен отдельно от integration entry point. Через native `adb input keyevent` проверены Back для закрытия IME, Down: логин → пароль → «Войти», OK: валидация пустой формы. Пароль для этой ручной проверки не вводился. У эмулятора TV hardware profile, но системная IME из образа Android; её внешний вид не подтверждает клавиатуру конкретного телевизора.

## 12. Шапка и порядок серий

Каталог, избранное и карточка аниме используют общий фон за прозрачным Scaffold и полупрозрачную шапку с blur 14. Содержимое по-прежнему ограничено областью под AppBar. Серии в сетке и меню player сортируются по числовому номеру от последней к первой; сортируется копия списка. Hero-кнопка запуска первой серии сохранена, текущая серия в диалоге получает focus и остаётся видимой.

10 октября 2026 года прошли format, analyzer, DCM, 141 unit/widget/architecture-тест и 16 goldens. Визуально просмотрены 12 изменённых эталонов каталога, избранного и карточки в 960×540 и 1280×720. Допуск сравнения не менялся. Проверка пультом подтверждает переход к последней серии в сетке и выбор второй серии через Up в меню player.

На Android API 36 ARM64 прошли 9 fixture E2E и 6 Python-тестов fixture server, seed 20261010. Native 720/360 HLS, смена серии, возврат, focus вкладок и отмена диалога продолжают работать. Live-прогон после этих UI-изменений не повторялся. Отдельный release APK не пересобирался; сведения о предыдущем APK приведены в разделе 6.
