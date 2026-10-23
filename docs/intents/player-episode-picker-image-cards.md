# Карточки с изображениями в выборе серий внутри плеера

## Зачем

Сейчас в выборе серий внутри плеера серии отображаются простым текстовым
списком. Пользователь хочет видеть те же карточки с изображениями
и подписями, что и в списке серий на странице аниме.

## Чего хочу

Заменить текстовые элементы выбора серий в плеере карточками с изображениями.
Их оформление, подписи и поведение должны соответствовать карточкам серий
на странице аниме после изменений из
[intent о компактных карточках и общем виджете](compact-episode-cards-shared-widget.md).

Использовать тот же общий виджет UI Kit: компактные пропорции, изображение,
подпись на тёмной размытой подложке, единая реакция на фокус и анимация.
Подложка должна быть той же, что на карточках главной, и переиспользоваться
через общий компонент; отдельный эффект размытия для picker не нужен.
Выбор серии в плеере должен показывать полноценные карточки, а не только текст.

## Что важно сохранить

Сохранить выбор и запуск нужной серии из плеера, порядок и доступность серий,
номер и название, отметку просмотра и различимость текущей серии.
Управление пультом и касанием должно оставаться удобным.

Карточки в плеере должны переиспользовать оформление списка серий страницы
аниме, чтобы последующие изменения общего виджета применялись в обоих местах.


## Контекст текущей реализации

В [`PlayerScreen._chooseEpisode`](../../lib/packages/features/player/presentation/screens/player_screen.dart)
используется общий [`PlayerChoicesDialog<T>`](../../lib/packages/features/player/presentation/widgets/player_choices_dialog.dart):
`ListView` с `TvChoiceTile`, фиксированным для текущего масштаба текста
`itemExtent`, начальной прокруткой и autofocus текущей серии. Этот же диалог
обслуживает качество, поэтому изменение карточек серий не должно менять
представление выбора качества. Серии сортируются по убыванию номера;
просмотренность объединяется из `watchedEpisodesProvider` и session.
Отмена и выбор текущей серии не переоткрывают источник; другая серия
запускается с нуля через `_switchEpisode`. После панели управление
возвращается видео, а проверка `_initializationId` исключает устаревший выбор.

Изображения и названия доступны в
[`AnistarEpisodeDto`](../../infrastructure/anistar/lib/src/contract/anistar_episode_dto.dart)
(`title`, nullable `previewUri`, `isWatched`). Однако
[`AnistarPlaybackRepository.createSession`](../../lib/packages/features/player/data/repositories/anistar_playback_repository.dart)
сейчас переносит в [`PlaybackSession`](../../lib/packages/features/player/domain/models/playback_session.dart)
только номера и отметки серий, без названий и превью. В details эти поля
уже передаются через [`AnimeEpisode`](../../lib/packages/features/anime/domain/models/anime_episode.dart).
Значит, одних изменений визуального виджета недостаточно: источник метаданных
для picker ещё нужно определить через domain-контракт player. Наличие
`previewUri` необязательно; отсутствие или ошибка изображения не должны
лишать серию подписи и возможности выбора.

[`EpisodeCard`](../../lib/packages/features/anime/presentation/widgets/episode_card.dart)
и [`MobileEpisodeRow`](../../lib/packages/features/anime/presentation/widgets/mobile_episode_row.dart)
уже используют [`MediaCard`](../../lib/packages/ui_kit/lib/src/widgets/media_card.dart)
с вариантом `episode`, общей обработкой фокуса через `TvFocusTile`
и загрузкой изображения через `AppNetworkImage`.
Текущий вариант ещё содержит Play и отдельную область текста;
желаемый компактный вид зависит от связанного intent, а не от копирования
этого состояния. `MediaCard` уже принимает `selected`, `autofocus`,
`focusNode`, метки и callbacks. Текущая серия, просмотренность и focus
имеют разный смысл и должны оставаться различимыми. Граница общего
компонента описана в [UI Kit](../../lib/packages/ui_kit/README.md):
данные, порядок и действие принадлежат feature.

В [прототипе](../../prototype/app.js) `openPlayerEpisodes()` повторно
использует `episode()`, меняя действие карточки; текущая серия получает
`aria-current`, отдельную отметку, focus и прокрутку. Изображения там
демонстрационные (`episodeDemoImages`), поэтому это визуальный ориентир,
а не источник метаданных. Раскладки picker и details различаются в
[app.css](../../prototype/app.css) и [responsive.css](../../prototype/responsive.css);
общая карточка сама по себе не означает одинаковую сетку.

## Ограничения и существующие проверки

[ADR-0008](../adr/0008-youtube-tv-interaction-reference.md),
[TV-контракт](../specs/06_tv_interaction.md),
[mobile-контракт](../specs/10_mobile_interaction.md) и
[воспроизведение](../specs/04_playback.md) сохраняют правую панель на TV,
нижнюю на телефоне, изоляцию фоновых команд и возврат после закрытия.
Общие анимации и reduced motion задаёт [AppMotion](../specs/08_motion.md).
Размер карточек, прокрутку к текущей серии и направления D-pad необходимо
согласовать с геометрией панели и увеличенным текстом; нынешний расчёт
прокрутки текстовых строк нельзя считать готовым контрактом карточек.

[`player_choices_dialog_test.dart`](../../test/packages/features/player/presentation/player_choices_dialog_test.dart)
проверяет позднюю выбранную серию, прокрутку пультом и масштаб текста;
его goldens относятся к качеству. В
[`player_screen_test.dart`](../../test/packages/features/player/presentation/screens/player_screen_test.dart)
есть отмена панели и изоляция seek, в
[`episode_card_test.dart`](../../test/packages/features/anime/presentation/widgets/episode_card_test.dart)
— отметка просмотра и Semantics. Эти проверки ещё не подтверждают
изображения, fallback, названия и независимые состояния карточек внутри
player picker. Границы widget/golden/E2E-проверок заданы
[руководством по тестированию](../05_development_and_testing.md).
