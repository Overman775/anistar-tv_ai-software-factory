# Android TV и Mobile E2E Fixtures | AniStar TV

Инструменты E2E запускают Android integration tests против локальных HTTPS fixtures. Fixture server имитирует AniStar HTML и HLS; настоящие repositories, parser и native video работают с его ответами. Сценарии и правила их написания описаны в [`integration_test/README.md`](../../integration_test/README.md).

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

Общий runner выполняет TV и mobile последовательно, сохраняет результат каждого и после ошибки TV запускает mobile. Flutter/Gradle и APK output общие, поэтому одновременные E2E runners блокируются build lock.

## Побочные эффекты и очистка

Runner запускает локальный fixture server, настраивает `adb reverse` и временно меняет immersive confirmation на устройстве. Cleanup останавливает server, снимает созданный `adb reverse`, восстанавливает настройку и освобождает build lock. Каждый запуск получает собственный server и состояние fixtures.

## Проверка Python-инструментов

Fixture-команды выше запускают Android runner. Чтобы отдельно проверить Python-инструменты fixture server, выполните из корня проекта:

```bash
python3 -m unittest discover -s tool/e2e -p '*_test.py'
```

Эта команда не запускает Android E2E.

<a id="e2e-reports"></a>
## Отчёты

Каждая платформа сохраняет отчёт в отдельном каталоге вида `build/e2e/<platform>-<mode>-seed-<seed>-<avd>.<suffix>/`. Каталог содержит `runner.log`, `flutter.log`, `flutter-events.jsonl`, `logcat.log`, fixture `requests.jsonl`, `selection.json`, `summary.json` и `junit.xml`. При отказе preflight отчёт указывает этап и причину, не представляя native tests как успешно завершённые.

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

Live не входит в offline-прогон. Запускайте его только явно командой `bash scripts/e2e-tv.sh live`; она автоматически использует локальный `env/live-test.local.json`. В VS Code доступна задача **Flutter: Live Android E2E**. Git исключает локальный файл; шаблон без credentials находится в `env/live-test.example.json`. Live harness передаёт credentials через Dart define и заполняет форму входа.

Live требует отдельного тестового аккаунта и может менять серверную историю просмотренных серий. Не запускайте изменение реального избранного как скрытый повтор offline-теста. Ограничения и полный протокол приведены в [проверке с живым аккаунтом](../../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

## Навигация

[Сценарии, покрытие и правила изоляции](../../integration_test/README.md), [команды и контекст Android E2E](../../docs/05_development_and_testing.md#5-интеграционные-тесты-android-tv-и-телефона), [полная live-процедура](../../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом).
