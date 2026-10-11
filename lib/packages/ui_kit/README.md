# 🎨 UI Kit Package | AniStar TV

UI Kit содержит тему и общие TV-компоненты. Публичный импорт: `package:ui_kit/ui_kit.dart`.

Ориентир взаимодействия и границы адаптации: [ADR-0008](../../../docs/adr/0008-youtube-tv-interaction-reference.md).

## 1. Тема и токены

| API | Назначение |
| --- | --- |
| AppTheme | lightTheme / darkTheme, Material 3 и focus-state кнопок |
| TvTypography | packages/ui_kit/Inter, размеры и веса TV-текста |
| AppPalette | Цвета |
| AppSpacing | Отступы |
| AppRadii | Радиусы |
| AppMotion | Длительности, кривые и reduced motion |

Анимации описаны в [контракте](../../../docs/specs/08_motion.md). Feature не задаёт собственные duration/curve для этих эффектов; durationOf отключает их по настройкам доступности.

AppNetworkImage ограничивает размер декодирования в памяти по одной оси, сохраняя пропорции; оригинал остаётся в дисковом кеше для detail и Hero.

Текстовые стили доступны через Theme.of(context).textTheme. Цвета Material через colorScheme; общие TV-токены через публичные классы пакета.

Inter поставляется локально в начертаниях 400, 500 и 700; заголовки и акценты используют реальный Bold, без запросов к отсутствующему 800. Файлы из [официального Inter 4.1](https://github.com/rsms/inter/releases/tag/v4.1), внутренняя версия 4.001, commit 9221beed3; Regular/Medium сохранены без изменений. SIL OFL 1.1 находится в assets/fonts/LICENSE.txt.

Шкала ролей: заголовки 24–32, названия карточек 19, основной текст 18 с высотой строки 1.45, обычный текст и управление 16, вторичные подписи 14. Логотип меню сохраняет 22; диагностический журнал использует monospace. Описание ограничено TvTypography.proseMaxWidth = 720 logical pixels. TvChoiceTile.rowExtentOf учитывает системный масштаб текста и отступы виртуализированной строки.

---

## 2. Компоненты

| Компонент | Контракт |
| --- | --- |
| TvFocusable | Focus, активация OK и semantic label |
| AppNetworkImage | Cached image, decode по геометрии/DPR, skeleton, fallback и управляемый fade |
| TvSideSheet / showTvSideSheet | Правая модальная панель, переход, контрастный focus и замкнутая навигация |
| TvPosterHero | Одинаковый скруглённый постер для обоих концов Hero |
| TvSkeleton / TvSkeletonBox | Примитивы загрузки |
| TvStateView / TvProgressView | Empty/error/retry и прогресс; StateView прокручивает длинный текст, объявляет сообщение и раскрывает focus действия |
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
