# 🔌 DI и жизненный цикл | AniStar TV

Руководство по привязке зависимостей и владению ресурсами. Границы слоёв определяют [архитектурные принципы](01_architecture_principles.md).

## 1. DI и состояние

Riverpod управляет DI и существующим сервисным и асинхронным состоянием. BLoC используется для экранных событий и переходов. Сохраняйте бизнес-правила у владельца фичи. [Runner](../lib/runner/runner.dart) создаёт один корневой `ProviderScope` и устанавливает app overrides. [ADR-0004](adr/0004-use-riverpod-for-app-di.md), [ADR-0007](adr/0007-neutral-core-and-infrastructure.md).

Фича объявляет provider контракта. Например, [catalogRepositoryProvider](../lib/packages/features/catalog/catalog_providers.dart) возвращает `CatalogRepository`. [createAppOverrides](../lib/app/app_container.dart) передаёт реализацию через override. BLoC, репозитории и сервисы принимают зависимости конструкторами. Domain и Data не используют `BuildContext`, роутер или Riverpod.

Так App связывает контракт каталога с его реализацией и общими `AnistarClient` и `Logger`.

```dart
catalogRepositoryProvider.overrideWith(
  (ref) => AnistarCatalogRepository(
    ref.watch(anistarClientProvider),
    ref.watch(loggerProvider),
  ),
),
```

Фичи читают типизированный доступ через auth provider. Отдельные флаги гостя или аккаунта в потребителях могут расходиться с состоянием auth. [Вход](specs/01_authentication.md).

---

## 2. Владение ресурсами

| Ресурс | Владелец и завершение |
| :--- | :--- |
| Logger и storage | Runner создаёт и передаёт через overrides. |
| `ProviderScope` и repository bindings | App composition. |
| Общий Dio | [Networking provider](../infrastructure/networking/lib/src/networking_providers.dart) закрывает через `ref.onDispose`. |
| AniStar client и cookie session | [Infrastructure providers](../infrastructure/anistar/lib/src/anistar_providers.dart) пересоздают их при смене origin. При dispose удаляют свои interceptors и закрывают session. Общий Dio закрывает его владелец. |
| Catalog BLoC | Закрывает создавший экран или provider. |
| Log viewer BLoC | Закрывает создавший `BlocProvider`. |
| Video controller, listener, focus и timer | `State` плеера очищает ресурсы по их lifecycle. Освобождает старый controller до создания следующего. |

Смена зеркала пересобирает Dio и зависящие от origin привязки. [Сеть и HLS](04_network_and_playback.md).
