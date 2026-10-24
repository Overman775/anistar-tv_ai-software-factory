# 🧭 Ответственность фич | AniStar TV

Карта существующих владельцев поведения, состояния и взаимодействий. Помогает выбрать место изменения в feature-based CleanArch. Значения понятий определяет [глоссарий](01_01_domain_glossary.md), направления зависимостей и DI — [архитектурные принципы](01_architecture_principles.md).

## 1. Владельцы поведения

Пути ниже ведут к текущим точкам входа. Таблица описывает ответственность фичи целиком; наличие правила в строке не требует переноса его в новый слой или класс.

| Фича | Отвечает за | Граница ответственности и точки входа |
| :--- | :--- | :--- |
| `auth` | Доступ приложения, вход, выход, гостевой режим и профиль аккаунта. | Единственный владелец режима доступа. [AuthController](../lib/packages/features/auth/auth_controller.dart), [AuthAccess](../lib/packages/features/auth/domain/auth_access.dart); [спецификация](specs/01_authentication.md). |
| `catalog` | Выдача аниме, страницы, фильтры и сортировка каталога. | Предоставляет `AnimeSummary`, `AnimePage`, `CatalogFilter` потребителям. [CatalogBloc](../lib/packages/features/catalog/presentation/bloc/catalog_bloc.dart), [контракты](../lib/packages/features/catalog/domain/repositories); [страницы](specs/03_page_loading.md), [фильтры](specs/09_catalog_filters.md). |
| `anime` | Полная карточка, связанные части, список серий и выбор серии для основного действия. | Читает отметки watch_history, использует действия favorites. [AnimeScreen](../lib/packages/features/anime/presentation/screens/anime_screen.dart), [selectAnimeWatchAction](../lib/packages/features/anime/domain/models/anime_watch_action.dart); [спецификация](specs/12_anime_details.md). |
| `search` | Отправка запроса, валидация, поисковая выдача, пагинация и локальная история запросов. | Использует модели выдачи catalog; не владеет историей просмотра. [SearchBloc](../lib/packages/features/search/presentation/search_bloc.dart), [SearchRules](../lib/packages/features/search/domain/search_rules.dart), [локальная история](../lib/packages/features/search/data/local_search_history_repository.dart); [спецификация](specs/13_search.md). |
| `favorites` | Подтверждённые статусы, операции и выдача избранного аккаунта. | Владеет изменением избранного независимо от экрана с кнопкой. [FavoritesController](../lib/packages/features/favorites/favorites_controller.dart), [FavoritesRepository](../lib/packages/features/favorites/domain/favorites_repository.dart); [спецификация](specs/02_favorites.md). |
| `player` | Получение playback session, native playback, выбор серии/качества, retry и lifecycle плеера. | Сообщает о фактическом начале воспроизведения; серверную отметку делает watch_history. [PlayerScreen](../lib/packages/features/player/presentation/screens/player_screen.dart), [playback repository](../lib/packages/features/player/data/repositories/anistar_playback_repository.dart); [спецификация](specs/04_playback.md). |
| `watch_history` | Загрузка и подтверждение просмотренных серий, последовательность операций отметки. | Владеет отметками аккаунта; не выбирает действие на карточке и не управляет native controller. [WatchedEpisodes](../lib/packages/features/watch_history/watched_episodes.dart), [репозиторий](../lib/packages/features/watch_history/domain/repositories/watched_episodes_repository.dart); [спецификация](specs/07_watched_episodes.md). |
| `home` | Оболочка приложения, выбор раздела и состояние его отображения. | Компонует экраны фич. [HomeScreen](../lib/packages/features/home/presentation/screens/home_screen.dart); [TV](specs/06_tv_interaction.md), [mobile](specs/10_mobile_interaction.md). |
| `log_viewer` | Загрузка и отображение диагностических логов. | Получает данные через свой [LogRepository](../lib/packages/features/log_viewer/domain/repositories/log_repository.dart); создание логов принадлежит app_logging. |
| `common` | Уже используемые общие feature helpers: отображение ошибок, рейтинга, преобразование ошибок сайта. | [Каталог common](../lib/packages/features/common). Новое правило конкретной фичи размещается у её владельца; повторное использование само по себе не делает правило общим. |

---

## 2. Композиция и инфраструктура

