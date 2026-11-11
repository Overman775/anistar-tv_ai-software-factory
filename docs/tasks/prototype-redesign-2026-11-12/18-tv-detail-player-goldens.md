# TV-эталоны карточки аниме, плеера и боковых панелей

- **ID:** tv-detail-player-goldens-18
- **Plan source:** `prototype-redesign-2026-11-12`, revision 3, [approved plan](<../../plans/prototype-redesign-2026-11-12.md>)
- **Covers capabilities:** CAP-08
- **Acceptance criteria:** —
- **Contribution to plan criteria:** AC-16, AC-17
- **Purpose:** Functionality
- **Epic/Feature:** Редизайн AniStar TV по прототипу от 12 ноября 2026 года
- **Scope:** anime
- **Affected layers:** tests
- **Estimate:** 8–14 h
- **Parent task:** —
- **Depends on:** tv-watch-shortcut-13, mobile-shell-and-grids-15
- **Blocked by:** —

---

## 1. Context and expected outcome

Карточка, панели и плеер имеют проверенные TV-эталоны и замены устаревших сцен.

## 2. Task scope (`implemented`)

1. До обновления зафиксировать тест-владелец, сцену, логический размер, DPR, масштаб текста и решение по каждому затронутому эталону. На 960×540, 1280×720 и 1920×1080 logical px с DPR 1 и явным TV-профилем покрыть свёрнутую и раскрытую карточку, характерные боковые панели и управление плеером. Сохранить компактное нативное окно.
2. Сохранить аниме и плотные ошибки при 100% и 200% для 960×540 и 1280×720, общий отказ с повтором, длинный заголовок, отсутствие изображения/метаданных, гостя и аккаунт, текущую и просмотренную серии, выбор отдельно от фокуса и reduced motion, где он влияет на вид. Для общего файла теста согласовать владельца с задачами соседних сцен до обновления.
3. Выборочно обновить сцены и просмотреть каждый PNG и дифф. После подтверждения замены убрать старые эталоны раскрытой при входе карточки и Hero с устаревшими ожиданиями, дубли и осиротевшие файлы в затронутой области. Действующие проверки фокуса, возврата и плеера сохранить. Передать выборочные пути тестов или `ANISTAR_TEST_SELECTORS_JSON` в `fvm dart run melos run test:goldens:update`. Повторить `fvm dart run melos run test:goldens` с тем же набором без обновления и зафиксировать выполненные тесты.

## 3. Deferred work (`deferred`)

—

## 4. Architectural context

- **Scope:** test/app и test/packages/features/{anime,player}.
- **Constraints:** Перед записью согласовать с задачами 17–19 одного владельца для каждого общего файла теста или PNG. Совместные записи и Flutter-команды выполнять последовательно.
- **Reuse:** Viewport harness, существующие тесты аниме и общие сцены редизайна.
- **Critical decisions:**

  - D-09. Обновить экранные эталоны под новый дизайн и проверять все три логических размера TV 16:9. Заменить устаревшие ожидания после подтверждения покрытия новых состояний. Мобильные и компонентные снимки используют размеры своей сцены.

## 5. Verification and acceptance

- [ ] Для изменений Dart выполнить применимые проектные проверки последовательно: `fvm dart run melos run analyze`, `fvm dart run melos run dcm`, `fvm dart run melos run format:check`.

Полные критерии проверяются в следующих задачах.

- AC-16, AC-17. [Итоговая приёмка редизайна, регрессий и эталонов](20-redesign-final-verification.md).

### Local acceptance criteria

| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | global | Карточка, панели и плеер имеют проверенные TV-эталоны и замены устаревших сцен. | Сверить покрытие до и после и повторить сравнение без режима обновления. Widget/E2E подтверждают фокус, навигацию и нативный плеер отдельно от PNG. |

### QA checks after PR

- —

## 6. Designs, API and documentation

- **Contract type:** `local_contract`
- **Figma:** —
- **Contract / API:** Явный TV-профиль, logical px, DPR 1 и тексты согласованного масштаба.
- **Data mode:** Локальные визуальные фикстуры
- **Documentation:** [Handoff прототипа](<../../../prototype/DESIGN-HANDOFF.md>), [Спецификация 04](<../../../docs/specs/04_playback.md>), [Спецификация 06](<../../../docs/specs/06_tv_interaction.md>), [Спецификация 08](<../../../docs/specs/08_motion.md>), [Спецификация 11](<../../../docs/specs/11_visual_system.md>), [Спецификация 12](<../../../docs/specs/12_anime_details.md>), [ADR-0008](<../../../docs/adr/0008-youtube-tv-interaction-reference.md>), [Команды Melos](<../../../docs/melos_tooling.md>), [Разработка и тестирование](<../../../docs/05_development_and_testing.md>).
