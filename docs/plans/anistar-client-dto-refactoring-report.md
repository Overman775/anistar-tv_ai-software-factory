# Выполнение рефакторинга DTO и репозиториев

Дата: 12 октября 2026 года. Рефакторинг завершён, D1–D12 проверены. После прямого указания пользователя обновлены устаревшие golden baselines, полный quality gate прошёл. План: [anistar-client-dto-refactoring.md](anistar-client-dto-refactoring.md).

## Исходное состояние

- До правок рабочее дерево содержало только пользовательский `docs/plans/`; он сохранён.
- AGENTS.md прочитан. Указанный `../.tessl/RULES.md` отсутствует; поиск не обнаружил другой RULES.md.
- План прочитан полностью; ADR 0007/0008/0009, architecture/code style, TV и motion specs изучены.
- Исходный целевой запуск: 303 passed, 4 failed — `catalog_filters_golden_test.dart`:
  `genre picker and filtered catalog` и `anime filter focus` для compact/wide.
  Команда из плана запускала goldens вместе с остальными тестами. Лог: `build/verification/dto-refactoring/baseline.log`.
- Первая попытка запусков была недоступна из-за записи в FVM cache вне sandbox; повтор с доступом выполнился.

## Выполнение D1–D12

Статусы относятся к сдаваемому состоянию. Итоговый gate выполнен полностью и завершился успешно. Исключение из исходного запрета на обновление baselines согласовано пользователем 12 октября 2026 года; область исключения и доказательства приведены ниже.

| Пункт | Статус | Реализация и доказательства |
| --- | --- | --- |
| D1 Контракт | Проверен | `infrastructure/anistar/lib/anistar.dart`, `html.dart`, `src/contract/`; `package_boundaries_test.dart`: common library transitive graph, domain, presentation, data и resolver/re-export/part fixtures. |
| D2 DTO | Проверен | `AnistarAnimeSummaryDto`, `AnistarAnimeDetailsDto`, `AnistarEpisodeDto`, `AnistarVideoSourceDto`; `HtmlCatalogParameters`, `ParsedEpisode`. `model_immutability_test.dart`: immutable snapshots и nested headers. HTML sort/filter fixtures сохраняют encoded paths и cookie isolation. |
| D3 Domain/mapping | Проверен | AnimeSummary poster nullable; immutable page/details/screen/session collections. `anistar_catalog_mapping.dart`: 0/null rating и favorite context. Contract tests: metadata, invalid mandatory values, wrong page/detail ID; `anime_card_test.dart`: placeholders/Hero/actions TV/mobile. |
| D4 Playback | Проверен | Ready sources → PlaybackSession, height 360/720. Contract fake: explicit headers/expiry, signed URI identity, fallback, unsupported quality, unique positive ordered episodes, gap navigation. Fixture playback/refresh, independent per-source expiry и общий client error matrix прошли в финальном gate. |
| D5 Ошибки | Проверен | `HtmlAnistarClient._safe`, `mapAnistarErrors`; все шесть repository failure matrix, UnknownFailure, safe repository diagnostics. Existing auth, expiry, 403/challenge, mirror recovery, networking redaction tests passed. |
| D6 Репозитории | Проверен | `anistar_repository_contracts_test.dart`: success/failure всех шести, numeric input без клиента, empty success vs failure, обе parallel branches started и details/episodes/both failure. Future.wait сохраняет исходную ошибку и потребляет оба отказа. |
| D7 Каталог | Проверен | Final filter/sort; CatalogStarted.repository; BLoC captures source/page/generation. Replacement test: late old page и intermediate first page ignored. Existing refresh failure/retry/dispose/focus/sort widget tests passed. |
| D8 Watch history | Проверен | domain/repositories, data/repositories, watch_history_providers.dart; bindings updated. Existing logout/account-switch/dispose/serialization/confirmation/no mutation retry regressions passed. |
| D9 Логи | Проверен | Reader throws, missing directory only empty; Result/LogFailure; app binding. Tests: malformed name, missing file, failed listing/read, ordinary error-like text, safe message, DI override, selection/refresh/dispose guards. Writer/isolate/rotation unchanged. |
| D10 Slug/совместимость | Проверен | Slug поля/тип/обязательность/маршруты сохранены. Routes, generated files, SDK, зависимости и lockfile не изменены. По указанию пользователя актуализированы шесть PNG четырёх исходно падавших golden-тестов; затем отдельно поднята версия приложения до 1.1.1+4 и обновлён CHANGELOG. Search active code/fixtures: no Direct* or DioAnistarClient. |
| D11 Проверки | Проверен с согласованным исключением | Final scripts/check.sh: exit 0; format 299 files / 0 changes, analyzer no issues, DCM 299 files / no issues, unit/widget 376 passed, goldens 66 passed. Последний gate после дополнительного live smoke — `live-native-smoke/check-after-smoke-fix.log`. Тесты и проверки не ослаблены. По прямому указанию пользователя обновлены шесть устаревших PNG четырёх исходно падавших тестов. |
| D12 Передача | Проверен | README/architecture/structure/network/motion/filter specs и ADR-0010 обновлены. После исправления extraction graphify полностью пересобран: 333 code files и 60 документов, свежие AST и semantic fragments без старого кеша. Raw и post-build: 0 пустых endpoints и 0 self-loops; post-build также 0 dangling endpoints. Детали и ограничения — в дополнении ниже. Итоговый diff проверен, git diff --check чистый. |

