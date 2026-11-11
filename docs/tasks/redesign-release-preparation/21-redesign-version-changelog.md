# Повысить версию AniStar TV и описать выпуск с редизайном

- **ID:** redesign-version-changelog-21
- **Plan source:** [Редизайн AniStar TV, редакция 3](../../plans/prototype-redesign-2026-11-12.md), контекст выпуска. Задача добавлена отдельным поручением пользователя.
- **Covers capabilities:** —
- **Acceptance criteria:** —
- **Contribution to plan criteria:** —
- **Purpose:** Functionality
- **Epic/Feature:** Редизайн AniStar TV
- **Scope:** app
- **Affected layers:** —
- **Estimate:** 1–2 h
- **Parent task:** —
- **Depends on:** [redesign-final-verification-20](../prototype-redesign-2026-11-12/20-redesign-final-verification.md)
- **Blocked by:** Итоговая приёмка редизайна.

## 1. Context and expected outcome

После приёмки редизайна повысить версию приложения и добавить запись о выпуске в `CHANGELOG.md`. Запись отражает изменения, которые действительно вошли в принятый результат для TV и телефона.

## 2. Task scope (`implemented`)

1. Прочитать текущую версию командой `fvm dart run melos run version:show`. Выбрать уровень по [правилам версионирования](../../vcs_guidelines.md#2-единая-версия-приложения) и получить предварительный расчёт через `version:plan`. Для совместимого редизайна ориентир — `minor`. От `1.4.0+7` это дало бы `1.5.0+8`. При исполнении брать фактическую версию и проверять, что номер сборки растёт.
2. Проверить предварительный вывод `fvm dart run melos run version:set -- --app-version X.Y.Z --build-number N`. Записать выбранное значение той же командой с `--write` по поручению повысить версию. Источник версии — корневой `pubspec.yaml`.
3. Добавить новую секцию в `CHANGELOG.md` в существующем формате. Указать версию, дату выпуска и номер сборки. Составить список изменений по принятому результату задачи 20. Отдельно выделить заметные изменения для TV и телефона. Сверить формулировки с реализацией и результатами проверок.

## 3. Deferred work (`deferred`)

Коммит, тег, push и публикация выпуска относятся к отдельному поручению. Эта задача охватывает версию и changelog.

## 4. Architectural context

- **Scope:** [pubspec.yaml](../../../pubspec.yaml) и [CHANGELOG.md](../../../CHANGELOG.md).
- **Reuse:** Штатные команды Melos `version:show`, `version:plan`, `version:set` и `version:check`.
- **Constraints:** Одна версия `X.Y.Z+N` для Android и iOS. Версии workspace-пакетов остаются прежними.
- **Critical decisions:** Уровень повышения следует совместимости фактически поставленных изменений. Номер сборки строго растёт.
- **Verified facts and external conditions:** Подготовка начинается после принятия задачи 20.

## 5. Verification and acceptance

- **Verifiable outcome after PR:** `pubspec.yaml` и заголовок новой записи `CHANGELOG.md` указывают один выпуск, запись сверена с принятым редизайном.

### Local acceptance criteria

| ID | Applicability | Criterion | Verification |
| --- | --- | --- | --- |
| AC-01 | global | Корневая версия повышена по правилам проекта. Номер сборки больше предыдущего, версии workspace-пакетов прежние. | Сопоставить diff с предварительным выводом `version:set`. Выполнить `fvm dart run melos run version:show` и `fvm dart run melos run version:check --include-private`. |
| AC-02 | global | В changelog добавлена запись с той же версией и номером сборки. Она описывает фактически принятые изменения для TV и телефона. | Сверить запись с `pubspec.yaml`, итоговым diff и результатом задачи 20. Проверить `git diff --check`. |

### QA checks after PR

- [ ] При подготовке распространяемого APK проверить версию и номер сборки артефакта. Применить проверки актуального дерева по [правилам подготовки релиза](../../vcs_guidelines.md#4-подготовка-будущего-релиза).

## 6. Designs, API and documentation

- **Contract type:** `local_contract`
- **Figma:** —
- **Contract / API:** `version: X.Y.Z+N` в корневом `pubspec.yaml`.
- **Documentation:** [Git и версии](../../vcs_guidelines.md), [команды Melos](../../melos_tooling.md).
- **Data mode:** Принятый diff редизайна и свидетельства задачи 20.
