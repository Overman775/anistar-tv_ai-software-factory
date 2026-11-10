# Мобильные карточки: только название аниме без года

## Зачем

Сейчас на карточках мобильного приложения рядом с названием показывается год.
В прототипе подпись содержит только название аниме. Нужно повторить этот вид.

## Чего хочу

Убрать отображение года с мобильных карточек. В подписи оставить только название
аниме, с оформлением и расположением точно как в актуальном прототипе.
Ориентир — подпись `.poster-title` в `mediaCard()` в
[app.js](../../prototype/app.js) и её стили в [app.css](../../prototype/app.css).

## Что важно сохранить

Название аниме сохраняется целиком в данных; его отображение следует прототипу.
Изменение касается подписи мобильных карточек. Данные года, фильтрация по году
и отображение года на странице аниме этим intent не затрагиваются.


## Технический контекст

В [MobileAnimeCard](../../lib/packages/features/catalog/presentation/mobile/mobile_anime_card.dart)
название передаётся как `MediaCard.label`, а год — отдельным `caption: anime.year`.
Это не суффикс внутри названия. [CatalogScreen._mobileGrid](../../lib/packages/features/catalog/presentation/screens/catalog_screen.dart)
использует этот адаптер; через [MobileHomeShell](../../lib/packages/features/home/presentation/mobile/mobile_home_shell.dart)
он обслуживает главную и избранное, а также используется в отфильтрованном каталоге.
[SearchScreen](../../lib/packages/features/search/presentation/search_screen.dart) создаёт
`MediaCard` отдельно и тоже передаёт год в `caption`: мобильная поисковая выдача
входит в желаемый результат, но не проходит через `MobileAnimeCard`.

Общий [MediaCard._copy](../../lib/packages/ui_kit/lib/src/widgets/media_card.dart)
рисует название и год отдельными текстовыми блоками поверх градиента постера.
Название ограничено двумя строками с ellipsis; Semantics по умолчанию объединяет
полные `label` и `caption`. Компонент обслуживает также TV и карточки серий,
поэтому этот intent не задаёт глобальное удаление `caption` из UI Kit.
[AppContentTypography.cardTitleOf](../../lib/packages/ui_kit/lib/src/theme/app_content_typography.dart)
сейчас возвращает 15 logical pixels. В прототипе `mediaCard()` выводит только
`title` внутри `.poster-title` / `.od-clamp-2`; мобильные правила
[responsive.css](../../prototype/responsive.css) задают 16 px, межстрочный
интервал 1,4 и отступы `48px 12px 12px`. Базовый стиль — Manrope, вес 600,
выравнивание слева, подпись внизу постера. Это ориентир именно оформления подписи;
геометрия карточки и остальные элементы не входят в изменение.

[Мобильная спецификация](../specs/10_mobile_interaction.md) и
[визуальная система](../specs/11_visual_system.md) пока явно описывают название
вместе с годом и размер 15: они расходятся с этим намерением.
`AnimeSummary.year` остаётся данными; [MobileAnimeContent](../../lib/packages/features/anime/presentation/widgets/mobile_anime_content.dart)
выводит `details.year` в метаданных и отдельно сохраняет фильтры страницы аниме.

## Границы проверки

[anime_card_badges_test.dart](../../test/packages/features/catalog/presentation/widgets/anime_card_badges_test.dart)
сейчас ожидает видимый год и размер названия 15, включая mobile.
[mobile_badges_golden_test.dart](../../test/packages/features/catalog/presentation/screens/mobile_badges_golden_test.dart)
и [search_golden_test.dart](../../test/packages/features/search/presentation/search_golden_test.dart)
покрывают разные пути выдачи. Их наличие не подтверждает новый вид: тесты здесь
не запускались, baselines не обновлялись, сравнение на устройстве не выполнялось.
Сохранение полного доступного названия при двух визуальных строках остаётся
существенным ограничением; поведение озвучивания года отдельно не уточнено.
Уровни проверки и ограничения golden/live описаны в
[руководстве по тестированию](../05_development_and_testing.md).
