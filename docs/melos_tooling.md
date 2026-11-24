# 🛠️ Команды Melos | AniStar TV

Запускайте команды из корня через `fvm dart run melos run <команда>`. [Корневой pubspec](../pubspec.yaml) задаёт полный каталог скриптов и закрепляет Melos 7.8.1. Ограничение `cli_util ^0.4.1` в `flutter_launcher_icons` блокирует Melos 7.8.2 и новее.

<a id="содержание"></a>

## 1. Подготовка и быстрый запуск

Android требует FVM, Flutter из [.fvmrc](../.fvmrc), JDK 17 и Android SDK. iOS Simulator требует macOS и Xcode. За настройкой устройств и полной установкой обратитесь к [anistar-install](../.agents/skills/anistar-install/SKILL.md).

Версии Gradle, AGP и Kotlin закреплены в [Gradle wrapper](../android/gradle/wrapper/gradle-wrapper.properties) и [settings.gradle.kts](../android/settings.gradle.kts). `android.builtInKotlin=false` сохраняет общий режим Kotlin для приложения и `share_plus`. Меняйте настройку после миграции плагинов по [руководству Flutter](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin).

```bash
fvm install
fvm flutter pub get --enforce-lockfile
fvm dart run melos bootstrap --enforce-lockfile
fvm dart run melos run run:dev
```

`fvm dart run melos run --list` выводит публичные скрипты. Приватным передавайте `--include-private` перед разделителем `--`. Аргументы после `--` получает скрипт.

Melos использует `.fvm/flutter_sdk`, поддерживает `--sdk-path` и `MELOS_SDK_PATH`. Wrapper’ы проекта принимают `ANISTAR_FLUTTER_SDK` для другого пути к тому же закреплённому SDK. `scripts/with_python.sh` подбирает Python 3.10+ или использует `ANISTAR_PYTHON`. Для прямого запуска скриптов настройте `PATH`.

