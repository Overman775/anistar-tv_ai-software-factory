import sys
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from validate_plan import semantic_normal_form, validate  # noqa: E402


PLAN = """# План: Доверенный центр сертификации для платёжной WebView
plan_id: payment-webview-trusted-ca
revision: 1
plan_state: PLAN_READY
status: draft
approved_revision: none
source: spec
handoff_recommendation: direct

## Что меняем
- Проблема/цель: разрешить доверенный центр сертификации только платёжной WebView.
- Наблюдаемый результат: платёж открывается при корректной цепочке.
- Входит:
  - CAP-01 — проверка сертификата, ограниченная платформенным контекстом.
- Не входит: изменение всех WebView.
- Источник и контекст: локальная спецификация.

## Как будет работать
### Основной поток
1. Платёжная WebView начинает загрузку разрешённого хоста.
2. Платформа проверяет сертификат по выбранному контракту доверия.
3. Успешная проверка продолжает загрузку, ошибка останавливает её.

### Исключения и развилки
| Условие | Поведение | Связанное решение |
| :--- | :--- | :--- |
| Неизвестный хост | Особая проверка доверия не применяется | D-01 |

## Как устроено решение
| Область/владелец | Ответственность и изменение | Почему | Решение |
| :--- | :--- | :--- | :--- |
| Платформенная граница | Изолирует особую проверку доверия платёжным контекстом | Не расширять доверие глобально | D-01 |

### Контракт и подтверждение
| Применимость | Тип контракта | Поведенчески значимая суть | Подтверждение |
| :--- | :--- | :--- | :--- |
| CAP-01 | platform_plugin_api | Хост и сертификат участвуют в нативной проверке | `official_fact`: API платформы |

## Ключевые решения
| ID | Решение | Почему | Применимость | Проверка/ограничение |
| :--- | :--- | :--- | :--- | :--- |
| D-01 | Особая проверка доверия ограничена платёжным хостом | Не расширять доверие обычных WebView | CAP-01 | Неизвестный хост отклоняется |

## Неизвестное и границы
- Внешние зависимости и обработка: отсутствуют.
- Исследование, ограничение по времени и результат: не требуется.
- Риски: случайное расширение особой проверки доверия.

## Готовность и проверка
### Приёмка разработчиком и готовность
- Приёмка: разрешённый хост открывается, неизвестный не получает особую проверку доверия.
- Готовность: решение и платформенная граница определены.

### Проверки QA
- Проверить успешный платёжный хост и ошибку неизвестного хоста.

## Передача дальше
- Рекомендация: `direct`.
- Почему: одна возможность и стабильная граница.
- Что получает следующий этап: утверждённый смысловой план.
- Предупреждение/условия: платформенные проверки обязательны.
- Продолжение: ожидает выбора пользователя.
- Рекомендация сама по себе не является авторизацией.
"""


