# Factory Planning Plan Contract

Canonical contract for `.ai-pipeline/staging/planning-plan.md` and
`docs/plans/{plan_id}.md`. Plan is developer map, not evidence warehouse and not
ticket backlog.

## Ownership

Planning owns:

- goal, observable outcome, scope, non-goals;
- stable capabilities/requirements (`CAP-{NN}`);
- main behavior and meaningful exceptions;
- solution shape, ownership, behavior-shaping contract gist;
- decisions, unknowns, risks, developer readiness, QA intent;
- handoff recommendation.

Planning does not own task/slice IDs, task purpose, owning scope, affected
layers, estimates, dependency graph, implementation/deferred task fields, or
publication ID. `factory-decompose` derives these later without changing approved
semantics. `factory-implement` may execute any approved plan after explicit user
choice or pre-authorized delegated continuation, even when recommendation is
`decompose`; report size/risk warning.

Never use future task/slice IDs in plan applicability or structure.

Plan content is the durable semantic layer. If information must remain true
after internal refactoring, keep it here. Task-local delivery detail belongs to
Factory Decompose; checkout-current paths, symbols, edit order, and commands belong to
Factory Implement execution preparation. A plan-only request stops without current
implementation-detail lookup.

## Metadata and State

Use exactly these metadata keys:

```text
plan_id: stable-kebab-case-id
revision: 1
plan_state: PLAN_READY
status: draft | approved
approved_revision: none | N
source: request | spec | local | mixed
handoff_recommendation: direct | decompose | either
```

No question budgets, counters, publication metadata, task counts, or estimates.

Only a complete preflight-clean plan becomes a user-reviewable revision.
Unresolved decisions, blockers, and recursive questions remain in
`.ai-pipeline/staging/planning-session.md` and must not replace the last
presented revision.

Approval invariants:

- user-reviewable draft requires `PLAN_READY`, `status: draft`, and
  `approved_revision: none`;
- approved requires `PLAN_READY`, `status: approved`, and
  `approved_revision == revision`;

Approval authorization has two forms:

- exact approval of presented revision `N`;
- explicit delegated planning captured before discovery, allowing planner to
  settle and approve a preflight-clean revision without another checkpoint.

Keep metadata unchanged. For delegated planning, record human-readable evidence
under `Источник и контекст` as
`Авторизация планирования: explicit_user_delegation — "{exact directive}"`. This
distinguishes delegation from exact revision review without adding machine
contract fields.

First candidate promoted as reviewable plan is revision `1`. Normal mode
presents it; delegated planning proceeds to approval without pause. Before that
promotion, question answers, semantic candidate rewrites, preflight returns,
and machine-only repairs consume no revision. After promotion, semantic
change increments exactly once and resets approval. Semantic changes include
behavior, scope, outcome, solution shape, decision, contract gist, boundary,
readiness, verification, source conclusion, or handoff recommendation.
Formatting, spelling, URL normalization, and machine-only repair without
changed meaning keep revision and approval state. Approved durable file is
immutable; a later semantic change starts next draft revision in staging.

## Reality Check Taxonomy

Use `INFO | ASK | BLOCK` internally. Present only resulting decisions and
unknowns, not a second Reality Check report.

Working-session statuses:

- `USER_DECISION`: pending choice kept in session until resolved;
- `BLOCK`: required fact/decision preventing a ready plan.

Working-session provenance may distinguish user-confirmed, evidence-backed
default, and explicitly AI-delegated choices. The reviewable plan does not
expose a decision-status state machine: approval authorizes the complete settled
revision either exactly or through recorded advance delegation.

Evidence levels:

- `official_fact`: specification, official API/platform documentation;
- `user_acceptance_observation`: user-confirmed expected behavior or observed
  acceptance evidence;
- `project_fact`: repository, project docs, current runtime evidence;
- `inference`: explicit reasoning, convention, or assumption.

Use evidence levels for facts in solution/evidence and for working-session
provenance. Never present inference as fact. Explicit planning delegation may
settle behavior, UI/design, app-owned API/architecture, scope, and technical
choices inside requested outcome. It cannot fabricate backend/external facts,
credentials, legal/compliance or security approval, or justify weaker
protection. Prefer safe, reversible, evidence-backed choices.

