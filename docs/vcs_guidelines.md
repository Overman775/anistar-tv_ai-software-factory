# 🌿 Git и версии | AniStar TV

Это руководство описывает ветки и сообщения коммитов, версию Android-приложения и подготовку релиза. Версию и публикацию меняют только в рамках соответствующего явного поручения.

## 1. Ветки и изменения

Проект использует Conventional Commits и ветку `main`. Ветка `develop` отсутствует. CI/CD и Fastlane не настроены.

Новая задача обычно ответвляется от актуального `main`. Используйте осмысленные
`feature/<description>`, `fix/<description>`, `chore/<description>` или имеющийся
`codex/<description>`. Для отдельной стабилизации допустимы `release/vX.Y.Z` и
`hotfix/vX.Y.Z`. Создавать такие ветки для обычного tooling изменения не требуется.

Если работа действительно ведётся стеком веток, явно согласуйте базу/цель каждой
PR. Ветки задач в общей ветке фичи сливаются без squash, чтобы сохранить SHA
зависимостей. Готовая логическая задача в `main` может использовать squash.
В проекте нет проверенного обязательного GitLab/epic/develop процесса.

Коммит и заголовок PR: `type(scope): description`. Типы: `feat`, `fix`,
`refactor`, `docs`, `style`, `test`, `chore`, `perf`, `build`.

Scope означает имя реально изменённого пакета (`anistar_tv`, `anistar`, `core`,
`networking`, `storage`, `app_logging`, `ui_kit`). `root` обозначает общее tooling.
Фичи под `lib/packages/features` не отдельные pub-пакеты: scope `anistar_tv`.
ID задачи добавляется только если такая задача существует.

Примеры: `fix(anistar_tv): preserve player focus`, `chore(root): add Melos tooling`.
При squash проверьте итоговое сообщение. `vcs:check` проверяет whitespace diff.
Команда не навязывает branch names и не изменяет Git.

---

## 2. Единая версия приложения

Корневой `pubspec.yaml`: `version: X.Y.Z+N` служит единственным источником версии
Android приложения. CHANGELOG описывает конкретный выпуск. README содержит
назначение и запуск проекта. Пакеты workspace не публикуются самостоятельно.
Их существующие `0.0.1` сохраняются.
Не запускайте общее bump всех пакетов ради версии APK.

- Исправление совместимого поведения: PATCH.
- Новый совместимый функционал: MINOR.
- Несовместимое изменение пользовательского/публичного контракта: MAJOR.
- Docs/test/style/chore/refactor сами по себе не требуют bump приложения.

Conventional Commits помогают выбирать уровень, но не запускают автоматический
релиз. Проект уже 1.x и использует стабильное версионирование.
Стабильная версия использует три числа без leading zeros и prerelease суффиксов.

`N` должно быть положительным целым. При новом распространяемом артефакте оно строго растёт,
в том числе при сохранении X.Y.Z. Локальные повторные сборки/проверки версию не меняют.
В отсутствие CI счётчик обновляется явно владельцем релиза.

---

## 3. Команды Melos

```bash
fvm dart run melos run version:show
fvm dart run melos run version:check --include-private
fvm dart run melos run version:plan -- patch
fvm dart run melos run version:plan -- minor
fvm dart run melos run version:plan -- major
fvm dart run melos run version:plan -- build
# Пример будущей версии; по умолчанию только preview:
fvm dart run melos run version:set -- --app-version 1.1.2 --build-number 5
```

`plan` предлагает текущий build + 1. `set` отклоняет уменьшение X.Y.Z и любой
нерастущий build. По умолчанию `set` выполняет dry-run. Только после явного поручения
подготовить новую версию добавьте `--write`: обновится только корневой pubspec.
Пакеты, lockfile, CHANGELOG, Git index/commits/tags/remotes не меняются командой.

CHANGELOG заполняется отдельно по реально завершённым изменениям. Проверки
version tooling тестируют запись в temporary directory, а не в checkout.