## Команды и результаты

- Baseline: команда полного целевого набора из плана; 303 passed / 4 golden failures.
- `fvm flutter test --no-pub --exclude-tags=golden test/architecture test/infrastructure/anistar test/infrastructure/app_logging test/infrastructure/networking test/app/app_container_test.dart test/packages/features/common test/packages/features/catalog test/packages/features/anime test/packages/features/player test/packages/features/auth test/packages/features/favorites test/packages/features/watch_history test/packages/features/log_viewer`: 304 passed (`targeted.log`).
- `fvm flutter analyze --no-pub`: no issues (`analyze.log`, после новых tests полный gate повторяет analyzer).
- Первый итоговый `bash scripts/check.sh`: exit 1 только на golden этапе (`check.log`). Formatter/analyzer/DCM и все 376 unit/widget tests прошли; goldens: 62 passed / 4 failed.
- После согласования: `fvm flutter test --no-pub --tags=golden --concurrency=1 --test-randomize-ordering-seed=20261010 --update-goldens test/packages/features/catalog/presentation/screens/catalog_filters_golden_test.dart`: exit 0, 4 passed (`golden-update.log`).
- Полный `bash scripts/check.sh` после согласования baselines: exit 0, format 299 files / 0 changes, analyzer no issues, DCM no issues, 376 unit/widget и 66 golden tests passed (`check-after-golden-update.log`). Обновление не заменяло проверку: gate сравнивал снимки без `--update-goldens`.
- Исторический `graphify update .` после live smoke: exit 0, 3090 nodes / 5057 edges / 221 communities (`live-native-smoke/graphify-after-smoke-fix.log`). Тогда обновлялся только AST; diagnostic показал 2 пустых endpoint и 11 self-loops. По дополнительному указанию пользователя причины исправлены в extractor и выполнена полная свежая пересборка кода и документации — см. дополнение ниже. Старые логи сохранены как история, а не текущий результат.

Все логи находятся в `build/verification/dto-refactoring/` и не коммитятся. Старые неуспешные запуски сохранены отдельно от окончательного успешного gate.

## Ограничения

Реального REST-клиента и REST specification нет. Fake/DI подтверждают подмену dependency, но не
совместимость с сервером, его identifier/pagination соглашениями или отсутствующими операциями.
Details parser выводит ID из переданного slug: mapping не доказывает identity HTML-документа.
По дополнительному запросу пользователя live account и Android native smoke выполнены на TV-эмуляторе API 36 ARM64; результат приведён ниже. Физический TV, аппаратный декодер реального устройства, физический пульт и mobile live smoke не проверялись. Они не входят в приёмку исходного плана.
Обязательные проверки плана доступны и выполнены; открытых пунктов DoD нет. Обновление baselines — согласованное отклонение от первоначального запрета, без изменений UI-кода при актуализации снимков.

## Сопоставление исходных golden failures

Четыре теста выполняют шесть неуспешных сравнений PNG. Исходный лог и первый итоговый gate до актуализации baselines дают одинаковые значения:

| PNG | До и после |
| --- | --- |
| filtered_catalog_compact | 0.67%, 3496 px |
| catalog_sort_compact | 0.33%, 1736 px |
| anime_filter_focus_compact | 12.07%, 62582 px |
| filtered_catalog_wide | 0.56%, 5177 px |
| catalog_sort_wide | 0.34%, 3091 px |
| anime_filter_focus_wide | 9.60%, 88458 px |

