# Общие карточки аниме и серий

- **ID:** shared-media-cards-02
- **Plan source:** `prototype-redesign-2026-11-12`, revision 3, [approved plan](<../../plans/prototype-redesign-2026-11-12.md>)
- **Covers capabilities:** CAP-01, CAP-06
- **Acceptance criteria:** —
- **Contribution to plan criteria:** AC-02
- **Purpose:** Technical preparation
- **Epic/Feature:** Редизайн AniStar TV по прототипу от 12 ноября 2026 года
- **Scope:** ui_kit
- **Affected layers:** presentation, tests
- **Estimate:** 7–12 h
- **Parent task:** —
- **Depends on:** visual-system-01
- **Blocked by:** —
- **Technical preparation — consumers (`consumers`):** tv-catalog-rail-04, anime-episodes-entry-06, search-query-results-09, confirmed-favorites-11, native-player-episode-panel-14, mobile-shell-and-grids-15

---

## 1. Context and expected outcome

Карточки используют одни визуальные правила при разных данных и размерах контейнера.

## 2. Task scope (`implemented`)

1. Карточка аниме целиком активируется коротким OK, касанием и semantic tap. Постер обрезается по центру, название внизу до двух строк. Заглушка сохраняет размеры при загрузке и ошибке изображения. Размер карточки и обработка навигации остаются у контейнера.
2. Рейтинг без шкалы виден на TV и мобильной главной при наличии оценки. Размер текста 16 на TV и 14 на телефоне, иконка 16, отступы 4×8, зазор 4 и inset 8. Плашки используют подложку 64% с непрозрачными текстом и иконками. Подтверждённая закладка пассивна, скрыта у гостя и в избранном. Неизвестное поле пропускается. Семантическая подпись включает видимые метки.
3. Карточка серии показывает номер один раз, самостоятельное название, превью или заглушку и подтверждённую галочку. Текущая серия, фокус и просмотренность различимы. Открытие серии вызывается через callback владельца. Одинаковые номера не дублируются в видимой и семантической подписях: название «Серия N» после нормализации регистра и пробелов уже представлено номером. Семантика сообщает подтверждённый просмотр.

## 3. Deferred work (`deferred`)

—

## 4. Architectural context

- **Scope:** lib/packages/ui_kit.
- **Reuse:** Публичные элементы UI Kit принимают только визуальные поля, состояния и callbacks.
- **Critical decisions:**

  - D-01. Применить визуальные роли handoff через общий UI Kit и определять нативный профиль по устройству. Размеры служат ориентирами в logical pixels. Крупный текст сохраняет действия без обрезки. У визуальных 36 для метаданных область касания 48 без пересечения соседних целей. Дополнительной внешней рамки у ролей из handoff нет.

## 5. Verification and acceptance

- [ ] Для изменений Dart выполнить применимые проектные проверки последовательно: `fvm dart run melos run analyze`, `fvm dart run melos run dcm`, `fvm dart run melos run format:check`.

Полные критерии проверяются в следующих задачах.

- AC-02. [Мобильная навигация, сетки, заголовки и жесты](15-mobile-shell-and-grids.md).

### Local acceptance criteria

| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | global | Карточки используют одни визуальные правила при разных данных и размерах контейнера. | Widget-проверки обоих профилей для отсутствующих данных и изображений, ролей гостя и аккаунта, фокуса и активации всей поверхности. Проверить полупрозрачность на стабильном текстурном изображении. |

### QA checks after PR

- —

## 6. Designs, API and documentation

- **Contract type:** `local_contract`
- **Figma:** —
- **Contract / API:** Проекция данных `AnimeSummary` и серий на общие карточки через параметры отображения.
- **Data mode:** —
- **Documentation:** [Handoff прототипа](<../../../prototype/DESIGN-HANDOFF.md>), [Спецификация 06](<../../../docs/specs/06_tv_interaction.md>), [Спецификация 10](<../../../docs/specs/10_mobile_interaction.md>), [Спецификация 11](<../../../docs/specs/11_visual_system.md>), [ADR-0008](<../../../docs/adr/0008-youtube-tv-interaction-reference.md>), [UI Kit](<../../../lib/packages/ui_kit/README.md>).
