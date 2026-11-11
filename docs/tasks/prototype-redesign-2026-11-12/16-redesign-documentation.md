# Спецификации и справочники описывают новый редизайн

- **ID:** redesign-documentation-16
- **Plan source:** `prototype-redesign-2026-11-12`, revision 3, [approved plan](<../../plans/prototype-redesign-2026-11-12.md>)
- **Covers capabilities:** CAP-08
- **Acceptance criteria:** —
- **Contribution to plan criteria:** AC-16
- **Purpose:** Functionality
- **Epic/Feature:** Редизайн AniStar TV по прототипу от 12 ноября 2026 года
- **Scope:** docs
- **Affected layers:** tests
- **Estimate:** 7–12 h
- **Parent task:** —
- **Depends on:** tv-watch-shortcut-13, mobile-shell-and-grids-15
- **Blocked by:** —

---

## 1. Context and expected outcome

Документы, ссылки и владельцы поведения соответствуют принятой ревизии.

## 2. Task scope (`implemented`)

1. Обновить `PRODUCT.md`, затронутые спецификации и их ссылки, README UI Kit и README нормализованных данных. Согласовать описание сетки и TV-ленты, Hero и места основного действия, данных автора/частей, сортировки, общего результата карточки и управления обоих профилей.
2. Сохранить feature-based CleanArch и TV-ориентир ADR-0008. Правило выбора серии принадлежит anime domain, TV-список вызывает его. ADR, карту ответственности и глоссарий уточнять там, где их текущий текст становится неверным. Сведения о командах и подтверждённых проверках сохранять на уровне, предусмотренном соответствующим руководством.

## 3. Deferred work (`deferred`)

—

## 4. Architectural context

- **Scope:** docs, PRODUCT.md и README затронутых пакетов.
- **Reuse:** Существующие спецификации владеют подробным поведением, справочники — терминами и владельцами. Сохранить структуру документов.
- **Critical decisions:**

  - D-09. Обновить экранные эталоны под новый дизайн и проверять все три логических размера TV 16:9. Заменить устаревшие ожидания после подтверждения покрытия новых состояний. Мобильные и компонентные снимки используют размеры своей сцены.

## 5. Verification and acceptance


Полные критерии проверяются в следующих задачах.

- AC-16. [Итоговая приёмка редизайна, регрессий и эталонов](20-redesign-final-verification.md).

### Local acceptance criteria

| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | global | Документы, ссылки и владельцы поведения соответствуют принятой ревизии. | Сверить изменения с AC-01–AC-17, владельцами и ссылками. Проверить, что новые и существующие ссылки ведут к актуальным контрактам, а описание TV-сетки, Hero и главного действия не противоречит ревизии 3. |

### QA checks after PR

- —

## 6. Designs, API and documentation

- **Contract type:** `none`
- **Figma:** —
- **Contract / API:** —
- **Data mode:** —
- **Documentation:** [Спецификация 01](<../../../docs/specs/01_authentication.md>), [Спецификация 02](<../../../docs/specs/02_favorites.md>), [Спецификация 03](<../../../docs/specs/03_page_loading.md>), [Спецификация 04](<../../../docs/specs/04_playback.md>), [Спецификация 05](<../../../docs/specs/05_mirrors.md>), [Спецификация 06](<../../../docs/specs/06_tv_interaction.md>), [Спецификация 07](<../../../docs/specs/07_watched_episodes.md>), [Спецификация 08](<../../../docs/specs/08_motion.md>), [Спецификация 09](<../../../docs/specs/09_catalog_filters.md>), [Спецификация 10](<../../../docs/specs/10_mobile_interaction.md>), [Спецификация 11](<../../../docs/specs/11_visual_system.md>), [Спецификация 12](<../../../docs/specs/12_anime_details.md>), [Спецификация 13](<../../../docs/specs/13_search.md>), [ADR-0008](<../../../docs/adr/0008-youtube-tv-interaction-reference.md>), [ADR-0010](<../../../docs/adr/0010-normalized-anistar-contract.md>), [UI Kit](<../../../lib/packages/ui_kit/README.md>), [Нормализованные данные AniStar](<../../../infrastructure/anistar/README.md>), [Команды Melos](<../../../docs/melos_tooling.md>), [Разработка и тестирование](<../../../docs/05_development_and_testing.md>), [Описание продукта](<../../../PRODUCT.md>), [Реестр спецификаций](<../../../docs/specs/README.md>), [Доменный глоссарий](<../../../docs/01_01_domain_glossary.md>), [Ответственность фич](<../../../docs/01_02_feature_responsibilities.md>).
