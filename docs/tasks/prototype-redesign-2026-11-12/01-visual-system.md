# Общие визуальные роли AniStar TV

- **ID:** visual-system-01
- **Plan source:** `prototype-redesign-2026-11-12`, revision 3, [approved plan](<../../plans/prototype-redesign-2026-11-12.md>)
- **Covers capabilities:** CAP-01
- **Acceptance criteria:** —
- **Contribution to plan criteria:** AC-01
- **Purpose:** Technical preparation
- **Epic/Feature:** Редизайн AniStar TV по прототипу от 12 ноября 2026 года
- **Scope:** ui_kit
- **Affected layers:** presentation, tests
- **Estimate:** 9–15 h
- **Parent task:** —
- **Depends on:** —
- **Blocked by:** —
- **Technical preparation — consumers (`consumers`):** shared-media-cards-02, tv-catalog-rail-04, anime-episodes-entry-06, search-query-results-09, access-and-tv-menu-10, native-player-episode-panel-14, mobile-shell-and-grids-15

---

## 1. Context and expected outcome

Общие компоненты сохраняют геометрию и различимый фокус в состояниях обоих профилей.

## 2. Task scope (`implemented`)

1. Применить к теме Manrope 400–800 и Lucide через `AppIcon` и `lucide_icons_flutter`. Использовать цвета фона `#101214`, поверхностей `#1b1e21` и `#2b3034`, границ `#394045`, текста `#f5f6f3` / `#b2b9bd`, акцента `#D986A6`, активного акцента `#E6A2BC` и текста на акценте `#24141C`.
2. Закрепить внутреннюю рамку 2 и свечение 12 цвета `#D986A633`. Карточки, фильтры и действия сохраняют геометрию при фокусе, служебные кнопки и меню имеют прозрачную рамку в покое. Состояния выбора и фокуса различимы. Подготовить общие роли кнопок, панелей и состояний загрузки, пустоты и ошибки с семантикой.
3. Согласовать общие токены движения handoff § 14. Фокус и масштаб 280/180 мс, меню и панели 240/156 мс, fast/standard/page 160/240/280 мс. При системном уменьшении движения состояние применяется без ожидания. Большой системный текст увеличивает элементы, визуальная высота метаданных 36 допускает цель касания 48 без перекрытия. Применить кривые входа cubic-bezier(0.215,0.61,0.355,1) и выхода cubic-bezier(0.55,0.055,0.675,0.19) по ролям handoff § 14.

## 3. Deferred work (`deferred`)

—

## 4. Architectural context

- **Scope:** lib/packages/ui_kit.
- **Reuse:** Публичный `ui_kit.dart`, `AppIcon` и существующие роли темы/фокуса. Сетевые операции и состояние доступа принадлежат фичам.
- **Critical decisions:**

  - D-01. Применить визуальные роли handoff через общий UI Kit и определять нативный профиль по устройству. Размеры служат ориентирами в logical pixels. Крупный текст сохраняет действия без обрезки. У визуальных 36 для метаданных область касания 48 без пересечения соседних целей. Дополнительной внешней рамки у ролей из handoff нет.
  - D-07. Использовать действующие контракты доступа, поиска, избранного и плеера. Минимум поиска 2, порция из четырёх, 19/29 записей, специальные слова, искусственные ошибки и тестовое видео принадлежат демонстрации.

## 5. Verification and acceptance

- [ ] При изменении ассетов или списка шрифтов выполнить из корня `fvm dart run melos run generate` последовательно с другими командами. Проверить изменения сгенерированных файлов.
- [ ] Для изменений Dart выполнить применимые проектные проверки последовательно: `fvm dart run melos run analyze`, `fvm dart run melos run dcm`, `fvm dart run melos run format:check`.

Полные критерии проверяются в следующих задачах.

- AC-01. [Итоговая приёмка редизайна, регрессий и эталонов](20-redesign-final-verification.md).

### Local acceptance criteria

| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | global | Общие компоненты сохраняют геометрию и различимый фокус в состояниях обоих профилей. | Компонентные проверки обычного, сфокусированного, выбранного и недоступного состояния, неизменности геометрии, текста 200%, семантики и reduced motion в обоих профилях. |

### QA checks after PR

- —

## 6. Designs, API and documentation

- **Contract type:** `local_contract`
- **Figma:** —
- **Contract / API:** Публичные токены темы и визуальные компоненты с данными состояния и callbacks.
- **Data mode:** —
- **Documentation:** [Handoff прототипа](<../../../prototype/DESIGN-HANDOFF.md>), [Спецификация 08](<../../../docs/specs/08_motion.md>), [Спецификация 11](<../../../docs/specs/11_visual_system.md>), [ADR-0008](<../../../docs/adr/0008-youtube-tv-interaction-reference.md>), [UI Kit](<../../../lib/packages/ui_kit/README.md>).
