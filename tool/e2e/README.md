# 📺 Android E2E Fixtures | AniStar TV

Локальный HTTPS server имитирует AniStar HTML и HLS. Настоящие repositories, parser и native video работают с его ответами.

## Запуск

```bash
bash scripts/e2e.sh emulator-5554
```

Нужны запущенный Android emulator, закреплённый Flutter SDK, Python 3.10+ и Android SDK. FFmpeg нужен только для пересоздания media. Команда автоматически выполняет шесть Python-тестов fixture server.

## Контракты

- Каталог/карточка: windows-1251; player HTML: UTF-8 и JavaScript playlist.
- Вход с вымышленными credentials, Secure Storage restore и session expiry.
- Избранное хранится в fixture server: session cookie, AJAX plus/minus, список и control в HTML; режим favorite_error возвращает HTTP 200 с error.
- Рекламный ID 9493, две страницы и серии в обратном порядке.
- URL `720.mp4` возвращает HLS master; вложенный playlist содержит relative/absolute TS.
- Media требует Referer; Range возвращает 206 и Content-Range.
- `refresh_once` отклоняет первый playback URL; `always_expired` отклоняет все.
- Только loopback; ни одного запроса к AniStar или CDN.

Certificate находится в Android debug resources и повторён в Dart test helper. Private key в `tls/` публичный, предназначен для localhost fixtures. При замене certificate обновляйте обе копии; release resources его не содержат.

## Media

Синтетические 24-секундные H.264/AAC fixtures находятся в `media/`; они не входят в pubspec assets. Пересоздание:

```bash
bash scripts/regenerate_e2e_media.sh
```

После обновления выполните Python-тесты и E2E. Тесты fixture server отдельно:

```bash
python3 -m unittest discover -s tool/e2e -p '*_test.py'
```

## Живой сайт

`bash scripts/e2e.sh emulator-5554 live` использует `env/live-test.local.json` автоматически; в VS Code есть задача **Flutter: Live Android E2E**. Локальный файл исключён из Git, шаблон без credentials — `env/live-test.example.json`. Форму входа заполняет live harness через Dart define. Настройка и ограничения: [Проверка с живым аккаунтом](../../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

Все команды и сценарии: [Разработка и тестирование](../../docs/05_development_and_testing.md).
