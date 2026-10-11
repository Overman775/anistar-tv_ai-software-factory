# План рефакторинга DTO доменных моделей и репозиториев

Дата: 12 октября 2026 года. Статус: подготовлен для передачи на реализацию.

Цель — сохранить рабочий HTML-клиент, отделить его протокол от общего контракта AnistarClient и улучшить доменные модели и репозитории. Будущий REST-клиент должен иметь возможность возвращать те же нормализованные данные. Его API пока неизвестен, поэтому этот рефакторинг не обещает совместимость с любым сервером.

## Зафиксированные решения и объём

- `slug` сохраняется: имя, тип, обязательность, смысл и передача через DTO, клиент, domain и маршруты. Его рефакторинг не входит в задачу и не нужен для выполнения DoD.
- Сохраняются ID, пути фильтров, формат маршрутов, страницы и поддерживаемые качества 360/720. Внешний вид, фокус, управление и политика refresh остаются прежними.
- В объём входят DTO, общий контракт клиента, HTML-реализация, domain models, шесть сетевых репозиториев и локальный LogRepository, их DI, mapping и проверки.
- Допустимые изменения потребителей: nullable poster, неизменяемые параметры фильтрованного каталога, Result для логов, новые импорты и сигнатуры. Допустимо точечное исправление чтения логов в app_logging, необходимое для честного контракта ошибок.
- Не входят реальный REST-клиент, новые функции, изменение SDK/зависимостей, отдельный package контрактов, массовые переносы файлов, универсальные Repository/BaseEntity, новая генерация DTO, кеши и use cases для каждого вызова.

Этот документ заменяет предыдущие варианты плана в чате. Обязательное переименование AnimeScreenData и обязательное переписывание Future.wait ради удаления casts отменены: они не нужны для поставленной цели. Имена и способы реализации, прямо не зафиксированные ниже, исполнитель выбирает по простоте и правилам проекта.

## Основания и найденные зависимости

Текущая схема DTO → data repository → domain в основном соблюдена и соответствует [ADR 0007](../adr/0007-neutral-core-and-infrastructure.md) и [ADR 0009](../adr/0009-single-anistar-client-and-dio.md). DTO не нужно перемещать в domain или Core. Проблема — детали HTML и транспорта, которые пересекают границу клиента.

| Код | Наблюдение и необходимое изменение |
| --- | --- |
| [DirectCatalogSort](../../infrastructure/anistar/lib/src/direct_catalog_sort.dart), [DirectCatalogFilter](../../infrastructure/anistar/lib/src/direct_catalog_filter.dart) | Публичные типы знают DOM, DLE cookies и допустимые пути сайта. Перенести это поведение в HTML-адаптер |
| [DirectAnime](../../infrastructure/anistar/lib/src/direct_anime.dart), [DirectEpisode](../../infrastructure/anistar/lib/src/direct_episode.dart) | Summary и details используют один класс; episode раскрывает внутренний mediaId. Разделить проекции и скрыть идентификатор HTML-мутации |
| [AnistarPlaybackRepository](../../lib/packages/features/player/data/repositories/anistar_playback_repository.dart) | Репозиторий собирает Referer и извлекает end из URL. Получать готовые headers/expiry от клиента |
| [anistar.dart](../../infrastructure/anistar/lib/anistar.dart), [BaseRepository](../../infrastructure/networking/lib/src/base_repository.dart) | Общий экспорт раскрывает реализацию; ожидаемые исключения частично зависят от Dio. Разделить библиотеки и нормализовать ожидаемые ошибки |
| [AnimeSummary](../../lib/packages/features/catalog/domain/models/anime_summary.dart) и модели с коллекциями | Отсутствующий постер заменяется Uri(); final и toList(growable: false) не защищают содержимое коллекций. Использовать nullable poster и неизменяемые копии |
| [FilteredCatalogRepository](../../lib/packages/features/catalog/domain/repositories/filtered_catalog_repository.dart) | UI меняет sort у репозитория отдельно от события загрузки. Сделать конфигурацию делегата неизменяемой. Это упрощение контракта, а не доказательство существующей гонки |
| [WatchedEpisodesRepository](../../lib/packages/features/watch_history/watched_episodes_repository.dart) | Domain-интерфейс и Riverpod provider находятся в одном файле. Разделить их |
| [LogViewerScreen](../../lib/packages/features/log_viewer/presentation/screens/log_viewer_screen.dart), [FileLogOutput](../../infrastructure/app_logging/lib/src/file_log_output.dart) | Экран создаёт data-реализацию; reader уже превращает часть отказов в строки/пустые списки. Нужны DI и различение успешного чтения и ошибки на самом read boundary |

