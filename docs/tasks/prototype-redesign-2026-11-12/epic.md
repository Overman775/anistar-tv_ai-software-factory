# prototype-redesign-2026-11-12

Source: prototype-redesign-2026-11-12 revision 3

- [visual-system-01](01-visual-system.md)
- [shared-media-cards-02](02-shared-media-cards.md)
- [source-metadata-03](03-source-metadata.md)
- [tv-catalog-rail-04](04-tv-catalog-rail.md)
- [tv-visible-continuation-05](05-tv-visible-continuation.md)
- [anime-episodes-entry-06](06-anime-episodes-entry.md)
- [author-filter-sorting-07](07-author-filter-sorting.md)
- [anime-disclosure-navigation-08](08-anime-disclosure-navigation.md)
- [search-query-results-09](09-search-query-results.md)
- [access-and-tv-menu-10](10-access-and-tv-menu.md)
- [confirmed-favorites-11](11-confirmed-favorites.md)
- [tv-source-navigation-12](12-tv-source-navigation.md)
- [tv-watch-shortcut-13](13-tv-watch-shortcut.md)
- [native-player-episode-panel-14](14-native-player-episode-panel.md)
- [mobile-shell-and-grids-15](15-mobile-shell-and-grids.md)
- [redesign-documentation-16](16-redesign-documentation.md)
- [tv-list-goldens-17](17-tv-list-goldens.md)
- [tv-detail-player-goldens-18](18-tv-detail-player-goldens.md)
- [mobile-and-common-goldens-19](19-mobile-and-common-goldens.md)
- [redesign-final-verification-20](20-redesign-final-verification.md)
- [redesign-version-changelog-21](../redesign-release-preparation/21-redesign-version-changelog.md) — отдельная задача после итоговой приёмки редизайна.

```mermaid
flowchart TD
  %% Task purpose styles
  classDef functionality fill:#bbf,stroke:#333,stroke-width:1px;
  classDef technical_preparation fill:#6f9,stroke:#333,stroke-width:1px;
  classDef research fill:#f9f,stroke:#333,stroke-width:1px;
  classDef backend fill:#ff9,stroke:#333,stroke-width:1px,stroke-dasharray: 5 5;

  subgraph scope_000 ["Scope: anime"]
    task_001["anime-disclosure-navigation-08<br/>Подробности аниме, переходы... (11–16 h)"]
    task_002["anime-episodes-entry-06<br/>Свёрнутая карточка с общей ... (11–16 h)"]
    task_014["tv-detail-player-goldens-18<br/>TV-эталоны карточки аниме, ... (8–14 h)"]
    task_018["tv-watch-shortcut-13<br/>«Смотреть» запускает извест... (6–11 h)"]
  end

  subgraph scope_001 ["Scope: anistar"]
    task_012["source-metadata-03<br/>Исходные метаданные для выд... (8–15 h)"]
  end

  subgraph scope_002 ["Scope: app"]
    task_009["redesign-final-verification-20<br/>Итоговая приёмка редизайна,... (7–13 h)"]
  end

  subgraph scope_003 ["Scope: catalog"]
    task_003["author-filter-sorting-07<br/>Выдача автора и подтверждён... (10–16 h)"]
    task_013["tv-catalog-rail-04<br/>TV-каталог с закреплённой л... (11–16 h)"]
    task_015["tv-list-goldens-17<br/>Эталоны четырёх TV-выдач и ... (10–16 h)"]
    task_017["tv-visible-continuation-05<br/>Продолжение TV-выдачи при в... (10–16 h)"]
  end

  subgraph scope_004 ["Scope: docs"]
    task_008["redesign-documentation-16<br/>Спецификации и справочники ... (7–12 h)"]
  end

  subgraph scope_005 ["Scope: favorites"]
    task_004["confirmed-favorites-11<br/>Избранное и действия постер... (10–16 h)"]
  end

  subgraph scope_006 ["Scope: home"]
    task_000["access-and-tv-menu-10<br/>Запуск, вход и TV-меню с до... (10–16 h)"]
    task_006["mobile-shell-and-grids-15<br/>Мобильная навигация, сетки,... (11–16 h)"]
    task_016["tv-source-navigation-12<br/>Пульт и восстановление конт... (9–15 h)"]
  end

  subgraph scope_007 ["Scope: player"]
    task_007["native-player-episode-panel-14<br/>Новый интерфейс плеера с на... (10–16 h)"]
  end

  subgraph scope_008 ["Scope: search"]
    task_010["search-query-results-09<br/>Поиск с явной отправкой и в... (10–16 h)"]
  end

  subgraph scope_009 ["Scope: ui_kit"]
    task_005["mobile-and-common-goldens-19<br/>Мобильные и общие эталоны п... (8–14 h)"]
    task_011["shared-media-cards-02<br/>Общие карточки аниме и серий (7–12 h)"]
    task_019["visual-system-01<br/>Общие визуальные роли AniSt... (9–15 h)"]
  end

  class task_000 functionality;
  class task_001 functionality;
  class task_002 functionality;
  class task_003 functionality;
  class task_004 functionality;
  class task_005 functionality;
  class task_006 functionality;
  class task_007 functionality;
  class task_008 functionality;
  class task_009 functionality;
  class task_010 functionality;
  class task_011 technical_preparation;
  class task_012 technical_preparation;
  class task_013 functionality;
  class task_014 functionality;
  class task_015 functionality;
  class task_016 functionality;
  class task_017 functionality;
  class task_018 functionality;
  class task_019 technical_preparation;

  %% Task dependencies
  task_013 --> task_000
  task_019 --> task_000
  task_002 --> task_001
  task_003 --> task_001
  task_012 --> task_001
  task_011 --> task_002
  task_019 --> task_002
  task_012 --> task_003
  task_013 --> task_003
  task_017 --> task_003
  task_000 --> task_004
  task_001 --> task_004
  task_010 --> task_004
  task_017 --> task_004
  task_006 --> task_005
  task_018 --> task_005
  task_000 --> task_006
  task_001 --> task_006
  task_004 --> task_006
  task_007 --> task_006
  task_010 --> task_006
  task_016 --> task_006
  task_000 --> task_007
  task_002 --> task_007
  task_004 --> task_007
  task_011 --> task_007
  task_006 --> task_008
  task_018 --> task_008
  task_005 --> task_009
  task_008 --> task_009
  task_014 --> task_009
  task_015 --> task_009
  task_011 --> task_010
  task_013 --> task_010
  task_017 --> task_010
  task_019 --> task_011
  task_011 --> task_013
  task_012 --> task_013
  task_019 --> task_013
  task_006 --> task_014
  task_018 --> task_014
  task_006 --> task_015
  task_018 --> task_015
  task_000 --> task_016
  task_001 --> task_016
  task_003 --> task_016
  task_004 --> task_016
  task_010 --> task_016
  task_013 --> task_016
  task_017 --> task_016
  task_013 --> task_017
  task_001 --> task_018
  task_004 --> task_018
  task_016 --> task_018
  task_009 --> release_followup["21. Повысить версию и обновить changelog"]
```

