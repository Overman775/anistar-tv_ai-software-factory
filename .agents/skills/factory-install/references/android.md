# Android toolchain

Сначала прочитай metadata уже установленной среды. Установку/обновление SDK,
настройки Java и создание AVD выполняй только после отчёта и согласия по
[SKILL.md](../SKILL.md#3-отчёт-и-обязательное-согласие), в подтверждённом составе.

## 1. Java и SDK

Требования бери из `docs/05_development_and_testing.md`,
`android/app/build.gradle.kts`, `android/settings.gradle.kts`,
`android/gradle/wrapper/gradle-wrapper.properties` и закреплённого Flutter.
JDK проекта сейчас 17. Gradle использует wrapper, глобальный Gradle/Kotlin не нужен.

Установи Android Studio способом своей ОС. Запусти Setup Wizard и SDK Manager.
Для headless host скачай [официальные command-line tools](https://developer.android.com/studio#command-tools)
для его ОС/CPU и распакуй в `<sdk>/cmdline-tools/latest/` так, чтобы внутри был
`bin/sdkmanager` (`sdkmanager.bat` на Windows). SDK Manager устанавливает пакеты
даже без полной IDE. Не путай command-line tools и platform-tools.

Определи фактический SDK path. Типичные значения:

| Host | SDK |
| --- | --- |
| macOS | `$HOME/Library/Android/sdk` |
| Linux / WSL2 | `$HOME/Android/Sdk` |
| Windows | `%LOCALAPPDATA%\Android\Sdk` |

Настрой `ANDROID_HOME` и PATH с `platform-tools`, `emulator`,
`cmdline-tools/latest/bin`. Если `ANDROID_SDK_ROOT` уже задан, он должен указывать
на тот же SDK. Scripts без `ANDROID_HOME` могут выбрать macOS fallback на Linux.
Укажи JDK 17 через `JAVA_HOME` и при необходимости
`fvm flutter config --jdk-dir <jdk-path>`. Проверь фактическую Java в
`fvm flutter doctor -v`: Android Studio может выбирать собственный JBR.
Не записывай `android/local.properties` с путями другого компьютера.

## 2. Пакеты SDK

После `fvm install` и проверки SDK прочитай `FlutterExtension.kt` внутри
`.fvm/flutter_sdk/packages/flutter_tools/gradle/` для `compileSdkVersion` и
`buildToolsVersion`. Если расположение изменилось, найди значения в этом SDK.
NDK бери из app Gradle (сейчас `28.2.13676358`). Не подставляй последнюю версию NDK.

Запусти `sdkmanager --list` и выбери доступные package IDs:

```text
platform-tools
cmdline-tools;latest
emulator
platforms;android-<compileSdk-закреплённого-Flutter>
build-tools;<buildTools-закреплённого-Flutter>
ndk;<ndkVersion-из-app-Gradle>
```

Установи их через `sdkmanager --sdk_root=<sdk> <package-ids>` или SDK Manager.
Символ `;` требует кавычек вокруг каждого package ID в Bash/PowerShell.
CMake установи, если его требует native plugin/Gradle; версию выбирай по этому
требованию. Для system images E2E отдельно нужен API из `tool/e2e/README.md`.
SDK tools могут требовать более новый Java runtime: проверь их diagnostics
и используй совместимый runtime для SDK Manager отдельно от JDK сборки.

Предложи пользователю прочитать и принять лицензии интерактивно:

```bash
fvm flutter doctor --android-licenses
fvm flutter doctor -v
```

Не подавай `yes` в license prompt. Если SDK Manager требует участия пользователя,
продолжи независимую настройку skills/security CLI и сообщи оставшийся шаг.
[Flutter Android Setup](https://docs.flutter.dev/platform-integration/android/setup),
[sdkmanager](https://developer.android.com/tools/sdkmanager).

## 3. TV и mobile AVD

Установка полного окружения включает подготовку двух отдельных AVD:
`anistar_tv_e2e` (Android TV) и `anistar_mobile_e2e` (Pixel 6), API 36 по текущему
`tool/e2e/README.md`. Существующие подходящие AVD сохрани. Другие имена передай
через `ANISTAR_TV_AVD` / `ANISTAR_MOBILE_AVD`.

Для новых AVD найди system images через `sdkmanager --list` и hardware profiles
через `avdmanager list device`. TV требует **настоящего TV image**, hardware D-pad
и keyboard. Phone image с TV skin не подходит. Выбери image CPU под host
(`arm64-v8a` или `x86_64`) и доступное ускорение. Не выдумывай TV package ID:
наборы images отличаются между API и CPU.

Создай только отсутствующие AVD через Device Manager или
`avdmanager create avd --name <имя> --package <проверенный-image-id> --device <profile>`.
Не применяй `--force` к существующему AVD, не делай wipe/reset.
Проверь `hw.dPad=yes` для TV и `hw.keyboard=yes`, затем выполни Cold Boot при
изменении hardware flags.

Проверь `emulator -accel-check`, список AVD и `adb devices -l`.
Запусти нужные AVD без блокировки сессии ожиданием всего lifetime emulator.
Дождись boot, проверь имена и профили существующим tooling:

```bash
python3 tool/e2e/emulator_selection.py --adb "$ANDROID_HOME/platform-tools/adb" --emulator "$ANDROID_HOME/emulator/emulator" --avd anistar_tv_e2e --expected tv
python3 tool/e2e/emulator_selection.py --adb "$ANDROID_HOME/platform-tools/adb" --emulator "$ANDROID_HOME/emulator/emulator" --avd anistar_mobile_e2e --expected mobile
```

На native Windows пути и launchers имеют `.exe`; используй соответствующий
shell и отмечай несовместимость project wrappers отдельно.
Проверенный boot/UI mode важнее самого факта создания AVD.
Если CPU/image или виртуализация недоступны, назови ограничение E2E и продолжи
сборку и остальные проверки. FFmpeg не нужен для запуска уже готовых fixtures.
[Android Emulator](https://developer.android.com/studio/run/managing-avds).
