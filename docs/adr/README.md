# Architecture Decision Records

ADR сохраняют контекст, принятое архитектурное решение и его последствия. Локальный рефакторинг без изменения архитектурных границ отдельного ADR не требует.

## Реестр

| Дата | ADR | Статус |
| --- | --- | --- |
| 2026-07-19 | [0004: Riverpod для DI](0004-use-riverpod-for-app-di.md) | Accepted |
| 2026-07-19 | [0005: Единое runtime-логирование](0005-centralize-runtime-logging.md) | Accepted |
| 2026-10-10 | [0006: Прямой AniStar на Android](0006-android-direct-anistar.md) | Accepted |
| 2026-10-10 | [0007: Нейтральный Core и инфраструктура](0007-neutral-core-and-infrastructure.md) | Accepted |
| 2026-10-11 | [0008: YouTube для телевизоров как ориентир взаимодействия](0008-youtube-tv-interaction-reference.md) | Accepted |
| 2026-10-11 | [0009: Единый AniStarClient и Dio](0009-single-anistar-client-and-dio.md) | Accepted |
| 2026-10-12 | [0010: Нормализованный контракт AniStar](0010-normalized-anistar-contract.md) | Accepted |
| 2026-10-24 | [0011: Компактный код и политика анализа](0011-compact-code-analysis-policy.md) | Accepted |

Решения о parser-сервере и прежнем Core удалены при очистке проекта; номера оставшихся ADR сохранены. `Accepted` означает, что решение принято, но не подтверждает завершение его реализации. При создании ADR используйте [указатель шаблонов](../templates/README.md) и [шаблон ADR](../templates/adr.md). Раздел «Альтернативы» нужен, когда он объясняет реальные рассмотренные варианты; не придумывайте варианты, которых не было.

Для изменений интерфейса сначала прочитайте [ADR-0008](0008-youtube-tv-interaction-reference.md). Он задаёт основной TV-ориентир и порядок пересмотра UI-контрактов.
