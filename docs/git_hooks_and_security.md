# 🔒 Git hooks и проверки безопасности | AniStar TV

Руководство по установке локальных хуков и запуску Gitleaks, OSV-Scanner и Semgrep. Правила веток, версий и выпуска описаны в [Git и версиях](vcs_guidelines.md).

## 1. Локальные Git hooks

[Конфигурация Lefthook](../lefthook.yml) действует локально. `pre-commit` проверяет staged whitespace, ищет секреты в staged diff, отклоняет запрещённые пути credentials/signing files и проверяет формат Dart. Formatter получает staged пути и читает файлы целиком из рабочего дерева. При частичном staging прочитанное содержимое может отличаться от index.

`pre-push` сканирует committed историю, затем запускает полный [check](melos_tooling.md#2-проверки-и-тесты) на рабочем дереве. Незакоммиченные изменения могут влиять на результат. Fixture E2E, APK и live остаются отдельными командами.

### Установка

Перед установкой проверьте custom hooks и `core.hooksPath`. Сохраните существующую конфигурацию и действия. [Необязательные Graphify hooks](../tool/graphify/README.md) обслуживают граф после commit, checkout, merge и rewrite независимо от Lefthook.

Подготовьте FVM и [SDK проекта](melos_tooling.md#1-подготовка-и-быстрый-запуск). Для Git hooks установите Lefthook и Gitleaks. Для полного `security` нужны также OSV-Scanner и Semgrep.

```bash
brew install lefthook gitleaks osv-scanner semgrep
lefthook install
```

---

<a id="ручной-запуск"></a>

## 2. Ручной запуск

```bash
lefthook validate
bash scripts/lefthook.sh run pre-commit
lefthook run pre-push --force
```

[Wrapper Lefthook](../scripts/lefthook.sh) отключает auto-stash в `pre-commit`, чтобы formatter получал текущее содержимое. `--force` запускает `pre-push` вручную при отсутствии push-файлов.

---

## 3. Проверки безопасности

Запускайте из корня `fvm dart run melos run security`. [Профиль в pubspec](../pubspec.yaml) последовательно выполняет три отдельные от `check` проверки. Для каждой нужен её CLI, иначе запуск завершится ошибкой. Для одного сканера подставьте его команду вместо `security`.

| Команда | Область и ограничения |
| :--- | :--- |
| [`security:secrets`](../scripts/security_gitleaks.sh) | Gitleaks офлайн сканирует committed историю по всем локальным refs, требуется полный clone. Вывод маскируется. Inline allow и локальные ignore-файлы игнорируются. |
| [`security:deps`](../scripts/security_osv.sh) | OSV-Scanner отправляет package metadata прямых и транзитивных зависимостей из корневого `pubspec.lock` в OSV. Повторный resolution, обход source/cache и offline fallback отсутствуют. |
| [`security:code`](../scripts/security_semgrep.sh) | Semgrep OSS применяет правила [.semgrep/](../.semgrep/) и [.semgrepignore](../.semgrepignore) локально без аккаунта, сети или отправки исходников. Нужен Python 3.10+. Findings, ошибки и отсутствие просканированных файлов останавливают проверку. Wrapper выводит путь, строку и rule ID без совпавшего исходника. |

[Правила Gitleaks](../.gitleaks.toml) содержат узкое исключение для публичного localhost TLS ключа fixture server. Реальные credentials храните вне исходников и fixtures.
