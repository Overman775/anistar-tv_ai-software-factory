# ADR-0004: Riverpod как единственный DI-контейнер

- **Статус:** Accepted
- **Дата:** 2026-07-19
- **Уточнено:** [0007](0007-neutral-core-and-infrastructure.md): владельцы провайдеров и app binding.

## Контекст

Приложение использует общие runtime-сервисы, HTTP-клиенты и реализации
репозиториев. Ранее они передавались через `provider`, тогда как для будущего
роста проекта нужна единая, типизированная точка композиции и простые overrides
в widget-тестах.

## Решение

- Использовать `flutter_riverpod` как единственный DI-контейнер приложения.
- Создавать `ProviderScope` в `runner.dart`; logger, storage и `NetworkConfig`
  передавать через overrides.
- Провайдеры клиентов принадлежат infrastructure-пакетам; binding repository
  implementations находится в `app/app_container.dart` (уточнение ADR-0007).
- Оставить `flutter_bloc` для feature state, но не использовать его как DI.
- Сохранять constructor injection для repository, service и BLoC; domain/data
  не импортируют Riverpod.

## Последствия

Положительные: один способ собирать зависимости, безопасная замена provider в
тестах, явный composition root и отсутствие поиска сервисов через
`BuildContext`.

Ограничения: Riverpod используется только на app/presentation границе; не
следует переносить в него бизнес-логику или создавать feature-wide state без
реальной необходимости.

## Связанные решения

- [ADR-0007](0007-neutral-core-and-infrastructure.md): границы пакетов и владельцы провайдеров.
