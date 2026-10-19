# Linux и Linux внутри WSL2

Установку и обновление package indexes выполняй только после отчёта и согласия
по [SKILL.md](../SKILL.md#3-отчёт-и-обязательное-согласие), только для выбранных
компонентов. Обновления инструментов описаны в [updates.md](updates.md).

Определи distro через `/etc/os-release`, CPU через `uname -m`, пакетный менеджер
и доступность `sudo`. Примеры относятся к Debian/Ubuntu. Для Fedora/Arch сопоставь
зависимости с официальными пакетами distro. Не запускай apt на другой системе
и не устанавливай Homebrew как обязательную Linux-зависимость.

## Системные инструменты

```bash
sudo apt-get update
sudo apt-get install git bash curl ca-certificates unzip zip xz-utils tar patch ripgrep python3 python3-venv openjdk-17-jdk ffmpeg libglu1-mesa
```

Проверь Python 3.10+. Для старого distro установи поддерживаемый Python через uv
или официальный пакет. Не заменяй системный Python и не применяй
`pip --break-system-packages`.

Установи uv через официальный standalone installer: скачай
`https://astral.sh/uv/install.sh`, прочитай и выполни `sh <файл>`.
Затем `uv tool update-shell`, добавь сообщённый tool bin в текущий PATH
и проверь из нового shell. При необходимости `uv python install 3.12`.
[uv Installation](https://docs.astral.sh/uv/getting-started/installation/).

Установи FVM без предварительного Flutter/Dart: скачай
`https://fvm.app/install.sh`, прочитай и выполни `bash <файл>`.
Подключи PATH из вывода installer и проверь `fvm --version`.
[FVM Installation](https://fvm.app/documentation/getting-started/installation).
Если installer недоступен, скачай standalone archive из официальных FVM Releases
по ссылке в этой инструкции, проверь checksum и добавь бинарник в свой PATH.

Для installer Impeccable установи Node.js LTS через уже настроенный version manager
или официальный способ для distro. Пакет distro подходит, если его версия
удовлетворяет installer. [Node.js Download](https://nodejs.org/en/download).

## GitHub, hooks, security и DCM

Установи `gh` через [официальный apt/rpm repository](https://github.com/cli/cli/blob/trunk/docs/install_linux.md).
Проверь host из Git remote через `gh auth status --hostname <host>`.
При необходимости запусти интерактивный `gh auth login --hostname <host>`.

Для Lefthook, Gitleaks и OSV-Scanner используй поддерживаемый пакет distro
или бинарные releases официальных проектов для своей архитектуры:

- [Lefthook Installation](https://github.com/evilmartians/lefthook/blob/master/docs/install.md).
- [Gitleaks Releases](https://github.com/gitleaks/gitleaks/releases).
- [OSV-Scanner Installation](https://google.github.io/osv-scanner/installation/).

При скачивании release проверь опубликованную checksum/provenance и установи
бинарник в пользовательский bin из PATH. Не требуй Go/Rust только ради сборки CLI,
если есть готовый release. Для OSV нужен `scan source`, для Gitleaks — `git`
и флаги из `scripts/security_gitleaks.sh`.

```bash
uv tool install --python 3.12 semgrep
semgrep --version
```

Не запускай `semgrep login` или `semgrep --config=auto`: проект использует локальные
OSS-правила без аккаунта. [Semgrep CE](https://docs.semgrep.dev/getting-started/quickstart-ce).

DCM установи через [официальный signed apt repository или release](https://dcm.dev/docs/getting-started/for-developers/installation/).
Для apt выбери CPU через `dpkg --print-architecture`, отдельный keyring
и `signed-by`. Не перезаписывай repository-файл Dart из примера поставщика:
используй отдельный `dcm.list`. До установки выбери версию из `dcm_global.yaml`.
На других distro используй официальный архив для ОС/CPU.
Проверь `dcm --version` и фактический доступ к анализаторам.

Настрой `JAVA_HOME` на найденный JDK 17, а не путь с жёстким `amd64`.
Проверь `java -version`. Затем продолжи [Android](android.md).

## Android на Linux

Установи Android Studio из [официального Linux-дистрибутива](https://developer.android.com/studio/install#linux)
или command-line tools по [android.md](android.md).
Для emulator проверь KVM и доступ пользователя к `/dev/kvm`.
Runtime libraries выбирай по diagnostics для текущего distro.
Linux desktop toolchain Flutter для Android не нужен.

WSL2 требует отдельной проверки виртуализации и ADB по [windows.md](windows.md).
Экспорт branding через `sips` доступен только на macOS.
