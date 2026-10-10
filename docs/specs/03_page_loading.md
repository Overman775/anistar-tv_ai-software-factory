# 📄 Загрузка страниц | AniStar TV

## 1. Общий HTTP-контракт

Каталог, detail и серии загружаются прямым Dio HTTP на текущем зеркале. Нет исполнения JavaScript или браузерного DOM. Cookies добавляет session interceptor только для собственного origin.

| Данные | Путь |
| --- | --- |
| Первая страница каталога | `/anime/` |
| Следующая страница каталога | `/anime/page/{page}/` |
| Detail | `/{slug}.html` |
| Серии и media URL | `/test/player2/videoas_p2p_new.php?id={animeId}` |
| Избранное | `/index.php?do=favorites&cstart={page}` |

Source запрашивает bytes и передаёт `Accept: text/html`, `User-Agent: AniStarTV/1.0`, `Cache-Control: no-cache`. Декодирование определяется Content-Type: Windows-1251/CP1251 либо строгий UTF-8 по умолчанию. Некорректный UTF-8 — Failure; случайно угаданная кодировка не подставляется.

Connect/send timeout — 8 секунд, receive — 20. Transport допускает два повтора идемпотентных запросов при сетевом отказе, HTTP 408/429/5xx. POST и [mutating GET](02_favorites.md) не повторяются. HTTP 403 не имеет transport retry. Эти повторы не заменяют отдельные бюджеты поиска зеркал и player refresh.

Source/парсер возвращают DTO или бросают Failure. Feature repository маппит DTO в domain и через BaseRepository возвращает Result. Ошибку/защитную HTML нельзя превращать в успешный пустой ответ.

## 2. Каталог и карточки списка

Парсер читает `.news` и `.plash`; title/link берёт из `.title_left a` или первого `a[href]`, mobile title — `.title-top`. Допустим путь `/{numericId}-{slug}.html` с host текущего зеркала и непустым title. Неподходящие отдельные карточки пропускаются.

Относительные ссылки разрешаются от baseUri. ID **9493** исключается независимо от названия/позиции рекламы. Повторяющиеся ID внутри страницы сохраняются один раз, в порядке первого появления. Poster и favorite status необязательны.

Обычный каталог без пригодных карточек — ошибка разметки. Для избранного действует только специальное подтверждение пустого списка. В текущем парсере poster/page URI могут иметь HTTP или HTTPS; native release запрещает cleartext, а HLS принимает только HTTPS. Не считать поддержку HTTP URI гарантией их загрузки.

`hasNext` определяется ссылкой того же origin с номером больше текущего: `/anime/page/N/`, для избранного — cstart либо `/favorites/page/N/`. Это признак продолжения, а не номер следующего запроса: наличие ссылки на страницу 690 не означает переход сразу на 690.

## 3. Пагинация UI

| Состояние/событие | Переход |
| --- | --- |
| CatalogStarted | Новый generation, Loading, запрос page=1, сброс старого списка |
| Первая страница успешна | Ready(items, hasMore) |
| Первая страница с ошибкой | Failure без items; доступен ручной повтор |
| More при hasMore и непустом списке | Ready с прежними items и isLoadingMore; запрос текущей page+1 |
| Следующая страница успешна | Добавить новые ID по порядку, обновить page/hasMore |
| Следующая страница с ошибкой | Failure с прежними items и hasMore; page не увеличивается |
| More после Failure без retry=true | Игнорировать; scroll/focus не создают цепочку повторов |
| Ответ прежней generation / закрытого BLoC | Игнорировать |

More игнорируется при пустом списке, отсутствии hasMore или уже выполняющейся дозагрузке. После ошибки ручной retry запрашивает ту же неуспешную страницу. Дубликаты между страницами не добавляются; ответ только с известными ID всё равно обновляет page/hasMore.

Scroll и focus около конца сетки могут запросить дозагрузку. Refresh и смена вкладки начинают новый список; на фоне завершившийся старый запрос не должен вернуть старые items. Синхронизация звёзд и revision описана в [избранном](02_favorites.md).

## 4. Detail и серии

Slug должен соответствовать `^\d+-[^/?#]+$`; animeId и page должны быть положительными. Repository параллельно запрашивает detail HTML и player HTML через Future.wait, сохраняя исходную Failure. Успех требует обеих частей и совпадения detail ID с выбранным ID.

Detail требует непустой `h1[itemprop=name]` и `ul.head`. Metadata берётся из строк «Год выпуска», «Жанр», «Озвучка», «Серии»; описание — `.descripts`, категория — `.ful-cat`/`.tags`. Необязательные поля могут отсутствовать. Favorite status остаётся nullable.

PlaylistLiteral извлекает сбалансированный массив `playlst`, учитывая строки, escapes и комментарии. JSON5 читается как данные; eval запрещён. Серия получает номер из title своего объекта, а качество/URL — из его files. Нельзя сопоставлять серии и качества по порядку независимых URL.

Повторные номера серий исключаются по первому объекту, список сортируется по номеру. Принимаются строковые качества `360`/`720` и HTTPS URL из files. Серия без пригодного HLS может оставаться в списке; попытка воспроизведения должна вернуть Failure отсутствующего потока. `files_mp4`/`files_as` не используются. Пустой пригодный список серий — ошибка, а не успешная пустая detail.

## 5. Приёмка и источники

Должны сохраняться: Windows-1251 и UTF-8; desktop/mobile; ID 9493; deduplication внутри/между страницами; определение hasNext; сохранение items после ошибки More; ручной retry той же page; отбрасывание старых ответов; соответствие detail ID; сортировка серий и неизменный signed URI.

- [Source](../../infrastructure/anistar/lib/src/anistar_source.dart), [парсер](../../infrastructure/anistar/lib/src/anistar_html_parser.dart), [CatalogBloc](../../lib/packages/features/catalog/presentation/bloc/catalog_bloc.dart), [detail repository](../../lib/packages/features/anime/data/repositories/anistar_anime_repository.dart).
- [Parser tests](../../test/infrastructure/anistar/anistar_html_parser_test.dart), [source failures](../../test/infrastructure/anistar/anistar_source_test.dart), [пагинация](../../test/packages/features/catalog/presentation/bloc/catalog_bloc_test.dart), [detail](../../test/packages/features/anime/data/repositories/anistar_anime_repository_test.dart), [Android E2E](../../integration_test/app_e2e_test.dart).
