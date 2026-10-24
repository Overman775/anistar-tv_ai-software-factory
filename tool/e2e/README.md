# Android TV, Mobile и iOS Simulator E2E Fixtures | AniStar TV

Android runners запускают integration tests против локальных HTTPS fixtures. Fixture server имитирует AniStar HTML и HLS; настоящие repositories, parser и native video работают с его ответами. Отдельный опциональный iOS runner использует iPhone Simulator. Сценарии и правила их написания описаны в [`integration_test/README.md`](../../integration_test/README.md).

## Окружение

Запускайте команды из корня проекта. Нужны закреплённый Flutter SDK через FVM, Android SDK, Python 3.10 или новее и запущенный существующий AVD. По умолчанию используются `anistar_tv_e2e` (Android TV API 36) и `anistar_mobile_e2e` (Pixel 6 / API 36). FFmpeg нужен только для пересоздания media fixtures.

Скрипты не создают и не стирают AVD. Если нужного устройства нет, скрипт показывает доступные экземпляры и команду запуска. TV hardware skin и широкое разрешение на phone image недостаточны: до сборки проверяются boot readiness и настоящий Android UI mode. TV также требует hardware D-pad. Ранее созданный `anistar_e2e` использует phone image, поэтому TV-скрипт не выбирает его по умолчанию.

Melos выбирает доступный совместимый Python interpreter автоматически. Для другого interpreter задайте `ANISTAR_PYTHON`. При прямом запуске Python scripts настройте `PATH` на Python 3.10 или новее: tooling использует аннотации `str | None`, несовместимые с системным Python 3.9.

## Запуск runners

| Набор | Команда |
| :--- | :--- |
| Только TV | `bash scripts/e2e-tv.sh` |
| Только mobile | `bash scripts/e2e-mobile.sh` |
| Обе платформы последовательно на двух разных эмуляторах | `bash scripts/e2e-all.sh` |

Скрипты выбирают AVD по имени, а не первый emulator в adb. Имена можно переопределить через `ANISTAR_TV_AVD` и `ANISTAR_MOBILE_AVD`. Чтобы указать запущенный экземпляр явно, передайте `emulator-<port>` первым аргументом платформенного скрипта. Например: `bash scripts/e2e-mobile.sh emulator-5554`. Старый CLI остаётся совместимым: `bash scripts/e2e.sh <tv-emulator> fixtures` и `bash scripts/e2e.sh <phone-emulator> fixtures-mobile`.

Одиночный TV/mobile runner принимает фильтр после необязательных аргументов
устройства и режима. `--plain-name <substring>` ищет подстроку.
`--name <regexp>` сопоставляет полное имя теста регулярным выражением. Допустима также
форма `--plain-name=<substring>` или `--name=<regexp>`:

```bash
bash scripts/e2e-tv.sh --plain-name 'search submits'
bash scripts/e2e-mobile.sh emulator-5554 fixtures-mobile --name '^MobileSearch submits query$'
```

Прямой вызов Bash runner передаёт исходные argv от shell, поэтому обычные
кавычки сохраняют значения в примерах выше.

Melos 7.8.1 передаёт аргументы через shell и не сохраняет границы значений с
пробелами. Для выборочного E2E через Melos задайте непустой JSON-массив
`ANISTAR_TEST_SELECTORS_JSON`; он может содержать только `--plain-name` или
`--name` с их значениями:

```bash
ANISTAR_TEST_SELECTORS_JSON='["--plain-name","search submits"]' fvm dart run melos run test:e2e:tv --include-private
```

