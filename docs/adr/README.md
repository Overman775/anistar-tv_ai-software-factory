# Architecture Decision Records

ADR фиксируют принятые системные решения, их контекст и последствия. Локальный рефакторинг без изменения границ отдельного ADR не требует.

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

Заменённые решения о parser-сервере и старом Core удалены при очистке проекта. Номера оставшихся ADR сохранены.

Для изменений интерфейса сначала прочитайте [ADR-0008](0008-youtube-tv-interaction-reference.md): он задаёт основной TV-ориентир и порядок пересмотра UI-контрактов.

## Формат нового ADR

1. Статус, дата и связанные решения.
2. Контекст и конкретная проблема.
3. Принятое решение и границы применимости.
4. Последствия и ограничения.
