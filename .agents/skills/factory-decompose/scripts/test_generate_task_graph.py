import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_task_graph.py")
SPEC = importlib.util.spec_from_file_location("generate_task_graph", SCRIPT_PATH)
graph = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(graph)


class GenerateTaskGraphTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self.temp_dir.name)
        self.tasks_dir = self.root / "tasks"
        self.tasks_dir.mkdir()
        self.source_lock = self.root / "decomposition-source.json"
        self.source_lock.write_text(
            json.dumps(
                {
                    "plan_id": "orders-plan",
                    "plan_revision": 2,
                    "plan_hash": "sha256:test",
                    "plan_path": "docs/plans/orders-plan.md",
                    "capability_ids": [],
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_empty_capability_ids_source_lock_is_rejected(self):
        _, messages = graph.load_source_lock(str(self.source_lock))

        self.assertTrue(
            any("capability_ids не должен быть пустым" in message for message in messages)
        )

    def write_tasks(self, tasks, schema_version=2, markdown=None):
        scope_dir = self.tasks_dir / "generated"
        scope_dir.mkdir(exist_ok=True)
        coverage = []
        total_min = 0
        total_max = 0
        purpose_labels = {
            "functionality": "Функциональность",
            "technical_preparation": "Техническая подготовка",
            "research": "Исследование",
        }
        for index, task in enumerate(tasks, start=1):
            capability_id = f"CAP-{index:02d}"
            task_id = task.get("id")
            coverage.append(
                {
                    "capability_id": capability_id,
                    "task_ids": [task_id] if isinstance(task_id, str) and task_id else [],
                    "coverage": "complete",
                }
            )
            estimate = task.get("estimate")
            if isinstance(estimate, dict):
                min_hours = estimate.get("min_hours")
                max_hours = estimate.get("max_hours")
                if isinstance(min_hours, (int, float)) and not isinstance(min_hours, bool):
                    total_min += min_hours
                if isinstance(max_hours, (int, float)) and not isinstance(max_hours, bool):
                    total_max += max_hours

            filename = task.get("filename")
            if (
                not isinstance(filename, str)
                or Path(filename).name != filename
                or "\\" in filename
            ):
                continue
            if markdown is None:
                estimate_label = graph.normalize_estimate(task)[0]
                content = (
                    f"# {task.get('title', 'Задача')}\n\n"
                    f"- **ID:** {task_id or '—'}\n"
                    "- **Источник плана:** orders-plan, revision 2\n"
                    f"- **Покрывает возможности:** {capability_id}\n"
                    f"- **Назначение:** {purpose_labels.get(task.get('purpose'), task.get('purpose', '—'))}\n"
                    f"- **Модуль:** {task.get('scope', '—')}\n"
                    f"- **Оценка:** {estimate_label}\n"
                )
            elif isinstance(markdown, dict):
                content = markdown.get(task_id, "")
            else:
                content = markdown
            (scope_dir / filename).write_text(content, encoding="utf-8")

        payload = {
            "schema_version": schema_version,
            "source_plan": {
                "plan_id": "orders-plan",
                "revision": 2,
                "hash": "sha256:test",
            },
            "capability_coverage": coverage,
            "summary": "Задачи списка заказов",
            "total_min_hours": total_min,
            "total_max_hours": total_max,
            "tasks": tasks,
        }
        self.source_lock.write_text(
            json.dumps(
                {
                    "plan_id": "orders-plan",
                    "plan_revision": 2,
                    "plan_hash": "sha256:test",
                    "plan_path": "docs/plans/orders-plan.md",
                    "capability_ids": [item["capability_id"] for item in coverage],
                },
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        self.write_payload(payload)
        return graph.load_tasks(str(self.tasks_dir))

    def write_payload(self, payload):
        scope_dir = self.tasks_dir / "generated"
        scope_dir.mkdir(exist_ok=True)
        (scope_dir / "task_result.json").write_text(
            json.dumps(payload, ensure_ascii=False), encoding="utf-8"
        )

    def run_cli(self):
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(self.root / "graph.md"),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

    @staticmethod
    def v2_task(task_id="orders-list-core-01", **overrides):
        sequence = task_id.rsplit("-", 1)[-1]
        slug = task_id.rsplit("-", 1)[0]
        task = {
            "id": task_id,
            "filename": f"{sequence}-{slug}.md",
            "title": "Показать список заказов",
            "purpose": "functionality",
            "scope": "orders_list",
            "outcome": "Пользователь видит список заказов",
            "affected_layers": ["domain", "data", "presentation"],
            "contract_type": "backend_api",
            "implemented": ["loading", "loaded"],
            "deferred": [],
            "parent_task": None,
            "depends_on": [],
            "blocked_by": [],
            "estimate": {"min_hours": 6, "max_hours": 8, "confidence": "medium"},
        }
        task.update(overrides)
        return task

    def test_explicit_scope_and_outcome_id_are_used(self):
        tasks = self.write_tasks([self.v2_task()])

        task = tasks["orders-list-core-01"]
        self.assertEqual("orders_list", task["scope"])
        self.assertEqual("Показать список заказов", task["name"])
        self.assertEqual(["domain", "data", "presentation"], task["affected_layers"])

    def test_v2_ignores_removed_name_alias(self):
        tasks = self.write_tasks([self.v2_task(name="Старое имя")])

        self.assertEqual("Показать список заказов", tasks["orders-list-core-01"]["name"])
        mermaid = graph.generate_mermaid_graph(tasks)
        self.assertNotIn("Старое имя", mermaid)

    def test_all_three_purposes_are_supported(self):
        source = [
            self.v2_task(f"orders-{purpose}-01", purpose=purpose, scope=purpose)
            for purpose in ("functionality", "technical_preparation", "research")
        ]
        tasks = self.write_tasks(source)

        self.assertEqual(
            {"functionality", "technical_preparation", "research"},
            {task["purpose"] for task in tasks.values()},
        )

    def test_unknown_purpose_is_reported_in_russian(self):
        tasks = self.write_tasks([self.v2_task(purpose="integration")])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("неизвестное назначение" in message.lower() for message in messages))

    def test_v2_missing_purpose_is_reported(self):
        task = self.v2_task()
        del task["purpose"]

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("назначение" in message.lower() for message in messages))

    def test_v2_without_scope_does_not_infer_it_from_outcome_id(self):
        task = self.v2_task()
        task.pop("scope")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertIsNone(tasks[task["id"]]["scope"])
        self.assertTrue(any("scope" in message and "не указан" in message for message in messages))

    def test_schema_v1_layer_shaped_task_is_hard_rejected_without_graph(self):
        old_task = {
            "id": "cart-ui-01",
            "title": "Old UI",
            "primary_scope": "cart",
            "layer": "ui",
            "requires": [],
            "estimate_hours": 4,
        }
        self.write_tasks([old_task], schema_version=1)

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("schema_version", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any("schema_version" in message for message in violations["violations"])
        )

    def test_schema_v1_empty_envelope_is_hard_rejected_without_graph(self):
        self.write_payload({"schema_version": 1, "tasks": []})

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("schema_version", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any("schema_version" in message for message in violations["violations"])
        )

    def test_schema_v2_rejects_non_object_task_entry_without_graph(self):
        self.write_payload({"schema_version": 2, "tasks": ["not-an-object"]})

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any("объектом" in message for message in violations["violations"])
        )

    def test_unrecognized_old_payload_is_hard_rejected_without_graph(self):
        self.write_payload(
            {
                "primary_scope": "cart",
                "layer": "ui",
                "requires": [],
                "estimate_hours": 4,
            }
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any("schema" in message for message in violations["violations"])
        )

    def test_schema_violation_is_preserved_when_task_has_cycle(self):
        task = self.v2_task("orders-loop-01", depends_on=["orders-loop-01"])
        self.write_tasks([task], schema_version=1)

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("schema_version", result.stderr)
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(violations["cycles"])
        self.assertTrue(
            any("schema_version" in message for message in violations["violations"])
        )

    def test_v2_does_not_fallback_to_removed_aliases(self):
        task = self.v2_task(
            primary_scope="old_scope",
            layer="ui",
            requires=["old-dependency-01"],
            estimate_hours=5,
        )
        for field in ("scope", "affected_layers", "depends_on", "estimate"):
            task.pop(field)

        tasks = self.write_tasks([task])
        loaded = tasks[task["id"]]
        messages = "\n".join(graph.validate_dependencies(tasks))

        self.assertIsNone(loaded["scope"])
        self.assertIsNone(loaded["affected_layers"])
        self.assertIsNone(loaded["depends_on"])
        self.assertEqual(0, loaded["estimate_max_hours"])
        for field in ("scope", "affected_layers", "depends_on", "estimate"):
            self.assertIn(field, messages)

    def test_mermaid_defines_only_current_purpose_classes(self):
        tasks = self.write_tasks(
            [self.v2_task("orders-list-core-01", affected_layers=["domain"])]
        )

        mermaid = graph.generate_mermaid_graph(tasks)

        class_names = {
            line.strip().split()[1]
            for line in mermaid.splitlines()
            if line.strip().startswith("classDef ")
        }
        self.assertEqual(
            {"functionality", "technical_preparation", "research", "backend"},
            class_names,
        )

    def test_v2_loader_preserves_raw_presence_and_malformed_values(self):
        task = self.v2_task(
            affected_layers="data",
            implemented=0,
            consumers="orders-consumer-02",
            research_question=[],
            timebox_hours="four",
            expected_result={},
            estimate={"min_hours": 1, "max_hours": 2, "confidence": ""},
        )
        tasks = self.write_tasks([task])
        loaded = tasks[task["id"]]

        for field in (
            "filename",
            "title",
            "outcome",
            "affected_layers",
            "contract_type",
            "implemented",
            "consumers",
            "research_question",
            "timebox_hours",
            "expected_result",
            "schema_version",
        ):
            self.assertTrue(loaded["raw_presence"][field])
        self.assertTrue(loaded["raw_presence"]["estimate.confidence"])
        self.assertEqual("data", loaded["affected_layers"])
        self.assertEqual(0, loaded["implemented"])
        self.assertEqual("", loaded["estimate_confidence"])

    def test_v2_reports_missing_required_fields(self):
        task = self.v2_task()
        for field in (
            "filename",
            "title",
            "outcome",
            "affected_layers",
            "contract_type",
            "implemented",
            "deferred",
            "parent_task",
            "depends_on",
            "blocked_by",
            "estimate",
        ):
            task.pop(field)
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        for field in (
            "filename",
            "title",
            "outcome",
            "affected_layers",
            "implemented",
            "deferred",
            "parent_task",
            "depends_on",
            "blocked_by",
            "estimate",
        ):
            self.assertTrue(
                any(field in message and "обязательное поле" in message for message in messages),
                field,
            )

    def test_task_requires_schema_version_2(self):
        task = self.v2_task(affected_layers=["domain"])
        task.pop("schema_version", None)
        scope_dir = self.tasks_dir / "generated"
        scope_dir.mkdir(exist_ok=True)
        (scope_dir / "task_result.json").write_text(
            json.dumps({"tasks": [task]}, ensure_ascii=False), encoding="utf-8"
        )

        tasks = graph.load_tasks(str(self.tasks_dir))
        messages = graph.validate_dependencies(tasks)

        self.assertTrue(
            any("schema_version" in message and "2" in message for message in messages)
        )

    def test_v2_functionality_reports_malformed_base_types(self):
        task = self.v2_task(
            filename=[],
            title=0,
            scope=[],
            outcome=0,
            affected_layers="data",
            implemented={},
            deferred={},
            parent_task=1,
            depends_on="orders-base-00",
            blocked_by="API-1",
            estimate=[],
        )
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)
        combined = "\n".join(messages)

        for fragment in (
            "filename",
            "title",
            "scope",
            "outcome",
            "affected_layers должно быть списком",
            "implemented должно быть списком",
            "deferred должно быть списком",
            "parent_task",
            "depends_on должно быть списком",
            "blocked_by должно быть списком",
            "estimate должно быть объектом",
        ):
            self.assertIn(fragment, combined)

    def test_cli_hard_fails_malformed_scope_without_graph(self):
        self.write_tasks([self.v2_task(scope=[])])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any("scope" in message for message in violations["violations"])
        )

    def test_cli_hard_fails_truthy_non_string_filename_without_graph(self):
        self.write_tasks([self.v2_task(filename=1)])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertNotIn("Задачи не найдены", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any("filename" in message for message in violations["violations"])
        )

    def test_cli_hard_fails_v2_task_without_id(self):
        task = self.v2_task()
        task.pop("id")
        self.write_tasks([task])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertNotIn("Задачи не найдены", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        violations = json.loads(
            (self.root / "violations.json").read_text(encoding="utf-8")
        )
        self.assertTrue(
            any(
                "id" in message and "обязательное поле" in message
                for message in violations["violations"]
            )
        )

    def test_cli_valid_envelope_passes_and_writes_graph(self):
        self.write_tasks([self.v2_task()])

        result = self.run_cli()

        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Graph gate: PASS", result.stderr)
        self.assertTrue((self.root / "graph.md").is_file())
        self.assertFalse((self.root / "violations.json").exists())

    def test_cli_empty_staging_is_hard_failure(self):
        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("task_result.json", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_missing_dependency_is_hard_failure(self):
        self.write_tasks(
            [self.v2_task(depends_on=["orders-missing-99"])]
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("отсутствующей задачи", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_invalid_contract_type_and_layer_are_hard_failure(self):
        self.write_tasks(
            [
                self.v2_task(
                    contract_type="graphql",
                    affected_layers=["domain", "widgets"],
                )
            ]
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("contract_type", result.stderr)
        self.assertIn("affected_layers", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_duplicate_task_id_is_hard_failure(self):
        self.write_tasks([self.v2_task(), self.v2_task()])

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("ID повторяется", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_duplicate_filename_is_hard_failure(self):
        shared_filename = "01-orders-shared.md"
        self.write_tasks(
            [
                self.v2_task("orders-first-01", filename=shared_filename),
                self.v2_task("orders-second-02", filename=shared_filename),
            ]
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("одинаковый filename", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_missing_markdown_is_hard_failure(self):
        task = self.v2_task()
        self.write_tasks([task])
        (self.tasks_dir / "generated" / task["filename"]).unlink()

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("Markdown-файл", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_visible_markdown_identity_mismatch_is_hard_failure(self):
        task = self.v2_task()
        self.write_tasks([task])
        markdown_path = self.tasks_dir / "generated" / task["filename"]
        content = markdown_path.read_text(encoding="utf-8")
        markdown_path.write_text(
            content.replace(task["id"], "orders-wrong-99", 1),
            encoding="utf-8",
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("видимый ID", result.stderr)
        self.assertFalse((self.root / "graph.md").exists())

    def test_cli_source_tuple_mismatch_is_hard_failure(self):
        self.write_tasks([self.v2_task()])
        source = json.loads(self.source_lock.read_text(encoding="utf-8"))
        source["plan_hash"] = "sha256:changed"
        self.source_lock.write_text(
            json.dumps(source, ensure_ascii=False), encoding="utf-8"
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("source_plan не совпадает", result.stderr)

    def test_cli_capability_coverage_mismatch_is_hard_failure(self):
        self.write_tasks([self.v2_task()])
        source = json.loads(self.source_lock.read_text(encoding="utf-8"))
        source["capability_ids"].append("CAP-99")
        self.source_lock.write_text(
            json.dumps(source, ensure_ascii=False), encoding="utf-8"
        )

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("Capability coverage", result.stderr)

    def test_v2_uses_depends_on_and_ignores_requires(self):
        base = self.v2_task("orders-base-01", affected_layers=["domain"])
        explicit = self.v2_task(
            "orders-explicit-03", depends_on=[base["id"]], requires=["ignored-task-99"]
        )
        tasks = self.write_tasks([base, explicit])

        self.assertEqual([base["id"]], tasks[explicit["id"]]["depends_on"])

    def test_v2_filename_uses_task_sequence_as_prefix(self):
        task = self.v2_task("orders-list-core-01", filename="orders-list-core-01.md")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("01-slug.md" in message for message in messages))

    def test_v2_rejects_legacy_id_without_two_digit_sequence(self):
        task = self.v2_task("orders-list-core-1", filename="1-orders-list-core.md")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("-NN" in message for message in messages))

    def test_estimate_8_12_16_are_allowed_and_17_is_violation(self):
        source = [
            self.v2_task(
                f"orders-size-{hours:02d}",
                scope=f"size_{hours}",
                affected_layers=["domain"],
                estimate={"min_hours": hours, "max_hours": hours, "confidence": "high"},
            )
            for hours in (8, 12, 16, 17)
        ]
        tasks = self.write_tasks(source)

        messages = graph.validate_dependencies(tasks)

        self.assertFalse(any("orders-size-08" in message for message in messages))
        self.assertFalse(any("orders-size-12" in message for message in messages))
        self.assertFalse(any("orders-size-16" in message for message in messages))
        self.assertTrue(any("orders-size-17" in message and "16" in message for message in messages))

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertFalse((self.root / "graph.md").exists())

    def test_v2_string_estimate_is_not_parsed(self):
        task = self.v2_task(estimate="6–8 ч")

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertEqual(0, tasks[task["id"]]["estimate_max_hours"])
        self.assertTrue(any("estimate должно быть объектом" in message for message in messages))

    def test_v2_estimate_dict_ignores_estimate_hours_alias(self):
        task = self.v2_task(
            "orders-dict-01",
            affected_layers=["domain"],
            estimate={"min_hours": 9, "max_hours": 10, "confidence": "medium"},
            estimate_hours=4,
        )
        tasks = self.write_tasks([task])

        self.assertEqual(10, tasks[task["id"]]["estimate_max_hours"])

    def test_invalid_estimate_dict_does_not_fallback_to_estimate_hours(self):
        task = self.v2_task(
            "orders-invalid-dict-01",
            affected_layers=["domain"],
            estimate={"confidence": "low"},
            estimate_hours=5,
        )

        tasks = self.write_tasks([task])
        messages = graph.validate_dependencies(tasks)

        self.assertEqual(0, tasks[task["id"]]["estimate_max_hours"])
        self.assertTrue(
            any("min_hours и max_hours должны быть числами" in message for message in messages)
        )

    def test_v2_estimate_validates_order_numbers_but_confidence_is_optional(self):
        reversed_range = self.v2_task(
            "orders-estimate-reversed-01",
            estimate={"min_hours": 20, "max_hours": 8, "confidence": "medium"},
        )
        negative = self.v2_task(
            "orders-estimate-negative-02",
            estimate={"min_hours": -1, "max_hours": 2, "confidence": "high"},
        )
        nonnumeric = self.v2_task(
            "orders-estimate-text-03",
            estimate={"min_hours": "one", "max_hours": 2, "confidence": "low"},
        )
        missing_confidence = self.v2_task(
            "orders-estimate-confidence-04",
            estimate={"min_hours": 1, "max_hours": 2},
        )
        tasks = self.write_tasks(
            [reversed_range, negative, nonnumeric, missing_confidence]
        )

        messages = graph.validate_dependencies(tasks)
        combined = "\n".join(messages)

        self.assertIn("orders-estimate-reversed-01", combined)
        self.assertIn("min_hours не может быть больше max_hours", combined)
        self.assertIn("orders-estimate-negative-02", combined)
        self.assertIn("min_hours не может быть отрицательным", combined)
        self.assertIn("orders-estimate-text-03", combined)
        self.assertIn("min_hours и max_hours должны быть числами", combined)
        self.assertFalse(any("orders-estimate-confidence-04" in message for message in messages))

    def test_technical_preparation_requires_valid_existing_consumers(self):
        consumer = self.v2_task("orders-consumer-01")
        empty = self.v2_task(
            "orders-tech-empty-02",
            purpose="technical_preparation",
            consumers=[],
        )
        missing = self.v2_task(
            "orders-tech-missing-03",
            purpose="technical_preparation",
            consumers=["orders-missing-99"],
        )
        valid = self.v2_task(
            "orders-tech-valid-04",
            purpose="technical_preparation",
            consumers=[consumer["id"]],
        )
        tasks = self.write_tasks([consumer, empty, missing, valid])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any(empty["id"] in message and "consumers" in message for message in messages))
        self.assertTrue(any(missing["id"] in message and "orders-missing-99" in message for message in messages))
        self.assertFalse(any(valid["id"] in message and "consumers" in message for message in messages))

    def test_research_requires_question_positive_timebox_and_expected_result(self):
        invalid = self.v2_task(
            "orders-research-invalid-01",
            purpose="research",
            research_question="",
            timebox_hours=0,
            expected_result=None,
        )
        valid = self.v2_task(
            "orders-research-valid-02",
            purpose="research",
            research_question="Как стабильно обновлять offset?",
            timebox_hours=4,
            expected_result="Зафиксированное решение и прототип",
        )
        tasks = self.write_tasks([invalid, valid])

        messages = graph.validate_dependencies(tasks)
        combined = "\n".join(messages)

        for field in ("research_question", "timebox_hours", "expected_result"):
            self.assertIn(invalid["id"], combined)
            self.assertIn(field, combined)
            self.assertFalse(any(valid["id"] in message and field in message for message in messages))

    def test_functionality_does_not_require_conditional_fields(self):
        task = self.v2_task("orders-functionality-valid-01")
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        for field in ("consumers", "research_question", "timebox_hours", "expected_result"):
            self.assertFalse(any(task["id"] in message and field in message for message in messages))

    def test_data_layer_does_not_imply_backend_api_grounding(self):
        task = self.v2_task(affected_layers=["data", "presentation"])
        tasks = self.write_tasks([task], markdown="Нет сведений о контракте")

        messages = graph.validate_dependencies(tasks)

        self.assertFalse(any("API" in message and task["id"] in message for message in messages))

    def test_deferred_completed_by_must_reference_existing_task(self):
        task = self.v2_task(
            deferred=[
                {
                    "behavior": "error_and_retry",
                    "completed_by": "orders-missing-02",
                    "temporary_behavior": "generic_error",
                }
            ]
        )
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(any("orders-missing-02" in message and "отлож" in message.lower() for message in messages))

    def test_deferred_completed_by_accepts_existing_task(self):
        followup = self.v2_task("orders-error-retry-02", affected_layers=["presentation"])
        task = self.v2_task(
            deferred=[
                {
                    "behavior": "error_and_retry",
                    "completed_by": followup["id"],
                    "temporary_behavior": "generic_error",
                }
            ]
        )
        tasks = self.write_tasks([task, followup])

        messages = graph.validate_dependencies(tasks)

        self.assertFalse(any("отлож" in message.lower() for message in messages))

    def test_deferred_cannot_be_completed_by_same_task(self):
        task = self.v2_task()
        task["deferred"] = [
            {
                "behavior": "error_and_retry",
                "completed_by": task["id"],
                "temporary_behavior": "generic_error",
            }
        ]
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(
            any("не может закрываться этой же задачей" in message for message in messages)
        )

    def test_deferred_cycle_is_hard_blocked(self):
        first = self.v2_task("orders-first-01")
        second = self.v2_task("orders-second-02")
        first["deferred"] = [
            {
                "behavior": "second_behavior",
                "completed_by": second["id"],
                "temporary_behavior": "generic_error",
            }
        ]
        second["deferred"] = [
            {
                "behavior": "first_behavior",
                "completed_by": first["id"],
                "temporary_behavior": "generic_error",
            }
        ]
        self.write_tasks([first, second])
        tasks = graph.load_tasks(str(self.tasks_dir))

        self.assertTrue(graph.check_deferred_cycles(tasks))

        result = self.run_cli()

        self.assertEqual(1, result.returncode)
        self.assertIn("цикл отложенного поведения", result.stderr.lower())

    def test_falsy_invalid_deferred_values_are_not_masked(self):
        source = [
            self.v2_task("orders-deferred-dict-01", deferred={}),
            self.v2_task("orders-deferred-string-02", deferred=""),
            self.v2_task("orders-deferred-zero-03", deferred=0),
        ]
        tasks = self.write_tasks(source)

        messages = graph.validate_dependencies(tasks)

        for task in source:
            self.assertTrue(
                any(
                    task["id"] in message and "deferred должно быть списком" in message
                    for message in messages
                )
            )

    def test_missing_or_none_deferred_defaults_to_empty_list(self):
        missing = self.v2_task("orders-deferred-missing-01")
        missing.pop("deferred")
        explicit_none = self.v2_task("orders-deferred-none-02", deferred=None)
        tasks = self.write_tasks([missing, explicit_none])

        self.assertEqual([], tasks[missing["id"]]["deferred"])
        self.assertEqual([], tasks[explicit_none["id"]]["deferred"])

    def test_dependency_cycle_is_detected(self):
        first = self.v2_task("orders-first-01", depends_on=["orders-second-02"])
        second = self.v2_task("orders-second-02", depends_on=["orders-first-01"])
        tasks = self.write_tasks([first, second])

        self.assertTrue(graph.check_circular_dependencies(tasks))

    def test_parent_task_must_reference_existing_task(self):
        task = self.v2_task(parent_task="orders-missing-parent-00")
        tasks = self.write_tasks([task])

        messages = graph.validate_dependencies(tasks)

        self.assertTrue(
            any("родительская задача" in message.lower() and "orders-missing-parent-00" in message for message in messages)
        )

    def test_parent_task_cycle_is_detected_separately(self):
        first = self.v2_task("orders-first-01", parent_task="orders-second-02")
        second = self.v2_task("orders-second-02", parent_task="orders-first-01")
        tasks = self.write_tasks([first, second])

        self.assertEqual([], graph.check_circular_dependencies(tasks))
        self.assertTrue(graph.check_parent_task_cycles(tasks))

    def test_mixed_dependency_and_parent_cycle_is_hard_blocked(self):
        first = self.v2_task("orders-first-01", depends_on=["orders-second-02"])
        second = self.v2_task("orders-second-02", parent_task="orders-first-01")
        tasks = self.write_tasks([first, second])

        self.assertEqual([], graph.check_circular_dependencies(tasks))
        self.assertEqual([], graph.check_parent_task_cycles(tasks))
        self.assertTrue(graph.check_mixed_relation_cycles(tasks))

    def test_same_relation_pair_prefers_hard_dependency_once(self):
        parent = self.v2_task("orders-parent-01")
        child = self.v2_task(
            "orders-child-02",
            depends_on=[parent["id"]],
            parent_task=parent["id"],
        )
        tasks = self.write_tasks([parent, child])

        relations = graph.build_relation_graph(tasks)

        self.assertEqual([(parent["id"], "depends_on")], relations[child["id"]])

    def test_local_blocker_is_relation_and_uses_task_alias_in_mermaid(self):
        blocker = self.v2_task("orders-blocker-01")
        target = self.v2_task("orders-target-02", blocked_by=[blocker["id"]])
        tasks = self.write_tasks([blocker, target])

        relations = graph.build_relation_graph(tasks)
        mermaid = graph.generate_mermaid_graph(tasks)

        self.assertEqual([(blocker["id"], "blocked_by")], relations[target["id"]])
        self.assertIn('task_000 -. "блокирует" .-> task_001', mermaid)
        self.assertNotIn("blocker_000", mermaid)

    def test_local_blocker_duplicate_pair_prefers_hard_dependency(self):
        blocker = self.v2_task("orders-blocker-01")
        target = self.v2_task(
            "orders-target-02",
            depends_on=[blocker["id"]],
            blocked_by=[blocker["id"]],
        )
        tasks = self.write_tasks([blocker, target])

        relations = graph.build_relation_graph(tasks)
        mermaid = graph.generate_mermaid_graph(tasks)

        self.assertEqual([(blocker["id"], "depends_on")], relations[target["id"]])
        self.assertEqual(1, mermaid.count("task_000 --> task_001"))
        self.assertNotIn("блокирует", mermaid)

    def test_local_blocker_mixed_cycle_is_hard_blocked_with_russian_diagnostic(self):
        first = self.v2_task(
            "orders-first-01",
            blocked_by=["orders-second-02"],
        )
        second = self.v2_task(
            "orders-second-02",
            depends_on=[first["id"]],
        )
        self.write_tasks([first, second])
        tasks = graph.load_tasks(str(self.tasks_dir))

        self.assertTrue(graph.check_mixed_relation_cycles(tasks))

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(self.root / "graph.md"),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(1, result.returncode)
        self.assertIn("смешанный цикл", result.stderr.lower())

    def test_mixed_cycle_cli_diagnostic_is_russian(self):
        first = self.v2_task("orders-first-01", depends_on=["orders-second-02"])
        second = self.v2_task("orders-second-02", parent_task="orders-first-01")
        self.write_tasks([first, second])
        output = self.root / "graph.md"

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(output),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("смешанный цикл", result.stderr.lower())

    def test_parent_task_cycle_cli_diagnostic_is_russian(self):
        first = self.v2_task("orders-first-01", parent_task="orders-second-02")
        second = self.v2_task("orders-second-02", parent_task="orders-first-01")
        self.write_tasks([first, second])
        output = self.root / "graph.md"

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(output),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("цикл стека веток", result.stderr.lower())

    def test_cycle_cli_diagnostic_is_russian(self):
        first = self.v2_task("orders-first-01", depends_on=["orders-second-02"])
        second = self.v2_task("orders-second-02", depends_on=["orders-first-01"])
        self.write_tasks([first, second])
        output = self.root / "graph.md"

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--staging-dir",
                str(self.tasks_dir),
                "--output",
                str(output),
                "--source-lock",
                str(self.source_lock),
            ],
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(1, result.returncode)
        self.assertIn("цикл зависимостей", result.stderr.lower())

    def test_mermaid_uses_ascii_purpose_classes(self):
        source = [
            self.v2_task(f"orders-{purpose}-01", purpose=purpose, scope=purpose)
            for purpose in ("functionality", "technical_preparation", "research")
        ]
        tasks = self.write_tasks(source)

        mermaid = graph.generate_mermaid_graph(tasks)

        for class_name in ("functionality", "technical_preparation", "research"):
            self.assertIn(f"classDef {class_name}", mermaid)
            self.assertIn(f" {class_name};", mermaid)

    def test_mermaid_uses_deterministic_safe_aliases(self):
        unsafe_id = 'orders/list "core"-01'
        unsafe_scope = 'orders/list "scope"'
        blocker = 'API/BLOCK "1"-x'
        task = self.v2_task(
            unsafe_id,
            scope=unsafe_scope,
            affected_layers=["domain"],
            blocked_by=[blocker],
        )
        tasks = self.write_tasks([task])

        mermaid = graph.generate_mermaid_graph(tasks)
        reversed_mermaid = graph.generate_mermaid_graph(dict(reversed(list(tasks.items()))))

        self.assertEqual(mermaid, reversed_mermaid)
        self.assertIn("subgraph scope_000", mermaid)
        self.assertIn("task_000[", mermaid)
        self.assertIn("blocker_000[", mermaid)
        self.assertNotIn(f"subgraph {unsafe_scope}", mermaid)
        self.assertNotIn(f"class {unsafe_id}", mermaid)
        self.assertNotIn(f"{blocker}[", mermaid)
        self.assertIn("orders/list &quot;core&quot;-01", mermaid)
        self.assertIn("Модуль: orders/list &quot;scope&quot;", mermaid)
        self.assertIn("Блокер: API/BLOCK &quot;1&quot;-x", mermaid)

    def test_mermaid_renders_parent_edge_without_hard_dependency_duplicate(self):
        parent = self.v2_task("orders-base-01", affected_layers=["domain"])
        stacked = self.v2_task(
            "orders-stacked-02",
            affected_layers=["presentation"],
            parent_task=parent["id"],
        )
        tasks = self.write_tasks([parent, stacked])
        mermaid = graph.generate_mermaid_graph(tasks)
        self.assertIn('task_000 -. "стек веток" .-> task_001', mermaid)

        stacked["depends_on"] = [parent["id"]]
        tasks = self.write_tasks([parent, stacked])
        mermaid = graph.generate_mermaid_graph(tasks)
        self.assertIn("task_000 --> task_001", mermaid)
        self.assertNotIn("стек веток", mermaid)


if __name__ == "__main__":
    unittest.main()
