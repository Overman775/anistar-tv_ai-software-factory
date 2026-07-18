# Разработка

## Требования

- FVM и Flutter 3.44.2;
- JDK 17 и Android SDK;
- доступный AniStar Parser.

## Запуск

```bash
fvm install
fvm flutter pub get
fvm flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=ANISTAR_API_URL=http://10.0.2.2:8001/
```

Для production используйте `--flavor prod -t lib/main_prod.dart` и HTTPS parser endpoint.
HTTP разрешён только во flavor `dev`; production manifest блокирует cleartext-трафик.

## Ежедневные проверки

```bash
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
dcm analyze lib test
fvm flutter test
fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart
```

## Частые проблемы

| Симптом | Действие |
| --- | --- |
| Каталог не загружается | Проверьте `ANISTAR_API_URL` и доступность parser с устройства. |
| Видео не запускается | Создайте новую сессию в player; проверьте ответ `getPlaybackInfo`. |
| Приложение не видно в TV launcher | Убедитесь, что установлена актуальная APK с `LEANBACK_LAUNCHER`. |
| Parser недоступен с physical TV | Передайте LAN-адрес вместо emulator-адреса `10.0.2.2`. |
| Генерация API не запускается | Установите `openapi-generator` версии 7.23.0 и проверьте схему. |

## Поддержка документации

Обновляйте этот каталог при изменении API-контракта, структуры модулей, команды запуска или Android toolchain. После заметных изменений кода выполняйте `graphify update .`.