## Целевые границы

```text
HTML → HtmlAnistarClient ──┐
                          ├→ общий DTO → feature data repository → domain model → UI
REST → будущий клиент ────┘
```

Общий DTO описывает данные операции клиента. HTML parser может создавать его напрямую, когда отдельная промежуточная модель ничего не добавляет. Внутренняя parsed-модель нужна только для сведений, которые не должны выходить наружу, например mediaId. Для будущего REST отдельные JSON response models вводятся только при реальном отличии формата.

Публичные библиотеки пакета:

- `anistar.dart`: AnistarClient, общие DTO, параметры запросов и ожидаемые ошибки. Только независимые от транспорта типы.
- `html.dart`: HtmlAnistarClient и типы настройки HTML-сессии/зеркала, нужные app composition и инфраструктурным тестам.
- `providers.dart`: Riverpod composition.
- `parsing.dart`: явный вход для тестов парсинга.

Общие типы удобно разместить в `src/contract/`. Остальные файлы перемещать только при необходимости. Feature data импортирует общий контракт; composition — библиотеки создания реализаций. Domain не импортирует data, presentation, providers или AniStar. Presentation получает domain-контракты через feature providers, что является допустимой зависимостью.

## 1 Общие DTO и HTML-параметры

| Сейчас | Целевой тип и данные |
| --- | --- |
| DirectAnime в catalog/favorites | `AnistarAnimeSummaryDto`: id, slug, title, posterUri?, year?, rating?, isFavorite? |
| DirectAnime в details | `AnistarAnimeDetailsDto`: id, slug, title, posterUri?, year?, genres, filters, description?, voiceover?, seriesInfo?, isOngoing, isFavorite? |
| DirectCatalogPage | `AnistarCatalogPageDto`: список summary, page, hasNext |
| DirectCatalogFilter | `AnistarCatalogFilterDto`: label и существующий path |
| DirectEpisode | `AnistarEpisodeDto`: number, title, previewUri?, isWatched, список источников |
| Строковые ключи sources | `AnistarVideoSourceDto`: int height, Uri manifestUri, Map<String, String> httpHeaders, DateTime? expiresAt |
| DirectCatalogSort / DirectSortCriterion | `AnistarCatalogSort` / `AnistarSortCriterion`: критерий и направление, без поведения HTML |
| DioAnistarClient | `HtmlAnistarClient`: название отражает способ получения данных, Dio остаётся внутренним транспортом |

Summary и details — отдельные конечные классы, без общего базового Anime. Сохранить смысл текущих полей: null favorite означает неизвестное состояние, нулевой рейтинг не означает отсутствие рейтинга, ongoing определяется текущим правилом HTML-парсинга. Не добавлять неподтверждённую семантику и новые поля ради будущего API.

DTO создают неизменяемые копии переданных collections. Вложенные элементы также должны быть неизменяемыми. Const-конструкторы с коллекциями можно заменить обычными; equality/copyWith/code generation не нужны без конкретного потребителя. В DTO нет toDomain(), fromJson(), DOM, cookies/session state или запросов.

Вынести формирование DLE cookies, перевод критерия в поле сайта и проверку подтверждённой сортировки во внутренний HTML-компонент. Критерии клиента: date, rating, views, comments, title; news_read остаётся в адаптере. Сохранить соответствие продуктового popularity рейтингу. Проверки допустимых путей и origin остаются внутри HTML-адаптера, выполняются при парсинге и перед запросом. Percent encoding и локальность cookies сортировки сохраняются.

## 2 Источники воспроизведения

HTML-адаптер выдаёт готовые источники с URI, headers и optional expiry. Headers и expiry принадлежат конкретному источнику: их нельзя вычислять один раз для всех качеств. Исходная подписанная ссылка сохраняется без пересборки, которая могла бы изменить подпись. Отсутствующий либо неподдерживаемый expiry даёт null, сохраняя исправный поток.

