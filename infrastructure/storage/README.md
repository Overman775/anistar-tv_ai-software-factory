# 💾 Storage Package | AniStar TV

`storage` предоставляет платформенные preferences и secure storage для runner и потребителей инфраструктурных пакетов.

## Использование

Используйте публичные библиотеки:

| Импорт | API |
| --- | --- |
| `package:storage/storage.dart` | `SharedPreferencesStorage` и `SecureStorage` |
| `package:storage/providers.dart` | Провайдеры хранилищ |

Runner создаёт `SharedPreferencesStorage`, вызывает `init` и передаёт тот же экземпляр в app overrides. `SecureStorage` также передаётся через overrides. Обе реализации получают logger конструктором.

## Границы и условия использования

Не импортируйте `src/**`. Зависимости разрешаются корневым pub workspace. Ключи и прикладные правила хранения принадлежат потребителю. Значения secure storage не записываются в логи.

## Как проверить

`test/app/app_container_test.dart` проверяет binding runtime-экземпляров и охватывает DI, но не проверяет native backend хранилища. Android E2E проверяет запись cookies, восстановление через новый runner и удаление при выходе на настоящем backend `flutter_secure_storage`. Команды запуска Android fixture E2E описаны в [Melos tooling](../../docs/melos_tooling.md#2-запуск-сборка-и-устройства).

## Навигация

- [Структура проекта](../../docs/02_project_structure.md) — границы пакетов и передача зависимостей runner.
- [Сеть и HLS](../../docs/04_network_and_playback.md) — использование сессии и cookies.
- [Melos tooling](../../docs/melos_tooling.md) — команды проверок и Android E2E.
