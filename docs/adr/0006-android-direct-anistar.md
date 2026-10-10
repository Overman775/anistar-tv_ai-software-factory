# ADR-0006: Прямой AniStar на Android

- **Статус:** Accepted
- **Дата:** 2026-10-10

## Контекст

[Проверки Android](../06_verification.md) подтвердил получение каталога, карточки и playlst обычным Dart HTTP, а также native HLS 360p/720p с Referer и явным форматом. Проверенное зеркало доступно без браузера и parser-сервера.

## Решение

- Android-клиент использует AnistarSource, bytes/charset, DOM и JSON5 как данные.
- Feature repositories преобразуют DTO сайта в domain.
- Native video_player получает полный CDN URI, Referer и VideoFormat.hls.
- Один автоматический refresh получает новую ссылку и сохраняет позицию/паузу; ручной retry начинает новый бюджет.
- Зеркало задаётся HTTPS origin через ANISTAR_MIRROR_URL.
- Клиент поддерживает онлайн-просмотр; скачивание и офлайн не входят в scope.

## Последствия

Клиент работает без посредника, но зависит от разметки сайта и доступности зеркала для IP пользователя. Интерактивная CAPTCHA не обходится.

Сетевой контракт: [Сеть и HLS](../04_network_and_playback.md). Проверки: [Состояние проверок](../06_verification.md).