Удалить playerUri() из общего AnistarClient. Внутренний helper адреса HTML-плеера остаётся для Referer и отметок просмотра. MediaId хранится только во внутреннем результате парсинга; markWatched(animeId, episodeNumber) получает его сам, выполняет запись и подтверждает результат. Не добавлять лишний HTTP-запрос только из-за разделения внутренней и публичной моделей. Сохранить отсутствие повторной записи уже просмотренного и автоматического retry изменяющего запроса.

Playback repository выбирает качество и собирает PlaybackSession. Он не разбирает end, не строит Referer и не знает HTML endpoint. PlaybackQuality получает числовой height вместо apiValue; текст 360p/720p остаётся прежним. Неподдерживаемое качество источника игнорируется, а отсутствие любого поддерживаемого потока возвращает PlaybackFailure. Сохранить текущий fallback к наибольшему доступному поддерживаемому качеству.

## 3 Доменные модели и mapping

Сохранить имена и размещение AnimeSummary, AnimeDetails, AnimeEpisode, AnimePage, AnimeScreenData, CatalogFilter, CatalogSort и PlaybackSession. Summary/details — проекции аниме; page и screen data — результаты запросов; filter/sort — значения выбора; session — данные для запуска воспроизведения. Ни одной из этих ролей не нужен обязательный суффикс Entity.

AnimeEpisode.number уникален в рамках конкретного аниме. Не считать его глобальным ID. Существующий account String? достаточен; новая сущность из одного поля не требуется. CatalogSort уже сравнивается по значению как record. Не вводить equality только по ID для аниме, скрывающий изменение содержимого. FavoritesState, CatalogState и состояния controllers остаются за пределами domain.

Обязательные изменения:

1. Сделать AnimeSummary.posterUri nullable, удалить fallback `?? Uri()` в catalog/favorites mapping. Согласованно обновить TV/mobile cards и передачу fallback постера в details: прежний placeholder, отсутствие запроса пустого URL, сохранённые Hero/focus и маршруты.
2. Защитить collections доменных результатов неизменяемыми копиями: page items, details genres/filters, screen data episodes, playback lists/maps/sets и возвращаемые genres/watched. Не копировать заново уже защищённое значение в каждом getter. Для presentation state достаточно сохранить неизменяемость при создании/обновлении; не переписывать все state-классы без необходимости.
3. Общий mapping summary/page и фильтров оформить небольшими функциями data у владельца модели. Favorites repository явно задаёт isFavorite=true для списка избранного; обычный каталог сохраняет null/false/true. Не переносить этот контекст в DTO-конструктор.
4. Сохранить параллельную загрузку details и episodes, проверку соответствия ID и единый Result. Текущий Future.wait допустим. При изменении координации не терять исходную ошибку в ParallelWaitError и не оставлять необработанный отказ второй ветви. Полный успех требует обеих частей; частичного результата нет.

Распределить валидацию без универсального framework и дублирования правил:

| Граница | Правило |
| --- | --- |
| Repository input | Неположительный ID/номер серии или страница меньше 1 возвращают Failure без обращения к клиенту |
| HTML adapter | Проверяет формат slug/path, parsing и безопасность адресов; сохраняет текущую нормализацию metadata, порядок и дедупликацию |
| DTO → domain | Проверяет согласованность результата: номер страницы равен запрошенному, detail ID равен запрошенному. Неверные обязательные данные дают Failure |
| Optional metadata | Сохраняет нынешнюю семантику: невалидный rating нормализуется в null, 0 сохраняется; неизвестный expiry — null. Отсутствующий год/постер/описание не ломает всю карточку |
| Playback result | Selected quality входит в available; requested quality сохраняет выбор пользователя. Номера серий — положительные, уникальные, отсортированные; watched относится к ним |

Проверки обязательных данных должны работать в release, а не только через assert. Не исправлять молча чужой ID/номер страницы. Контракт клиента требует согласованных обязательных значений; fake с некорректным ответом проверяет защиту mapping. Не строить валидатор всех возможных строк и URI.

Год, озвучку и сведения о сериях оставить строками. AnimeScreenData не содержит UI-объектов, поэтому его имя не мешает архитектуре. Проверка detail ID не доказывает identity HTML-документа: текущий parser выводит ID из переданного slug. Не заявлять более сильную гарантию без достоверного поля ответа.

