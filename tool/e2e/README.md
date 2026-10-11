# Android TV и Mobile E2E Fixtures | AniStar TV

Локальный HTTPS server имитирует AniStar HTML и HLS. Настоящие repositories, parser и native video работают с его ответами.

## Запуск

```bash
bash scripts/e2e-tv.sh
bash scripts/e2e-mobile.sh
# Последовательно, два разных эмулятора, отдельные результаты:
bash scripts/e2e-all.sh
```

Нужны существующие запущенные AVD: `anistar_tv_e2e` (Android TV API 36) и `anistar_mobile_e2e` (Pixel 6 / API 36), закреплённый Flutter SDK, Python 3.10+ и Android SDK. Они выбираются по имени AVD, а не номеру первого устройства в adb. Имена можно переопределить через `ANISTAR_TV_AVD` / `ANISTAR_MOBILE_AVD`; явный `emulator-<port>` передаётся первым аргументом платформенного скрипта. AVD не создаются и не стираются; отсутствующее устройство вызывает ошибку с командой его запуска. FFmpeg нужен только для пересоздания media.

TV hardware skin и широкое разрешение на phone image недостаточны. До сборки проверяются boot readiness и настоящий Android UI mode; TV дополнительно требует hardware D-pad. Прежний `anistar_e2e` имеет phone image и не выбран TV-скриптом по умолчанию.

TV-набор находится в `integration_test/app_e2e_test.dart`, mobile — в `integration_test/mobile_e2e_test.dart`. Общие fixtures/transport/storage используют один harness; touch helpers отделены от remote helpers. Runner определяет профиль нативно и использует фактические размеры экрана. TV покрывает крестовину, удержание OK/seek, фокус и правые панели. Mobile отдельно покрывает touch/IME, сессию, скролл и обновление, вкладки/Back, фильтр/сортировку, нижние панели избранного, native HLS и настоящий поворот Android, ошибки/ручной повтор.

Общий запуск выполняет оба набора последовательно и сохраняет оба результата, включая случай отказа первого. Flutter/Gradle и APK output общие, поэтому параллельные E2E runners отклоняются build lock. Старый CLI совместим: `bash scripts/e2e.sh <tv-emulator> fixtures`, `bash scripts/e2e.sh <phone-emulator> fixtures-mobile`.

## Отчёты

У каждой платформы собственный каталог `build/e2e/<platform>-<mode>-seed-<seed>-<avd>.<suffix>/`: `runner.log`, `flutter.log`, `flutter-events.jsonl`, `logcat.log`, fixture `requests.jsonl`, `selection.json`, `summary.json` и `junit.xml`. При отказе preflight отчёт записывает причину этапа без успешных native-тестов. Общий запуск создаёт отдельные `tv/` и `mobile/` и агрегирует summary/JUnit в корне своего каталога.

Для другого порядка: `ANISTAR_TEST_SEED=1337 bash scripts/e2e-all.sh`. Изменение seed не меняет выбранные устройства. Cleanup убирает fixture server и его adb reverse, восстанавливает настройку immersive confirmation и освобождает lock.

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

`bash scripts/e2e-tv.sh live` использует `env/live-test.local.json` автоматически; в VS Code есть задача **Flutter: Live Android E2E**. Live не входит в общий offline-прогон. Локальный файл исключён из Git, шаблон без credentials — `env/live-test.example.json`. Форму входа заполняет live harness через Dart define. Настройка и ограничения: [Проверка с живым аккаунтом](../../docs/05_development_and_testing.md#9-проверка-с-живым-аккаунтом).

Все команды и сценарии: [Разработка и тестирование](../../docs/05_development_and_testing.md).
