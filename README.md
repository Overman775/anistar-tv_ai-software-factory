# AniStar TV

Android TV-клиент для каталога AniStar Parser: аниме, серии и нативное HLS-воспроизведение с управлением пультом.

Приложение не парсит HTML AniStar и не обращается к CDN напрямую. Оно использует локальный или production-экземпляр AniStar Parser, который возвращает типизированные данные и короткоживущие защищённые HLS URL.

## Запуск

Требования: FVM, JDK 17, Android SDK и запущенный AniStar Parser. Версия Flutter закреплена в .fvmrc.

~~~bash
fvm install
fvm flutter pub get
fvm flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=ANISTAR_API_URL=http://10.0.2.2:8001/
~~~

Для Android Emulator адрес по умолчанию — http://10.0.2.2:8001/; для physical TV передайте LAN/HTTPS-адрес parser через ANISTAR_API_URL. Production запускается через --flavor prod -t lib/main_prod.dart.

## OpenAPI-клиент

Каноническая схема vendored в openapi/anistar.openapi.json; её источник — ../anistar_parser/openapi.json.

~~~bash
# в parser-проекте
uv run python scripts/generate_openapi.py
uv run python scripts/validate_openapi.py openapi.json

# в этом проекте: после копирования схемы в openapi/
bash tool/generate_anistar_api.sh
~~~

Скрипт закрепляет OpenAPI Generator 7.23.0, генерирует path-пакет packages/anistar_api, запускает built_value_generator и применяет минимальный workaround для известной ошибки generator с enum default. Generated-код не редактируется вручную.

## Основные команды

~~~bash
fvm dart run build_runner build
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
dcm analyze lib test
fvm flutter test
fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart
~~~

## Документация

Подробности собраны в [docs/](docs/README.md): [архитектура](docs/architecture.md), [API и HLS](docs/api-integration.md), [разработка](docs/development.md) и [архитектурные решения](docs/adr/README.md).

## Graphify

~~~bash
graphify query "как каталог получает parser API и создаёт HLS-сессию"
graphify update .
~~~

Generated client, схема, SDK и кэш исключены из детального графа через .graphifyignore; в граф попадают application-owned API boundary и feature-модули.
