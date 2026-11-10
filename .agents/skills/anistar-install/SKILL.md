---
name: anistar-install
description: "Подготовить окружение приложения AniStar TV после clone или на новом компьютере: FVM/Flutter, Melos, Android, проектные CLI и проверки. Также диагностика и восстановление окружения. Не установка агентной фабрики."
---

# AniStar Install

Проектный скилл для установки окружения самого приложения AniStar TV.
Работай в checkout приложения. Фабрику, её роли и сторонние агентские скиллы
не устанавливай и не обновляй. Этот файл не требует подключения к factory.yaml.

Перед подготовкой прочитай [границы и состав окружения](references/project-environment.md).

## 1. Осмотр и состав

Прочитай актуальные файлы проекта:

- `AGENTS.md`, `README.md`;
- `docs/05_development_and_testing.md` — окружение, flavors, проверки;
- `docs/melos_tooling.md` — команды и порядок;
- `docs/vcs_guidelines.md` — hooks, security CLI;
- `.fvmrc`, `pubspec.yaml`, `pubspec.lock`, `dcm_global.yaml`;
- для Android — `android/app/build.gradle.kts`, `android/settings.gradle.kts`,
  `android/gradle/wrapper/gradle-wrapper.properties`;
- для E2E — `tool/e2e/README.md`.

Определи режим: подготовка, диагностика или восстановление. Обновление SDK и
пакетов — отдельная задача `anistar-flutter-update`; установка сохраняет pins.
По умолчанию готовь Android TV/mobile. iOS Simulator — только по запросу, на
macOS с Xcode, по документации проекта. Отсутствие iOS toolchain не блокирует Android.

Проверь ОС/CPU/shell, права, пути и версии существующих инструментов, Git status,
`core.hooksPath`, SDK, устройства и доступность нужных лицензий. На Windows
различай native, Git Bash и WSL; не смешивай SDK/Python/PATH разных сред.
Команда version/doctor не должна незаметно скачивать отсутствующий SDK.

| Компонент | Как определить необходимость и версию |
| --- | --- |
| Git, Bash и утилиты shell | Фактические scripts проекта; проверить доступность из среды агента |
| FVM, Flutter, Dart | Flutter из `.fvmrc`; Dart входит в закреплённый Flutter, отдельный глобальный Dart не нужен |
| Melos и Dart-пакеты | Корневые pubspec.yaml/pubspec.lock; Melos запускается через `fvm dart run melos`, не глобально |
| Java, Android SDK/NDK | Требования Gradle и закреплённого Flutter; использовать Gradle wrapper, не глобальный Gradle |
| Python | Требования `scripts/with_python.sh` и E2E; сейчас 3.10+, при необходимости `ANISTAR_PYTHON` |
| DCM | dcm_global.yaml и docs; проверить CLI и действующую лицензию отдельно |
| Lefthook, Gitleaks, OSV-Scanner, Semgrep | docs/vcs_guidelines.md, lefthook.yml, scripts/security_*.sh |
| Эмуляторы TV/mobile | Для полного fixture E2E; актуальные API/имена в tool/e2e/README.md |
| FFmpeg с libx264 | Только если пользователь просит пересоздавать media fixtures; готовые fixtures его не требуют |

Способы установки бери из официальных инструкций выбранных поставщиков для ОС:
найди ссылки в проектных документах, при необходимости открой официальные docs.
Не переносить случайные команды Homebrew на Linux/Windows. Не устанавливать
GitHub CLI, Node, Graphify или другие инструменты без конкретной проектной потребности.

Покажи краткий список: оставить / установить / восстановить / заблокировано,
версии и изменения PATH, SDK, hooks и локальных файлов. Существующее разрешение
пользователя действует; уточняй только недостающий выбор или расширение объёма.
Диагностика заканчивается отчётом без установки. Сохраняй совместимые установки,
пользовательские настройки и секреты. Login, trust и лицензии — штатно, без секретов
в чате. Не обновляй всю систему и не повторяй неизменившийся неудачный installer.

## 2. SDK и workspace

После подготовки FVM и необходимых системных инструментов выполняй последовательно:

