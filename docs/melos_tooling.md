# 🛠️ Melos: локальная точка запуска | AniStar TV

Это руководство описывает подготовку среды, команды Melos и границы локальных проверок AniStar TV. Команды Melos запускаются из корня проекта через закреплённую локальную зависимость.

## 1. Подготовка

Melos **7.8.0** закреплён в `dev_dependencies` и `pubspec.lock`. Конфигурация находится в корневом `pubspec.yaml`. Существующий Dart pub workspace сохранён: корневое приложение и шесть пакетов. `useRootAsPackage` включает приложение в список Melos. Переносить приложение в `app/` не требуется.

Нужны FVM, SDK из `.fvmrc`, JDK 17, Android SDK, Python 3.10+, DCM из
`dcm_global.yaml`. Для нативных ресурсов нужен macOS `sips`, для HLS fixtures нужен
FFmpeg с libx264. Graphify необязателен и использует собственный Python.

Melos Python/E2E-команды выбирают доступный Python 3.10+ (`python3` или
`python3.14` … `python3.10`). Системный macOS 3.9 пропускается. Явный override:
`ANISTAR_PYTHON=/path/to/python3`. Этот выбор действует также для вложенных tools.
Глобальный PATH не изменяется. Для прямого вызова E2E scripts подготовьте PATH сами.

```bash
fvm install
fvm flutter pub get --enforce-lockfile
fvm dart run melos bootstrap --enforce-lockfile
fvm dart run melos run --list
```

Все примеры ниже выполняются из корня. `fvm dart run melos` всегда запускает
закреплённую локальную зависимость. Интерфейс `fvm exec melos`
также поддерживается, если в PATH установлен Melos launcher:

```bash
fvm dart pub global activate melos 7.8.0
# Добавить pub-cache/bin в PATH по инструкции Dart, если ещё не добавлен.
fvm exec melos run check
```