Снимки test/master визуально проверены: расхождения текущей геометрии/фокуса уже присутствовали до
рефакторинга. После разрешения пользователя обновлены только эти шесть PNG. Снимки выбора жанра в том же файле остались неизменными. Test/master artifacts сохранены в ignored failures/. Все шесть новых baselines побайтово совпадают с визуально проверенными testImage из первого итогового gate; подтверждение — `golden-update-audit.json`.

## Итоговая проверка diff

Проверены common exports и contract dependencies; producer/parser/source/client цепочка, готовые
playback источники; общий error mapper и safety diagnostics; immutable domain и nullable poster;
каталог с generation; watch history imports/bindings; log read boundary/Result/BLoC/composition;
fixtures, independent fake, tests и документация. `git diff --check` не обнаружил whitespace ошибок.
Routes, generated files, pubspec/lock и FVM pin не изменены; старые API имена отсутствуют
в активном Dart-коде. Из PNG изменены только шесть согласованных baselines. Все D1–D12 отмечены
в плане; исключение по baselines записано явно, остальные требования сохранены.

Промежуточные analyzer/DCM ошибки исправлены. Изменены только необходимая обработка данных,
границы зависимостей и соответствующие tests/docs. Рутинные решения: Future.wait сохранён, AnimeScreenData
не переименован; новый BaseEntity/Repository/cache/REST adapter не введён.

## Согласованное обновление baselines и финальный аудит

Пользователь 12 октября 2026 года прямо разрешил обновить четыре исходно падавших golden-теста:
«Вот эти Golden тесты просто обнови». Это изменило только запрет на актуализацию их baselines;
остальные ограничения плана, сценарии, assertions, tolerances и quality gate сохранены.

`completion-audit.json` фиксирует состояние до разрешения: совпадение всех шести расхождений с
исходным запуском, защищённые inputs и SHA-256 Dart-файлов. `golden-update-audit.json` подтверждает,
что ни один из 302 проверяемых Dart-файлов после предыдущего gate не изменился, а новые PNG
совпадают с проверенными failure images. Итоговая сверка не обнаружила изменений SDK, зависимостей,
routes или generated files; `git diff --check` завершился с exit 0.

После актуализации выполнен полный gate без пропусков и режима обновления снимков,
затем повторно выполнен `graphify update .`. D11 закрыт по результату exit 0; D1–D12 выполнены
с указанным согласованным исключением и ограничениями graphify/будущего REST.

## Дополнительный live/native smoke (12 октября 2026 года)

По запросу пользователя проверен настоящий AniStar/CDN на Android TV AVD `anistar_tv_e2e`,
`emulator-5554`, API 36, ARM64, Flutter 3.47.7; seed 20261010. Transport, HTML parser,
репозитории, Secure Storage и Android video platform не подменялись.

- Host: `fvm flutter test tool/diagnostics/anistar_network_test.dart --reporter=expanded` —
  exit 0, 1 passed: зеркало `v30.astar.bz`, анонимный каталог, login, authenticated catalog,
  restore и локальное очищение сессии.
- Native: `bash scripts/e2e-tv.sh emulator-5554 live` с Python 3.12 в PATH — exit 0,
  1 native case, failures/errors/skipped = 0. Сам сценарий занял 72 секунды.
- Проверены login через UI, encrypted restore без второго login POST, карточка/серии,
  добавление/удаление избранного, звезда и сохранение на сайте после пересоздания приложения,
  настоящий HLS 720p/360p, продвижение позиции, remote seek, seek до 120 секунд, pause/resume,
  сохранение позиции при смене качества, переход на серию 4, Back, серверные отметки серий
  1/4 и их восстановление после второго перезапуска, logout и снятие screen-awake flag.
- Избранное возвращено в исходное состояние. Серия 4 осталась отмеченной в истории тестового
  аккаунта, как предусмотрено live-сценарием; снятие серверных отметок не реализовано.
- Обычная dev APK с `lib/main_dev.dart` пересобрана без live credentials и установлена
  вместо integration APK: build и `adb install -r` завершились с exit 0.

