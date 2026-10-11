# 📂 Структура проекта и модулей | AniStar TV

Проект использует Dart pub workspace. App и features находятся в корневом Flutter-приложении; инфраструктура и UI Kit оформлены отдельными пакетами.

## 1. Глобальная структура

```text
.
├── infrastructure/
│   ├── core/             # Нейтральные Result и Failure
│   ├── networking/       # HTTP, BaseRepository, network failures
│   ├── storage/          # Preferences и secure storage
│   ├── app_logging/      # Logger, file output и observers
│   └── anistar/          # Единый клиент, cookies, зеркало, HTML/JSON5 и DTO
├── lib/
│   ├── app/              # App, composition root и GoRouter
│   ├── runner/           # Bootstrap Flutter и сервисов
│   ├── packages/
│   │   ├── features/     # auth, catalog, favorites, anime, player, watch_history, home, log_viewer, common
│   │   └── ui_kit/       # Тема и TV-компоненты
│   ├── main_dev.dart
│   └── main_prod.dart
├── test/                 # Unit, widget и architecture-тесты
├── integration_test/     # Emulator E2E и live smoke
├── android/              # TV manifest, flavors и Gradle
├── env/                  # Dart defines зеркала
├── docs/                 # Руководства, ADR и исследования
└── pubspec.yaml          # App и workspace, один pubspec.lock
```

Все infrastructure-пакеты и ui_kit используют `resolution: workspace`. Один `fvm flutter pub get` из корня разрешает зависимости. Тесты также запускаются из корня.

---

## 2. Публичные библиотеки

| Пакет | Импорт | Назначение |
| --- | --- | --- |
| core | `package:core/data.dart` | Result и Failure |
| networking | `package:networking/networking.dart` | HTTP и BaseRepository |
| storage | `package:storage/storage.dart` | Preferences и secure storage |
| app_logging | `package:app_logging/app_logging.dart` | Logger и observers |
| anistar | `package:anistar/anistar.dart` | AnistarClient, зеркало и DTO |
| anistar | `package:anistar/parsing.dart` | Чистые парсеры и декодирование |
| ui_kit | `package:ui_kit/ui_kit.dart` | Тема и TV-компоненты |

Провайдеры сервисов доступны через `package:<owner>/providers.dart`. Реализации `lib/src/**` закрыты для внешних импортов.

---

## 3. Структура feature

```text
lib/packages/features/catalog/
├── catalog_providers.dart   # Repository provider-контракт
├── domain/
│   ├── models/              # Domain-модели
│   └── repositories/        # Интерфейсы
├── data/
│   └── repositories/        # Реализации и DTO → domain
└── presentation/
    ├── bloc/                # События и состояния
    ├── screens/             # Экраны
    └── widgets/             # Локальные компоненты
```

Domain не импортирует Flutter, transport и парсер. Presentation использует domain и feature provider; конкретная реализация назначается в app.

---

## 4. Инициализация приложения

`main_dev.dart` и `main_prod.dart` вызывают `runApplication()` из `lib/runner/runner.dart`.

1. Runner создаёт Flutter binding и устанавливает обработчики ошибок.
2. Инициализирует logger, Bloc observer и landscape orientation.
3. Создаёт и инициализирует SharedPreferencesStorage; создаёт SecureStorage.
4. Читает baseline из `ANISTAR_MIRROR_URL` и сохранённую версию стандартного зеркала; DI отслеживает смену origin.
5. Передаёт runtime-объекты в `createAppOverrides` и запускает App внутри ProviderScope.
6. Feature Auth восстанавливает и проверяет защищённую сессию. App создаёт router только после входа; при выходе или истечении сессии router освобождается.

Зависимости и lifecycle: [Архитектура](01_architecture_principles.md). Команды запуска: [Разработка и тестирование](05_development_and_testing.md).
