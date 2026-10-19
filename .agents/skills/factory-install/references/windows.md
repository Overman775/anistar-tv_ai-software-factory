# Windows

Установку WSL, пакетов и изменения настроек выполняй только после отчёта и согласия
по [SKILL.md](../SKILL.md#3-отчёт-и-обязательное-согласие), только в выбранном
окружении и составе. Обновления описаны в [updates.md](updates.md).

## 1. Среда выполнения

Определи Windows version, CPU, shell и host агентских инструментов.
PowerShell-команды выполняются на Windows, Bash-команды — в выбранном Bash.
Выбор распространяется на Git hooks и MCP, а не только на терминал.

Проект использует Unix scripts, `bin/dart`, symlinks и POSIX subprocess-тесты.
Для полного текущего tooling основной путь — **WSL2 с Linux toolchain**.
Это Windows-установка через Linux-окружение, не обещание нативной совместимости
всех scripts. Если пользователь выбрал нативный Windows, используй раздел 3.

Проверь `wsl --status` и `wsl --list --verbose`. Если WSL отсутствует:

```powershell
wsl --install -d Ubuntu
```

Windows может потребовать elevation, перезагрузку и создание Linux-пользователя.
Сообщи точный незавершённый шаг. Не считай его выполненным автоматически.
[Microsoft WSL Install](https://learn.microsoft.com/en-us/windows/wsl/install).

## 2. WSL2

Внутри distro выполни [linux.md](linux.md), затем остальные этапы `SKILL.md`.
Держи checkout, FVM cache, uv environments, SDK и hooks в Linux filesystem.
Для нового clone предпочитай `~/src/anistar_tv`, не `/mnt/c/...`.
Существующие незакоммиченные изменения не переноси и не удаляй автоматически.
При переходе из Windows checkout сохрани их отдельно.

Агент должен выполнять команды в том же distro и checkout.
Windows-host MCP не обнаружит Linux `fvm`/`dcm` через Windows PATH.
Используй поддерживаемое host подключение к WSL или локальную обёртку
`wsl.exe -d <distro> --cd <linux-checkout> -- <command> ...`.
Сохрани args и проверь MCP handshake. Не переписывай общие configs машинными
путями. При невозможности запуска отметь MCP как ненастроенный.

Установи **Linux SDK** в WSL и укажи его в `ANDROID_HOME`.
Windows SDK/`.exe` через `/mnt/c` не заменяют Linux build toolchain.
Проверь `/dev/kvm` и `emulator -accel-check` перед созданием Linux AVD.
Наличие WSLg не подтверждает аппаратное ускорение Android Emulator.

Если Linux emulator не работает, Android Studio и AVD можно установить на Windows.
Видимость host AVD из WSL и `adb reverse` проверяй отдельно.
Не включай публичный ADB listener и не отключай firewall ради связи.
Без проверенного localhost/защищённого bridge не заявляй готовность fixture E2E.
Физический телефон позволяет проверить запуск, но не заменяет два AVD, которые
требует `tool/e2e/emulator_selection.py`. Сборку APK и tooling продолжай без emulator.

## 3. Нативный Windows

Установи недостающие пакеты после `winget show --id <ID> -e`:

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id Python.Python.3.12 -e
winget install --id astral-sh.uv -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id EclipseAdoptium.Temurin.17.JDK -e
winget install --id Google.AndroidStudio -e
winget install --id Google.OSVScanner -e
```

Не добавляй флаги принятия лицензий за пользователя. При отсутствии WinGet
используй официальный installer продукта. Перезапусти shell после изменения PATH.
Отключать защиту PowerShell/антивирус не требуется.

FVM: `choco install fvm`, если Chocolatey уже настроен; иначе официальный
[standalone Windows archive FVM](https://fvm.app/documentation/getting-started/installation)
для x64/arm64 с пользовательским PATH. Отдельный Dart не нужен.
DCM: `choco install dcm --version <совместимая-версия>` или
[официальный Windows release](https://dcm.dev/docs/getting-started/for-developers/installation/).
Версия должна соответствовать `dcm_global.yaml`.

Lefthook, Gitleaks, ripgrep, patch и FFmpeg установи из официального менеджера
или release для CPU. Проверь checksum для архивов. `patch` с нужными флагами
должен запускаться из Python subprocess, а не существовать только как shell alias.
Не копируй случайный `patch.exe` из другого проекта.

```powershell
uv python install 3.12
uv tool install --python 3.12 semgrep
uv tool update-shell
```

Semgrep поддерживает [нативную установку](https://docs.semgrep.dev/getting-started/quickstart-ce).
Она не доказывает совместимость Bash wrapper проекта.
Проверь UTF-8 (`PYTHONUTF8=1`) для текущего процесса; постоянную переменную
добавляй только текущему пользователю при необходимости.

Проектные Bash-команды запускай в Git Bash. Проверь `bash`, `patch`, `python3`,
`fvm`, `gh`, `dcm`, security CLI и SDK из **этого** процесса.
`py -3.12` не заменяет имя `python3`, используемое subprocess-тестами.
Настрой пользовательский wrapper на тот же Python, если `python3` недоступен.
Проверь `.claude/skills` и `.fvm/flutter_sdk`: Git может checkout-ить symlink как
текст. Восстанови ссылки/junctions штатным способом с учётом Developer Mode.
Не удаляй существующие skills и не меняй глобальный `core.autocrlf`.
Сохрани LF у shell scripts.

Impeccable запускай через `scripts/impeccable.cmd` в PowerShell/cmd.
Python-пути содержат `Scripts/python.exe`, а не `bin/python`.

Выполни workspace/gates из `SKILL.md`. При сбое на Unix-пути, ссылке или shell
сохрани конкретную ошибку. Предложи WSL2 и продолжи независимые native-проверки.
Не переписывай scripts при установке и не называй native-комплект проверенным,
пока gates не прошли.