class ValidatePlanTest(unittest.TestCase):
    def codes(self, text: str, phase: str = "draft", previous: str | None = None):
        return {item["code"] for item in validate(text, phase=phase, previous_text=previous)}

    def test_valid_draft_passes(self):
        self.assertEqual([], validate(PLAN))

    def test_valid_approved_plan_passes(self):
        approved = PLAN.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        self.assertEqual([], validate(approved, phase="approved", previous_text=PLAN))

    def test_delegated_authorization_uses_same_approval_transition(self):
        delegated = PLAN.replace(
            "- Источник и контекст: локальная спецификация.",
            "- Источник и контекст: локальная спецификация.\n"
            "- Авторизация планирования: explicit_user_delegation — \"решай сам\".",
        )
        self.assertEqual([], validate(delegated))
        approved = delegated.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        self.assertEqual(
            [], validate(approved, phase="approved", previous_text=delegated)
        )

    def test_required_headings_are_exact_and_ordered(self):
        broken = PLAN.replace("## Что меняем", "## Картина за минуту")
        self.assertIn("HEADINGS_INVALID", self.codes(broken))

    def test_metadata_is_minimal_and_handoff_is_typed(self):
        broken = PLAN.replace("revision: 1", "revision: 1\nquestion_budget_total: 3")
        broken = broken.replace("handoff_recommendation: direct", "handoff_recommendation: tickets")
        codes = self.codes(broken)
        self.assertIn("FORBIDDEN_METADATA", codes)
        self.assertIn("HANDOFF_INVALID", codes)

    def test_capabilities_are_declared_and_references_resolve(self):
        missing = PLAN.replace(
            "  - CAP-01 — проверка сертификата, ограниченная платформенным контекстом.\n",
            "",
        )
        codes = self.codes(missing)
        self.assertIn("CAPABILITY_MISSING", codes)
        self.assertIn("DECISION_CAPABILITY_UNKNOWN", codes)
        self.assertIn("API_EVIDENCE_CAPABILITY_UNKNOWN", codes)

    def test_every_capability_has_typed_contract_coverage(self):
        expanded = PLAN.replace(
            "  - CAP-01 — проверка сертификата, ограниченная платформенным контекстом.",
            "  - CAP-01 — проверка сертификата, ограниченная платформенным контекстом.\n"
            "  - CAP-02 — сохранение текущей навигационной границы.",
        )

        self.assertIn(
            "CAPABILITY_CONTRACT_COVERAGE_MISSING",
            self.codes(expanded),
        )

        globally_covered = expanded.replace(
            "| CAP-01 | platform_plugin_api |",
            "| global | platform_plugin_api |",
        )
        self.assertNotIn(
            "CAPABILITY_CONTRACT_COVERAGE_MISSING",
            self.codes(globally_covered),
        )

    def test_capability_references_must_be_declared_globally(self):
        broken = PLAN.replace(
            "- Проверить успешный платёжный хост и ошибку неизвестного хоста.",
            "- Проверить CAP-99 на успешном и ошибочном сценариях.",
        )

        self.assertIn("CAPABILITY_REFERENCE_UNKNOWN", self.codes(broken))

    def test_handoff_section_matches_metadata(self):
        broken = PLAN.replace("- Рекомендация: `direct`.", "- Рекомендация: `decompose`.")
        self.assertIn("HANDOFF_SECTION_MISMATCH", self.codes(broken))

    def test_user_decision_cannot_enter_presented_plan(self):
        broken = PLAN.replace("- Риски:", "- USER_DECISION: выбрать хост.\n- Риски:")
        self.assertIn("UNRESOLVED_MARKER_IN_PLAN", self.codes(broken))

    def test_block_stays_in_working_session_not_plan(self):
        blocked = PLAN.replace("plan_state: PLAN_READY", "plan_state: BLOCKED_REQUIREMENTS")
        blocked = blocked.replace("- Риски:", "- BLOCK: отсутствует contract.\n- Риски:")
        codes = self.codes(blocked)
        self.assertIn("PLAN_STATE_INVALID", codes)
        self.assertIn("UNRESOLVED_MARKER_IN_PLAN", codes)

    def test_active_question_subsection_cannot_enter_presented_plan(self):
        broken = PLAN.replace(
            "\n## Готовность и проверка",
            "\n### Текущий пакет вопросов\n#### Q-01 — выбор\n- Вопрос: выбрать хост?\n\n## Готовность и проверка",
        )
        self.assertIn("ACTIVE_QUESTIONS_IN_PLAN", self.codes(broken))

    def test_only_d_ids_can_enter_decision_table(self):
        broken = PLAN.replace(
            "| D-01 | Особая проверка доверия",
            "| EXT-01 | Особая проверка доверия",
        )
        self.assertIn("DECISION_ID_INVALID", self.codes(broken))

    def test_plan_without_material_decisions_does_not_invent_d_row(self):
        decision_table = """| ID | Решение | Почему | Применимость | Проверка/ограничение |
| :--- | :--- | :--- | :--- | :--- |
| D-01 | Особая проверка доверия ограничена платёжным хостом | Не расширять доверие обычных WebView | CAP-01 | Неизвестный хост отклоняется |"""
        no_decisions = PLAN.replace(" | D-01 |", " | — |").replace(
            decision_table,
            "- Существенных решений нет.",
        )
        self.assertEqual([], validate(no_decisions))
        dangling = no_decisions.replace(
            "- Риски: случайное расширение особой проверки доверия.",
            "- Риски: случайное расширение особой проверки доверия; см. D-01.",
        )
        self.assertIn("DECISION_REFERENCE_UNKNOWN", self.codes(dangling))

    def test_legacy_status_table_is_rejected(self):
        broken = PLAN.replace(
            "| ID | Решение | Почему | Применимость | Проверка/ограничение |",
            "| ID | Статус | Решение/факт | Evidence level | Источник/основание | Применимость | Проверка/обработка |",
        ).replace(
            "| :--- | :--- | :--- | :--- | :--- |\n| D-01 | Особая проверка доверия ограничена платёжным хостом | Не расширять доверие обычных WebView | CAP-01 | Неизвестный хост отклоняется |",
            "| :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n| D-01 | DEFAULT | Особая проверка доверия ограничена платёжным хостом | project_fact | текущий сценарий | CAP-01 | Неизвестный хост отклоняется |",
        )
        self.assertIn("DECISION_TABLE_INVALID", self.codes(broken))

    def test_api_evidence_type_is_checked(self):
        broken = PLAN.replace("platform_plugin_api", "swaggerish")
        self.assertIn("API_EVIDENCE_TYPE_INVALID", self.codes(broken))

    def test_external_contract_evidence_is_accepted(self):
        external = PLAN.replace("platform_plugin_api", "external_contract")
        self.assertEqual([], validate(external))

    def test_api_evidence_accepts_multiple_declared_capabilities(self):
        expanded = PLAN.replace(
            "  - CAP-01 — проверка сертификата, ограниченная платформенным контекстом.",
            "  - CAP-01 — проверка сертификата, ограниченная платформенным контекстом.\n  - CAP-02 — граница навигации.",
        ).replace(
            "| CAP-01 | platform_plugin_api |",
            "| CAP-01, CAP-02 | platform_plugin_api |",
        )
        self.assertEqual([], validate(expanded))
        unknown = expanded.replace("CAP-01, CAP-02 | platform_plugin_api", "CAP-01, CAP-03 | platform_plugin_api")
        self.assertIn("API_EVIDENCE_CAPABILITY_UNKNOWN", self.codes(unknown))

    def test_external_references_require_boundary_declaration(self):
        referenced = PLAN.replace(
            "`official_fact`: API платформы",
            "`official_fact`: API платформы; EXT-01",
        )
        self.assertIn("EXTERNAL_REFERENCE_UNKNOWN", self.codes(referenced))
        declared = referenced.replace(
            "- Внешние зависимости и обработка: отсутствуют.",
            "- Внешние зависимости и обработка:\n  - EXT-01 — владелец платформы подтверждает API; обработка: проверить до реализации.",
        )
        self.assertEqual([], validate(declared))

    def test_external_boundary_requires_explicit_handling(self):
        broken = PLAN.replace(
            "- Внешние зависимости и обработка: отсутствуют.",
            "- Внешние зависимости и обработка:\n"
            "  - EXT-01 — владелец платформы подтверждает API.",
        )

        self.assertIn("EXTERNAL_HANDLING_MISSING", self.codes(broken))

    def test_developer_readiness_and_qa_are_separate(self):
        broken = PLAN.replace("### Проверки QA", "### Проверка")
        self.assertIn("READINESS_SECTION_MISSING", self.codes(broken))

    def test_handoff_continuation_is_explicit_and_typed(self):
        missing = PLAN.replace(
            "- Продолжение: ожидает выбора пользователя.\n",
            "",
        )
        self.assertIn("HANDOFF_CONTINUATION_MISSING", self.codes(missing))

        invalid = PLAN.replace(
            "- Продолжение: ожидает выбора пользователя.",
            "- Продолжение: наверное запустить потом.",
        )
        self.assertIn("HANDOFF_CONTINUATION_INVALID", self.codes(invalid))

    def test_preauthorized_continuation_requires_delegation_evidence(self):
        unauthorized = PLAN.replace(
            "- Продолжение: ожидает выбора пользователя.",
            "- Продолжение: заранее разрешённый декомпоз.",
        )
        self.assertIn(
            "HANDOFF_CONTINUATION_UNAUTHORIZED",
            self.codes(unauthorized),
        )

        authorized = unauthorized.replace(
            "- Источник и контекст: локальная спецификация.",
            "- Источник и контекст: локальная спецификация.\n"
            "- Авторизация планирования: explicit_user_delegation — \"решай сам и декомпозируй\".",
        )
        self.assertNotIn(
            "HANDOFF_CONTINUATION_UNAUTHORIZED",
            self.codes(authorized),
        )

    def test_pseudocode_is_optional_but_constrained(self):
        pseudocode = """
### Псевдокод поведения
```text
Получить платёжный хост
Проверить принадлежность разрешённому списку
Выбрать системную или особую проверку доверия
Продолжить загрузку после успеха
Остановить загрузку после ошибки
```
"""
        valid = PLAN.replace("\n## Как устроено решение", pseudocode + "\n## Как устроено решение")
        self.assertEqual([], validate(valid))
        code_like = valid.replace("Остановить загрузку после ошибки", "if (host) { return true; }")
        self.assertIn("PSEUDOCODE_CODE_SYNTAX", self.codes(code_like))
        too_short = PLAN.replace(
            "\n## Как устроено решение",
            "\n### Псевдокод поведения\n```text\nОдин\nДва\n```\n\n## Как устроено решение",
        )
        self.assertIn("PSEUDOCODE_LENGTH_INVALID", self.codes(too_short))

    def test_semantic_change_requires_new_draft_revision(self):
        changed = PLAN.replace(
            "случайное расширение",
            "выход проверки доверия за платёжную границу",
        )
        self.assertIn("SEMANTIC_REVISION_INVALID", self.codes(changed, previous=PLAN))
        revised = changed.replace("revision: 1", "revision: 2")
        self.assertEqual([], validate(revised, previous_text=PLAN))

    def test_nonsemantic_edit_keeps_revision(self):
        formatted = PLAN.replace(
            "решение и платформенная граница",
            "решение  и  платформенная граница",
        )
        self.assertEqual([], validate(formatted, previous_text=PLAN))

    def test_url_normalization_preserves_balanced_parentheses(self):
        valid = "https://developer.apple.com/documentation/security/sectrustevaluatewitherror%28_%3A_%3A%29"
        malformed = "https://developer.apple.com/documentation/security/sectrustevaluatewitherror%28_%3A_%3A"
        self.assertNotEqual(semantic_normal_form(valid), semantic_normal_form(malformed))
        self.assertEqual(semantic_normal_form(f"{valid})"), semantic_normal_form(valid))

    def test_approved_snapshot_is_immutable(self):
        approved = PLAN.replace("status: draft", "status: approved").replace(
            "approved_revision: none", "approved_revision: 1"
        )
        reformatted = approved.replace(
            "решение и платформенная граница",
            "решение  и  платформенная граница",
        )
        self.assertIn(
            "APPROVED_IMMUTABLE",
            self.codes(reformatted, phase="approved", previous=approved),
        )


if __name__ == "__main__":
    unittest.main()