Не сочетайте JSON-переменную с selector arguments. Публичный `test:e2e`
отклоняет её и всегда выполняет полный gate. Подробности host selectors и
ограничений полного gate находятся в [Melos tooling](../../docs/melos_tooling.md#2-проверки).

Фильтр разрешён только для отдельного platform runner. `scripts/e2e-all.sh` и
публичный `test:e2e` принимают только два необязательных device arguments и
отклоняют дополнительные selectors. Общий запуск всегда запускает полные TV
и mobile suites последовательно на разных устройствах; mobile запускается
даже после ошибки TV.

Общий runner выполняет TV и mobile последовательно, сохраняет результат каждого и после ошибки TV запускает mobile. Flutter/Gradle и APK output общие, поэтому одновременные E2E runners блокируются build lock.

<a id="ios-fixture-e2e"></a>
## iOS fixture E2E

Запускайте iOS набор только явно из корня проекта:

```bash
fvm dart run melos run test:e2e:ios -- <simulator-UDID> <dev|prod> [mobile|tv]
```

Нужны macOS, Xcode и уже booted Simulator. Runner принимает его UDID и flavor,
затем необязательный профиль `mobile` (по умолчанию) или `tv`. Профиль `tv` доступен
только если выбранный Simulator имеет iPad device type; имя и ширина окна не
используются для проверки. Он задаёт test-only TV layout diagnostic и не меняет
production resolver и не означает поддержку iPad/tvOS. Runner запускает iOS native
player и локальный HTTPS fixture. Команда не входит в обязательный Android
`test:e2e` или `check`; успешная Simulator-сборка не подтверждает Keychain и HLS.
Не booted UDID или неверное устройство для профиля `tv` завершают runner ошибкой,
а не успешным пропуском.

Runner устанавливает публичный localhost fixture root certificate через
`simctl keychain` только в выбранный Simulator. Certificate остаётся установлен
после прогона. Runner не стирает данные Simulator и не удаляет certificate;
учитывайте это при выборе устройства. Отчёт сохраняется в `build/e2e/ios-<flavor>.*`.
`result.json` записывает flavor, `mobile`/`tv` profile, exit code и оставшийся trust.

## Побочные эффекты и очистка

Runner запускает локальный fixture server, настраивает `adb reverse` и временно меняет immersive confirmation на устройстве. Cleanup останавливает server, снимает созданный `adb reverse`, восстанавливает настройку и освобождает build lock. Каждый запуск получает собственный server и состояние fixtures.

TV fixture runner передаёт fixture server host ADB, выбранный device и package через `--native-ime-adb`, `--native-ime-device` и `--native-ime-package`. Endpoint `GET /__test/native-ime` возвращает `available`, `querySucceeded`, `status` и `currentEditorMatches`; сырые ответы `dumpsys input_method` и полного `dumpsys window` не публикуются. Полный window dump нужен для global focus и InputMethod window. Отсутствующий, ошибочный или переходный снимок не засчитывается как видимое либо скрытое состояние. Эта проверка использует нативные окна ОС: нулевые Flutter insets не означают, что видимая IME отсутствует.

## Проверка Python-инструментов

Fixture-команды выше запускают Android runner. Чтобы отдельно проверить Python-инструменты fixture server, выполните из корня проекта:

```bash
python3 -m unittest discover -s tool/e2e -p '*_test.py'
```

Эта команда не запускает Android E2E.

<a id="e2e-reports"></a>
## Отчёты

Каждая платформа сохраняет отчёт в отдельном каталоге вида `build/e2e/<platform>-<mode>-seed-<seed>-<avd>.<suffix>/`. Каталог содержит `runner.log`, `flutter.log`, `flutter-events.jsonl`, `logcat.log`, fixture `requests.jsonl`, `selection.json`, `summary.json` и `junit.xml`. При отказе preflight отчёт указывает этап и причину, не представляя native tests как успешно завершённые.

Отчёт содержит `scope=full` без selectors и `scope=filtered` при запуске с
фильтром, а также selector, seed, длительность, exit code, статус, этап,
счётчики, завершённые тесты и пути артефактов. Успешный filtered run выводит
`PARTIAL PASS`; он предназначен для диагностики и не удовлетворяет полному
E2E gate. Полный успешный platform run выводит `OK`. При ошибке runner выводит
`FAIL`, фазу и путь к отчёту и `flutter.log`.

Общий запуск создаёт отдельные `tv/` и `mobile/` каталоги и объединяет summary/JUnit в корне своего каталога. Отсутствующие или оборванные native events не дают успешный отчёт.

Порядок тестов задаёт seed `20261010`. Чтобы изменить порядок, задайте, например, `ANISTAR_TEST_SEED=1337 bash scripts/e2e-all.sh` или `ANISTAR_TEST_SEED=20261011 bash scripts/e2e-all.sh`. Изменение seed не меняет выбранные устройства.

## Протокол fixtures

- Каталог и карточка используют windows-1251. Player HTML использует UTF-8 и JavaScript playlist.
- Вход использует вымышленные credentials; наборы проверяют Secure Storage restore и session expiry.
- Избранное хранится в fixture server: session cookie, AJAX plus/minus, список и control в HTML. Режим `favorite_error` возвращает HTTP 200 с error.
- Fixture содержит рекламный ID 9493, две страницы и серии в обратном порядке.
- URL `720.mp4` возвращает HLS master. Вложенный playlist содержит relative/absolute TS.
- Server проверяет Referer на HLS master, вложенном playlist и TS. Range-запрос возвращает 206 и Content-Range.
- `refresh_once` отклоняет первый playback URL. `always_expired` отклоняет все playback URL.
- Server использует только loopback. Запросы к AniStar или CDN не выполняются.

Certificate находится в Android debug resources и повторён в Dart test helper. Private key в `tls/` публичный и предназначен для localhost fixtures. При замене certificate обновляйте обе копии. Release resources этот certificate не содержат.

## Media fixtures

Синтетические 24-секундные H.264/AAC fixtures находятся в `media/`. Они не входят в pubspec assets. Для пересоздания нужен FFmpeg:

```bash
bash scripts/regenerate_e2e_media.sh
```

После обновления выполните Python-тесты и E2E. Для отдельной проверки fixture server используйте команду из раздела «Проверка Python-инструментов».

## Живой сайт

Live не входит в offline-прогон. Запускайте его только явно командой `bash scripts/e2e-tv.sh live`; по умолчанию она использует `.private/credentials/live-test.json` из корня проекта. В VS Code доступна задача **Flutter: Live Android E2E**. Подготовьте файл по процедуре в [руководстве разработки и тестирования](../../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом); шаблон без credentials находится в `env/live-test.example.json`. Весь `.private/` и legacy-файлы `env/*.local.json` исключены из Git для защиты от случайного добавления. Runner читает live credentials из `.private/credentials/` по умолчанию; legacy-файлы он не использует. Live harness передаёт credentials через Dart define и заполняет форму входа.

Live требует отдельного тестового аккаунта и может менять серверную историю просмотренных серий. Не запускайте изменение реального избранного как скрытый повтор offline-теста. Ограничения и полный протокол приведены в [проверке с живым аккаунтом](../../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

## Навигация

[Сценарии, покрытие и правила изоляции](../../integration_test/README.md), [команды и контекст Android E2E](../../docs/05_development_and_testing.md#5-интеграционные-тесты-android-tv-и-телефона), [полная live-процедура](../../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом).
