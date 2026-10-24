# 🛠️ Команды Melos | AniStar TV

Используйте Melos из корня проекта для подготовки workspace, проверок, тестов,
генерации и Android/iOS Simulator-сборок. Команды запускают локальную версию Melos 7.8.1,
закреплённую в корневом `pubspec.yaml` и `pubspec.lock`.

Melos 7.8.1 — максимальная совместимая версия при текущем `flutter_launcher_icons`:
его ограничение `cli_util ^0.4.1` несовместимо с Melos 7.8.2 и новее.

## Содержание

- [1. Подготовка и быстрый запуск](#1-подготовка-и-быстрый-запуск)
- [2. Проверки и тесты](#2-проверки-и-тесты)
- [3. Проверки безопасности](#3-проверки-безопасности)
- [4. Запуск приложения и сборка](#4-запуск-приложения-и-сборка)
- [5. Генерация и ресурсы](#5-генерация-и-ресурсы)
- [6. Зависимости и обслуживание](#6-зависимости-и-обслуживание)
- [7. Остальные команды](#7-остальные-команды)

---

## 1. Подготовка и быстрый запуск

Для Android нужны FVM с Flutter SDK 3.47.7 из `.fvmrc`, JDK 17 и Android SDK. Для
iOS Simulator нужны macOS и Xcode. DCM нужен
для полной команды `check`. Для Python-задач требуется Python 3.10 или новее.
Дополнительные инструменты нужны только для соответствующих операций:

| Операция | Требование |
| :--- | :--- |
| Git hooks | Lefthook |
| Экспорт launcher icon, Android TV banner и splash | macOS и `sips` |
| Пересоздание HLS fixtures | FFmpeg с `libx264` |
| Проверки безопасности | Gitleaks, OSV-Scanner и Semgrep |
| Обслуживание локального графа | Graphify (необязательно) |

Установите закреплённый SDK, получите зависимости по lockfile и подготовьте
workspace:

```bash
fvm install
fvm flutter pub get --enforce-lockfile
fvm dart run melos bootstrap --enforce-lockfile
```

Команды Melos выполняйте из корня. Общая форма запуска:

```bash
fvm dart run melos run <имя-команды>
```

Посмотреть доступные публичные команды:

```bash
fvm dart run melos run --list
```

Melos по умолчанию не показывает и не запускает приватные команды. Для приватной
команды укажите `--include-private` до разделителя `--`. Аргументы после `--`
передаются самой команде:

```bash
fvm dart run melos run test:e2e:tv --include-private -- emulator-5554
fvm dart run melos run run:dev -- -d emulator-5554
```

Приватны `test:e2e:tv`, `test:e2e:mobile`, `test:e2e:live`,
`test:network:live`, `generate:e2e-media`, `check:apk`, `graph:update`,
`graph:check` и `version:check`.

Melos использует `.fvm/flutter_sdk`. Переменная `ANISTAR_FLUTTER_SDK` может
указывать на другой путь к тому же SDK, который закреплён в `.fvmrc`. Для SDK,
который выбирает Melos, также поддерживаются `--sdk-path` и `MELOS_SDK_PATH`.
Глобальная установка Melos не требуется.

Команды с `scripts/with_python.sh` выбирают доступный Python 3.10 или новее. По умолчанию
проверяются `python3`, затем `python3.14`–`python3.10`. Переменная
`ANISTAR_PYTHON` задаёт исполняемый файл явно. Выбор распространяется на
вложенные Python-инструменты. Для прямого вызова скриптов настройте `PATH`
самостоятельно.

Graphify-команды вызывают `python3 tool/graphify/prepare.py` напрямую; для них
нужен Python 3.10+ в `PATH`. При `melos bootstrap --enforce-lockfile` проект вызывает
подготовку Graphify в
optional-режиме. Если совместимая установка найдена, команда проверяет patch и
сохраняет interpreter в локальной ignored sidecar `graphify-out/.graphify_python`.
Без Graphify bootstrap продолжается. Обнаруженная установка с неверной версией,
patch или sidecar останавливает проверку. Для ручной настройки нового checkout
выполни:

```bash
python3 tool/graphify/prepare.py --optional
```

Переменная `ANISTAR_GRAPHIFY_PYTHON` позволяет выбрать другую локальную
установку Graphify.

Правила корпуса хранятся в tracked `.graphifyignore`, поэтому одинаковы для
checkout и worktree. Они исключают FVM SDK link, build/cache и generated outputs,
binary assets и HLS fixtures, credentials и runtime artifacts. Maintained source,
tests, docs и Factory instructions остаются доступны Graphify. См.
[руководство Graphify](../tool/graphify/README.md).

Для установки Git hooks см. [руководство VCS](vcs_guidelines.md#5-локальные-git-hooks).

---

## 2. Проверки и тесты

Полный `check` — основной профиль проверки перед завершением изменения. Он
выполняет подготовку SDK, lockfile и seed один раз, затем проверяет формат,
analyzer, DCM, unit-, widget- и архитектурные тесты с coverage, golden-тесты,
Python-инструменты и формат версии. Профиль останавливается при первой ошибке.
Сообщения analyzer уровня info и предупреждения DCM о стиле считаются ошибками.
Проверка формата и сравнение golden-эталонов не изменяют файлы. Профиль читает
текущее рабочее дерево и не требует чистого Git дерева; незакоммиченные изменения
могут повлиять на результат.
Порядок unit-тестов по умолчанию задаёт seed `20261010`.

```bash
fvm dart run melos run check
```

`check:flutter` выполняет подготовку SDK, lockfile и seed, затем проверяет формат,
запускает analyzer, unit-тесты с coverage и golden-тесты. Этот профиль не запускает
DCM, Python-инструменты и проверку версии. Отдельные команды подходят, когда нужно
повторить один этап:

| Задача | Команда |
| :--- | :--- |
| Форматировать поддерживаемые Dart-файлы | `fvm dart run melos run format` |
| Проверить формат без изменений | `fvm dart run melos run format:check` |
| Запустить analyzer | `fvm dart run melos run analyze` |
| Запустить DCM | `fvm dart run melos run dcm` |
| Запустить unit-, widget- и архитектурные тесты с coverage | `fvm dart run melos run test:unit` |
| Запустить тот же набор тестов с coverage | `fvm dart run melos run test:coverage` |
| Сравнить golden-эталоны | `fvm dart run melos run test:goldens` |
| Обновить golden-эталоны | `fvm dart run melos run test:goldens:update` |
| Запустить Python tooling | `fvm dart run melos run test:tooling` |
| Проверить только Flutter-инструментами | `fvm dart run melos run check:flutter` |

Melos 7.8.1 передаёт script arguments через shell и не сохраняет исходные
границы цитируемых аргументов. Простые пути `.dart` и односоставные значения
`--plain-name` или `--name` можно передавать как обычные аргументы. Для
селектора с пробелами или shell-символами используйте
`ANISTAR_TEST_SELECTORS_JSON`: это JSON-массив
непустых строк, который сохраняет каждый аргумент без изменений. Хост-профили
принимают пути тестовых файлов, `--plain-name` с подстрокой и `--name` с
регулярным выражением полного имени. Другие аргументы Flutter test запрещены.

```bash
fvm dart run melos run test:unit -- test/packages/features/search/search_bloc_test.dart
ANISTAR_TEST_SELECTORS_JSON='["--plain-name","empty query"]' fvm dart run melos run test:unit
ANISTAR_TEST_SELECTORS_JSON='["--name","^search \"one\" \\| test$"]' fvm dart run melos run test:goldens
ANISTAR_TEST_SELECTORS_JSON='["test/path with spaces.dart"]' fvm dart run melos run test:unit
```

JSON-массив нельзя сочетать с selector arguments команды. Для полного запуска
не задавайте эту переменную; пустой JSON-массив не поддерживается. Команды `check` и
`check:flutter` отклоняют эту переменную, чтобы сохранить полный gate.
Для E2E JSON-массив может содержать только `--plain-name` или `--name` и их
значения. Публичный `test:e2e` также отклоняет переменную. Выборочный E2E
доступен только отдельным TV/mobile runner.

При прямом запуске Bash runner получает исходные argv от shell, поэтому
обычные кавычки shell сохраняют значение:

```bash
bash scripts/quality_runner.sh test unit --prepare --plain-name 'empty query'
```

Каждый публичный запуск сначала один раз проверяет SDK и lockfile. Затем он
создаёт уникальный каталог `build/quality/` для логов и отчётов. Хост-тесты
сохраняют `flutter-events.jsonl`, `summary.json` и `junit.xml`; coverage для
unit-набора остаётся в `coverage/lcov.info`. В консоль выводится краткий
`OK` или `FAIL` с областью `full`/`filtered`, числом завершённых тестов,
счётчиками и путём к отчёту. При ошибке показываются последние строки лога.
Полный вывод находится в каталоге отчёта. Пустой или незавершённый запуск не
считается успешным.

Наличие selector помечает отчёт как `filtered`. Успешный выборочный запуск
полезен для диагностики, но не заменяет полный gate. `test:coverage` —
совместимый alias `test:unit` и принимает те же selectors. Обновлять baselines
можно отдельной командой `test:goldens:update`; `--update-goldens` нельзя
передать в обычную команду сравнения.

`test:e2e` последовательно запускает TV- и mobile-наборы fixture-тестов на
разных эмуляторах. Полная команда не принимает фильтры и запускает mobile даже
после ошибки TV, чтобы сохранить оба результата. Для отдельного fixture-набора
используйте `test:e2e:tv`
или `test:e2e:mobile` с `--include-private`. Приватная `test:e2e:live` запускает
сценарий с тестовым аккаунтом и меняет удалённую историю просмотренных серий.
Приватная `test:network:live` выполняет live-диагностику сети и входа без изменения
избранного и истории. Не запускайте live-команды без отдельного явного запроса.
Условия запуска и побочные эффекты
описаны в [руководстве по разработке и тестированию](05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

Одиночный TV/mobile runner принимает `--plain-name <substring>` для поиска
подстроки или `--name <regexp>` для полного совпадения имени. В Melos
передавайте selector через JSON-переменную, чтобы сохранить пробелы:

```bash
ANISTAR_TEST_SELECTORS_JSON='["--plain-name","search submits"]' fvm dart run melos run test:e2e:tv --include-private
```

Прямой вызов сохраняет исходные аргументы shell и поддерживает те же значения:

```bash
bash scripts/e2e-tv.sh --plain-name 'search submits'
```

Такой запуск отмечается `scope=filtered` и выводит `PARTIAL PASS` при успехе.
Он не удовлетворяет полному Android E2E gate. Команда `test:e2e` отклоняет
селекторы, чтобы нельзя было незаметно сократить обязательный набор.

`test:e2e:ios` — отдельный опциональный native fixture-runner. Он не входит в
`check` или Android `test:e2e`. Передайте booted Simulator UDID и flavor:

```bash
fvm dart run melos run test:e2e:ios -- <simulator-UDID> <dev|prod> [mobile|tv]
```

Для обычного mobile-сценария третий аргумент можно опустить или указать `mobile`.
Третий аргумент `tv` запускает только iPad layout diagnostic; он требует выбранный
iPad Simulator и задаёт TV profile только тестовому runner. Это не поддержка iPad
или tvOS и не включает автоматический выбор профиля по ширине.

```bash
fvm dart run melos run test:e2e:ios -- <iPad-UDID> dev tv
```

Пропуск означает, что iOS Keychain, AVFoundation и HLS не проверены. Требования
к сертификату fixture и его сохранению в выбранном Simulator описаны в
[E2E tooling](../tool/e2e/README.md#ios-fixture-e2e).

Тесты пакетов находятся в общем корневом `test/`; каждый запуск использует этот
набор один раз. Coverage сохраняется в `coverage/lcov.info`. Задайте другой seed
порядка тестов через `ANISTAR_TEST_SEED`, например:

```bash
ANISTAR_TEST_SEED=1337 fvm dart run melos run test:unit
```

`test:unit` и `test:coverage` исключают тесты с тегом `golden`. Команда
`test:goldens` сравнивает эталонные снимки. Обновляйте их командой
`test:goldens:update` только в рамках явного запроса. После обновления просмотрите diff.

Для точечного теста без общего набора Melos используйте Flutter напрямую:

```bash
fvm flutter test test/app/app_router_recovery_test.dart --reporter=failures-only
```

Android fixture E2E и live-проверки описаны в [руководстве по разработке и
тестированию](05_development_and_testing.md#5-интеграционные-тесты-android-tv-и-телефона).
Полный локальный gate выполняется последовательно: `check`, fixture `test:e2e`,
затем `build:android:prod:apk`. Он не запускает live-сценарий и не обновляет
golden baselines. Результаты и границы проверок описаны в
[руководстве по тестированию](05_development_and_testing.md#10-результаты-и-границы-проверки).

---

## 3. Проверки безопасности

Проверки безопасности запускаются отдельно от `check`:

| Команда | Что проверяет | Сеть |
| :--- | :--- | :--- |
| `security:secrets` | Gitleaks сканирует всю историю коммитов Git | Нет |
| `security:deps` | OSV-Scanner проверяет корневой workspace `pubspec.lock` | Да, запрос к OSV |
| `security:code` | Semgrep применяет локальные правила из `.semgrep/` | Нет |
| `security` | Последовательно запускает три проверки выше | Зависит от этапа |

Запускайте любую команду из корня:

```bash
fvm dart run melos run security
```

Для запуска одной проверки замените `security` на `security:secrets`,
`security:deps` или `security:code`. Подробности о hooks, установке CLI,
пределах сканирования и обработке ошибок приведены в
[руководстве VCS](vcs_guidelines.md#5-локальные-git-hooks) и
[руководстве по разработке и тестированию](05_development_and_testing.md#проверки-безопасности).

---

## 4. Запуск приложения и сборка

Команды `run:*` запускают debug-приложение. Команды `build:*:apk:debug` собирают
debug APK, а `build:*:apk` и `build:*:bundle` — release APK и App Bundle.

| Действие | Команда |
| :--- | :--- |
| Запустить dev | `fvm dart run melos run run:dev -- -d emulator-5554` |
| Запустить prod | `fvm dart run melos run run:prod -- -d emulator-5554` |
| Собрать dev debug APK | `fvm dart run melos run build:android:dev:apk:debug` |
| Собрать prod debug APK | `fvm dart run melos run build:android:prod:apk:debug` |
| Собрать dev release APK | `fvm dart run melos run build:android:dev:apk` |
| Собрать prod release APK | `fvm dart run melos run build:android:prod:apk` |
| Собрать dev release App Bundle | `fvm dart run melos run build:android:dev:bundle` |
| Собрать prod release App Bundle | `fvm dart run melos run build:android:prod:bundle` |
| Собрать dev debug для iPhone Simulator | `fvm dart run melos run build:ios:dev:simulator` |
| Собрать prod debug для iPhone Simulator | `fvm dart run melos run build:ios:prod:simulator` |

`build:android:prod:apk` по умолчанию собирает подписанный APK и требует локальную
конфигурацию `.private/signing/key.properties` и keystore в `.private/`.
Весь `.private/` исключён из Git. Для локальной unsigned compilation используйте
`fvm dart run melos run build:android:prod:apk:unsigned`. Настройка ключа, проверка
сертификата и локальный unsigned режим описаны в
[руководстве Android-подписи](android_signing.md).

Release APK-команда проверяет, что упакованные AOT libraries соответствуют
текущему Flutter build для всех ABI. Приватная `check:apk` повторно запускает
эту проверку для prod release APK. Она не заменяет сборку:

```bash
fvm dart run melos run check:apk --include-private
```

`dev` использует `lib/main_dev.dart` и `env/dev.json`. `prod` использует
`lib/main_prod.dart` и `env/prod.json`. Все запусковые и сборочные команды
вызывают подготовку окружения и передают `--dart-define-from-file`. Подготовка
проверяет dev/prod JSON; отсутствующий prod создаётся из шаблона, существующий
локальный файл сохраняется. Выполнить её отдельно можно командой
`fvm dart run melos run env:prepare`. Публичный шаблон находится в
`env/prod.example.json`.

Android dev/prod имеют отдельные application ID `com.anistar.tv.dev` и
`com.anistar.tv`. Старое приложение с `com.anistar.anistar_tv` остаётся отдельной
установкой; локальные данные не переносятся. iOS использует те же bundle ID и
flavors. iPhone Simulator по умолчанию получает mobile-профиль. Поддержка
физических Apple-устройств, iPad и tvOS не заявлена.

Для базового iOS launch выберите `Anistar TV (Development)` или
`Anistar TV (Production)` в `.vscode/launch.json`, выберите booted iPhone Simulator
и нажмите F5. Оба профиля запускают debug с соответствующим flavor JSON и сначала
выполняют `env:prepare`. Profile Mode доступен только для Android.

Flutter, Gradle и code generation используют общий output. Запускайте их
последовательно. Подробный gate и Android E2E-предусловия приведены в
[руководстве по разработке и тестированию](05_development_and_testing.md#2-проверки-и-сборка).

---

## 5. Генерация и ресурсы

Основная команда последовательно запускает генераторы кода workspace:

```bash
fvm dart run melos run generate
```

`generate` создаёт typed routes и FlutterGen assets/fonts. Генерация выполняется
один раз из корня с `--workspace`; не запускайте её параллельно через
`melos exec`. Generated sources хранятся в Git. После генерации просмотрите diff
и запустите `check`.

| Команда | Назначение |
| :--- | :--- |
| `generate`, `build_runner`, `generate:assets` | Запустить общую генерацию; последние две — совместимые псевдонимы |
| `watch` | Длительно наблюдать за workspace через `build_runner watch` |
| `generate:clean`, `build_runner:clean` | Очистить кэш build_runner; вторая команда — совместимый псевдоним |
| `generate:branding`, `generate:icon`, `generate:splash` | Генерировать Android launcher icon, TV banner и splash, а также iOS AppIcon и LaunchScreen на macOS |
| `generate:e2e-media` (приватная команда) | Пересоздать 360p/720p HLS fixtures; нужен FFmpeg с `libx264` |

Пересоздавайте fixtures явно:

```bash
fvm dart run melos run generate:e2e-media --include-private
```

Не запускайте Flutter icon или splash generators отдельно: общий wrapper
сохраняет размеры TV-ресурсов и Android 12 safe splash. Подробности об Android
и iOS icon и splash находятся в
[руководстве по разработке и тестированию](05_development_and_testing.md#8-иконка-и-android-tv-баннер).
Установка и обслуживание Graphify описаны в
[руководстве Graphify](../tool/graphify/README.md).

---

## 6. Зависимости и обслуживание

Команды просмотра не меняют версии зависимостей. Команды обновления меняют
lockfile; после них проверьте diff и выполните полный `check`.

| Задача | Команда |
| :--- | :--- |
| Получить зависимости строго по lockfile | `fvm dart run melos run get` |
| Посмотреть устаревшие зависимости | `fvm dart run melos run outdated` |
| Показать дерево зависимостей | `fvm dart run melos run deps` |
| Обновить совместимые версии | `fvm dart run melos run upgrade` |
| Обновить ограничения до major-версий | `fvm dart run melos run upgrade:major` |

Обновление Flutter SDK выполняйте по процедуре
[anistar-flutter-update](../.agents/skills/anistar-flutter-update/SKILL.md).
Версию приложения и version-команды описывает
[руководство VCS](vcs_guidelines.md#3-команды-melos).

Применение исправлений и очистка меняют рабочие файлы или build cache. Запускайте
их явно и просматривайте результат:

| Команда | Действие |
| :--- | :--- |
| `fix:check` | Предварительно показать предлагаемые Dart fixes |
| `fix` | Применить Dart fixes |
| `dcm:fix` | Применить DCM fixes |
| `fix:all` | Последовательно применить Dart и DCM fixes |
| `clean` | Очистить результаты Flutter-сборки |
| `clean:all` | Очистить результаты сборки и кэш генераторов |

---

## 7. Остальные команды

| Команда | Действие |
| :--- | :--- |
| `doctor` | Диагностировать Flutter и Android tooling |
| `devices`, `emulators` | Показать подключённые устройства и настроенные эмуляторы |
| `workspace` | Показать корневое приложение и шесть локальных пакетов |
| `vcs:check` | Проверить diff на whitespace-ошибки и conflict markers |
| `version:show` | Показать версию приложения из корневого `pubspec.yaml` |
| `version:check` (приватная команда) | Проверить формат версии без изменений Git |
| `version:plan` | Показать план увеличения версии; передать `patch`, `minor`, `major` или `build` |
| `version:set` | Предпросмотреть заданную версию; запись требует `--write` |
| `graph:update` (приватная команда) | Обновить локальный граф Graphify через найденный interpreter |
| `graph:check` (приватная команда) | Проверить локальный patch Graphify и регрессионные тесты |

У каждой команды своя ответственность; подробности версии и Git находятся в
[руководстве VCS](vcs_guidelines.md). `quality:*` — восемь приватных внутренних
задач Melos. Публичные профили вызывают их напрямую. Не используйте их как
повседневные команды.

Итоговое обновление Graphify в задаче выполняет её владелец один раз после
завершения всех писателей. Другие роли могут использовать `graphify query`,
`path` и `explain` для навигации. Если после обновления меняется индексируемый
файл, владелец запускает update снова после последнего изменения. Команда
`graphify update .` сама по себе не подтверждает полноту semantic fragments
документов.