`version:check` — приватная команда. Запускайте её явно с `--include-private`.
Остальные команды `version:*` доступны обычным способом. Встроенный `melos version` рассчитан на
автоматическое версионирование пакетов и может писать changelog/commit/tag.
Это не выбранный workflow приложения.
[Поведение встроенной команды](https://melos.invertase.dev/commands/version).

---

## 4. Подготовка будущего релиза

Только по отдельному поручению владельца: проверить исходную ветку и diff,
выбрать X.Y.Z/N, сделать preview, явно записать версию, заполнить CHANGELOG,
пройти `check`, fixture E2E обеих платформ и обычную release APK сборку с freshness
проверкой. Production APK-команда подписывает локальным ключом и проверяет его
публичный pin; команда unsigned compilation не создаёт готовый production-релиз. Перед
распространением проверьте signing config и вручную проверьте приложение на
физическом TV. Подробнее см. [руководство Android-подписи](android_signing.md).
Tag `vX.Y.Z`, commit, PR/merge, push и публикация выполняются отдельно. Настройка
tooling и локальная сборка не разрешают выполнять их.

---

## 5. Локальные Git hooks

Lefthook запускает локальные проверки перед commit и push. Graphify отдельно
устанавливает native hooks после commit, checkout, merge и rewrite, чтобы
обслуживать локальный граф. Локальные hooks не обеспечивают серверное
требование: сервер Git не запускает hooks из checkout.
`pre-commit` проверяет staged diff на whitespace-ошибки и офлайн сканирует
staged изменения на secrets. Проверка secrets также запрещает staged локальные
credentials и Android signing files. Закреплённый Dart SDK проверяет формат
Dart-файлов, которые Lefthook передал как изменённые.
Formatter читает содержимое из рабочего дерева и не меняет файлы или index.
Частично staged файл проверяется целиком по текущему рабочему содержимому, которое
может отличаться от содержимого в index.

`pre-push` сначала сканирует всю локальную committed историю на secrets, затем
запускает полный `check` на текущем рабочем дереве.
Чистое дерево не требуется. Незакоммиченные изменения могут повлиять на результат,
поэтому локальный check может отличаться от отправленного commit. В `check` входит
сравнение golden baselines, но не их обновление. Hooks не запускают fixture E2E,
сборку APK или live-проверки. Состав `check` описан в
[руководстве Melos](melos_tooling.md#2-проверки-и-тесты).

### Установка

Установите FVM и SDK проекта до запуска Melos-команд. Установите Lefthook через
Homebrew, чтобы запускать Git hooks. Для сканирования secrets, зависимостей и
кода установите Gitleaks, OSV-Scanner и Semgrep:

```bash
brew install lefthook gitleaks osv-scanner semgrep
```

Установленные CLI обязательны для соответствующих проверок. Если нужный CLI
отсутствует, проверка завершается ошибкой.

До установки проверьте существующие custom hooks и настройку `core.hooksPath`.
Сохраните их конфигурацию и действия. Не используйте принудительную установку
или сброс существующих hooks.

После clone один раз из корня проекта установите Git hooks:

```bash
lefthook install
```

Graphify необязателен. Если он установлен, отдельно выполните `graphify hook install`
из корня проекта. Эта команда устанавливает hooks `post-commit`, `post-checkout`,
`post-merge` и `post-rewrite`, merge driver `graphify` и правило
`graphify-out/graph.json merge=graphify` в `.gitattributes`. Эти hooks дополняют
Lefthook и не изменяют его `pre-commit` и `pre-push`. Подробности приведены в
[руководстве Graphify](../tool/graphify/README.md).

Полный `check` использует закреплённый Flutter SDK, DCM и Python 3.10+ для Python
tooling/version задач. Подготовка среды описана в
[руководстве Melos](melos_tooling.md#1-подготовка-и-быстрый-запуск).

### Ручной запуск

Из корня проекта можно проверить конфигурацию или выполнить hook-команды отдельно:

```bash
lefthook validate
bash scripts/lefthook.sh run pre-commit
lefthook run pre-push --force
fvm dart run melos run check
```

Для ручного `pre-commit` используйте wrapper: он отключает auto-stash Lefthook,
чтобы проверка читала рабочие файлы без скрытия unstaged изменений. Полный профиль
запускайте через `fvm dart run melos run check`; эту же команду вызывает `pre-push`.
Lefthook содержит только Git hooks. При ручном запуске `pre-push` вне push-контекста
используйте `--force`, если Lefthook пропускает hook без push-файлов.