## 4 Контракт ошибок

Ввести один AnistarClientException с категорией и безопасным сообщением для ожидаемых отказов. Его публичные поля не содержат Dio/DOM, response body, cookies или credentials. Избежать отдельного exception-класса на каждый HTTP status.

| Отказ клиента | Mapping в data |
| --- | --- |
| Timeout | Существующий TimeoutFailure |
| Connection failure | Существующий ConnectionFailure |
| Server failure | Существующий ServerFailure |
| Отклонённый запрос, авторизация, недоступный ресурс или неподдерживаемый ответ сайта | RequestFailure с безопасным сообщением; различать причины внутри клиента только там, где этого требует поведение |
| Неожиданная ошибка | Существующий UnknownFailure и безопасная диагностика |

Матрицу уточнить по существующим error tests до изменения кода: сохранить пользовательские сообщения и ветвления, включая 403/challenge и восстановление зеркала. Событие expired остаётся отдельным сигналом; одного Failure недостаточно для выхода из сессии. Не превращать отсутствие сессии при restore в ошибку: success(null) остаётся успешным результатом.

Все асинхронные операции HtmlAnistarClient нормализуют ожидаемые transport/parser/session отказы через общий helper. AnistarFailure может остаться внутренней ошибкой HTML-кода, но не экспортируется общим контрактом. Неожиданные программные ошибки обрабатываются отдельно на repository boundary, без подмены их ожидаемым сетевым отказом. Сохранить действующее скрытие чувствительных данных при ошибках авторизации; исходный текст исключения не должен автоматически попадать в сообщение или лог.

Один небольшой mapper в data переводит AnistarClientException в Failure. Result создаётся один раз. Существующий BaseRepository можно использовать для обёртки Result и unknown failures; ожидаемые ошибки AniStar должны быть преобразованы до его Dio-specific ветки. Не создавать новый универсальный BaseRepository и не переносить все ошибки networking в Core. PlaybackFailure/FavoritesFailure используются для соответствующих прикладных отказов. Внешние domain/presentation потребители не распознают исключения клиента или Dio.

## 5 Репозитории и выбор каталога

Сохранить узкие CatalogRepository, CatalogBrowseRepository, FavoritesRepository, AnimeRepository, PlaybackRepository и AuthRepository. Общий CRUD-интерфейс и единый репозиторий всех features не нужны. Репозитории координируют операции и mapping; они не владеют экраном, native controller, cookie session или вторым кешем favorites/history.

FilteredCatalogRepository оставить чистым делегатом с final filter и sort, задаваемыми при создании. Это неизменяемая конфигурация, а не изменяемое состояние выбора UI. При смене сортировки экран создаёт новый делегат. Передать его через минимальное расширение существующего события CatalogStarted; отдельная система событий/источников не нужна. При замене делегата BLoC одновременно меняет активный repository, увеличивает generation и начинает первую страницу. Замена источника всегда сбрасывает данные; preserveContent относится только к refresh того же источника.

Каждая загрузка захватывает repository, page и generation до await. Поздний результат старой сортировки не меняет новый список. Выбранная сортировка в UI согласована с активным запросом. Обычный refresh при отказе сохраняет загруженные страницы; retry повторяет нужную страницу. Межстраничная дедупликация остаётся в CatalogBloc. Изменение сортировки не создаёт новый AnistarClient или сессию.

Не добавлять отмену HTTP, общие кеши или переработку всего BLoC lifecycle. Сохранить существующие generation/dispose checks, обновив их для замены делегата. Сериализация мутаций и защита от ответа старого аккаунта остаются в существующих favorites/watch-history controllers.

## 6 Watch history и локальный LogRepository

Watch history разделить на domain/repositories/watched_episodes_repository.dart, data/repositories/anistar_watched_episodes_repository.dart и отдельный feature provider. Обновить imports, app binding и fixtures. Domain-файл содержит только интерфейс и нейтральные типы. Сохранить сериализацию записей, подтверждение результата и игнорирование ответа после смены аккаунта/logout/dispose.

