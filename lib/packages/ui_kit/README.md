# 🎨 UI Kit Package | AniStar TV

UI Kit содержит тему и общие TV-компоненты. Публичный импорт: `package:ui_kit/ui_kit.dart`.

## 1. Тема и токены

| API | Назначение |
| --- | --- |
| AppTheme | lightTheme / darkTheme, Material 3 и focus-state кнопок |
| TvTypography | Inter, размеры и веса TV-текста |
| AppPalette | Цвета |
| AppSpacing | Отступы |
| AppRadii | Радиусы |
| AppMotion | Длительности анимаций |

Текстовые стили доступны через Theme.of(context).textTheme. Цвета Material через colorScheme; общие TV-токены через публичные классы пакета.

---

## 2. Компоненты

| Компонент | Контракт |
| --- | --- |
| TvFocusable | Focus, активация OK и semantic label |
| AppNetworkImage | Cached image, skeleton и fallback |
| TvSkeleton / TvSkeletonBox | Примитивы загрузки |
| TvStateView / TvProgressView | Empty/error/retry и прогресс |
| TvBackdrop / TvSectionHeader | Фон и заголовок секции |

TvFocusable передаёт builder состояние focused. Feature рисует заметный focus-state. Без onLongPressed OK вызывает onPressed при KeyDown; с onLongPressed короткое OK срабатывает при отпускании, удержание от 600 мс вызывает onLongPressed после отпускания. KeyRepeat не вызывает действий. Потеря фокуса и dispose отменяют таймер. Долгое касание использует то же действие; вложенное меню не получает повторы удерживаемой клавиши.

> **Граница пакета:** UI Kit не импортирует features и не выполняет запросы AniStar. Сетка, anime hero и player controls принадлежат feature; общий компонент добавляется после повторного использования.

---

## 3. Тестирование

Тесты находятся в `test/packages/ui_kit/` и запускаются из корня:

```bash
fvm flutter test test/packages/ui_kit
```

Проверяем typography, image fallback, skeleton, состояния и клавиатурный focus. TV viewport: 960×540 и 1280×720 logical pixels.
