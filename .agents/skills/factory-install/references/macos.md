# macOS

Команды установки выполняй только после отчёта и согласия по
[SKILL.md](../SKILL.md#3-отчёт-и-обязательное-согласие), только для выбранных
компонентов. Обновления описаны в [updates.md](updates.md).

## Homebrew и CLI

Проверь `uname -m`, `xcode-select -p`, `command -v brew`, `brew --prefix`.
При отсутствии Command Line Tools запусти `xcode-select --install` и дождись
завершения installer. Полный Xcode для Android не нужен.

Если Homebrew отсутствует, скачай официальный installer в временный файл,
прочитай его и выполни `/bin/bash <файл>`:
[Homebrew Installation](https://docs.brew.sh/Installation).
Используй prefix installer: обычно `/opt/homebrew` на Apple Silicon и `/usr/local`
на Intel. Подключи `brew shellenv` в текущую сессию и профиль.
Не запускай `sudo brew` и не меняй владельца существующей установки.

Комплект для свежего компьютера приведён ниже. Устанавливай только отсутствующие
компоненты; совместимые CLI из другого менеджера сохраняй.

```bash
brew install git bash curl unzip xz patch ripgrep python@3.12 uv gh lefthook gitleaks osv-scanner semgrep ffmpeg
brew install --cask temurin@17 android-studio
```

Node.js LTS установи через доступную LTS formula Homebrew, проверив её через
`brew info` до установки. Добавь её bin в PATH, если formula keg-only.
Проверь `"$(brew --prefix python@3.12)/bin/python3.12" --version`.
Если `python3` разрешается в несовместимый системный Python, задай
`ANISTAR_PYTHON` на фактический interpreter и добавь bin/libexec/bin нужной formula
в PATH для прямых scripts. Не заменяй системный `/usr/bin/python3`.
Проверь `bash --version` в новом shell: Bash должен быть доступен Melos и hooks.

Установи FVM через Homebrew, проверив источник:

```bash
brew info fvm
brew install fvm
fvm --version
```

Если core formula отсутствует, используй текущий tap из
[официальной инструкции FVM](https://fvm.app/documentation/getting-started/installation).
Не мигрируй исправную установку между taps без необходимости.
Flutter затем устанавливается только через FVM по `SKILL.md`.

DCM устанавливается отдельно:

```bash
brew tap CQLabs/dcm
brew install CQLabs/dcm/dcm
dcm --version
```

До установки сравни доступную версию с `dcm_global.yaml`. Если latest не подходит,
выбери официальный versioned formula/release в допустимом диапазоне.
Trust стороннего tap подтверждается штатным механизмом Homebrew, если потребуется.
Настрой имеющийся DCM account/план, когда анализ требует активации.
Не устанавливай архивный `dart_code_metrics` вместо DCM CLI.
[DCM Installation](https://dcm.dev/docs/getting-started/for-developers/installation/).

Найди Java 17 через `/usr/libexec/java_home -v 17`; установи `JAVA_HOME` и PATH
в своём профиле. Затем продолжи [Android](android.md).

## GitHub и Python CLI

Проверь `gh --version` и `gh auth status --hostname <host-из-remote>`.
При отсутствии авторизации используй интерактивный `gh auth login` с тем же host.
Не выводи токены и не меняй существующий protocol/account без необходимости.
[GitHub CLI](https://cli.github.com/manual/gh_auth_login).

Graphify с pin устанавливай через uv по [agents-and-graph.md](agents-and-graph.md).
Semgrep уже установлен через Brew, второй экземпляр через pip/uv не нужен.
Проверь `ffmpeg -encoders` на `libx264`. `sips` входит в macOS и нужен только
для branding; экспорт при установке не требуется.

Источники: [Gitleaks](https://github.com/gitleaks/gitleaks#installing),
[OSV-Scanner](https://google.github.io/osv-scanner/installation/),
[Semgrep CE](https://docs.semgrep.dev/getting-started/quickstart-ce),
[Lefthook](https://github.com/evilmartians/lefthook/blob/master/docs/install.md).