LogRepository не использует AnistarClient. Его методы возвращают Future<Result<List<String>, Failure>> и Future<Result<String, Failure>>. Подключить FileLogRepository через feature provider и app composition; убрать импорт data из LogViewerScreen. Отдельный framework файловых репозиториев не нужен.

Важно: сейчас FileLogOutput.getLogFiles() скрывает FileSystemException за пустым списком, а getLogContent() возвращает ошибки как содержимое файла. Обёртка этих значений в Result.success оставит дефект. Точечно скорректировать чтение в app_logging, чтобы repository мог различать данные и отказ; проверить всех потребителей методов. Пустой доступный каталог — success([]); некорректное имя, исчезнувший выбранный файл и отказ чтения — Failure. Отсутствие ещё не созданного каталога логов может оставаться успешным пустым списком, как сейчас.

FileLogRepository преобразует ожидаемые файловые отказы в LogFailure с безопасным сообщением. Не распознавать ошибку поиском фразы в возвращённой строке: файл может содержать тот же текст. Небольшие передаваемые функции чтения допустимы для тестов; не создавать для этого новую файловую архитектуру и не менять запись, isolate, rotation или жизненный цикл logger.

LogViewerBloc обрабатывает Result, сохраняя выбранный файл и существующие generation checks. Произвольный текст exception больше не добавляется в UI. Обновить документированное исключение для прямого создания FileLogRepository. Согласовать новые сообщения ошибок с тестами; остальной интерфейс логов не менять.

## 7 Архитектурные проверки и заменяемость

Расширить [package_boundaries_test.dart](../../test/architecture/package_boundaries_test.dart), используя существующий [разбор Dart directives](../../test/support/dart_directives.dart). Для обхода локальных imports/exports достаточно небольшого resolver с visited set; отдельный анализатор зависимостей не нужен.

- Для общего anistar.dart и его внутренних зависимостей проверить отсутствие transport/HTML/Flutter/Riverpod/session/mirror implementation и app/features. Это проверка библиотеки, не всех зависимостей pubspec пакета anistar.
- В domain разрешить Dart SDK, нейтральный Core и согласованные domain-зависимости между features; запретить data/presentation/providers и остальную инфраструктуру. Учитывать package и относительные пути, re-exports и parts. Существующие зависимости anime/favorites на domain каталога разрешены.
- В presentation запретить data, anistar.dart/html.dart/parsing.dart и чужой src. Feature providers разрешены; их binding выполняет app. Не запрещать Riverpod в presentation и не обходить через него весь граф сторонних пакетов.
- В feature data запретить HTML/Dio/provider imports и библиотеки HTML-реализации клиента. Разрешённые mapping utilities и инфраструктурные Failure не делают DTO частью domain.
- После перемещения watch history он проверяется общими правилами. Проверить guard на маленьких примерах разрешённого контракта, запрещённого относительного пути и re-export.

Добавить FakeAnistarClient, реализующий только общий контракт. Unit-тесты всех шести сетевых репозиториев используют его без HTML/Dio. Отдельный DI-тест подменяет anistarClientProvider и подтверждает получение подмены всеми сетевыми репозиториями. Тестировать это в контейнере, без запуска полной HTML startup-последовательности. Это подтверждает заменяемость dependency, но не совместимость с несуществующим REST-сервером.

Сохранить HTML fixture-тесты как проверки адаптера/интеграционных цепочек. Fake playback должен возвращать URI без end, явный expiry и собственные headers без Referer; repository переносит их без домысливания. Отдельно проверить LogRepository через подмену чтения и DI.

## Порядок выполнения и проверки

1. Проверить актуальные инструкции, git status и исходные целевые тесты. Сохранить чужие изменения. Сбои исходного состояния записать отдельно.
2. Выполнить разделы 1 и 3 вместе: новые DTO, domain collections/nullable poster и обновление mapping/потребителей. Разделять на небольшие законченные изменения, не оставляя старого producer с новым consumer.
3. Выполнить раздел 2 и обновить playback tests. Затем раздел 4 для всех операций клиента и репозиториев.
4. Выполнить разделы 5 и 6 отдельными изменениями, проверяя соответствующие BLoC/controller/widget сценарии.
5. Завершить раздел 7, очистить временную совместимость, обновить README и ADR. Проверить итоговый diff и полный quality gate.

