# ▶️ Воспроизведение | AniStar TV

## 1. Источник и session

Только онлайн HLS, Android native video_player / Media3. Chrome, WebView, parser-сервер, proxy, MP4 download и offline playlist не участвуют.

Перед открытием источника repository получает свежий player HTML. Выбранная серия определяется номером, качество — files её объекта. Если запрошенного качества нет, выбирается наибольшее доступное для этой серии; requestedQuality и selectedQuality хранятся раздельно. Отсутствующие серия/поток — Failure.

Session содержит manifestUri, заголовки, доступные серии/качества и необязательный expiresAt. Signed URL сохраняется полностью, включая `+`, запятые, path и query. Key не генерируется клиентом. `end` разбирается как Unix seconds, если значение поддерживается DateTime; неверный/слишком большой timestamp не мешает открытию целого URI. expiresAt — metadata, не гарантированное время жизни и не отдельный таймер refresh.

В UI серии отображаются по убыванию числового номера: последняя сверху. Сортируется копия списка; исходный порядок repository/session и привязка номера к потоку не меняются. В диалоге focus и начальная прокрутка определяются выбранным номером, а не первым элементом.

## 2. Native запросы

Controller должен использовать `VideoFormat.hls` независимо от суффикса URL: `.mp4` у 720p может возвращать manifest с `#EXTM3U`. Фильтрация только по расширению запрещена.

Referer — URL player page текущего origin с animeId. Заголовок должен передаваться master, вложенным playlists и всем segments, включая другой CDN. Cookies сайта не передаются CDN. Относительные media URI разрешаются относительно соответствующего manifest, не относительно зеркала AniStar.

Работа Range и MPEG-TS, relative/absolute segments и Referer проверяется через HTTPS fixture с настоящим native player. Одна проверка manifest или первого segment не доказывает запуск/seek всей цепочки.

## 3. Lifecycle и действия

Инициализация controller ограничена 35 секундами. Новый controller создаётся после освобождения прежнего. Идентификатор операции защищает от запоздавших результатов при Back, смене route, серии и качества.

| Действие | Позиция / воспроизведение |
| --- | --- |
| Первое открытие | Начало серии, воспроизведение после initialization |
| Смена качества | Сохранить позицию и playing/paused state |
| Смена серии | Начать с нуля |
| Изменение animeId/episode в route | Открыть новый источник с нуля |
| Pause/play | Выполнить native команду; ошибка обрабатывается общим recovery |
| Seek | Ограничить позицию диапазоном 0…duration |
| Back / logout / смена origin | Закрыть экран, освободить controller/listener/timer/focus |

Нельзя обновлять UI или запускать проигрывание по результату уже закрытой операции. При уходе системный UI возвращается к режиму, ожидаемому приложением.

## 4. Recovery

Для выбранного источника допускается **один автоматический refresh**. Бюджет общий для initialization failure, runtime error и ошибки native команды. Refresh повторно получает HTML, создаёт controller и восстанавливает последнюю позицию и paused state.

Успех refresh не обнуляет бюджет: следующая ошибка этого же источника показывает понятный error/retry. Ручной retry или явная смена серии/качества начинают новый бюджет. Пользовательский повтор не должен переиспользовать старую подписанную ссылку без нового HTML.

Ошибка CDN не запускает перебор зеркал. Если отказал сам запрос player HTML, применяется [контракт зеркал](05_mirrors.md), который может закрыть protected router до подтверждения новой сессии.

## 5. Приёмка и источники

Должны проверяться native start 720p/360p, продвижение позиции, seek, pause, смена качества/серии и Back; Referer всей цепочки; один refresh; прекращение повторов; ручное восстановление; поздний результат после dispose. HTML и native errorDescription с signed URL не должны попадать в UI/логи.

- [Playback repository](../../lib/packages/features/player/data/repositories/anistar_playback_repository.dart), [player screen](../../lib/packages/features/player/presentation/screens/player_screen.dart), [budget](../../lib/packages/features/player/domain/models/playback_refresh_budget.dart).
- [Session tests](../../test/packages/features/player/data/repositories/anistar_playback_repository_test.dart), [lifecycle tests](../../test/packages/features/player/presentation/screens/player_screen_test.dart), [Android E2E](../../integration_test/app_e2e_test.dart), [live smoke](../../integration_test/direct_android_test.dart).

Физический TV/декодер отдельно не подтверждён. Реальное суточное expiry не ожидалось; отказ и refresh воспроизводятся fixture. Текущие результаты — в [отчёте](../06_verification.md).

Отметка начала просмотра и история описаны отдельно: [Просмотренные серии](07_watched_episodes.md). Ошибка сохранения отметки не должна превращаться в ошибку HLS или запускать refresh источника.
