# 🎨 UI Kit Package | AniStar TV

UI Kit содержит тему, TV-компоненты и ресурсы для разработчиков feature, которым нужны единые стили и управление с пульта. Публичный импорт: `package:ui_kit/ui_kit.dart`.

```dart
import 'package:ui_kit/ui_kit.dart';
```

Ассеты и назначение изображений описаны в разделе [Ресурсы](#4-ресурсы). Основные UI-контракты описаны в [спецификации 11](../../../docs/specs/11_visual_system.md).

Ориентир взаимодействия и границы адаптации: [ADR-0008](../../../docs/adr/0008-youtube-tv-interaction-reference.md).

## 1. Использование и общая тема

| API | Назначение |
| --- | --- |
| `AppTheme`, `TvTypography` | Темы и типографическая шкала TV/mobile на Manrope |
| `AppPalette`, `AppSpacing`, `AppRadii`, `AppSizes` | Семантические цвета, отступы, радиусы и общая геометрия |
| `AppMotion` | Длительности, кривые и учёт системного уменьшения движения |
| `AppIcon`, `AppIconType` | Типизированные Lucide-иконки из локальных SVG |
| `AppButton`, `MediaCard`, `MediaCardBookmark` | Общие действия, карточки постера/широкого изображения/серии и метка подтверждённого избранного |
| `AppAvatar` | Изображение аккаунта с инициалами при отсутствии URI, загрузке или ошибке |
| `AppFocusBorder` | Общая цветовая анимация рамки фокуса с неизменной шириной и геометрией |
| `TvFocusable`, `TvFocusTile`, `TvChoiceTile` | Ввод, focus и выбор с пульта |

Согласованные цвета, роли текста, геометрия и состояния описаны в [спецификации визуальной системы](../../../docs/specs/11_visual_system.md). Длительности и кривые принадлежат [спецификации анимаций](../../../docs/specs/08_motion.md); feature использует AppMotion вместо локальных duration/curve.

`AppTheme` подключает Manrope как семейство темы. Пакет содержит начертания 400, 500, 600, 700 и 800; их лицензия OFL находится в `assets/fonts/Manrope-OFL.txt`.

Пример иконки и общего действия; callback и состояние занятости передаёт feature:

```dart
const AppIcon(AppIconType.heart, semanticLabel: 'Добавить в избранное');

AppButton(
  label: 'Смотреть',
  onPressed: startPlayback,
  icon: const AppIcon(AppIconType.play),
  busy: isStarting,
)
```

`AppButton` сохраняет focus во время `busy` и отклоняет повторную активацию. `AppIcon.fromMaterial` остаётся совместимым входом для имеющихся Material `IconData`. `AppIconType` включает 37 локальных Lucide SVG, в том числе стрелки сортировки и `share`.

`AppFocusBorder` доступен из публичного `package:ui_kit/ui_kit.dart`. Он рисует перед дочерним содержимым рамку постоянной толщины, анимируя только её цвет. `focusBorderEnter` задаёт 280 мс с `easeOutCubic`; `focusBorderExit` — 200 мс с `easeInCubic`. Рамка не задерживает перенос focus и не меняет размеры layout. `durationOf` превращает длительность в ноль при `disableAnimations` или `accessibleNavigation`; карточный scale остаётся отдельным состоянием.

## 2. Общие компоненты

| Компонент | Контракт |
| --- | --- |
| `MediaCard` | Нейтральная карточка `poster`, `landscape` или `episode`; caller передаёт подпись, изображение, метки и callback |
| `AppNetworkImage` | Загружает и кеширует переданный URI, ограничивает decode текущей геометрией/DPR и сохраняет fallback |
| `TvFocusable` | Обрабатывает OK, KeyRepeat для долгого действия, busy/enabled и изменение состояния focus |
| `TvFocusTile` | Общая рамка и геометрия для карточки или строки выбора; принимает состояния selected, enabled и busy |
| `TvChoiceTile` | Строка выбора с Semantics selected и размером, учитывающим системный масштаб текста |
| `AppActionSheet`, `TvSideSheet` | Общая панель; TV-панель удерживает focus, `closeOnLeft` управляет закрытием, `expandChild` растягивает дочернее содержимое |
| `TvPosterHero` | Общий переход исходного постера с clip, fallback и reduced motion |
| `TvSkeleton`, `TvSkeletonBox` | Скелетоны без focus и содержательной Semantics |
| `TvStateView`, `TvProgressView` | Состояния empty/error/retry и progress; действие может быть busy или disabled через `actionBusy` и `actionEnabled`, а внешний `actionKey` сохраняет стабильную цель автоматизации |
| `TvBackdrop`, `TvHeaderSurface`, `TvSectionHeader` | Общие фоны и заголовки |
| `AppMetadataBadge` | Неинтерактивная метка с доступной подписью |

Пример карточки:

```dart
MediaCard(
  label: anime.title,
  caption: anime.year?.toString(),
  imageUrl: anime.posterUri?.toString(),
  semanticLabel: anime.title,
  variant: MediaCardVariant.poster,
  onPressed: () => openAnime(anime.id),
)
```

`MediaCard` предоставляет общий вид и focus-state. Feature управляет сеткой, порядком, данными, маршрутом и действием. `showCaption: false` скрывает текстовую подпись, не скрывая изображение и доступное имя. `showBookmark: true` показывает декоративную закладку с сердцем для подтверждённого избранного; UI Kit не определяет статус аккаунта. Вариант `episode` по умолчанию не показывает Play и активирует всю карточку. `episodeHeight` задаёт базовую высоту, которая может увеличиваться по тексту. `AppNetworkImage` может выполнять сетевую загрузку переданного URI; UI Kit не интерпретирует его как данные AniStar. UI Kit не импортирует features, domain-модели или repositories.

`AppAvatar` получает имя и необязательный `imageUrl`. Caller передаёт URI только после проверки владельца и состояния данных. При отсутствии URI, загрузке или ошибке картинки компонент показывает инициалы. Компонент не загружает метаданные профиля и не выбирает источник изображения.

У варианта `episode` узкое превью при ограниченной высоте может уменьшаться, сохраняя `16:9`; без ограничения высоты оно сохраняет естественную геометрию. Системный масштаб текста не ограничивается. Визуальный заголовок и подпись серии занимают не более двух строк, а Semantics сохраняет полное переданное `semanticLabel` или полные `label` и `caption` по умолчанию. Сеточная высота серий и одинаковая геометрия карточек/скелетонов описаны в [спецификации карточки аниме](../../../docs/specs/12_anime_details.md); общий визуальный контракт и детали адаптации — в [спецификации 11](../../../docs/specs/11_visual_system.md).

`TvFocusable` сохраняет прежний builder `(context, focused)` и предоставляет `stateBuilder` с `TvFocusState` для focus, hover, pressed, enabled и busy. Первый системный KeyRepeat активирует `onLongPressed`; отдельный таймер удержания не вводится. Потеря focus и dispose отменяют ещё не распознанное удержание.

`MediaCard.showCaption` по умолчанию показывает подпись; при `false` скрывается только её текстовая плашка поверх изображения. Изображение, метки и семантическое имя карточки сохраняются.

`AppContentTypography` задаёт локальные роли каталога, карточки сериала и серий. Роли сохраняют системный `textScaler`; общая тема и остальные экраны не масштабируются.

---

## 3. Как проверить

Тесты находятся в `test/packages/ui_kit/` и запускаются из корня:

```bash
fvm flutter test test/packages/ui_kit
```

Проверяем typography, image fallback, skeleton, состояния и клавиатурный focus. TV viewport: 960×540 и 1280×720 logical pixels.

---

## 4. Ресурсы

Публичный импорт: `package:ui_kit/assets.dart`, где `Assets` отвечает за изображения и файлы, а `FontFamily` за шрифты. FlutterGen создаёт эти exports из `assets/images/` и `assets/fonts/`. Из корня workspace типизированные exports генерируются командой `fvm dart run melos run generate`, а нативные ресурсы на macOS — `fvm dart run melos run generate:branding`. Использование package assets и команды генерации описаны в [разработке и тестировании](../../../docs/05_development_and_testing.md#2-проверки-и-сборка) и [Melos tooling](../../../docs/melos_tooling.md#5-генерация-и-ресурсы).

| Исходник в `assets/images/` | Назначение |
| --- | --- |
| `anistar_logo.png` | Прозрачный RGBA-знак 1254×1254 для `AnistarLogo` на стартовом экране, входе и в TV-меню. Также используется для Android 12+ splash. |
| `anistar_launcher.png` | Изображение с фоном 1024×1024 для Android launcher и adaptive icon, а также iOS AppIcon |
| `anistar_tv_banner.png` | Баннер с фоном 1280×720 для Android TV launcher и splash до Android 12, а также iOS LaunchScreen |

В UI-знаке фон и промежутки между лучами прозрачны. Тёмная рамка кнопки play принадлежит самому знаку. Не заменяйте UI-знак launcher-изображением с фоном.

Android 12+ splash использует `android12splash_safe.xml`. Отступ 26% с каждой стороны помещает знак в круглую системную маску. Фон: `#101214`. Общий скрипт экспорта после генерации сохраняет ссылку на этот drawable в дневной и ночной LaunchTheme. iOS LaunchScreen использует `anistar_tv_banner.png` с `scaleAspectFit` и фоном `#101214`. В `Info.plist` сохранены портретная и альбомная ориентации Runner.

Настройка splash не задаёт ориентацию. Runner выбирает профиль TV/mobile. Android- и iOS-ресурсы генерируются общей командой `fvm dart run melos run generate:branding`; настройка описана в разделе [иконка, баннер и заставка](../../../docs/05_development_and_testing.md#8-иконка-android-tv-баннер-и-заставки-androidios).

[brand_assets_test.dart](../../../test/packages/ui_kit/brand_assets_test.dart) проверяет доступность package assets, прозрачность знака и размещение splash внутри маски во всех плотностях и обеих темах. Golden-снимки стартового экрана, входа и меню фиксируют знак на поверхностях приложения.

## 5. Навигация

- [Визуальная система](../../../docs/specs/11_visual_system.md) — цвета, роли текста, геометрия карточек и общие состояния.
- [Карточка аниме](../../../docs/specs/12_anime_details.md) — поведение частей, серий и основного действия.
- [TV-взаимодействие](../../../docs/specs/06_tv_interaction.md) — focus, активация и управление с пульта.
- [Анимации](../../../docs/specs/08_motion.md) — длительности, кривые и reduced motion.
- [ADR-0008](../../../docs/adr/0008-youtube-tv-interaction-reference.md) — ориентир поведения и границы адаптации.
- [Разработка и тестирование](../../../docs/05_development_and_testing.md) — использование package assets, генерация и настройка Android ресурсов.