Глобальная активация не нужна для `fvm dart run melos`. Bootstrap не устанавливает
Git hooks, не генерирует IDE-файлы и не обновляет версии. [Конфигурация Melos](https://melos.invertase.dev/configuration/overview).

---

## 2. Запуск, сборка и устройства

| Команда после `fvm dart run melos run` | Действие |
| --- | --- |
| `run:dev` / `run:prod` | Debug-запуск соответствующего entry point |
| `build:android:dev:apk:debug` / `build:android:prod:apk:debug` | Debug APK |
| `build:android:dev:apk` / `build:android:prod:apk` | Release APK и проверка AOT freshness |
| `build:android:dev:bundle` / `build:android:prod:bundle` | Локальный release AppBundle |
| `check:apk` | Повторная проверка обычного prod release APK |
| `doctor`, `devices`, `emulators` | Диагностика SDK и перечень устройств/AVD |

`dev` использует `lib/main_dev.dart` и `env/dev.json`. `prod` использует
`lib/main_prod.dart`. `env/prod.json` подставляется только если существует,
иначе остаётся default mirror. Образец: `env/prod.example.json`. Локальный
production JSON не содержит тестовые credentials.

Скрипт сверяет SDK с `.fvmrc`
и поддерживает `ANISTAR_FLUTTER_SDK`. Для Melos SDK override используйте `--sdk-path` /
`MELOS_SDK_PATH`. Использовать override можно только с тем же закреплённым SDK.

```bash
fvm dart run melos run run:dev -- -d emulator-5554
fvm dart run melos run build:android:prod:apk
```

Melos 7.8 перехватывает вложенные `--help` / `--version` даже после `--`.
Поэтому справку underlying tools открывайте напрямую (`fvm dart run build_runner
watch --help`, `fvm flutter pub upgrade --help`). Для version:set используйте
`--app-version`. Обычные device/build аргументы передаются через `--`.

После integration tests выполняйте обычную build-команду: она сохраняет pub
lifecycle и обновляет plugin registrar. APK freshness сверяет AOT, JNI staging,
merge, stripped output и APK для всех ABI. Проверка встроена в обычный release
APK. Для split-per-ABI используйте отдельную проверку конкретных артефактов.
Текущая тестовая подпись пригодна для локальной проверки. Этот интерфейс не
настраивает распространение приложения.

---

## 3. Проверки

| Команда | Действие |
| --- | --- |
| `check` | SDK/lockfile → format → analyzer → DCM → unit coverage → goldens → Python tooling → version check |
| `check:flutter` | Локальный профиль без DCM. Соответствует прежнему `check.sh ci` |
| `analyze`, `dcm` | Строгие проверки приложения, пакетов и тестов |
| `format:check`, `format` | Проверка формата / явное форматирование |
| `test:unit`, `test:coverage` | Общие unit/widget/architecture и `coverage/lcov.info` |
| `test:goldens`, `test:goldens:update` | Сравнение / явное обновление baselines |
| `test:tooling` | Python quality, E2E runners, version tooling и graphify regressions, если настроен его interpreter |
| `test:e2e` | Последовательный TV + mobile fixture E2E |
| `test:e2e:tv`, `test:e2e:mobile` | Отдельная Android fixture suite |
| `test:e2e:live` | Явный live TV-сценарий с тестовым аккаунтом |
| `test:network:live` | Явная host-проверка реальной сети/входа |
| `vcs:check`, `version:check` | Проверка diff / формата версии в корневом pubspec |

Тесты всех пакетов находятся в корневом `test/`. Melos не запускает одну suite
семь раз и не пропускает проверки отсутствующих package-local `test/`.
Coverage уже общий. Дополнительное объединение package LCOV не требуется.
Профиль `check` использует существующий fail-fast quality gate, fatal infos/DCM
warnings и seed `20261010`. Seed меняется через `ANISTAR_TEST_SEED`.

```bash
ANISTAR_TEST_SEED=1337 fvm dart run melos run test:unit
fvm dart run melos run test:e2e:tv -- emulator-5554
fvm dart run melos run test:e2e:mobile -- emulator-5556
fvm dart run melos run test:e2e -- emulator-5554 emulator-5556
# Точечный тест, обход общей suite:
fvm flutter test test/app/app_router_recovery_test.dart --reporter=failures-only
```

Default AVD: `anistar_tv_e2e` и `anistar_mobile_e2e`. Overrides:
`ANISTAR_TV_AVD` / `ANISTAR_MOBILE_AVD`. Их нужно предварительно запустить.
E2E-скрипты проверяют identity/profile/D-pad и сохраняют JUnit/JSON/логи в
`build/e2e/`. Одинаковый AVD для обеих платформ отклоняется. TV/mobile выполняются
последовательно из-за общего Flutter/Gradle output.

Live запускайте отдельно с локальным `env/live-test.local.json`. Не передавайте
credentials в истории команд. Live E2E меняет серверную историю просмотренных
серий тестового аккаунта. Не включайте его в обычный `check`. Подготовка и ограничения описаны в
[руководстве тестирования](05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

Обновление golden baselines требует просмотра различий. Comparison не меняет baselines.

---

<a id="генерация-и-обслуживание"></a>

## 4. Генерация и обслуживание

| Команда | Действие |
| --- | --- |
| `generate`, `build_runner`, `generate:assets` | `build_runner build --workspace`: routes + FlutterGen assets/fonts и project format routes |
| `watch` | Длительный `build_runner watch --workspace` |
| `generate:clean`, `build_runner:clean` | Очистка cache build_runner |
| `generate:branding`, `generate:icon`, `generate:splash` | Общий экспорт launcher/adaptive icons, TV banner и safe splash |
| `generate:e2e-media` | Пересоздать 360p/720p HLS fixtures через FFmpeg |
| `get`, `outdated`, `deps`, `workspace` | Lockfile resolution, updates, дерево зависимостей, список пакетов |
| `upgrade`, `upgrade:major` | Явное обновление зависимостей / major constraints |
| `fix:check`, `fix`, `dcm:fix`, `fix:all` | Preview Dart fixes / явное применение исправлений |
| `clean`, `clean:all` | Очистить build / build и generator cache |
| `graph:update`, `graph:check` | Обновить локальный граф / проверить extractor patch и regressions |

Генерация выполняется один раз из корня через `--workspace`, а не параллельным
`melos exec`. Параметр `generate --scope=pkg` не выбирает
часть workspace для root script. Для точечного изменения используйте прямой
`build_runner` в нужном пакете. Generated sources сохраняются в Git. После
генерации просматривайте diff и выполняйте `check`.

Иконки и splash нельзя пересоздавать сырым generator вызовом: общий wrapper
сохраняет размеры TV, banner и ссылку на Android 12 safe-area drawable.
Aliases `generate:icon` и `generate:splash` намеренно обновляют полный согласованный
набор нативных ресурсов. Генерацию HLS выполняют отдельно при обслуживании fixture,
не в составе обычных тестов. Явно запускайте `fix`, upgrades, clean и golden update.
Они не входят в bootstrap/check. Порядок обновления SDK описывает локальный
[anistar-flutter-update](../.agents/skills/anistar-flutter-update/SKILL.md).

---

## 5. Состав и границы tooling

Сохранены узнаваемые analyze/format/fix/DCM/check, tests/coverage,
build_runner/generate/watch/clean, dependency commands, icon/splash и
run/build platform-flavor-artifact интерфейсы. Staging/production адаптированы
к существующим dev/prod. Android E2E добавлен поверх готовых native fixture runners.
Версия приложения и Conventional Commits адаптированы в [VCS](vcs_guidelines.md).

Исключения по фактам проекта:

- iOS/IPA/Pods: поддерживаемая платформа: Android/Android TV.
- Fastlane, stores, CI jobs, CI diff filters и автоматический build counter: отсутствуют.
- SVG→vec, SVG hooks/statistics: assets здесь PNG/OTF, SVG pipeline отсутствует.
- OpenAPI/swagger/normalization и destructive API regeneration: используется HTML клиент.
- gen-l10n: отсутствуют l10n.yaml/ARB и соответствующая localization инфраструктура.
- dependency_validator: существующие architecture
  tests проверяют package/public API boundaries, новой зависимости без нужды нет.
- per-package test discovery/LCOV merge и автоопределение concurrency: suite центральная.
  Unit concurrency уже 4, goldens 1. Существующие ограничения сохранены.
- Отдельный context compiler не входит в комплект Factory.
- принудительные ID внешней системы задач, develop/epic pipeline, hooks и чужой коммуникационный стиль:
  не требуются локальному Git workflow AniStar TV.

Порядок проверок и границы выводов: [Разработка и тестирование](05_development_and_testing.md#10-результаты-и-границы-проверки). Результаты конкретного запуска и пропуски указываются в итоговом отчёте задачи.