```json
{
  "kind": "epic",
  "id": "prototype-redesign-2026-11-12",
  "title": "prototype-redesign-2026-11-12",
  "outcome": "Tasks from approved plan prototype-redesign-2026-11-12",
  "tasks": [
    {
      "id": "visual-system-01",
      "file": "docs/tasks/prototype-redesign-2026-11-12/01-visual-system.md"
    },
    {
      "id": "shared-media-cards-02",
      "file": "docs/tasks/prototype-redesign-2026-11-12/02-shared-media-cards.md"
    },
    {
      "id": "source-metadata-03",
      "file": "docs/tasks/prototype-redesign-2026-11-12/03-source-metadata.md"
    },
    {
      "id": "tv-catalog-rail-04",
      "file": "docs/tasks/prototype-redesign-2026-11-12/04-tv-catalog-rail.md"
    },
    {
      "id": "tv-visible-continuation-05",
      "file": "docs/tasks/prototype-redesign-2026-11-12/05-tv-visible-continuation.md"
    },
    {
      "id": "anime-episodes-entry-06",
      "file": "docs/tasks/prototype-redesign-2026-11-12/06-anime-episodes-entry.md"
    },
    {
      "id": "author-filter-sorting-07",
      "file": "docs/tasks/prototype-redesign-2026-11-12/07-author-filter-sorting.md"
    },
    {
      "id": "anime-disclosure-navigation-08",
      "file": "docs/tasks/prototype-redesign-2026-11-12/08-anime-disclosure-navigation.md"
    },
    {
      "id": "search-query-results-09",
      "file": "docs/tasks/prototype-redesign-2026-11-12/09-search-query-results.md"
    },
    {
      "id": "access-and-tv-menu-10",
      "file": "docs/tasks/prototype-redesign-2026-11-12/10-access-and-tv-menu.md"
    },
    {
      "id": "confirmed-favorites-11",
      "file": "docs/tasks/prototype-redesign-2026-11-12/11-confirmed-favorites.md"
    },
    {
      "id": "tv-source-navigation-12",
      "file": "docs/tasks/prototype-redesign-2026-11-12/12-tv-source-navigation.md"
    },
    {
      "id": "tv-watch-shortcut-13",
      "file": "docs/tasks/prototype-redesign-2026-11-12/13-tv-watch-shortcut.md"
    },
    {
      "id": "native-player-episode-panel-14",
      "file": "docs/tasks/prototype-redesign-2026-11-12/14-native-player-episode-panel.md"
    },
    {
      "id": "mobile-shell-and-grids-15",
      "file": "docs/tasks/prototype-redesign-2026-11-12/15-mobile-shell-and-grids.md"
    },
    {
      "id": "redesign-documentation-16",
      "file": "docs/tasks/prototype-redesign-2026-11-12/16-redesign-documentation.md"
    },
    {
      "id": "tv-list-goldens-17",
      "file": "docs/tasks/prototype-redesign-2026-11-12/17-tv-list-goldens.md"
    },
    {
      "id": "tv-detail-player-goldens-18",
      "file": "docs/tasks/prototype-redesign-2026-11-12/18-tv-detail-player-goldens.md"
    },
    {
      "id": "mobile-and-common-goldens-19",
      "file": "docs/tasks/prototype-redesign-2026-11-12/19-mobile-and-common-goldens.md"
    },
    {
      "id": "redesign-final-verification-20",
      "file": "docs/tasks/prototype-redesign-2026-11-12/20-redesign-final-verification.md"
    }
  ]
}
```
