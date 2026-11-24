# 🧭 Ответственность фич | AniStar TV

Карта владельцев поведения и состояния. См. [значения терминов](01_01_domain_glossary.md) и [правила слоёв и DI](01_architecture_principles.md).

## 1. Владельцы поведения

| Фича | Ответственность | Точки входа |
| :--- | :--- | :--- |
| `auth` | Единственный владелец доступа, входа, выхода, гостевого режима и профиля аккаунта. | [AuthController](../lib/packages/features/auth/auth_controller.dart), [вход](specs/01_authentication.md). |
| `catalog` | Выдача, пагинация, фильтры и сортировка каталога. Предоставляет `AnimeSummary`, `AnimePage`, `CatalogFilter`. | [CatalogBloc](../lib/packages/features/catalog/presentation/bloc/catalog_bloc.dart), [страницы](specs/03_page_loading.md), [фильтры](specs/09_catalog_filters.md). |
| `anime` | Полная карточка, части, серии и правило выбора серии для основного действия. | [AnimeScreen](../lib/packages/features/anime/presentation/screens/anime_screen.dart), [selectAnimeWatchAction](../lib/packages/features/anime/domain/models/anime_watch_action.dart), [карточка](specs/12_anime_details.md). |
| `search` | Валидация и отправка запроса, выдача, пагинация и локальная история поиска. | [SearchBloc](../lib/packages/features/search/presentation/search_bloc.dart), [SearchRules](../lib/packages/features/search/domain/search_rules.dart), [LocalSearchHistoryRepository](../lib/packages/features/search/data/local_search_history_repository.dart), [поиск](specs/13_search.md). |
| `favorites` | Подтверждённые статусы, изменение и список избранного аккаунта. | [FavoritesController](../lib/packages/features/favorites/favorites_controller.dart), [избранное](specs/02_favorites.md). |
| `player` | Playback session, native playback, выбор серии и качества, retry и lifecycle. | [PlayerScreen](../lib/packages/features/player/presentation/screens/player_screen.dart), [воспроизведение](specs/04_playback.md). |
| `watch_history` | Чтение и подтверждение отметок аккаунта, порядок операций записи. | [WatchedEpisodes](../lib/packages/features/watch_history/watched_episodes.dart), [просмотренные серии](specs/07_watched_episodes.md). |
| `home` | Оболочка, выбор раздела и состояние его отображения. Компонует экраны фич. | [HomeScreen](../lib/packages/features/home/presentation/screens/home_screen.dart). |
| `log_viewer` | Чтение и отображение диагностических логов. | [LogRepository](../lib/packages/features/log_viewer/domain/repositories/log_repository.dart). |
| `common` | Общие feature helpers для отображения ошибок, рейтинга и преобразования ошибок сайта. Правила конкретной фичи остаются у её владельца. | [Каталог common](../lib/packages/features/common). |

---

## 2. Композиция и инфраструктура

[App container](../lib/app/app_container.dart) связывает контракты с реализациями и передаёт область аккаунта/origin. [App routes](../lib/app/app_routes.dart) связывает экраны и маршруты.

[AniStar](../infrastructure/anistar/README.md) владеет протоколом сайта, нормализованными DTO, cookies, зеркалами и site session. Ответственность остальных пакетов указана в [карте workspace](02_project_structure.md#2-владельцы-пакетов). Фича определяет смысл сохраняемых данных и применяет общие компоненты к своему сценарию.

---

## 3. Взаимодействия между фичами

| Сценарий | Передача ответственности |
| :--- | :--- |
| Запуск просмотра с карточки | TV-список передаёт намерение в app. Для выбора серии app использует актуальные загруженные данные, правило `anime` и отметки `watch_history`. При необходимости app открывает полную карточку, где пользователь выбирает серию. [Карточка](specs/12_anime_details.md). |
| Отметка просмотра | `player` сообщает о начале воспроизведения. `watch_history` записывает отметку и обновляет её после подтверждения сайта. Ошибка отметки не запускает HLS refresh. [Просмотренные серии](specs/07_watched_episodes.md). |
| Избранное | `auth` определяет доступ. Экран вызывает действие `favorites`, который через репозиторий подтверждает и публикует результат. [Избранное](specs/02_favorites.md). |
| Поиск | `search` возвращает `AnimePage` и `AnimeSummary` из `catalog`. App открывает полную карточку. [Поиск](specs/13_search.md). |
| Смена аккаунта или зеркала | `auth` и инфраструктура определяют доступ и origin. App передаёт новую область, потребители отбрасывают поздние ответы и освобождают ресурсы. [Вход](specs/01_authentication.md), [зеркала](specs/05_mirrors.md), [lifecycle](01_03_di_and_lifecycle.md#2-владение-ресурсами). |

При изменении публичного контракта проверьте потребителей. `anime` использует `CatalogFilter`, `FavoritesRepository` реализует `CatalogRepository`, а Data-адаптеры переиспользуют [catalog mapping](../lib/packages/features/catalog/data/mapping/anistar_catalog_mapping.dart).

Общие UI-контракты действуют во всех фичах. [TV](specs/06_tv_interaction.md), [mobile](specs/10_mobile_interaction.md), [анимации](specs/08_motion.md), [визуальная система](specs/11_visual_system.md).

---

## 4. Как выбрать место изменения

Найдите владельца решения или состояния и проверьте его контракт и потребителей. Меняйте подробное поведение в спецификации. Обновляйте карту при смене владельца или взаимодействия. Расхождение кода и спецификации фиксируйте в задаче. Новое архитектурное решение оформляйте по [процессу ADR](adr/README.md).
