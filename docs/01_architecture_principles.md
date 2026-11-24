# 🏛️ Архитектурные принципы | AniStar TV

AniStar TV использует feature-based CleanArch. Пути пакетов и точек входа указаны в [структуре проекта](02_project_structure.md).

## 1. Принципы

Группируйте код вокруг пользовательской области. Сохраняйте одного владельца каждого решения. Добавляйте абстракцию для текущей задачи. Внешние ресурсы передавайте через конструктор или provider override, чтобы подменять HTTP и native playback в тестах.

---

## 2. Слои и зависимости

| Слой | Ответственность и допустимые зависимости |
| :--- | :--- |
| Core | Pure Dart `Result`, `Failure`, `UnknownFailure`. Без зависимостей от Flutter и workspace-пакетов. |
| Infrastructure | HTTP, storage, logging, протокол сайта. Без импортов App и features. |
| Feature Domain | Модели и repository interfaces. Без Flutter, Riverpod, Dio и HTML/JSON5. |
| Feature Data | Реализации repository и маппинг DTO сайта в domain. Использует публичные контракты Domain, AniStar и Networking. |
| Feature Presentation | Экран, UI-состояние и локальный lifecycle. Использует domain-контракты и публичный UI Kit. |
| UI Kit | Общая тема, токены и компоненты. Правила фич и запросы остаются у своих владельцев. |
| App / Runner | Запуск, композиция и маршруты. App связывает контракты с реализациями. |

Импортируйте публичные библиотеки пакетов. Границы, включая чужой `lib/src/**`, проверяет [package_boundaries_test.dart](../test/architecture/package_boundaries_test.dart).

---

## 3. Feature и repository

Domain задаёт контракт. Data адаптирует внешний источник. Presentation отображает domain-результат. Например, `AnistarCatalogRepository` реализует `CatalogRepository` через `AnistarClient` и переводит DTO в модели каталога. Domain-модели и state immutable. При изменении создавайте новое значение и защищайте опубликованные коллекции от мутации.

---

## 4. DI и состояние

Riverpod управляет DI и существующим сервисным и асинхронным состоянием. BLoC обрабатывает экранные события и переходы. Сохраняйте бизнес-правила у владельца фичи и один корневой `ProviderScope`. Фича объявляет provider контракта, App передаёт реализацию через override. BLoC, репозитории и сервисы принимают зависимости конструкторами. Domain и Data работают без `BuildContext`, роутера и Riverpod. Доступ гостя или аккаунта читайте через типизированный auth provider.

[Пример override, владельцы ресурсов и порядок освобождения](01_03_di_and_lifecycle.md).

---

## 5. Результаты, ошибки и навигация

`HtmlAnistarClient` бросает безопасный `AnistarClientException` для ожидаемого отказа сайта. Feature Data преобразует его через `mapAnistarErrors` в `Failure`. `BaseRepository` оборачивает исход в `Result<T, Failure>` на границе репозитория. Networking определяет transport failures, Core предоставляет `UnknownFailure`, Player Domain владеет `PlaybackFailure`. HTML, cookies и детали сессии остаются внутри инфраструктуры. Ошибка запроса сохраняется как `Failure`.

Сохраняйте source ID/slug, nullable-поля и полный manifest URI с headers/expiry по [нормализованному контракту](adr/0010-normalized-anistar-contract.md).

`GoRouter` и typed routes принадлежат app. Фича передаёт намерение перехода через callback. UI управляет своим локальным dialog. BLoC не получает `BuildContext` и не выполняет переходы.

---

## 6. Lifecycle

Ресурс освобождает создавший его владелец. При смене origin инфраструктура пересоздаёт Dio, клиент, cookie session и зависимые привязки. Плеер освобождает прежний controller до создания следующего. [Таблица владельцев](01_03_di_and_lifecycle.md#2-владение-ресурсами) и [сетевой контракт](04_network_and_playback.md).

---

## 7. Навигация и платформенные профили

TV и телефон используют общие domain-данные и playback. Ориентация телефона не переключает профиль. Для изменений интерфейса применяйте [ADR-0008](adr/0008-youtube-tv-interaction-reference.md), [TV-контракт](specs/06_tv_interaction.md) и [mobile-контракт](specs/10_mobile_interaction.md).

---

## 8. Предметный язык и ответственность фич

Для изменений поведения, моделей и взаимодействий читайте [глоссарий](01_01_domain_glossary.md), [карту ответственности](01_02_feature_responsibilities.md) и применимые спецификации. Передайте делегатам конкретные пути. Обновляйте справочники при смене смысла термина или владельца, спецификации — при изменении подробного поведения. Укажите расхождение кода со спецификацией в задаче.