Reviewable-plan item ownership:

- `D-{NN}`: a settled choice changing behavior, scope, ownership, or a material
  constraint. Decision row contains final choice, reason, applicability, and
  verification/constraint.
- Source/project facts: live in `Как устроено решение` or
  `Контракт и подтверждение`;
  they do not receive `D-*` IDs merely to prove the plan was researched.
- `EXT-{NN}`: unresolved externally owned fact/dependency with owner and
  handling, declared only in `Неизвестное и границы`.
- Research result: describe under research/timebox; unresolved research gets
  explicit handling there, not a decision status.
- Out-of-scope boundary: state under `Не входит` or boundaries, not as a
  decision row.

Split partially resolved external facts: resolved part becomes ordinary fact;
unresolved subfact keeps its own `EXT-{NN}` and handling.

## Human-first Rules

Headings and ordinary prose are Russian; exact identifiers, machine values,
paths, commands, API/product names, and established abbreviations stay intact.
Translate generic English when technical identity survives: `owner` ->
«владелец», `request/response` -> «запрос/ответ», `success/failure` ->
«успех/ошибка». State words such as `loading/error/retry/empty`, `open/close`,
and `existing/missing` are ordinary prose unless they are exact identifiers.
Translatable generic English prose is a preflight defect. Run one wording pass
on the rendered candidate only; do not count language ratios, maintain a
glossary, or search code solely for wording.

Mandatory H2 sections are exact and ordered:

1. `## Что меняем`
2. `## Как будет работать`
3. `## Как устроено решение`
4. `## Ключевые решения`
5. `## Неизвестное и границы`
6. `## Готовность и проверка`
7. `## Передача дальше`

First three let developer understand plan without reading evidence trail.

- Name problem, outcome, in-scope capabilities, and non-goals concretely.
- Give one numbered primary flow. Add a compact exception/decision table when
  flow branches; do not bury branches in prose.
- Describe component responsibility and ownership before paths/symbols.
- Exact files/classes/methods are optional and only decision-critical.
- Give each capability a stable execution seed: observable behavior, owner,
  behavior-shaping boundary, applicable states/effects, constraints, and
  acceptance. Do not turn that seed into an implementation inventory.
- Current code anchors may appear as evidence-backed references when they decide
  architecture or compatibility. Names that only help locate code downstream
  stay out of the durable plan.
- Earlier sections describe resulting behavior and ownership. Keep decision
  reason/evidence once in `Ключевые решения`; reference `D-{NN}` where useful
  instead of copying its rationale.
- When no settled choice changes behavior, scope, ownership, or constraints,
  write exactly `- Существенных решений нет.` under `Ключевые решения`. Do not
  manufacture a decision from a source fact or implementation detail.
- Keep full API/platform fingerprint internal. Plan shows only fields,
  callbacks, payload, key, or local contract details changing behavior.
- Do not optimize for a fixed word count. Large sources may require large plans;
  remove repetition, evidence dumps, and non-decision implementation detail.

Section-role deduplication map:

- `Что меняем`: problem, outcome, scope, and non-goals; no decision rationale.
- `Как будет работать`: sequence and branches; reference `D-*` without retelling
  why the choice was made.
- `Как устроено решение`: responsibility, ownership boundary, and contract gist;
  its `Почему` cell explains component placement, not the full decision history.
- `Ключевые решения`: the single full statement and rationale for each choice.
- `Неизвестное и границы`: only unresolved external facts, research handling,
  and risks; do not restate settled decisions.
- Developer acceptance: observable deterministic outcomes, without rationale or
  device/integration matrix. QA: runtime, device, and integration evidence only.
- When an `EXT-*` prevents implementation of named capabilities, add a compact
  readiness matrix under `Приёмка разработчиком и готовность`: capability,
  current readiness, and exact start condition. This makes `PLAN_READY` mean
  "semantic map is ready" without pretending all development can start.
  External items that affect only QA/release do not require the matrix; state
  that boundary in one sentence instead. Do not add readiness tables by quota.