| Участник | Ответственность |
| :--- | :--- |
| [App container](../lib/app/app_container.dart) | Связывает контракты с реализациями, передаёт зависимости и область аккаунта/origin. Не становится владельцем правил избранного или выбора серии. |
| [App routes](../lib/app/app_routes.dart) | Связывает экраны и маршруты приложения. Feature передаёт намерение перехода через существующие callbacks. |
| [AniStar](../infrastructure/anistar/README.md) | Протокол сайта, нормализованные данные, cookies, зеркала и site session. Feature data переводит контракт сайта в свои модели и ошибки. |
| [Networking](../infrastructure/networking/README.md) | HTTP transport и `BaseRepository`. |
| [Core](../infrastructure/core/README.md) | Нейтральные `Result`/`Failure` и общие примитивы в пределах контракта пакета. |
| [Storage](../infrastructure/storage/README.md) | Механизм хранения. Значение сохраняемых данных определяет фича-владелец. |
| [App Logging](../infrastructure/app_logging/README.md), [UI Kit](../lib/packages/ui_kit/README.md) | Логирование и общие UI-компоненты соответственно; предметные решения остаются у фич. |

---

## 3. Взаимодействия между фичами

Общие UI-контракты применяются к владельцам из разделов выше: [TV-взаимодействие](specs/06_tv_interaction.md), [мобильное взаимодействие](specs/10_mobile_interaction.md), [анимации](specs/08_motion.md) и [визуальная система](specs/11_visual_system.md). UI Kit предоставляет общие компоненты и токены, app связывает маршруты, а экраны фич применяют их к своим сценариям.

| Сценарий | Участники и передача ответственности | Подробный контракт |
| :--- | :--- | :--- |
| Запуск просмотра с карточки | anime получает карточку и серии, учитывает подтверждённые отметки watch_history и выбирает серию. App открывает player с выбранными данными. | [Карточка аниме](specs/12_anime_details.md) |
| Отметка просмотра | player обнаруживает фактическое начало воспроизведения → watch_history отправляет операцию через свой репозиторий → подтверждение сайта обновляет отметки. Ошибка отметки не является основанием обновлять HLS-источник. | [Просмотренные серии](specs/07_watched_episodes.md) |
| Изменение избранного | Экран вызывает действие favorites → контроллер выполняет операцию через репозиторий → подтверждённый результат доступен потребителям. Доступ аккаунта определяется auth. | [Избранное](specs/02_favorites.md) |
| Поиск и открытие результата | search владеет запросом и историей, использует `AnimePage`/`AnimeSummary` из catalog; переход к полной карточке связывает app. | [Поиск](specs/13_search.md) |
| Смена аккаунта или зеркала | auth и инфраструктура определяют актуальные доступ и origin; app передаёт область зависимостям. Потребители отсеивают устаревшие результаты и освобождают ресурсы по своим lifecycle-контрактам. | [Вход](specs/01_authentication.md), [зеркала](specs/05_mirrors.md), [lifecycle](01_architecture_principles.md#6-lifecycle) |

Существующие модели и контракты могут использоваться несколькими фичами: search возвращает модели catalog, anime использует `CatalogFilter`, а `FavoritesRepository` реализует `CatalogRepository`. Data-адаптеры переиспользуют [catalog mapping](../lib/packages/features/catalog/data/mapping/anistar_catalog_mapping.dart). Эти связи учитываются при изменении публичных контрактов; карта не вводит запрет на все межфичевые зависимости.

---

## 4. Как выбрать место изменения

1. Уточните смысл терминов по глоссарию и поведение по применимой спецификации.
2. Найдите фичу, которая владеет изменяемым решением или состоянием. Экран, показывающий данные, не обязательно является их владельцем.
3. Проверьте существующий контракт и его потребителей. Сохраняйте направления зависимостей из архитектурных принципов и композицию через app.
4. Меняйте подробные сценарии и критерии приёмки в спецификации. Обновляйте эту карту, если меняется владелец или взаимодействие, а глоссарий — если меняется смысл термина.

При расхождении кода и документов укажите конкретное расхождение в задаче. Не используйте справочники как основание для несогласованного изменения архитектуры. Новое архитектурное решение оформляется по действующему [процессу ADR](adr/README.md).
