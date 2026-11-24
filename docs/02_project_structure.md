# 📂 Структура проекта и модулей | AniStar TV

Корневой Flutter-пакет содержит App и features. Шесть локальных пакетов перечислены в [pubspec.yaml](../pubspec.yaml) и используют общий `pubspec.lock`. Команды запуска и проверки находятся в [Melos tooling](melos_tooling.md).

## 1. Структура workspace

| Где | Что искать |
| :--- | :--- |
| `lib/app/`, `lib/runner/` | Композиция, маршруты и запуск. |
| `lib/packages/features/`, `lib/packages/ui_kit/` | Фичи корневого пакета и отдельный UI Kit. |
| `infrastructure/` | Локальные пакеты инфраструктуры. |
| `android/`, `ios/` | Android, Android TV и iOS Runner с dev/prod flavors. |
| `env/` | Dart define JSON и шаблоны. |
| `test/`, `integration_test/`, `tool/e2e/` | Тесты, fixtures и runners. |
| `prototype/` | Адаптивный прототип в `index.html`, `app.js`, `app.css` и `responsive.css`. Визуальные требования находятся в [DESIGN-HANDOFF](../prototype/DESIGN-HANDOFF.md). Flutter-реализация находится в `lib/`. |
| `docs/` | Руководства, спецификации и ADR. |

---

## 2. Владельцы пакетов

| Пакет | Публичные библиотеки | Ответственность |
| :--- | :--- | :--- |
| [core](../infrastructure/core/README.md) | `data.dart` | `Result`, `Failure` и нейтральные примитивы. |
| [networking](../infrastructure/networking/README.md) | `networking.dart`, `providers.dart` | Dio, transport failures и `BaseRepository`. |
| [storage](../infrastructure/storage/README.md) | `storage.dart`, `providers.dart` | Preferences и secure storage. |
| [app_logging](../infrastructure/app_logging/README.md) | `app_logging.dart`, `providers.dart` | `Logger`, output и observers. |
| [anistar](../infrastructure/anistar/README.md) | `anistar.dart`, `html.dart`, `parsing.dart`, `providers.dart` | Контракт сайта, HTML-адаптер, парсинг, зеркала и сессия. |
| [ui_kit](../lib/packages/ui_kit/README.md) | `ui_kit.dart`, `assets.dart` | Тема, TV/mobile профиль, общие компоненты и ресурсы. |

Используйте импорты `package:<имя пакета>/<библиотека>`. Направления зависимостей и запреты определяют [архитектурные принципы](01_architecture_principles.md#2-слои-и-зависимости).

---

## 3. Структура feature

| Внутри `lib/packages/features/<feature>/` | Что размещать |
| :--- | :--- |
| `domain/` | Модели, repository interfaces, операции и domain decorators. |
| `data/` | Реализации repository и преобразование DTO. |
| `presentation/` | BLoC, экраны, UI-состояние и виджеты фичи. |
| `*_providers.dart` | Контрактные providers и существующее async state. |

Создавайте папку, когда в ней есть код соответствующего слоя. Для границы отдельного пакета нужно архитектурное решение. Список фич и владельцев находится в [карте ответственности](01_02_feature_responsibilities.md#1-владельцы-поведения).

---

## 4. Запуск и composition root

`lib/main_dev.dart` и `lib/main_prod.dart` вызывают [runApplication](../lib/runner/runner.dart). Runner инициализирует Flutter, обработчики ошибок, logger, профиль, storage и mirror manager. Затем он запускает App в корневом `ProviderScope`. TV запускается в landscape со скрытыми системными панелями, телефон использует edge-to-edge. [TV](specs/06_tv_interaction.md), [mobile](specs/10_mobile_interaction.md).

[App container](../lib/app/app_container.dart) назначает реализации через overrides. [App router](../lib/app/app_router.dart) и [app routes](../lib/app/app_routes.dart) управляют маршрутами. Выход или истечение сессии закрывает маршруты аккаунта вместе с плеером. Правила переходов задаёт [спецификация входа](specs/01_authentication.md).

---

## 5. Где размещать изменение

Выберите владельца по таблицам пакетов и слоёв. Если меняется протокол сайта, начните с `infrastructure/anistar`. Для общего визуального контракта проверьте UI Kit. Изменения привязок и маршрутов идут в `lib/app`, изменения bootstrap — в `lib/runner`. Когда затронуты несколько фич, сверяйте [карту ответственности](01_02_feature_responsibilities.md).

---

## 6. Тесты и спецификации

Для unit, widget, golden и архитектурных тестов используйте корневой `test/` и подпуть соответствующей области (`app`, `infrastructure`, `packages/features` или `architecture`). Общие fakes и mock adapters находятся в `test/mocks/`. Integration scenarios находятся в `integration_test/`, средства запуска и fixtures — в `tool/e2e/`. Контракты находятся в [спецификациях](specs/README.md), архитектурные решения — в [ADR](adr/README.md).
