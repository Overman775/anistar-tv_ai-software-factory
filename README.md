# 📺 AniStar TV

**AniStar TV** — Flutter-приложение для Android TV: каталог аниме, выбор серии и нативное HLS-воспроизведение с управлением пультом.

> ℹ️ **Концепция:** приложение отвечает за TV-интерфейс и воспроизведение. Каталог, серии и короткоживущие HLS-сессии предоставляет отдельный AniStar Parser через типизированный OpenAPI-контракт.

## 🚀 Быстрый старт

Требования: FVM, JDK 17, Android SDK и запущенный AniStar Parser.

```bash
# 1. Установить закреплённую версию Flutter
fvm install

# 2. Получить зависимости
fvm flutter pub get

# 3. Запустить dev-сборку на Android Emulator
fvm flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=ANISTAR_API_URL=http://10.0.2.2:8001/
```

Для физического телевизора укажите LAN- или HTTPS-адрес parser. Production-сборка принимает только HTTPS endpoint.

## ✨ Возможности

- адаптивный каталог для TV с пагинацией и навигацией стрелками;
- экран аниме с описанием и выбором серии;
- нативное HLS-воспроизведение через `video_player` без WebView;
- новая защищённая playback-сессия перед каждым просмотром;
- dev/prod flavors, локальные логи и сгенерированный OpenAPI-клиент.

## ⚙️ Конфигурация

| Параметр | Назначение | Значение по умолчанию |
| --- | --- | --- |
| `ANISTAR_API_URL` | Базовый URL AniStar Parser | Dev: `http://10.0.2.2:8001/`; для prod обязателен явный HTTPS URL |
| `--flavor dev` | Локальная разработка, HTTP разрешён | — |
| `--flavor prod` | Production, cleartext HTTP запрещён | — |

## 📚 Документация

- [🏛️ Архитектура и структура](docs/01_architecture_and_structure.md)
- [📏 Рекомендации по коду и TV UI](docs/02_code_style_and_tv_guidelines.md)
- [🌐 Сеть, OpenAPI и HLS](docs/03_network_openapi_and_playback.md)
- [🧪 Разработка и тестирование](docs/04_development_and_testing.md)
- [🧭 Архитектурные решения](docs/adr/README.md)

## ✅ Проверка проекта

```bash
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
dcm analyze lib test
fvm flutter test
fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart
```
