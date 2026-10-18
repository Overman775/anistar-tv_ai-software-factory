---
name: anistar-flutter-update
description: "Обновление stable Flutter через FVM и зависимостей pub workspace AniStar TV с локальными тестами и Android-сборкой. Используй для запросов обновить Flutter, Dart SDK или пакеты проекта."
---

# Обновление Flutter в AniStar TV

Адаптировано из `rc-flutter-update` проекта RC Mobile App. Здесь Android / Android TV, Dart pub workspace и локальные проверки; Melos объединяет локальные команды; iOS, браузеры и CI/CD не нужны.

## Контекст

- `.fvmrc` закрепляет точный релиз; `.fvm/flutter_sdk` — локальная ссылка FVM. Если существует `.fvm/fvm_config.json`, синхронизируй и его.
- Участники workspace перечислены в корневом `pubspec.yaml`: infrastructure-пакеты и UI Kit. Общий `pubspec.lock` находится в корне.
- UI использует `material_ui`; учитывай совместимость theme/router и не смешивай Material-типы двух пакетов.
- Используй `fvm flutter` / `fvm dart`; scripts также принимают `ANISTAR_FLUTTER_SDK`. Не обновляй глобальный Flutter и SDK других проектов.
- Выполняй Flutter-команды последовательно. Не меняй исходники, тесты или scripts во время тестирования и сборки.
- Сохраняй существующие незакоммиченные изменения. Обновление не подразумевает commit, push или публикацию.

## Порядок работы

1. Проверь состояние Git, SDK и lockfile. Сохрани исходные версии для сравнения. Разбей работу на выбор stable, SDK, зависимости, совместимость, проверки и итог.
2. Получи `fvm releases` и проверь актуальный stable по [официальному архиву](https://docs.flutter.dev/install/archive) и [changelog](https://raw.githubusercontent.com/flutter/flutter/stable/CHANGELOG.md). Не используй GitHub `releases/latest`: там могут быть устаревшие beta. Если пользователь запросил последний stable, выбирай его без дополнительного вопроса. Для конкретной версии используй её.
3. Установи и закрепи точный релиз:

   ```bash
   fvm install VERSION
   fvm use VERSION --skip-pub-get
   fvm flutter --version --machine
   fvm flutter precache --android
   ```

   Из фактического SDK получи Dart version и architecture. Не определяй Dart version по номеру Flutter.
4. Обнови `environment.sdk` всех участников workspace под новый Dart, сохрани верхнюю границу major. Обнови существующие `environment.flutter` под новый Flutter. Не меняй `sdk: flutter` в dependencies и не добавляй Flutter dependency в чистый Dart Core.
5. Разреши зависимости из корня, сохрани `pub outdated --json`, затем обнови stable-пакеты с major-изменениями:

   ```bash
   fvm flutter pub get
   fvm flutter pub outdated --json
   fvm flutter pub upgrade --major-versions
   fvm flutter pub outdated --json
   ```

   Учитывай весь workspace. Для прямых зависимостей проверь `latest`, обнови нижние границы constraints до проверенных версий, включая patch/minor. Не добавляй overrides ради зелёного resolver. Для SDK-pinned и несовместимых transitive пакетов укажи конкретное ограничение; не называй их обновлёнными до latest.
6. Прочитай официальные migration guides и changelog реально изменившихся API. Для Android проверь предупреждения SDK о Kotlin/AGP/Gradle и [матрицу совместимости KGP](https://kotlinlang.org/docs/gradle-configure-project.html). Обновляй native toolchain в совместимых пределах; не редактируй pub cache и не включай built-in Kotlin глобально, пока плагины ещё применяют legacy KGP. Исправь использование пакетов; если затронуты typed routes, выполни `fvm dart run melos run generate`. Если изменилось форматирование, запусти `fvm dart run melos run format`.
7. Проверь:

   ```bash
   fvm dart run melos run check
   fvm dart run melos run test:e2e
   fvm dart run melos run build:android:prod:apk
   ```

   E2E запускай на Android emulator с текущим SDK и настоящими HTTP/storage/player через локальный HTTPS fixture. Укажи фактический device и seed. Если устройство недоступно, явно отметь непроверенный уровень; не подменяй его widget-тестом. После integration test собирай APK с обычным pub lifecycle.
8. При ошибке исправь её и повтори затронутую проверку. Провал теста не является успешным обновлением. Не снимай strict analyzer/DCM rules и не переписывай golden baselines без просмотра различий.
9. Обнови актуальные документы `docs/05_development_and_testing.md` и `docs/06_verification.md`, затем `graphify update .` и `git diff --check`. Не создавай отдельную историю планов/отчётов и не добавляй CI/CD.

## Definition of done

- FVM pin, фактический SDK и environment constraints согласованы.
- Direct dependencies используют проверенные последние stable-релизы; исключения и SDK/transitive ограничения названы.
- Lockfile воспроизводится через `fvm flutter pub get --enforce-lockfile`.
- Формат, analyzer, DCM, unit/widget, goldens, Android E2E и release APK проверены либо явно отмечены как недоступные.
- В сводном документе указаны Flutter/Dart до и после, реально обновлённые direct packages, результаты, ограничения и SHA-256 APK. Changelog содержит только подтверждённые изменения, относящиеся к проекту.
