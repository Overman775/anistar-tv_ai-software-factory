# 💾 Storage Package | AniStar TV

Платформенные preferences и secure storage.

## 1. Публичные библиотеки

| Импорт | API |
| --- | --- |
| `package:storage/storage.dart` | SharedPreferencesStorage и SecureStorage |
| `package:storage/providers.dart` | Провайдеры хранилищ |

Внешний код не импортирует src/**. Зависимости разрешаются корневой pub workspace.

---

## 2. Ответственность и lifecycle

Runner создаёт SharedPreferencesStorage, вызывает init и передаёт тот же экземпляр в app overrides. SecureStorage также передаётся через overrides. Обе реализации получают logger конструктором.

Ключи и прикладные правила хранения принадлежат потребителю. Значения secure storage не записываются в логи.

---

## 3. Проверки

Binding runtime-экземпляров проверяется в `test/app/app_container_test.dart`. Это проверка DI; она не проверяет native backend хранилища. Android E2E проверяет запись cookies, восстановление через новый runner и удаление при выходе на настоящем backend flutter_secure_storage.

Границы пакетов: [Структура проекта](../../docs/02_project_structure.md).
