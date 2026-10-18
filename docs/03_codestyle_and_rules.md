# 📏 Code Style & TV UI | AniStar TV

Настройки Dart и DCM находятся в `analysis_options.yaml`; версия DCM задана в `dcm_global.yaml`. Базовый стиль: Effective Dart, строки до 120 символов и formatter SDK.

## 1. Строгость и линтер

Включены `strict-casts`, `strict-inference`, `strict-raw-types`. Каждый workspace-пакет включает корневую конфигурацию Dart/DCM. Analyzer и DCM в полной проверке не допускают замечаний.

- Используйте **Object? и проверки типов** вместо dynamic в прикладном коде.
- Используйте **Logger**, а не print.
- Проверяйте nullable-значения вместо необоснованного `!`.
- Локальный ignore должен объяснять ограничение; ошибки из `cannot-ignore` подавлять нельзя.
- Generated-файлы не исправляются вручную.

---

## 2. Именование

| Элемент | Стиль | Пример |
| --- | --- | --- |
| Класс, enum, extension | UpperCamelCase | `PlaybackSession` |
| Файл, папка | snake_case | `playback_repository.dart` |
| Метод, переменная, константа | lowerCamelCase | `createSession`, `maxRetries` |
| Boolean | is / has / can / should | `hasNext` |
| Callback | on + событие | `onEpisodeTap` |

Приватные поля начинаются с `_`. Неиспользуемый аргумент обозначается `_`.

---

## 3. Организация кода

- Модели и state сохраняют immutable-контракт; изменение создаёт новый state.
- Зависимости репозитория, BLoC и сервиса видны в конструкторе.
- Повторяемые размеры, длительности и значения логики вынесены в const.
- Самостоятельный UI-блок оформлен отдельным Widget, а не `_buildHeader()`.
- Порядок членов классов и lifecycle-методов виджетов проверяет DCM.
- Future без ожидания отмечен через `unawaited()`; его ошибки имеют явный обработчик или выходят в общий error handler.

### ❌ Логика в build

```dart
@override
Widget build(BuildContext context) {
  repository.getPage(1); // Повторный запрос при каждой перестройке.
  return const CatalogGrid();
}
```

### ✅ Загрузка через состояние

Запрос запускается событием BLoC или lifecycle экрана; build только отображает состояние.

После await проверяйте `mounted`/`context.mounted`, если дальше меняется widget state или используется context. Поздний запрос не должен обновить уже закрытый экран.

---

## 4. Ошибки и логирование

BaseRepository выполняет общий маппинг исключений. Не дублируйте его try/catch в каждом репозитории. Site-specific отказ распознаётся в anistar; native playback обрабатывается плеером.

Используйте typed-методы Logger:

```dart
logger.infoFor<CatalogBloc>('Catalog loading started');
```

Логируйте запуск, команду, результат async-операции и retry. HTML, значения secure storage, cookies, токены и подписанные CDN URL не добавляются в сообщения. Native errorDescription не выводится пользователю.

---

## 5. TV UI

Основной UX-ориентир — YouTube для телевизоров по [ADR-0008](adr/0008-youtube-tv-interaction-reference.md). При изменении layout одновременно пересмотрите начальный фокус, стрелки, OK/удержание, Back и возврат после закрытия панели. Контракты: [TV-взаимодействие](specs/06_tv_interaction.md) и [анимации](specs/08_motion.md).

### Focus и пульт

1. После открытия экрана есть понятный начальный focus target.
2. Focus виден с расстояния: контраст, рамка и масштаб.
3. Стрелки перемещают focus в ожидаемом направлении; элемент остаётся видимым при прокрутке.
4. OK выполняет одно действие; родитель и дочерняя кнопка не обрабатывают его дважды.

Для карточек используйте **TvFocusable**. Material-кнопки подходят для локальных действий с заметным focus-state.

### Layout и тема

- Проверяйте viewport **960×540** и **1280×720** logical pixels.
- Учитывайте safe area, overscan и читаемость текста с расстояния.
- Длинные подписи ограничивайте maxLines и ellipsis.
- Число колонок определяется доступной шириной.
- Цвета, typography, spacing, radii и motion берите из [UI Kit](../lib/packages/ui_kit/README.md).
- Удалённые изображения: AppNetworkImage; загрузка: TvSkeleton / TvSkeletonBox.

Форма сетки, карточек, skeleton layout и player controls принадлежит feature. Общий компонент переносится в UI Kit после повторного использования.

Проверки перед завершением изменения: [Разработка и тестирование](05_development_and_testing.md).
