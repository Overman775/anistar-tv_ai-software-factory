# 🧭 ADR-0001: AniStar Parser, OpenAPI и native HLS

> **Статус:** заменено ADR-0002 19 июля 2026 года.

> Исторический выбор Parser и native HLS остаётся в силе; способ генерации и networking уточнён в [ADR-0002](0002-use-swagger-parser-retrofit-networking.md).

## 1. Контекст

HTML AniStar, WebView player и прямые CDN URL не образуют стабильный контракт для Android TV-клиента. Изменение upstream-разметки ломает приложение, а подписанные ссылки имеют ограниченный срок жизни.

AniStar Parser уже предоставляет каталог, серии и переписанные HLS manifests через HTTP API.

## 2. Решение

1. AniStar Parser становится единственной внешней границей данных и воспроизведения.
2. `openapi/anistar.openapi.json` генерирует типизированный пакет `packages/anistar_api`.
3. Feature repositories переводят generated DTO в domain-модели приложения.
4. Перед каждым просмотром клиент создаёт новую playback-сессию.
5. HLS воспроизводится нативно через `video_player`; WebView не используется.

## 3. Последствия

### Положительные

- изменение upstream изолировано внутри parser;
- API-контракт обновляется воспроизводимо;
- presentation не знает о CDN, HTML и transport DTO;
- player использует нативный Android media stack.

### Ограничения

- приложению нужен доступный parser endpoint;
- истёкший HLS token требует новой playback-сессии;
- изменение схемы требует регенерации и проверки клиента.