A short repeated guard condition is allowed when a flow or check would otherwise
be ambiguous. Do not copy the full rationale, source trail, or risk explanation
across sections. Deduplicate semantically; never use word count or text-similarity
thresholds as a quality gate.

Pseudocode is optional. Use only when state machine, reducer, schema, or
algorithm is clearer than prose. Put it under `### Псевдокод поведения` in a
`text` fence, 5–12 natural-language lines. Describe states and decisions; no
production Dart, method bodies, imports, braces, semicolons, or code syntax.

## API Evidence

Every plan has compact contract/evidence table in `Как устроено решение`:

```markdown
### Контракт и подтверждение
| Применимость | Тип контракта | Поведенчески значимая суть | Подтверждение |
| :--- | :--- | :--- | :--- |
| CAP-01 | backend_api | `status` меняет доступное действие | official_fact: URL Swagger |
| CAP-01, CAP-03 | local_contract | Общий результат меняет оба экрана | project_fact: контракт координатора |
| CAP-02 | external_contract | Правила провайдера ограничивают сценарий | official_fact: документация провайдера |
| global | none | Внешний контракт не участвует | project_fact: текущий сценарий |
```

Allowed types:

- `backend_api`;
- `platform_plugin_api`;
- `storage`;
- `local_contract`;
- `external_contract`;
- `none`.

Use `external_contract` for behavior-shaping rules owned by an external service,
provider, SDK vendor, or integration specification when they are not a backend
endpoint contract or platform/plugin API.

`none` is explicit evidence classification, not missing analysis. Fingerprint
may live in optional internal evidence but never becomes mandatory plan bulk.
`Применимость` accepts `global` or a comma-separated list of declared `CAP-*`
IDs. Combine capabilities when one evidence statement is genuinely shared; do
not duplicate a row only to satisfy formatting. Every declared capability must
be covered by at least one typed row; `global` covers all capabilities and
`none` is valid explicit coverage.

## Working Session and Questions

Use [Factory Planning Working Session](session-contract.md) before creating or
revising a user-reviewable plan. Active questions, `USER_DECISION`, `BLOCK`,
contradictions, and answer-impact history stay there; they are discovery state,
not canonical plan content. Promote only after its exit criteria hold and both
semantic and deterministic preflight pass.

## Canonical Template

````markdown
# План: {краткое название}
plan_id: {stable-kebab-case-id}
revision: {N}
plan_state: PLAN_READY
status: draft | approved
approved_revision: {none | N}
source: request | spec | local | mixed
handoff_recommendation: direct | decompose | either

## Что меняем
- Проблема/цель:
- Наблюдаемый результат:
- Входит:
  - CAP-01 — {целостная возможность или требование}.
- Не входит:
- Источник и контекст:
- Авторизация планирования: {ожидает подтверждения редакции | `explicit_user_delegation` — "точная фраза пользователя"}.

## Как будет работать
### Основной поток
1. {Действие/состояние пользователя или системы}.
2. {Следующее наблюдаемое поведение}.

### Исключения и развилки
| Условие | Поведение | Связанное решение |
| :--- | :--- | :--- |
| ... | ... | D-01 |

### Псевдокод поведения
```text
Необязательные 5–12 строк естественного языка только когда яснее прозы.
```

## Как устроено решение
| Область/владелец | Ответственность и изменение | Почему | Решение |
| :--- | :--- | :--- | :--- |
| ... | ... | ... | D-01 |

### Контракт и подтверждение
| Применимость | Тип контракта | Поведенчески значимая суть | Подтверждение |
| :--- | :--- | :--- | :--- |
| CAP-01 | local_contract | ... | `project_fact`: ... |

## Ключевые решения
| ID | Решение | Почему | Применимость | Проверка/ограничение |
| :--- | :--- | :--- | :--- | :--- |
| D-01 | ... | ... | CAP-01, CAP-03 | ... |

`Применимость`: перечисленные через запятую объявленные `CAP-{NN}` либо
`global`, но не будущие ID задач. Факты и внешние зависимости не становятся
строками решений.

Если существенных решений нет, замените таблицу на:

```markdown
- Существенных решений нет.
```

В таком случае используйте `—` в предыдущих ячейках `Связанное решение` и
`Решение`. Каждый упомянутый `D-*` должен иметь одну объявленную строку решения.

