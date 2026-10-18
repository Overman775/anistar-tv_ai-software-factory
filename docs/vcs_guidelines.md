# Git и версии | AniStar TV

Conventional Commits, единая версия приложения, отдельный build number
и явная подготовка релиза. Здесь существующая
основная ветка — `main`; `develop`, CI/CD и Fastlane не настроены.

## Ветки и изменения

Новая задача обычно ответвляется от актуального `main`. Используйте осмысленные
`feature/<description>`, `fix/<description>`, `chore/<description>` или имеющийся
`codex/<description>`. Для отдельной стабилизации допустимы `release/vX.Y.Z` и
`hotfix/vX.Y.Z`; создавать их для обычного tooling изменения не требуется.

Если работа действительно ведётся стеком веток, явно согласуйте базу/цель каждой
PR. Ветки задач в общей ветке фичи сливаются без squash, чтобы сохранить SHA
зависимостей; готовая логическая задача в `main` может использовать squash.
В проекте нет проверенного обязательного GitLab/epic/develop процесса.

Коммит и заголовок PR: `type(scope): description`. Типы: `feat`, `fix`,
`refactor`, `docs`, `style`, `test`, `chore`, `perf`, `build`.
Scope — имя реально изменённого пакета (`anistar_tv`, `anistar`, `core`,
`networking`, `storage`, `app_logging`, `ui_kit`); `root` — общее tooling.
Фичи под `lib/packages/features` не отдельные pub-пакеты: scope `anistar_tv`.
ID задачи добавляется только если такая задача существует.
Примеры: `fix(anistar_tv): preserve player focus`, `chore(root): add Melos tooling`.
При squash проверьте итоговое сообщение. `vcs:check` проверяет whitespace diff;
оно не навязывает branch names и не изменяет Git.

## Единая версия приложения

Корневой `pubspec.yaml`: `version: X.Y.Z+N` — единственный источник версии
Android приложения. README отражает X.Y.Z; CHANGELOG описывает конкретный выпуск.
Пакеты workspace не публикуются самостоятельно; их существующие `0.0.1` сохраняются.
Не запускайте общее bump всех пакетов ради версии APK.

- Исправление совместимого поведения: PATCH.
- Новый совместимый функционал: MINOR.
- Несовместимое изменение пользовательского/публичного контракта: MAJOR.
- Docs/test/style/chore/refactor сами по себе не требуют bump приложения.

Conventional Commits помогают выбирать уровень, но не запускают автоматический
релиз. Проект уже 1.x и использует стабильное версионирование.
Стабильная версия использует три числа без leading zeros и prerelease суффиксов.
`N` — положительное целое; при новом распространяемом артефакте оно строго растёт,
в том числе при сохранении X.Y.Z. Локальные повторные сборки/проверки версию не меняют.
В отсутствие CI счётчик обновляется явно владельцем релиза.

## Команды Melos

```bash
fvm dart run melos run version:show
fvm dart run melos run version:check
fvm dart run melos run version:plan -- patch
fvm dart run melos run version:plan -- minor
fvm dart run melos run version:plan -- major
fvm dart run melos run version:plan -- build
# Пример будущей версии; по умолчанию только preview:
fvm dart run melos run version:set -- --app-version 1.1.2 --build-number 5
```

`plan` предлагает текущий build + 1. `set` отклоняет уменьшение X.Y.Z и любой
нерастущий build. По умолчанию `set` — dry-run. Только после явного поручения
подготовить новую версию добавьте `--write`: обновятся корневой pubspec и README.
Пакеты, lockfile, CHANGELOG, Git index/commits/tags/remotes не меняются командой.
CHANGELOG заполняется отдельно по реально завершённым изменениям. Проверки
version tooling тестируют запись в temporary directory, а не в checkout.

Используйте `melos run version:*`. Встроенный `melos version` рассчитан на
автоматическое версионирование пакетов и может писать changelog/commit/tag;
он не является выбранным workflow приложения.
[Поведение встроенной команды](https://melos.invertase.dev/commands/version).

## Подготовка будущего релиза

Только по отдельному поручению владельца: проверить исходную ветку и diff,
выбрать X.Y.Z/N, сделать preview, явно записать версию, заполнить CHANGELOG,
пройти `check`, fixture E2E обеих платформ и обычную release APK сборку с freshness
проверкой. Выполнить ручную проверку физического TV и signing config перед
распространением. Tag `vX.Y.Z`, commit, PR/merge, push и публикация — отдельные
действия; настройка tooling и локальная сборка их не авторизуют.
