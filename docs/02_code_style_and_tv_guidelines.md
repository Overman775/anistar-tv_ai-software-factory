# 📏 Рекомендации по коду и TV UI | AniStar TV

Документ описывает практики, которые подходят текущему размеру проекта. Это ориентиры для нового и изменяемого кода, а не набор формальных запретов.

## 1. Базовый подход

- Следуйте [Effective Dart](https://dart.dev/effective-dart).
- Сначала выбирайте стандартные возможности Flutter и Dart.
- Не добавляйте abstraction layer без реального повторного использования.
- Оставляйте затронутый файл немного понятнее, чем он был.
- Полагайтесь на `flutter analyze` и DCM вместо ручных споров о форматировании.

Проект использует `strict-casts`, `strict-inference` и `strict-raw-types`.

## 2. Именование

Чёткое имя важнее короткого.

| Элемент | Стиль | Пример |
| --- | --- | --- |
| Класс, enum | `UpperCamelCase` | `PlaybackSession` |
| Файл, папка | `snake_case` | `playback_repository.dart` |
| Метод, переменная | `lowerCamelCase` | `createSession` |
| Boolean | `is` / `has` / `can` | `isLoadingMore` |
| Callback | `on` + событие | `onEpisodeTap` |

## 3. Организация Dart-кода

Предпочтения проекта:

- immutable models и state;
- constructor injection для BLoC, repositories и services;
- `Object?` с проверкой типа вместо неограниченного `dynamic`;
- logger вместо `print()`;
- `const` для повторяемых размеров, длительностей и строк логики;
- отдельный `StatelessWidget` для самостоятельного UI-блока;
- обязательное освобождение controller, focus node, timer, stream и BLoC.

`// ignore` допустим только для понятного локального ограничения, которое нельзя устранить без ухудшения кода. Причина должна быть очевидна рядом с ignore.

### Constructor injection

```dart
// Предпочтительно: зависимость видна и легко заменяется в тесте.
final class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  CatalogBloc({required CatalogRepository repository, required Logger logger});
}
```

Не передавайте `BuildContext` в domain/data-код и не выполняйте навигацию из BLoC.

### DI

- Riverpod — единственный DI-контейнер; не добавляйте `provider` и не смешивайте контейнеры.
- `app/app_providers.dart` — composition root: здесь связываются transport-клиенты, repository interfaces и runtime services.
- `runner.dart` передаёт runtime-объекты через `ProviderScope.overrides`.
- Feature может читать dependency provider в presentation, но repository, BLoC и service получают зависимости только через конструктор.

### Логирование

Используйте `Logger` из `app_logger` и typed-методы `debugFor<T>()`, `infoFor<T>()`, `warningFor<T>()`, `errorFor<T>()`: они добавляют владельца записи без отдельного Talker-типа. Логируйте границы: запуск, пользовательскую команду, результат async-операции, retry и ошибку. Не пишите значения secure storage, токены, query-параметры HLS URL и другие пользовательские данные.

## 4. Асинхронность и ошибки

- После `await` проверяйте lifecycle, если дальше используется widget state или context.
- Fire-and-forget Future должен быть явно отмечен через `unawaited()` или обработан.
- Не скрывайте ошибку пустым `catch`. Логируйте техническую причину, пользователю показывайте понятное действие.
- Повтор HLS-воспроизведения создаёт новую session, а не использует старый URL.

## 5. TV UI

TV-интерфейс отличается от touch-first приложения. При изменении экрана проверяйте следующие свойства.

### Focus

1. После открытия есть один понятный начальный focus target.
2. Сфокусированный элемент заметен с расстояния: рамка, масштаб и контраст меняются одновременно.
3. Стрелки ведут в ожидаемом направлении и не запирают пользователя внутри секции.
4. `OK` выполняет одно действие. Родитель и дочерняя кнопка не должны обрабатывать его одновременно.
5. При прокрутке focus остаётся видимым; экран не прокручивается сам до первого нажатия пользователя.

Для карточек используйте общий `TvFocusable`. Обычные Material-кнопки подходят для локальных действий, если их focus-state хорошо виден.

### Layout

- Базовый компактный TV viewport для widget-тестов — `960×540` logical pixels.
- Дополнительный широкий сценарий — `1280×720`.
- Важный текст не размещается у края; учитывайте safe area и overscan.
- Основной текст должен читаться с расстояния, поэтому touch-size и мелкие подписи недостаточны.
- Длинный текст ограничивается `maxLines` и `TextOverflow.ellipsis`.
- Сетка выбирает число колонок по доступной ширине, а не по физическому разрешению экрана.

### Theme и компоненты

- Цвета, отступы, радиусы и motion берите из `ui_kit`.
- Шрифты и размеры текста берите из TV-темы UIKit; базовый шрифт приложения — Inter.
- Для удалённых изображений используйте `AppNetworkImage`: он даёт cache, skeleton и единый fallback.
- Для загрузки используйте `TvSkeleton` и `TvSkeletonBox`; форму загрузочного layout определяет feature, а не UIKit.
- Feature-виджет не должен создавать новую палитру или собственную скорость анимаций без причины.
- Общий компонент переносится в UIKit после второго реального использования, не заранее. Grid, карточки, player controls и диалоги остаются в feature, пока не появились независимые потребители.

## 6. Перед завершением изменения

```bash
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
dcm analyze lib test
fvm flutter test
```

Дополнительно проверьте с пульта путь `каталог → аниме → серия → player → назад` на Android TV или эмуляторе.