## Неизвестное и границы
- Внешние зависимости и обработка:
  - EXT-01 — {внешний владелец и недостающий факт}; обработка: {что, кем и когда проверяется}.
- Исследование, ограничение по времени и результат:
- Риски:

## Готовность и проверка
### Приёмка разработчиком и готовность
- Приёмка:
- Готовность:

{Опционально, когда внешние зависимости задерживают реализацию:}

| Возможность | Текущая готовность | Условие старта |
| :--- | :--- | :--- |
| CAP-01 | Частично готово | Контракт EXT-01 опубликован |

### Проверки QA
- {Наблюдаемая пользовательская/интеграционная проверка}.

## Передача дальше
- Рекомендация: `direct | decompose | either`.
- Почему:
- Что получает следующий этап:
- Предупреждение/условия:
- Продолжение: {ожидает выбора пользователя | заранее разрешённое прямое выполнение | заранее разрешённый декомпоз | только план}.
- Рекомендация сама по себе не является авторизацией.
````

Omit optional pseudocode. Do not rename or omit mandatory H2 sections. A
presented plan contains no active question subsection, `USER_DECISION`, or
`BLOCK`; those remain in planning session until resolved.
Pre-authorized continuation requires recorded `explicit_user_delegation` plus
the matching original downstream request; otherwise use `ожидает выбора
пользователя` or `только план`.

## Transactional Persistence and Approval

For first revision candidate, later revision, or approval candidate:

1. Render complete temporary sibling; run semantic preflight, then validator.
2. A semantic gap returns to working session without replacing target or
   consuming revision. Repair machine-only defects without user approval.
3. Validate the temporary candidate, never live target. After first promotion,
   pass `--previous` for revision, approval-only, and nonsemantic transitions.
4. Flush when supported; atomically replace only after both checks pass. Keep
   previous valid target/checkpoint after failure or interruption.

Never use destructive cleanup. Cancel stops work and reports retained session
and plan paths. Normal approval is exact `Подтвердить revision N`; discovery
answers are not approval. Explicit delegated planning recorded before discovery
is advance authorization, not exact revision review. Approval-only metadata
transition does not increment revision. Both paths use same approval candidate;
approval candidate must differ only in approval metadata from validated draft.

`handoff_recommendation` advises. Without pre-authorization, user chooses
`factory-implement` direct execution or `factory-decompose` after durable approval. With an
original explicit implementation/decomposition request plus delegated planning,
parent orchestrator may continue requested handoff automatically; Factory Planning
itself never launches downstream.

Both downstream paths may apply the shared implementation-detail contract
without a new semantic approval. Factory Decompose adds slice-relevant anchors to task
Markdown; Factory Implement records checkout-current anchors in `execution-brief.md`.
Neither consumer changes approved behavior when current code placement differs.

## Quality Bar

- Plan can be read top-to-bottom once; first three sections explain feature.
- Every capability is semantically executable either directly or after task
  slicing, without requiring exact current file or symbol names.
- Main flow is numbered; branches use decision table when meaningful.
- No fake precision: task IDs, estimates, dependency graph, or file inventory.
- Every unknown has owner/handling; every readiness claim is observable.
- Every declared `CAP-*` has typed contract coverage; every `EXT-*` names its
  owner or missing fact and has explicit non-empty `обработка:`.
- A developer-blocking `EXT-*` maps to affected `CAP-*` readiness and an exact
  start condition; QA/release-only externals do not force a ceremonial matrix.
- No unresolved decision, contradiction, active question, or blocking fact is
  hidden inside a presented revision.
- `Приёмка разработчиком и готовность` is separate from `Проверки QA`.
- Every `D-*` is a real choice; facts stay in solution/evidence and every
  referenced `EXT-*` has one boundary declaration with handling.
- Architecture and ownership satisfy full canonical architecture sources; they
  are never reduced to a feature-code guess.
- Each section has a distinct job: rationale is not copied across flow,
  solution, decisions, acceptance, and QA. No fixed word-count target applies.
- No `TBD`, hidden requirements, copied full Swagger response, implementation,
  test execution, task publishing, decomposition, or downstream launch.
