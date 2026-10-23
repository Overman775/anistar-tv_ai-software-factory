# Баг: Hero-анимация прерывается загрузкой страницы аниме

## Зачем

По наблюдению пользователя, при открытии аниме с главной Hero-переход
начинается, но затем включается загрузка: изображение на некоторое время
исчезает и после загрузки появляется заново. Из-за этого переход выглядит
прерывистым. При возврате со страницы аниме на главную Hero-анимация работает.

## Чего хочу

Разобраться в причине и исправить прямой Hero-переход от карточки на главной
к странице аниме. Переход должен оставаться визуально непрерывным:
изображение не должно исчезать и повторно появляться из-за смены состояния
страницы на загрузку и затем на загруженное содержимое.

## Что важно сохранить

Сохранить работающую обратную Hero-анимацию при возврате к карточке,
загрузку актуальных данных страницы и корректное отображение её состояний.
Исправление не должно зависеть только от прогретого кеша: проверить переход
при ещё не загруженных данных и повторное открытие аниме.

Сохранить контракт [анимаций](../specs/08_motion.md): исходный постер виден
уже в первом кадре loading, смена деталей не прерывает полёт, другой URL
постера не убирает исходное изображение до декодирования замены. Учитывать
reduced motion и возврат фокуса/прокрутки по [ADR-0008](../adr/0008-youtube-tv-interaction-reference.md),
[TV-контракту](../specs/06_tv_interaction.md) и
[мобильному контракту](../specs/10_mobile_interaction.md).

## Что пока неясно

Точная причина и затронутые профили интерфейса пока не подтверждены.
Начать воспроизведение с перехода с главной на страницу аниме и проверить,
какой элемент исчезает и на каком этапе загрузки прерывается переход.

### Что подтверждено исходниками

В текущем коде уже есть защиты именно от такого разрыва. Их наличие не
доказывает отсутствие ошибки на устройстве; повторно вводить их как новое
решение без воспроизведения не следует.

- Путь выбора: `HomeScreen` → `CatalogScreen` → `AnimeCard` / `MobileAnimeCard`
  → callback `onAnimeTap` из `HomeRoute.build` → `AnimeRoute.go`. В
  [маршрутах](../../lib/app/app_routes.dart) выбранный `AnimeSummary` передаётся
  через `$extra`; `AnimeRoute.build` берёт `fallbackPosterUri` только при
  совпадении ID. URL постера не добавляется в query. `AnimeRoute.buildPage`
  использует [AppNavigationPage](../../lib/app/app_navigation_page.dart)
  с fade/slide 280 мс вперёд и 200 мс назад при обычном motion.
- [AnimeScreen](../../lib/packages/features/anime/presentation/screens/anime_screen.dart):
  `initState` → `_load` → `_fetchData` → `AnimeRepository.getAnime`.
  `FutureBuilder` вызывает `_buildFuture`, который оставляет skeleton до
  завершения входного перехода (`_entered`) и загрузки данных. `_onRouteStatus`
  и `didChangeDependencies` отдельно исключают временный offstage layout
  `HeroController` из признаков завершения перехода.
- [AnimeSkeleton](../../lib/packages/features/anime/presentation/widgets/anime_skeleton.dart)
  создаёт целевой `TvPosterHero` до ответа repository, если есть ID и исходный
  постер. Готовый [AnimeHero](../../lib/packages/features/anime/presentation/widgets/anime_hero.dart)
  использует постер деталей либо исходный fallback. На телефоне
  [MobileAnimeSkeleton](../../lib/packages/features/anime/presentation/widgets/mobile_anime_skeleton.dart)
  и [MobileAnimeContent](../../lib/packages/features/anime/presentation/widgets/mobile_anime_content.dart)
  используют общий `MobileAnimePosterHeader`.
- [TvPosterHero](../../lib/packages/ui_kit/lib/src/widgets/tv_poster_hero.dart)
  использует тег `anime-poster-{id}`, `RectTween`, скруглённый shuttle из
  целевого `Hero.child`, `Skeleton.ignore` и `HeroMode` с учётом reduced motion.
  Для `AppNetworkImage` отключён resize по layout, а для одинакового URL —
  отдельный fade. [AppNetworkImage](../../lib/packages/ui_kit/lib/src/widgets/app_network_image.dart)
  кладёт исходное изображение под новое при смене URL и сохраняет fallback
  при ошибке загрузки замены.

### Проверки и их границы

[navigation_motion_test.dart](../../test/app/navigation_motion_test.dart)
проверяет переход из главной/избранного до загрузки деталей, Back, быстрый
Back с поздним ответом и reduced motion. `decodedPosterTests` проверяет
наличие исходного декодированного `RawImage` с шагом 16 мс при раннем/позднем
ответе деталей и на обратном переходе; поздний ответ также содержит другой
URL постера. [Android entry point](../../integration_test/navigation_motion_test.dart)
переиспользует `decodedPosterTests`.

[app_network_image_test.dart](../../test/packages/ui_kit/widgets/app_network_image_test.dart)
отдельно проверяет fallback при ожидании, успехе, ошибке и reduced motion.
Эти проверки заранее заполняют memory image cache и проверяют дерево
`RawImage`, поэтому сами по себе не доказывают непрерывность видимых пикселей
при холодном кеше, реальном CDN или на физическом устройстве.
[Мобильная проверка маршрутов](../../test/app/mobile_route_chrome_test.dart)
выполняется с `disableAnimations: true` и не покрывает кадры Hero-полёта.
При этом свежий запуск перечисленных тестов и runtime-воспроизведение в
рамках этого уточнения intent не выполнялись.

### Гипотезы и условия уточнения

Без трассы нельзя выбрать между потерей/пересозданием Hero endpoint при
переходе loading → ready, изменением доступности исходного изображения в
кеше и отличием фактического маршрута/сборки от описанного кода. Это
проверяемые гипотезы, а не установленная причина. Пользователь уточнил:
сбой замечен на TV-эмуляторе, исчезает именно постер. Ревизию сборки
и точную конфигурацию устройства ещё нужно зафиксировать при воспроизведении.

Для дальнейшей проверки достаточно сопоставить кадры входного перехода,
ожидания ответа и смены loading → ready: ранний/поздний ответ деталей;
одинаковый/другой URL и отказ замены изображения; первое открытие с холодным
кешем и повторное; Back во время загрузки и после неё. Сначала проверить
профиль, на котором замечен сбой, затем второй профиль и reduced motion.
Границы выводов widget/Android/физического устройства сохраняются по
[руководству тестирования](../05_development_and_testing.md#10-результаты-и-границы-проверки).