Тесты и документацию добавлять вместе с изменением, а не откладывать все до последнего шага. Временные aliases/re-exports допустимы только внутри миграции. Исторические ADR могут сохранять старые имена; активный код, fixtures и актуальная документация используют новый API.

Для изменений потребителей nullable poster и сортировки сначала прочитать ADR 0008 и связанные TV/motion спецификации. Сохранить существующее управление; не менять golden baselines ради прохождения рефакторинга. Typed routes не требуют изменения, но при фактическом изменении generated-входов использовать штатный build_runner, а не ручное редактирование generated files.

| Проверка | Минимальные сценарии |
| --- | --- |
| DTO и domain collections | Изменение исходного списка/map/set не меняет объект; add и присваивание по индексу запрещены; старый результат не меняется при новом |
| Mapping и metadata | Summary/details, rating 0/null, favorite null/false/true, избранное true, отсутствующий постер и прежние TV/mobile placeholders |
| Числовые входы и согласованность | Неверные ID/page/episode до вызова клиента; неверная страница ответа и detail ID дают Failure; пустой успех отличается от отказа |
| Anime repository | Успех двух параллельных запросов, отказ каждой ветви и обеих, отсутствие частичного результата и необработанного исключения |
| HTML filters/sort | Encoded paths, origin/валидация, пагинация, подтверждение сортировки и отсутствие изменения общих cookies |
| Playback | Signed URL, per-source headers/expiry, неизвестный/выходящий за диапазон expiry, requested/selected quality, fallback, unsupported sources, предыдущая/следующая серия через пропуски |
| Каталог | Быстрая смена сортировки, поздняя старая страница, refresh failure, retry той же страницы, dispose и сохранённый focus |
| Auth/Favorites/History | Restore success(null), ожидаемые failures, expiry, смена аккаунта/logout во время запроса, подтверждённая мутация, отсутствие retry записи |
| Log reader/repository | Пустой каталог, ошибка чтения, неверное имя, исчезнувший файл, обычное содержимое с текстом похожим на ошибку, безопасные сообщения и DI override |
| Log BLoC | Поздний ответ после нового выбора/refresh/dispose, сохранение выбранного файла при failure |
| DI и архитектура | Общий клиент/сессия, смена origin и изоляция cookies, закрытие ресурсов, fake override, запреты и разрешения imports |

Во время работы запускать затронутые тесты. Ниже пример набора для исходной проверки; после переносов использовать актуальные пути:

```bash
fvm flutter test test/architecture test/infrastructure/anistar test/app/app_container_test.dart test/packages/features/catalog test/packages/features/anime test/packages/features/player test/packages/features/auth test/packages/features/favorites test/packages/features/watch_history test/packages/features/log_viewer
```

После последнего изменения кода последовательно выполнить:

```bash
bash scripts/check.sh
graphify update .
```

Не запускать повторно те же полные наборы без новых изменений/сбоев. Live-тесты с аккаунтом, публикация и обновление baselines не нужны для приёмки этой задачи. Новые тесты проверяют поведение и границы, не повторяют приватную реализацию. Дополнительный ручной/native smoke можно указать отдельно, не выдавая его отсутствие за результат проверки.

## Definition of Done

Дополнение от 12 октября 2026 года: пользователь прямо разрешил актуализировать устаревшие golden baselines четырёх исходно падавших тестов `catalog_filters_golden_test.dart` (шесть PNG). Это исключение из запрета на обновление baselines; остальные требования и проверки плана сохранены. Доказательства и результаты повторного полного gate — в [отчёте](anistar-client-dto-refactoring-report.md).

Все пункты обязательны. Для каждого исполнитель указывает файл/символ, название теста либо результат команды. Непроверенный пункт остаётся открытым; переименование типов или одна успешная компиляция не подтверждают весь DoD.

