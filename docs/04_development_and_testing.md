# 🧪 Разработка и тестирование | AniStar TV

Документ содержит минимальный рабочий процесс: как запустить приложение, проверить изменение и диагностировать частые проблемы.

## 1. Требования

- FVM и Flutter `3.44.2`;
- Dart `3.12.x` из Flutter SDK;
- JDK 17;
- Android SDK;
- доступный AniStar Parser.

## 2. Первый запуск

Скопируйте шаблон production-конфига и укажите реальный HTTPS endpoint Parser:

```bash
cp env/prod.example.json env/prod.json
```

`env/prod.json` игнорируется Git. `env/dev.json` содержит безопасный адрес Android Emulator и хранится в репозитории.

```bash
fvm install
fvm flutter pub get
fvm flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define-from-file=env/dev.json
```

Для physical TV замените `10.0.2.2` на адрес компьютера в локальной сети. Устройство и parser должны видеть друг друга.

## 3. VS Code и анализ

Откройте корень проекта: VS Code автоматически использует FVM SDK, форматирует Dart при явном сохранении, проверяет Markdown-ссылки и скрывает служебные каталоги. Рекомендуемые расширения, включая DCM и Dart-Code, перечислены в `.vscode/extensions.json`.

Политика Dart и DCM живёт в `analysis_options.yaml`; допустимая версия DCM закреплена в `dcm_global.yaml`. Сгенерированный OpenAPI-клиент исключён из правил приложения и проверяется отдельной командой.

## 4. Flavors и сборка

| Flavor | Entry point | Назначение |
| --- | --- | --- |
| `dev` | `lib/main_dev.dart` | Локальная разработка, подробные логи, HTTP |
| `prod` | `lib/main_prod.dart` | Production-конфигурация, HTTPS |

```bash
# Debug APK
fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart \
  --dart-define-from-file=env/dev.json

# Production entry point
fvm flutter build apk --release --flavor prod -t lib/main_prod.dart \
  --dart-define-from-file=env/prod.json
```

Release signing перед публикацией настраивается отдельно в Android-проекте.

## 5. Ежедневные проверки

```bash
# Форматирование
fvm dart format --output=none --set-exit-if-changed lib test

# Статический анализ
fvm flutter analyze
dcm analyze lib test

# Тесты приложения и API package
fvm flutter test
fvm dart analyze api

# Android TV сборка
fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart \
  --dart-define-from-file=env/dev.json
```

## 6. Тестовая стратегия

Тесты защищают поведение, которое дорого проверять вручную после каждого изменения.

| Тип | Что проверяем | Примеры |
| --- | --- | --- |
| Unit | Mapping, repository и BLoC transitions | API DTO → domain, пагинация |
| Widget | Состояния компонентов и действия | Error/retry, карточки, controls |
| TV layout | Focus и отсутствие overflow | `960×540`, `1280×720` |
| Device smoke | Реальный пульт и декодирование HLS | Полный сценарий просмотра |

Цель 100% coverage для этого проекта не установлена. Тест нужен там, где есть ветвление, исправленный баг, mapping контракта или важный TV-сценарий.

### Структура тестов

Тесты повторяют структуру production-кода:

```text
lib/packages/features/catalog/presentation/screens/catalog_screen.dart
test/packages/features/catalog/presentation/screens/catalog_screen_test.dart
```

Для локального package `ui_kit` папка `lib/src` опускается:

```text
lib/packages/ui_kit/lib/src/widgets/tv_focusable.dart
test/packages/ui_kit/widgets/tv_focusable_test.dart
```

Внешние зависимости заменяются fake repository или HTTP adapter. Общие fake и
mock-реализации находятся в `test/mocks/`, а не рядом с тестами feature; тест
не должен обращаться к реальному parser.

### TV layout tests

Для экрана или сложного TV-компонента задайте размер test view и проверьте навигацию с клавиатуры:

```dart
tester.view
  ..physicalSize = const Size(960, 540)
  ..devicePixelRatio = 1;

await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
await tester.sendKeyEvent(LogicalKeyboardKey.select);
expect(tester.takeException(), isNull);
```

Golden-тесты пока не являются обязательными. Их стоит добавить, когда дизайн экранов стабилизируется и pixel-level regression станет полезнее стоимости поддержки эталонов.

Для UIKit тестируйте общий контракт: typography, fallback удалённого изображения, skeleton и loading/error state. Feature-тест проверяет собственную форму skeleton layout и TV-навигацию, а не внутреннюю реализацию UIKit.

## 7. Ручной smoke-check на TV

Перед заметным изменением player или focus-навигации проверьте:

1. Приложение видно в Android TV launcher.
2. Первый focus target понятен на каждом экране.
3. Стрелки проходят весь путь по сетке и возвращаются назад.
4. `OK` не срабатывает дважды.
5. HLS запускается, перематывается и переживает повторную session.
6. После выхода из player системные панели не остаются поверх приложения.

## 8. Частые проблемы

| Симптом | Что проверить |
| --- | --- |
| Каталог не загружается | `ANISTAR_API_URL`, доступность parser и firewall |
| Parser недоступен с physical TV | Используется LAN-адрес, а не `10.0.2.2` |
| Видео не запускается | Ответ `getPlaybackInfo`, manifest и новая session |
| Приложение не видно в launcher | В APK присутствует `LEANBACK_LAUNCHER` |
| Prod не открывает HTTP | Это ожидаемо: используйте HTTPS endpoint |
| OpenAPI generation падает | Версия generator — `7.23.0`, схема актуальна |

## 9. Когда обновлять документацию

Обновите соответствующий файл при изменении:

- структуры feature или направления зависимостей;
- API-контракта и генерации клиента;
- lifecycle playback-сессии;
- команд запуска, Flutter или Android toolchain;
- базового поведения пульта и TV-layout.
- состава `env/*.json`, Riverpod providers или общих UIKit primitives.
