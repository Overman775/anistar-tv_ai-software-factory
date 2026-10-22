# 📂 Структура проекта и модулей | AniStar TV

AniStar TV построен как Flutter-приложение с Dart pub workspace. Корневой пакет остаётся приложением. Шесть локальных workspace-пакетов включают инфраструктуру и UI Kit. Ниже описаны точки входа и базовые правила размещения кода. Рабочие команды приведены в [Melos tooling](melos_tooling.md).

## 1. Структура workspace

```text
.
├── infrastructure/
│   ├── core/             # Result, Failure
│   ├── networking/       # Dio, BaseRepository, network failures
│   ├── storage/          # Preferences и secure storage
│   ├── app_logging/      # Logger и observers
│   └── anistar/          # HTTP-адаптер сайта, cookie session и DTO
├── lib/
│   ├── app/              # Composition root, router и приложение
│   ├── runner/           # Bootstrap платформы и runtime-сервисов
│   ├── packages/
│   │   ├── features/     # Функциональные области приложения
│   │   └── ui_kit/       # Тема, токены и общие виджеты
│   ├── main_dev.dart
│   └── main_prod.dart
├── test/                 # Unit, widget, golden и architecture tests
├── integration_test/     # Android fixtures, optional iOS fixture и явные live scenarios
├── android/              # Android и Android TV конфигурация
├── ios/                  # iOS Runner, flavors dev/prod и Simulator-конфигурации
├── env/                  # Dart define JSON и шаблоны
├── docs/                 # Руководства, спецификации и ADR
└── pubspec.yaml          # Корневое приложение, workspace и Melos
```

Workspace пакеты перечислены в `pubspec.yaml` и используют общий `pubspec.lock`. App и features остаются в корневом Flutter-пакете. Не создавайте для них отдельные package boundaries без архитектурного решения.

---

## 2. Владельцы пакетов

| Пакет | Публичный API | Ответственность |
| :--- | :--- | :--- |
| `core` | `package:core/data.dart` | `Result`, `Failure`, нейтральная ошибка |
| `networking` | `package:networking/networking.dart`, `providers.dart` | Dio factory, transport, `BaseRepository` |
| `storage` | `package:storage/storage.dart`, `providers.dart` | Preferences и защищённое локальное хранилище |
| `app_logging` | `package:app_logging/app_logging.dart`, `providers.dart` | Инициализация `Logger`, output и observers |
| `anistar` | `package:anistar/anistar.dart`, `html.dart`, `parsing.dart`, `providers.dart` | Site contract, HTML адаптер, парсинг и mirror session |
| `ui_kit` | `package:ui_kit/ui_kit.dart`, `assets.dart` | Тема, TV/mobile профиль и повторно используемые UI-компоненты |

Infrastructure пакет не импортирует app или feature. Код извне обращается только к экспортированным библиотекам. `lib/src/**` остаётся внутренней реализацией пакета. Границы проверяет `test/architecture/package_boundaries_test.dart`.

---

## 3. Структура feature

```text
lib/packages/features/catalog/
├── catalog_providers.dart        # контрактные providers и async state
├── domain/
│   ├── models/                    # модели приложения
│   └── repositories/              # interfaces и domain decorators
├── data/
│   ├── repositories/              # реализация контрактов
│   └── mapping/                   # DTO сайта → domain
└── presentation/
    ├── bloc/                      # BLoC, events и states
    ├── screens/
    └── widgets/                   # компоненты только этой feature
```

Набор папок соответствует ответственности, а не обязательному шаблону для каждой feature. Не создавайте пустые слои. Domain не импортирует Flutter, Dio или адаптер сайта. Data зависит от публичных контрактов. Presentation не обращается к реализации repository напрямую.

В `lib/packages/features/` сейчас находятся `auth`, `catalog`, `search`, `favorites`, `anime`, `player`, `watch_history`, `home`, `log_viewer` и `common`. Это функциональные области корневого приложения, а не отдельные workspace packages.

```dart
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => throw StateError('CatalogRepository must be supplied by the application.'),
);
```

Feature объявляет интерфейс и provider-контракт. Конкретный binding расположен в [app composition root](../lib/app/app_container.dart): это сохраняет возможность подмены реализации в тестах и не заставляет feature знать transport.

---

## 4. Запуск и composition root

`lib/main_dev.dart` и `lib/main_prod.dart` вызывают `runApplication()` из `lib/runner/runner.dart`. Android и iOS dev/prod flavors используют эти entry points. Runner инициализирует Flutter, error handlers, logger, platform profile, storage и mirror manager, затем создаёт корневой `ProviderScope` и запускает `App`.

`lib/app/app_container.dart` собирает repository implementations и infrastructure providers через Riverpod overrides. `lib/app/app_router.dart` и `app_routes.dart` владеют typed routes. Feature widgets сообщают о пользовательском действии через callback. App выбирает маршрут.

Auth владеет единым типизированным состоянием доступа, восстановлением защищённой сессии и входом в явный гостевой режим. Riverpod DI предоставляет это состояние App и features; асинхронная загрузка и ошибки операции остаются отдельными от доступа. App управляет публичной и защищённой навигацией по этому состоянию. Выход или истечение сессии закрывает account-bound маршруты вместе с плеером. Полная матрица переходов и разрешений находится в [спецификации входа](specs/01_authentication.md).

Платформенный профиль определяется до компоновки. TV получает landscape и скрытые системные панели. Телефон использует edge-to-edge системные панели. Ориентация телефона не переключает профиль. Поведение описано в [TV](specs/06_tv_interaction.md) и [mobile](specs/10_mobile_interaction.md) контрактах.

---

## 5. Где размещать изменение

| Если изменение… | Размещайте в… |
| :--- | :--- |
| Добавляет нейтральный тип результата или ошибки | `infrastructure/core` |
| Меняет HTTP transport или общую обработку Dio | `infrastructure/networking` |
| Меняет правила HTML, cookies, mirror или DTO AniStar | `infrastructure/anistar` |
| Меняет domain operation одной области | `lib/packages/features/<feature>/domain` |
| Преобразует данные сайта в модели feature | `lib/packages/features/<feature>/data` |
| Меняет экран или локальное UI-состояние | `lib/packages/features/<feature>/presentation` |
| Нужен общий визуальный token/widget | `lib/packages/ui_kit` |
| Меняет bindings, bootstrap или маршруты приложения | `lib/app` или `lib/runner` |

При повторении UI в нескольких областях сначала проверьте UI Kit. Не переносите сетевую логику в виджет, общий DTO сайта в feature, а app-specific binding в infrastructure.

---

## 6. Тесты и спецификации

Тесты находятся в корневом `test/`. Соответствующая область отражается в пути `test/app`, `test/infrastructure` или `test/packages/features`. Integration scenarios находятся в `integration_test/`. Dart fakes и mock adapters расположены в `test/mocks/`. Android fixture tooling и assets находятся в `tool/e2e/`.

Пользовательские инварианты и критерии приёмки приведены в [specs](specs/README.md). Зафиксированные архитектурные решения находятся в [ADR](adr/README.md). Руководства объясняют границы и рабочие правила. Они не дублируют подробные сценарии.