- [x] **D1 Контракт.** anistar.dart раскрывает только общий клиент/DTO/параметры/ожидаемые ошибки. HtmlAnistarClient и его настройка вынесены в отдельную библиотеку; architecture test подтверждает границы раздела 7.
- [x] **D2 DTO.** Summary/details разделены, обязательность и null-семантика описаны, коллекции неизменяемы. DLE/DOM/path validation и mediaId скрыты в HTML; общие DTO не выполняют parsing или domain mapping.
- [x] **D3 Domain и mapping.** Коллекции защищены, posterUri nullable без фиктивного Uri(), общий mapping сохраняет различия каталога/избранного. Модели не объединены ради одинаковых полей, ненужные Entity/BaseEntity/equality не добавлены. Инварианты и optional metadata обрабатываются по разделу 3.
- [x] **D4 Playback.** Репозиторий использует готовые URI/headers/expiry, не знает end/Referer/player endpoint. Сохранены качество, fallback, signed URL, нумерация/навигация серий и refresh behavior. Тест с независимым fake и HTML fixtures проходят.
- [x] **D5 Ошибки.** Все ожидаемые отказы клиента нормализованы и переводятся в Failure один раз перед Result. Неожиданные ошибки различаются; безопасные сообщения, expiry и restore success(null) сохранены. Domain/presentation не разбирают Dio/client exceptions. Проверены маскирование чувствительных данных в логах и отсутствие их в UI-сообщениях.
- [x] **D6 Репозитории.** Все шесть сетевых репозиториев имеют success/failure tests через FakeAnistarClient. Числовые параметры валидируются без сети; параллельная загрузка карточки сохраняет исходную ошибку и не выдаёт частичный результат. Нет нового универсального Repository или лишнего кеша.
- [x] **D7 Каталог.** FilteredCatalogRepository имеет неизменяемую конфигурацию. Смена источника согласована с generation и пагинацией; быстрые смены/поздние ответы/refresh/retry не смешивают результаты, focus и scroll behavior сохранены.
- [x] **D8 Watch history.** Domain-интерфейс отделён от provider, реализация находится в data, bindings/imports обновлены. Сериализация и подтверждение записи, logout/account switch/dispose guards проходят регрессии.
- [x] **D9 Логи.** Reader различает содержимое и ошибку, LogRepository возвращает Result, FileLogRepository создаётся через composition. Ошибки не превращаются в успешный текст/пустой список, кроме явно разрешённого отсутствующего каталога. Log BLoC сохраняет async guards и безопасные сообщения; запись логов не переработана.
- [x] **D10 Slug и совместимость.** Slug и формат routes сохранены, пути фильтров/ID/страницы и продуктовые возможности не мигрированы. Нет временных aliases/re-exports и старых Direct*/DioAnistarClient в активном API/коде/fixtures. Исторические документы и старые имена артефактов тестов не требуют механического переименования.
- [x] **D11 Проверки.** Пройдены относящиеся к изменениям сценарии таблицы, architecture/DI tests и итоговый scripts/check.sh. Тесты не пропущены и не ослаблены ради прохождения; golden baselines актуализированы только в рамках согласованного выше исключения. Команды и результаты относятся к сдаваемому состоянию.
- [x] **D12 Документация и передача.** README и ADR описывают реализованные границы, исключение прямого создания LogRepository убрано, graphify обновлён. Отчёт содержит доказательства D1–D11 и реальные ограничения будущей интеграции REST.

При недоступной обязательной проверке указать команду, причину и непроверенные условия; это незавершённая проверка, а не выполненный DoD. Исходные сбои не смешивать с новыми регрессиями и не исправлять несвязанные части проекта без необходимости.

## Пределы будущего REST и задание исполнителю

REST-адаптер понадобится реализовать отдельно по его спецификации. Если он сохраняет текущие ID/slug/filter paths/страницы и операции, нормализовать его ответы в общий контракт. Если нет — отдельно согласовать изменение этих соглашений. Не создавать фиктивные slug, cursor mapping или успешные пустые результаты для отсутствующих возможностей. Сейчас никаких альтернативных идентификаторов, capabilities framework и REST endpoints не добавлять.

Реализуй разделы 1–7 по последовательности из раздела «Порядок выполнения и проверки», сверяясь с актуальным кодом и инструкциями репозитория. Сохрани slug и существующее поведение, кроме явно описанных улучшений обработки данных/ошибок. Рутинные детали реализации решай самостоятельно в рамках объёма. В конце передай ссылки на изменённые контракты и mapping, статусы D1–D12 с доказательствами, выполненные команды и результаты, отклонения от плана и оставшиеся ограничения. Не объявляй задачу завершённой при открытых обязательных пунктах.