```bash
fvm install
fvm flutter --version --machine
fvm flutter pub get --enforce-lockfile
fvm dart run melos --version
fvm dart run melos bootstrap --enforce-lockfile
fvm dart run melos run env:prepare
fvm dart run melos run generate
```

Проверь `.fvm/flutter_sdk` и версию против `.fvmrc`. Если ссылка не создана,
используй актуальный `fvm use --help` для того же pin без повторного pub get.
Не обходи FVM глобальным Flutter. При ошибке lockfile выясни причину, не выполняй
pub upgrade. Generated files руками не исправляй; после генерации проверь diff.

`env:prepare` сохраняет существующий env/prod.json и создаёт отсутствующий из
env/prod.example.json. Не подставляй реальные секреты и не коммить локальный файл.
Проверь PATH из среды агента и нового shell; GUI может не наследовать терминальный
PATH. Машинные пути не записывай в tracked configs.

## 3. Android и устройства

Установи Android Studio либо command-line tools по официальной инструкции.
Настрой фактические ANDROID_HOME, JAVA_HOME и PATH; SDK Manager и Gradle могут
требовать разные Java runtimes. Проверь Java, которую реально использует Flutter.
Версии JDK/NDK бери из текущего Gradle, compileSdk/build-tools — из закреплённого
Flutter/Gradle. Не подставляй latest и не копируй чужой android/local.properties.

Установи нужные platform-tools, command-line tools, platforms/build-tools и NDK;
emulator/system images — для выбранного E2E. CMake нужен только при требовании
native plugins. Package IDs сверяй с `sdkmanager --list`, заключай IDs с `;` в кавычки.
Пользователь принимает лицензии штатно через `fvm flutter doctor --android-licenses`.
Проверь `fvm flutter doctor -v`; не отвечай `yes` на лицензии автоматически.

Для полного Android E2E подготовь два отдельных AVD по tool/e2e/README.md:
TV и mobile, с образами под CPU хоста. TV требует настоящего TV image/UI mode,
D-pad и keyboard, не phone image с TV skin. Существующие подходящие AVD сохраняй;
не применяй wipe/reset/force. Проверяй ускорение, boot readiness и выбор устройства
через проектный `tool/e2e/emulator_selection.py` по инструкции E2E.
Если виртуализация или нужный образ недоступны, отметь E2E как заблокированный,
продолжи независимую подготовку. Не выдавай наличие AVD за успешный запуск E2E.

## 4. Проектные инструменты и проверки

Настрой DCM, security CLI и Lefthook по docs/vcs_guidelines.md. До установки hooks
сохрани существующую конфигурацию и core.hooksPath; не заменяй чужие hooks.
Python CLI изолируй подходящим способом, проверяй фактический interpreter.
Полный Gitleaks scan требует Git history: shallow clone отмечай отдельно;
получение истории выполняй в разрешённом объёме из существующего remote.

Если нужны Dart/DCM MCP, настрой только выбранный host по фактической конфигурации
проекта и официальным инструкциям серверов. Сохрани другие MCP; проверь handshake.
Это необязательная интеграция редактора, не условие сборки приложения.

Для полного окружения запускай последовательно:

```bash
fvm dart run melos run security
fvm dart run melos run check
fvm dart run melos run test:e2e
fvm dart run melos run build:android:prod:apk
```

Сверь команды с актуальным docs/melos_tooling.md. Security идёт отдельно от check;
OSV обращается в сеть и передаёт package metadata. Flutter/Gradle/codegen не
запускаются параллельно. Для частичного состава выполняй доступные проверки,
не устанавливая исключённое пользователем ради зелёного результата.

Findings анализатора, падение теста или отсутствие signing/prod inputs отделяй от
ошибки установки. Не исправляй код приложения, не ослабляй правила, не создавай
ключи подписи и не обновляй goldens ради успешной проверки. Live-тесты, публикация,
commit и push не входят в установку. Fixtures автоматически не пересоздавай.

Итог в чате: фактические версии, готовность SDK/workspace/hooks, результаты проверок,
путь APK только при успешной сборке, непроверенные возможности и действия человека.
Различай «установлено», «настроено» и «проверено». Отдельный отчёт, документацию,
спецификации или записи в фабрику для результата этого скилла не создавай.
