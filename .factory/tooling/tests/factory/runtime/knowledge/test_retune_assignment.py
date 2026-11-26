"""A direct Retune keeps its selected cases and independent observations after reconnect."""

import json
import subprocess
import unittest
from typing import Any

from factory.runtime import teacher
from tests import CLI
from tests.factory.runtime.workflow_fixture import WorkflowFixture


class RetuneAssignmentTests(unittest.TestCase):
    def test_resume_after_trial_and_keep_current_procedure_on_counterexample_regression(
        self,
    ) -> None:
        f = WorkflowFixture(self.addCleanup)
        config = f.config_file(lambda c: c["execution"].update(workspace="shared"))
        cases = {
            "case": ("  Export   Name  ", "Export_Name"),
            "counterexample": ("A  B", "A__B"),
            "control": ("Simple", "Simple"),
        }
        for key, text in cases.items():
            (f.root / key).write_text(json.dumps(text))
        (f.root / "baseline").write_text("Replace each space with an underscore")
        (f.root / "candidate").write_text("Join whitespace-separated words with one underscore")
        count = 0
        run = ""

        def call(action: str, *extra: str, request: str | None = None, ok: bool = True) -> Any:
            nonlocal count
            count += 1
            args = [
                *CLI,
                "lessons",
                "--workspace",
                str(f.root),
                "retune",
                action,
                "--config",
                str(config),
                "--request",
                request or f"r{count}",
                *extra,
            ]
            if run:
                args.extend(["--run", run])
            result = subprocess.run(args, text=True, capture_output=True)
            self.assertEqual(ok, result.returncode == 0, result.stderr + result.stdout)
            return json.loads(result.stdout) if ok else None

        run = call(
            "init",
            "--case",
            "case",
            "--counterexample",
            "counterexample",
            "--control",
            "control",
            "--baseline",
            "baseline",
            "--candidate",
            "candidate",
            "--instructions",
            "Compare the selected cases",
        )["run_id"]
        assigned = call("claim")
        ticket = assigned["dispatch_id"]
        self.assertEqual(ticket, call("claim")["dispatch_id"])
        call("bind", "--dispatch", ticket, "--handle", "teacher-one")
        for sample, before, after in [
            ("case", "fail", "pass"),
            ("counterexample", "pass", "fail"),
            ("control", "pass", "pass"),
        ]:
            for variant, verdict in [("baseline", before), ("candidate", after)]:
                worker = sample + "-" + variant
                common = (
                    "--dispatch",
                    ticket,
                    "--worker",
                    worker,
                    "--sample",
                    sample,
                    "--variant",
                    variant,
                )
                trial = call("trial", *common)
                self.assertNotIn("variant", trial)
                value, expected = json.loads(trial["task"])
                observed = (
                    value.replace(" ", "_")
                    if trial["procedure"].startswith("Replace")
                    else "_".join(value.split())
                )
                self.assertEqual(verdict, "pass" if expected == observed else "fail")
                evidence = f"Input {value!r}: observed {observed!r}; required {expected!r}"
                result = call(
                    "result",
                    *common,
                    "--ticket",
                    trial["ticket"],
                    "--verdict",
                    verdict,
                    "--evidence",
                    evidence,
                    request=worker + "-result",
                )
                if sample == "case" and variant == "baseline":
                    state = call("status")
                    self.assertEqual("case", state["subject"]["inputs"]["case"]["path"])
                    self.assertEqual(1, len(state["facts"]["trials"]))
                    self.assertEqual(
                        result,
                        call(
                            "result",
                            *common,
                            "--ticket",
                            trial["ticket"],
                            "--verdict",
                            verdict,
                            "--evidence",
                            evidence,
                            request=worker + "-result",
                        ),
                    )
                    self.assertEqual("reconcile", call("claim")["action"])
        call(
            "conclude",
            "--dispatch",
            ticket,
            "--verdict",
            "propose",
            "--evidence",
            "Original incident improved",
            ok=False,
        )
        call(
            "conclude",
            "--dispatch",
            ticket,
            "--verdict",
            "keep",
            "--evidence",
            "Counterexample regressed",
        )
        state = call("status")
        self.assertEqual("completed", state["terminal"])
        self.assertEqual(6, len(state["facts"]["trials"]))
        self.assertEqual("Replace each space with an underscore", (f.root / "baseline").read_text())
        self.assertEqual([], teacher.pending(f.root))
        run = call(
            "init",
            "--case",
            "case",
            "--counterexample",
            "counterexample",
            "--baseline",
            "baseline",
            "--candidate",
            "candidate",
            "--instructions",
            "Assess whether new trials are warranted",
        )["run_id"]
        second = call("claim")["dispatch_id"]
        call("bind", "--dispatch", second, "--handle", "teacher-two")
        skipped = call(
            "conclude",
            "--dispatch",
            second,
            "--verdict",
            "keep",
            "--evidence",
            "The same candidate and cases already demonstrated the counterexample regression",
        )
        self.assertEqual("keep", skipped["decision"])
        self.assertFalse(call("status")["facts"].get("trials"))
        self.assertEqual([], teacher.pending(f.root))
