# 🌿 Git и версии | AniStar TV

Руководство описывает локальный Git workflow, единую версию приложения и подготовку релиза.

## 1. Ветки и изменения

Обычно ответвляйтесь от актуального `main`. Используйте `feature/<description>`, `fix/<description>`, `chore/<description>` или `codex/<description>`. Для стабилизации допустимы `release/vX.Y.Z` и `hotfix/vX.Y.Z`. Для стека веток согласуйте базу и цель каждой PR. Ветки задач в общей feature-ветке сливайте без squash, чтобы сохранить SHA зависимостей. Для готовой задачи в `main` допустим squash.

Для коммита и заголовка PR используйте Conventional Commits в форме `type(scope): description`. Типы — `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`, `build`. Scope — имя изменённого pub-пакета, включая `anistar_tv` для фич приложения, или `root` для общего tooling. ID указывайте для существующей задачи. При squash проверьте итоговое сообщение.

---

## 2. Единая версия приложения

Корневой [pubspec.yaml](../pubspec.yaml) задаёт версию Android/iOS в формате `X.Y.Z+N`. Независимая публикация workspace-пакетов для этого workflow не предусмотрена. Версии вложенных пакетов сохраняйте при bump приложения.

| Изменение | Bump |
| :--- | :--- |
| Совместимое исправление | PATCH |
| Совместимый функционал | MINOR |
| Несовместимое изменение пользовательского или публичного контракта | MAJOR |

Изменения docs/test/style/chore/refactor сами по себе не требуют bump. Стабильная версия содержит три числа без ведущих нулей и prerelease-суффиксов. `N` — положительное целое. Оно строго растёт для нового распространяемого артефакта, даже если `X.Y.Z` прежнее. Локальные сборки для проверки используют текущую версию.

---

## 3. Команды Melos

```bash
fvm dart run melos run version:show
fvm dart run melos run version:check --include-private
fvm dart run melos run version:plan -- patch
fvm dart run melos run version:set -- --app-version 1.1.2 --build-number 5
```

`version:plan` принимает `patch`, `minor`, `major` и `build`, предлагает текущий build + 1. `version:set` по умолчанию делает preview и отклоняет уменьшение `X.Y.Z` или нерастущий build. Пример указывает условную версию. Добавьте `--write` только по явному поручению подготовить новую версию. Команда запишет только корневой pubspec. CHANGELOG заполните отдельно по завершённым изменениям. Для проверки diff используйте `fvm dart run melos run vcs:check`. Встроенный `melos version` может изменить пакеты, changelog и Git.

---

## 4. Подготовка будущего релиза

По отдельному поручению владельца проверьте исходную ветку и diff. Выберите версию, проверьте preview, запишите версию и заполните [CHANGELOG](../CHANGELOG.md). [Полный gate](05_development_and_testing.md#2-проверки-и-сборка) включает `check`, TV/mobile fixture E2E и сборку подписанного production APK. Проверьте [подпись и версию APK](android_signing.md) и выполните ручной smoke на физическом TV перед распространением.

Tag `vX.Y.Z`, commit, PR/merge, push и публикация требуют отдельного поручения. Сборка для проверки и unsigned compilation служат локальной проверке.

---

## 5. Локальные Git hooks

`pre-commit` проверяет staged diff на whitespace, секреты и запрещённые файлы. Формат Dart проверяется для staged путей по содержимому рабочего дерева. `pre-push` сканирует committed историю и запускает полный `check` на рабочем дереве. Fixture E2E, APK и live запускаются отдельно. [Настройка и проверки безопасности](git_hooks_and_security.md).

<a id="установка"></a>

[Установка Lefthook и сканеров](git_hooks_and_security.md#установка).

<a id="ручной-запуск"></a>

[Ручной запуск хуков](git_hooks_and_security.md#2-ручной-запуск).
