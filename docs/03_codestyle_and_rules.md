# 📏 Code Style и TV UI | AniStar TV

Стиль задают `analysis_options.yaml`, package-level analyzer configuration и закреплённая версия DCM в `dcm_global.yaml`. Форматируйте код SDK formatter и выполняйте строгие проверки из [Melos tooling](melos_tooling.md).

## 1. Обязательные правила

Включены `strict-casts`, `strict-inference` и `strict-raw-types`. Ошибки Analyzer и замечания DCM должны быть исправлены, а не подавлены без причины.

---

| Правило | Причина |
| :--- | :--- |
| При неизвестном типе используйте `Object?` и явные проверки | Сохраняет проверку типов и понятную обработку входных данных |
| Логируйте через `Logger`, не через `print` | Уровни и вывод централизованы; чувствительные данные можно исключить |
| Репозитории наследуют `BaseRepository` и возвращают `Result`/`Failure` | Ошибки получают единый контракт на границе Data и UI |
| Не импортируйте чужой private `src/` | Публичные API сохраняют границы пакета |
| Не редактируйте generated files вручную | Следующая генерация перезапишет такое изменение |
| Не добавляйте ignore без объяснения и необходимости | Исключение скрывает сигнал анализатора для следующих изменений |

---

## 2. Имена и структура

| Элемент | Формат | Пример |
| :--- | :--- | :--- |
| Типы, enum, extension | `UpperCamelCase` | `PlaybackSession` |
| Файлы и каталоги | `snake_case` | `playback_repository.dart` |
| Переменные, методы, константы | `lowerCamelCase` | `createSession`, `maxRetries` |
| Boolean | вопрос с `is`, `has`, `can`, `should` | `hasNext`, `isLoading` |
| Callback | `on` + действие | `onEpisodeTap` |
| Private member | `_` префикс | `_controller` |

Называйте тип по пользовательской области и операции, которую он выполняет. Не создавайте общий utility или generic abstraction, пока вторая реальная потребность не показала общий контракт.

### Локальная форма кода

- В коротких guard clauses и простых однострочных телах можно опустить фигурные скобки, если условие и действие читаются вместе. Сохраняйте блоки для нескольких операций, нужной локальной области видимости и неоднозначного вложенного `if`/`else`.
- Выводите тип локальной переменной, когда он очевиден из значения. Укажите тип, если он проясняет смысл выражения или нужный контракт.
- Сохраняйте именованный snapshot, если значение понадобится далее или состояние может измениться между чтениями, например после `await` либо пользовательского события. Повторно читайте состояние, если нужен его актуальный результат.
- Доверяйте Dart formatter расположение строк и trailing commas. Не добавляйте или не удаляйте их только ради lint-правила.

---

## 3. Слои и обработка ошибок

Domain определяет модели и repository interfaces. Data реализует интерфейс, преобразует данные AniStar и вызывает `BaseRepository.makeApiCall`. Presentation переводит `Result` в видимое состояние.

```dart
final result = await repository.getPage(1);
result.when(
  success: (page) => emit(CatalogReady(items: page.items, hasMore: page.hasNext)),
  failure: (failure) => emit(CatalogFailure(message: failure.message, items: const [], hasMore: false)),
);
```

Не дублируйте transport mapping локальным `try/catch` в каждом repository. Перехват допустим, когда feature должна выполнить явное восстановление или преобразовать специальный контракт. Ожидаемый отказ сайта отображается в соответствующую `Failure` на границе repository.

**Не скрывайте сбой значением по умолчанию:** пустой каталог не должен маскировать нераспознанную HTML-разметку, а неудачная запись избранного не должна отображаться как успех. Fallback допустим только если он определён пользовательским контрактом.

> **Почему:** единый `Result` сохраняет причину отказа до UI, где можно показать безопасное сообщение и явное действие повтора.

---

## 4. Async и состояние виджета

Не запускайте запросы и побочные эффекты из `build()`: Flutter может вызывать его повторно. Загрузку запускает событие BLoC, provider/notifier или lifecycle метода экрана согласно текущей модели feature.

```dart
@override
Widget build(BuildContext context) {
  repository.getPage(1); // Неверно: запрос повторится при перестроении.
  return const CatalogGrid();
}
```

После `await` проверьте `mounted` или `context.mounted`, прежде чем обновлять widget state или использовать его `BuildContext`. Fire-and-forget Future оформляйте `unawaited(...)` только при явной обработке ошибок или известном общем error handler. Закрывайте stream subscriptions, timers, focus nodes и native controllers в lifecycle владельца.

Оставляйте короткий callback inline, если его действие локально и понятно. Выносите callback в helper или `Widget`, когда это выделяет отдельную ответственность, повторное использование либо яснее задаёт ownership state, focus, controller или lifecycle. Для визуально самостоятельного блока предпочитайте отдельный `Widget`, когда это упрощает rebuild и тестирование. Не дробите `build()` только ради метрики.

---

## 5. Логи и чувствительные данные

Используйте типизированные методы `Logger`, чтобы указать источник события:

```dart
logger.infoFor<CatalogBloc>('Catalog loading started');
```

Не записывайте credentials, Cookie/Set-Cookie, пароли, raw HTML, POST body, signed CDN URI или `native errorDescription`. Для сетевой диагностики оставляйте только разрешённые публичные paths и безопасные метаданные. Правила подробнее изложены в [руководстве сети и playback](04_network_and_playback.md).

---

## 6. TV и mobile интерфейсы

TV-профиль должен полностью управляться пультом. До реализации layout или controls прочитайте [ADR-0008](adr/0008-youtube-tv-interaction-reference.md) и [TV interaction contract](specs/06_tv_interaction.md). Для phone действует отдельный [mobile interaction contract](specs/10_mobile_interaction.md).

При изменении экрана проверьте:

1. начальную и видимую цель фокуса;
2. ожидаемые переходы стрелок, OK, удержания и Back;
3. возврат фокуса после панели, dialog, ошибки или загрузки;
4. viewport TV **960×540** и **1280×720** logical pixels, а для mobile используйте compact и wide портретные размеры из существующих тестов;
5. системное уменьшение анимаций и асинхронную загрузку содержимого.

Цвета берите из `Theme.of(context).colorScheme` и общих значений `AppPalette`. Typography берите из `Theme.of(context).textTheme` и `TvTypography`. Spacing, radii и motion берите из `AppSpacing`, `AppRadii` и `AppMotion` в [UI Kit](../lib/packages/ui_kit/README.md). Экранный компонент и раскладка сетки принадлежат feature, пока у них нет повторного общего контракта.

---

## 7. UI Kit и ресурсы

Корневые темы предоставляет `AppTheme`. `AppPalette`, `AppSpacing`, `AppRadii`, `AppMotion`, `TvTypography` и `AppFocusStyle` владеют общими токенами. `AppNetworkImage` загружает изображения. `TvSkeleton` предоставляет состояние ожидания. Feature не добавляет в UI Kit правила AniStar или запросы.

Assets берите через сгенерированные FlutterGen exports из `ui_kit`. Не редактируйте generated-файлы вручную. После изменения исходных ресурсов запустите согласованную команду генерации из [Melos tooling](melos_tooling.md) и проверьте diff.

---

## 8. Изменение правил

Для локального изменения достаточно следовать конфигурации Analyzer/DCM. Меняйте общий lint, архитектурную границу, UI контракт или публичный API только с обновлением соответствующего правила/ADR/спецификации. Не копируйте в каждую feature собственную версию общего правила.

При пересмотре требований к форме кода применяйте общий критерий [ADR-0011](adr/0011-compact-code-analysis-policy.md).
