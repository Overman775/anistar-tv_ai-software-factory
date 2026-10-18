# ⚙️ Core Package | AniStar TV

`core` содержит нейтральные типы Pure Dart для репозиториев и их потребителей. Используйте его для передачи результата или ошибки без зависимости от Flutter и инфраструктуры.

## Использование

Подключайте публичный API через `package:core/data.dart`:

```dart
import 'package:core/data.dart';
```

`Result<S, F extends Failure>` представляет успех или ошибку репозитория. Используйте `when` для обработки обеих ветвей, а `successOrNull` и `failureOrNull` — для необязательного чтения.

## Границы и условия использования

Core не имеет package-зависимостей. Публичный barrel экспортирует `Result`, `Failure` и `UnknownFailure`. Не импортируйте `src/**`. Пакет разрешается корневым pub workspace.

Сетевые ошибки принадлежат `networking`, ошибки сайта — `anistar`, а ошибки native playback — feature `player`. В Core нет Flutter, Dio, storage, логирования и типов AniStar.

## Как проверить

Из корня workspace запустите тесты пакета:

```bash
fvm flutter test test/infrastructure/core
```

## Навигация

- [Структура проекта](../../docs/02_project_structure.md) — границы workspace, пакетов, features и runner.
- [Архитектура](../../docs/01_architecture_principles.md) — слои, зависимости и DI.
