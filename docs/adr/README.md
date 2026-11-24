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

Номера удалённых ADR сохранены за прежними решениями о parser-сервере и Core. `Accepted` обозначает принятое решение. Для нового решения используйте [шаблон ADR](../templates/adr.md).

При изменении интерфейса начните с [ADR-0008](0008-youtube-tv-interaction-reference.md).