Перед первым `test:tooling` или `check` подготовьте dev-окружение фабрики на Python 3.14 командой `.factory/tooling/bin/cli setup --dev`. Проверка использует готовое окружение. См. [настройку Python фабрики](../.factory/skills/factory-install/references/integration.md#interpreter).

Bootstrap запускает [необязательную подготовку Graphify](../tool/graphify/README.md). Отсутствие Graphify допустимо. Ошибка версии, патча или sidecar найденной установки останавливает bootstrap. Для Git hooks см. [настройку Lefthook](git_hooks_and_security.md#установка).

---

<a id="2-проверки"></a>

## 2. Проверки и тесты

`check` последовательно проверяет SDK и lockfile, формат, analyzer, DCM, unit/widget/architecture с coverage, goldens, Python tooling и версию. Первая ошибка останавливает профиль. Analyzer использует `--fatal-infos`, DCM — `--fatal-style` и `--fatal-warnings`. Требование к DCM задано в [dcm_global.yaml](../dcm_global.yaml). Проверка читает текущее рабочее дерево и сохраняет формат и baselines. `check:flutter` запускает формат, analyzer, unit coverage и golden comparison после подготовки SDK и lockfile.

| Команда | Назначение |
| :--- | :--- |
| `format`, `format:check` | Изменить формат Dart-файлов или проверить его |
| `analyze`, `dcm` | Повторить соответствующий статический этап |
| `test:unit`, `test:coverage` | Один корневой набор `test/` без тега `golden`, coverage в `coverage/lcov.info` |
| `test:goldens`, `test:goldens:update` | Сравнить или явно обновить golden-эталоны |
| `test:tooling` | Python-регрессии проекта и фабрики |
| `test:e2e` | Полные Android TV и mobile fixture suites |
| `test:e2e:tv`, `test:e2e:mobile` | Приватные команды для диагностики одной платформы |
| `test:e2e:ios` | Опциональный iOS fixture E2E. Аргументы `<simulator-UDID> <dev\|prod> [mobile\|tv]` |

[Полный gate](05_development_and_testing.md#2-проверки-и-сборка), [обновление goldens](05_01_widget_and_golden_tests.md#3-проверка-и-обновление-эталонов) и [live-команды и их побочные эффекты](05_02_live_testing.md) описаны в отдельных разделах. Android/iOS runners, настройки и артефакты описаны в [E2E tooling](../tool/e2e/README.md#запуск-runners).

Хост-команды `test:unit`, `test:coverage`, `test:goldens`, `test:goldens:update` принимают пути `.dart`, `--plain-name` (подстрока) и `--name` (регулярное выражение имени). Отдельные Android fixture runners принимают только селектор имени. Для значения с пробелами или shell-символами передайте непустой JSON-массив строк в `ANISTAR_TEST_SELECTORS_JSON`. Melos 7.8.1 пропускает обычные аргументы через shell и теряет границы таких значений.

```bash
fvm dart run melos run test:unit -- test/packages/features/search/search_bloc_test.dart
ANISTAR_TEST_SELECTORS_JSON='["--plain-name","empty query"]' fvm dart run melos run test:unit
```

Используйте либо JSON, либо селекторы после `--`. У прямого Bash runner кавычки shell сохраняют исходные аргументы. Остальные флаги Flutter test, включая `--update-goldens`, хост-профили отклоняют. `check`, `check:flutter` и `test:e2e` требуют полных наборов и отклоняют JSON-селекторы. Успешный результат `scope=filtered` годится для диагностики.

Порядок тестов задаёт `ANISTAR_TEST_SEED`, по умолчанию `20261010`. Хост-профиль готовит SDK и lockfile один раз. Ищите `summary.json`, `junit.xml`, `flutter-events.jsonl` и полный лог в каталоге запуска под `build/quality/`. Runner считает пустой или незавершённый тестовый запуск ошибкой. Diff goldens сохраняется рядом с тестом в `failures/`.

---

## 3. Проверки безопасности

`security` отдельно от `check` запускает Gitleaks, OSV-Scanner и Semgrep. OSV-Scanner передаёт метаданные пакетов из корневого `pubspec.lock` в OSV. [Команды, установка и ограничения сканеров](git_hooks_and_security.md#3-проверки-безопасности).

---

## 4. Запуск приложения и сборка

| Flavor | Entry point и defines | Android application ID и iOS bundle ID |
| :--- | :--- | :--- |
| `dev` | `lib/main_dev.dart`, `env/dev.json` | `com.anistar.tv.dev` |
| `prod` | `lib/main_prod.dart`, `env/prod.json` | `com.anistar.tv` |

`env:prepare` проверяет оба JSON и создаёт отсутствующий локальный `env/prod.json` из [шаблона](../env/prod.example.json). Существующий файл сохраняется. Wrapper вызывается при запуске и сборке и передаёт `--dart-define-from-file` для выбранного flavor.

| Действие | Команда Melos |
| :--- | :--- |
| Запустить debug на указанном устройстве | `run:dev -- -d emulator-5554` или `run:prod -- -d emulator-5554` |
| Собрать Android debug APK | `build:android:dev:apk:debug` или `build:android:prod:apk:debug` |
| Собрать Android release APK / App Bundle | `build:android:dev:apk` / `build:android:dev:bundle`, `build:android:prod:apk` / `build:android:prod:bundle` |
| Собрать iPhone Simulator debug | `build:ios:dev:simulator`, `build:ios:prod:simulator` |

APK находятся в `build/app/outputs/flutter-apk/`. Release APK проверяет свежесть AOT/JNI для всех ABI. `check:apk --include-private` повторяет проверку готового prod APK. Ключ и локальная unsigned compilation описаны в [Android-подписи](android_signing.md).

Для базового iOS запуска выберите запущенный iPhone Simulator и **Anistar TV (Development)** или **Anistar TV (Production)** в VS Code. Эти профили используют debug и соответствующий JSON. VS Code Profile Mode доступен для Android.

---

## 5. Генерация и ресурсы

`fvm dart run melos run generate` генерирует typed routes и FlutterGen assets/fonts один раз для workspace. Запускайте последовательно с Flutter и Gradle. Generated sources хранятся в Git. Меняйте исходники, повторяйте генерацию и проверяйте diff. Публичные импорты ресурсов описаны в [UI Kit](../lib/packages/ui_kit/README.md#4-ресурсы).

| Команда | Назначение |
| :--- | :--- |
| `build_runner`, `generate:assets` | Псевдонимы `generate` |
| `watch`, `generate:clean` | Наблюдать за workspace или очистить кэш генерации |
| `generate:branding`, `generate:icon`, `generate:splash` | Общий wrapper экспорта icon/banner/splash. Нужны macOS и `sips`. |
| `generate:e2e-media --include-private` | Пересоздать HLS fixtures 360p/720p. Нужен FFmpeg с `libx264`. |

---

## 6. Зависимости и обслуживание

`get` сверяет lockfile, `outdated` показывает обновления, `deps` — дерево зависимостей. `upgrade` обновляет зависимости, `upgrade:major` может изменить ограничения. После обновления проверьте diff и выполните `check`. Процедура обновления SDK описана в [anistar-flutter-update](../.agents/skills/anistar-flutter-update/SKILL.md).

`fix:check` показывает Dart fixes. `fix`, `dcm:fix` и `fix:all` меняют исходники. `clean` очищает результаты сборки, `clean:all` также очищает кэш генераторов.

---

## 7. Остальные команды

- `doctor`, `devices`, `emulators`, `workspace` показывают состояние Flutter, устройства, AVD и пакеты.
- `version:*` и `vcs:check` описаны в [руководстве VCS](vcs_guidelines.md#3-команды-melos).
- Приватные `graph:update` и `graph:check` используют Python 3.10+ из `PATH`. Настройка и проверка патча описаны в [Graphify tooling](../tool/graphify/README.md).
- Приватные `quality:*` служат внутренними точками входа. Для повседневных проверок используйте публичные профили выше.
