# ADR-0010: Нормализованный контракт AniStar

- **Статус:** Accepted
- **Дата:** 2026-10-12
- **Связи:** Уточняет [ADR-0007](0007-neutral-core-and-infrastructure.md) и [ADR-0009](0009-single-anistar-client-and-dio.md). Связанные поведенческие контракты: [загрузка страниц](../specs/03_page_loading.md), [каталогные фильтры](../specs/09_catalog_filters.md), [карточка аниме](../specs/12_anime_details.md).

## Контекст

Общий API экспортировал HTML-сессию, зеркало и транспортную реализацию. DTO сортировки содержал DOM и DLE cookies, episode раскрывал mediaId, а playback repository строил Referer и читал expiry из signed URL. Одна модель использовалась для каталога и подробностей. Локальный viewer создавал data repository в UI, а reader превращал файловые отказы в успешный текст или пустой список.

## Решение

- `anistar.dart` экспортирует только AnistarClient, DTO, параметры и AnistarClientException. `html.dart` содержит HtmlAnistarClient и настройку HTML-сессии и зеркала. `providers.dart` содержит composition. `parsing.dart` служит входом для инфраструктурных тестов. Feature data использует только общий контракт.
- Summary и details разделены без общего базового Anime. DTO и domain сохраняют slug и копируют collections в неизменяемые значения. Отсутствующий poster — `null` с прежним placeholder/Hero. Mapping summary/page и filters находится в data каталога. Feature favorites явно задаёт `true` только для своего списка.
- HTML-адаптер владеет DLE сортировкой и проверками path/origin. Он также владеет внутренним mediaId, Referer и expiry.
- Источник содержит height, исходный URI, headers и optional expiry для этого URI. Playback repository выбирает поддерживаемые 360/720 и сохраняет fallback, requested quality и refresh policy.
- Каждая async-операция адаптера нормализует ожидаемые отказы в безопасную AnistarClientException. `mapAnistarErrors` переводит её в Failure до единственного Result на repository boundary. Неожиданные ошибки становятся UnknownFailure. Диагностика не печатает исходный текст исключения с credentials. Expired остаётся отдельным stream-событием. Операция restore без сессии — success(null).
- FilteredCatalogRepository получает final filter/sort. CatalogStarted может заменить делегат: BLoC сбрасывает выдачу и generation вместе, захватывает источник/страницу/generation до await. Refresh того же источника сохраняет прежние страницы при отказе. Контроллеры мутаций сохраняют сериализацию и guards от старого аккаунта и dispose.
- Watch history имеет отдельные domain interface, data implementation и feature provider. LogRepository возвращает Result и связывается app composition. FileLogOutput read boundary бросает отказ вместо успешного текста. Отсутствующий каталог допускает пустой успех. Запись, rotation и isolate не изменены.

## Уточнение нормализованных данных от 2026-10-22

Расширение данных карточки должно сохранять границы нормализованного контракта: необязательные поля остаются nullable, дата и строка обновления сохраняют исходный текст, а ссылки фильтров передаются как исходные безопасно проверяемые URI. Порядок частей сохраняет подпись, исходную ссылку и идентификатор только когда он надёжно извлечён. Основная кнопка карточки использует подтверждённую историю сайта; это поведение принадлежит [спецификации карточки аниме](../specs/12_anime_details.md), а не DTO или новому постоянному профилю.

Экспортируемые client/DTO-контракты остаются границей адаптера. Поля нормализованных summary/details, ссылок фильтров и частей перечислены в [README пакета](../../infrastructure/anistar/README.md); пользовательские правила их отображения и переходов остаются в связанных спецификациях. Этот ADR фиксирует границы данных и не подтверждает прохождение проверок реализации.

## Последствия

Architecture tests обходят project imports/exports/parts с visited set. Независимый FakeAnistarClient проверяет все шесть сетевых репозиториев, а DI override — общую подмену без HTML startup. HTML fixtures остаются проверками реального адаптера. SDK, зависимости, routes, focus и golden baselines сохраняются.

REST-клиент не реализован. Неизвестный REST API может потребовать отдельно согласованной миграции ID/slug/filter paths/страниц или операций. Fake/DI не доказывают совместимость с конкретным сервером. Parser details выводит ID из переданного slug. Repository проверяет соответствие контрактного ID запросу, но не доказывает identity HTML-документа без подтверждённого поля ответа.
