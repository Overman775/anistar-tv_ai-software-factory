# ⚙️ Core Package | AniStar TV

Нейтральное Pure Dart ядро без package-зависимостей.

## 1. Публичные библиотеки

| Импорт | API |
| --- | --- |
| `package:core/data.dart` | Result, Failure, UnknownFailure |

Внешний код не импортирует src/**. Зависимости разрешаются корневой pub workspace.

---

## 2. Ответственность и lifecycle

`Result<S, F extends Failure>` представляет успех или ошибку репозитория. Используйте `when` для обработки двух ветвей; `successOrNull` / `failureOrNull` для необязательного чтения.

Сетевые ошибки принадлежат networking, ошибки сайта anistar, ошибки native playback feature player. В Core нет Flutter, Dio, storage, логирования и типов AniStar.

---

## 3. Проверки

Тесты запускаются из корня:

```bash
fvm flutter test test/infrastructure/core
```

Границы пакетов: [Структура проекта](../../docs/02_project_structure.md).
