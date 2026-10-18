# ADR-0004: Riverpod как единственный DI-контейнер

- **Статус:** Accepted
- **Дата:** 2026-07-19
- **Связи:** Уточнён в [ADR-0007](0007-neutral-core-and-infrastructure.md): владельцы провайдеров и app binding.

## Контекст

Приложение использует общие runtime-сервисы, HTTP-клиенты и реализации репозиториев. Ранее зависимости передавались через `provider`. Для роста проекта нужна единая типизированная точка композиции и простые overrides в widget-тестах.

## Решение

- Использовать `flutter_riverpod` как единственный DI-контейнер приложения.
- Создавать `ProviderScope` в `runner.dart`. Передавать logger, storage и `NetworkConfig` через overrides.
- Владельцами провайдеров клиентов являются infrastructure-пакеты. Binding реализаций репозиториев находится в `app/app_container.dart` (уточнение ADR-0007).
- Оставить `flutter_bloc` для feature state. Не использовать его как DI.
- Сохранять constructor injection для repository, service и BLoC. Domain и data не импортируют Riverpod.

## Последствия

Зависимости собираются одним способом. Тесты могут безопасно заменять их через overrides. Composition root остаётся явным, а сервисы не ищутся через `BuildContext`.

Riverpod используется только на границе app/presentation. Бизнес-логика не переносится в Riverpod. Feature-wide state не создаётся без реальной необходимости.