Первые попытки сохранены отдельно. Системный Python 3.9 остановил preflight до сборки;
использован установленный Python 3.12 без изменения tooling или SDK. Первый фактический native
прогон выявил устаревшую предпосылку теста: после прежних просмотров сервер уже отмечал серии
1–3, поэтому hero правильно предлагал серию 4, а тест ждал текст «Смотреть серию 1».
`direct_android_test.dart` теперь явно выбирает EpisodeCard с номером 1; проверки native качества,
позиции, перехода серии и серверных галочек сохранены. `LiveHarness.launch` восстанавливает
Flutter/platform error handlers тестового binding в finally после production runner, чтобы
framework failures завершали тест, а не скрывались logger. Production/UI код не менялся.

Доказательства находятся в ignored `build/verification/dto-refactoring/live-native-smoke/`:
`host-network.log`, `android-live-history-aware/summary.json`, `junit.xml`, `flutter.log`,
`regular-dev-apk.log`, `regular-dev-install.log`. Credentials, cookies и подписанные media URL
в документацию не включены; диагностические логи очищены от credentials и URL.

После поправок live-теста полный `bash scripts/check.sh` выполнен повторно: exit 0,
format 299 files / 0 changes, analyzer/DCM без замечаний, 376 unit/widget и 66 golden tests
passed. Лог — `live-native-smoke/check-after-smoke-fix.log`. Снимки в этом gate только
сравнивались; новых изменений baselines после согласованного обновления не было.
Затем выполнен `graphify update .`; результаты и проверка diff зафиксированы в
`live-native-smoke/final-audit.json`.

Требование Python ≥3.10 для E2E tooling добавлено в docs/05_development_and_testing.md.

## Дополнение: исправление extraction и полная пересборка graphify (2026-10-12)

По указанию пользователя граф пересобран целиком, включая semantic extraction всех
документов. Старые AST/semantic caches не использовались. Прежний граф и кеш сохранены
в ignored `build/verification/graphify-rebuild/`; итоговые счётчики — в `summary.json`.

Причины двух пустых endpoints и одиннадцати self-loops:

- HTML в triple-quoted Dart fixtures распознавался как variable declaration с пустым
  типом. Теперь поиск структуры использует маску строк и комментариев, сохраняя offsets;
  import URI и navigation literals по-прежнему извлекаются из оригинала.
- Шесть generated mixin references `$Route` сливались с одноимённым `Route` из-за
  нормализации ID и label matching. `$` теперь имеет отдельную идентичность.
- Пять Kotlin `super.method()` ошибочно указывали на override того же метода.
  `super` разрешается через локальные base classes; внешний FlutterActivity остаётся
  unresolved. Настоящие рекурсивные вызовы сохраняются.

Воспроизводимый version/SHA-256 guarded patch и installer находятся в
[`tool/graphify/`](../../tool/graphify/README.md). Патч применён к установленному
**graphifyy 0.9.85**, не к app source. После обновления инструмента его нужно проверить
заново. Семь regression tests падают на оригинальном инструменте и проходят на
исправленном; проверены также реальные fixtures/routes/MainActivity. E2E Python helpers
**38/38**, APK verifier **8/8** прошли с Python 3.12 в PATH; assertions не ослаблялись.

Raw extraction и итоговый graph.json имеют **0 пустых endpoints и 0 self-loops**.
В post-build также **0 dangling endpoints**. Raw audit отдельно показывает внешние
Python/Android imports до создания external stubs и объединение отношений/позиций
между одной парой узлов в simple undirected Graph. Исходные рёбра и позиции сохранены
в `extraction.json`; эти ограничения не объявляются устранёнными. Три Gradle Kotlin DSL
файла не дают symbols; исключения `.graphifyignore` сохранены. Dart extractor остаётся
regex-based. Семантика внешних веб-страниц не проверялась: извлечены только citations.

Смысловой разбор выполнялся текущей сессией: external API не использовался. Расход host
agent tokens не доступен через инструмент; значения 0 в fragments — placeholders схемы,
а не измеренный нулевой расход. Labels, report, graph.json и HTML генерируются заново.

При свежем чтении исправлены два устаревших активных описания: допустимое пустое
избранное в `docs/04_network_and_playback.md` и пути implementation/domain/providers
в watch-history spec. Исторические ссылки исходного плана оставлены как история.
Flutter/native app code и golden baselines в этом дополнении не менялись; последний
полный Flutter quality gate и live/native smoke описаны выше. Артефакты graphify,
regression logs до/после и health summaries: `build/verification/graphify-rebuild/`.
