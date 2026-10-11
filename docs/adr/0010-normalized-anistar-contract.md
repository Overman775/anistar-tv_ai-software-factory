# ADR-0010: Нормализованный контракт AniStar

- **Статус:** Accepted
- **Дата:** 2026-10-12
- **Уточняет:** [0007](0007-neutral-core-and-infrastructure.md), [0009](0009-single-anistar-client-and-dio.md).

## Контекст

Общий API экспортировал HTML-сессию, зеркало и транспортную реализацию. DTO сортировки содержал DOM и
DLE cookies, episode раскрывал mediaId, playback repository строил Referer и читал expiry из signed URL.
Одна модель использовалась для каталога и подробностей. Локальный viewer создавал data repository в UI,
а reader превращал файловые отказы в успешный текст или пустой список.

## Решение

anistar.dart экспортирует только AnistarClient, DTO, параметры и AnistarClientException. html.dart
содержит HtmlAnistarClient и настройку HTML-сессии/зеркала; providers.dart — composition; parsing.dart —
вход для инфраструктурных тестов. Feature data использует только общий контракт.

Summary/details разделены без общего базового Anime. DTO и domain сохраняют slug и копируют collections
в неизменяемые значения. Отсутствующий poster — null с прежним placeholder/Hero. Mapping summary/page
и filters находится в data каталога; favorites явно задаёт true только для своего списка.

HTML-адаптер владеет DLE сортировкой и проверками path/origin, внутренним mediaId, Referer и expiry.
Источник содержит height, исходный URI, headers и optional expiry для этого URI. Playback repository
выбирает поддерживаемые 360/720 и сохраняет fallback, requested quality и refresh policy.

Каждая async-операция адаптера нормализует ожидаемые отказы в безопасную AnistarClientException.
mapAnistarErrors переводит её в Failure до единственного Result на repository boundary. Неожиданные
ошибки становятся UnknownFailure; диагностика не печатает исходный текст исключения с credentials.
Expired остаётся отдельным stream-событием; restore без сессии — success(null).

FilteredCatalogRepository получает final filter/sort. CatalogStarted может заменить делегат: BLoC
сбрасывает выдачу и generation вместе, захватывает источник/страницу/generation до await. Refresh
того же источника сохраняет прежние страницы при отказе. Контроллеры мутаций сохраняют сериализацию
и guards от старого аккаунта и dispose.

Watch history имеет отдельные domain interface, data implementation и feature provider. LogRepository
возвращает Result и связывается app composition; FileLogOutput read boundary бросает отказ вместо
успешного текста. Отсутствующий каталог допускает пустой успех. Запись/rotation/isolate не изменены.

## Последствия и ограничения

Architecture tests обходят project imports/exports/parts с visited set. Независимый FakeAnistarClient
проверяет все шесть сетевых репозиториев, а DI override — общую подмену без HTML startup. HTML fixtures
остаются проверками реального адаптера. SDK, зависимости, routes, focus и golden baselines сохраняются.

REST-клиент не реализован. Неизвестный REST API может потребовать отдельно согласованной миграции
ID/slug/filter paths/страниц или операций. Fake/DI не доказывают совместимость с конкретным сервером.
Parser details выводит ID из переданного slug; repository проверяет соответствие контрактного ID
запросу, но не доказывает identity HTML-документа без подтверждённого поля ответа.
