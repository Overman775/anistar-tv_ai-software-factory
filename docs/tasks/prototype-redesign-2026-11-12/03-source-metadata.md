# Исходные метаданные для выдачи и карточки

- **ID:** source-metadata-03
- **Plan source:** `prototype-redesign-2026-11-12`, revision 3, [approved plan](<../../plans/prototype-redesign-2026-11-12.md>)
- **Covers capabilities:** CAP-02, CAP-04, CAP-05
- **Acceptance criteria:** —
- **Contribution to plan criteria:** AC-03, AC-10
- **Purpose:** Technical preparation
- **Epic/Feature:** Редизайн AniStar TV по прототипу от 12 ноября 2026 года
- **Scope:** anistar
- **Affected layers:** api, data, domain, tests
- **Estimate:** 8–15 h
- **Parent task:** —
- **Depends on:** —
- **Blocked by:** —
- **Technical preparation — consumers (`consumers`):** tv-catalog-rail-04, author-filter-sorting-07, anime-disclosure-navigation-08

---

## 1. Context and expected outcome

Выдача и карточка получают типизированные метаданные с исходными подписями и поддерживаемыми путями.

## 2. Task scope (`implemented`)

1. Довести до нормализованных summary и доменных моделей доступные исходные строки формата и числа серий, озвучку, пригодные ссылки жанров и текст обновления. В details довести автора и его пригодную ссылку, исходную дату и связанные части с полными подписями, исходным порядком и надёжно извлечёнными ID.
2. Проверять ссылки для текущего origin и поддерживаемого пути. Сохранять CP1251 percent-encoding и `+`, подписи и исходные строки `.date-icon` и `.reason` без пересчёта часового пояса. При отсутствии пригодного пути сохранять текст. Дополнительные поля nullable для старых DTO, кешированных записей и существующих тестовых источников. Фактические доступные серии подтверждает playlist.

## 3. Deferred work (`deferred`)

—

## 4. Architectural context

- **Scope:** infrastructure/anistar.
- **Reuse:** `AnistarClient`, HTML-адаптер, DTO и существующее отображение catalog/anime. DTO преобразуются в Feature Data, ошибки идут через `BaseRepository` и `Result`/`Failure`.
- **Critical decisions:**

  - D-02. Объединить TV-выдачи в одну композицию и сохранить плитки выбора жанров. Лента сохраняет положение при изменении сведений и раскрытии меню. Действия привязаны к актуальному выбору.
  - D-05. Сведения и серии образуют одну загрузку и один результат. Общий отказ даёт повтор и возврат. В mobile refresh ранее загруженное содержимое сохраняется по текущему контракту.
  - D-06. Открывать выдачу автора по пригодной ссылке сайта. Строка и переход «Манга» исключены. Автор без пригодной ссылки остаётся текстом. Изменения маршрутов и парсинга ограничены автором и данными согласованных поверхностей.

## 5. Verification and acceptance

- [ ] Для изменений Dart выполнить применимые проектные проверки последовательно: `fvm dart run melos run analyze`, `fvm dart run melos run dcm`, `fvm dart run melos run format:check`.

Полные критерии проверяются в следующих задачах.

- AC-03. [Пульт и восстановление контекста четырёх TV-выдач](12-tv-source-navigation.md).
- AC-10. [Подробности аниме, переходы по метаданным и частям](08-anime-disclosure-navigation.md).

### Local acceptance criteria

| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | global | Выдача и карточка получают типизированные метаданные с исходными подписями и поддерживаемыми путями. | HTML-фикстуры и проверки отображения через domain-модели с полными, частичными и отсутствующими полями, внешними и неподдерживаемыми путями, точным кодированием и порядком частей. |

### QA checks after PR

- —

## 6. Designs, API and documentation

- **Contract type:** `backend_api`
- **Figma:** —
- **Contract / API:** Нормализованные summary/details, `.date-icon`, `.reason`, ID и путь текущего origin. Исходное кодирование ссылки сохраняется.
- **Data mode:** HTML/HTTP-фикстуры
- **Documentation:** [Handoff прототипа](<../../../prototype/DESIGN-HANDOFF.md>), [Спецификация 03](<../../../docs/specs/03_page_loading.md>), [Спецификация 09](<../../../docs/specs/09_catalog_filters.md>), [Спецификация 12](<../../../docs/specs/12_anime_details.md>), [ADR-0010](<../../../docs/adr/0010-normalized-anistar-contract.md>), [Нормализованные данные AniStar](<../../../infrastructure/anistar/README.md>).
