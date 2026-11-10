from __future__ import annotations

import unittest

from factory_tooling.gates.gate_contract import GateResult, conclude, evidence, require_pass


class GateContractTest(unittest.TestCase):
    def result(self, records: list[object]) -> GateResult:
        return conclude(
            "test", "decompose.complete", "run", "policy", "artifacts", ["a", "b"], records
        )

    def test_missing_is_blocked(self) -> None:
        result = self.result([evidence("a", "PASS", "ok", ["log"])])
        self.assertEqual("BLOCKED", result["status"])
        with self.assertRaises(ValueError):
            require_pass(result)

    def test_mixed_failure_and_blocker_preserved(self) -> None:
        result = self.result(
            [
                evidence("a", "FAIL", "violation", ["task"]),
                evidence("b", "BLOCKED", "timeout", ["log"]),
            ]
        )
        self.assertEqual("FAIL", result["status"])
        self.assertEqual(["FAIL", "BLOCKED"], [c["status"] for c in result["checks"]])

    def test_only_complete_evidence_opens_gate(self) -> None:
        result = self.result([evidence(k, "PASS", "ok", ["log"]) for k in ["a", "b"]])
        require_pass(result)
        with self.assertRaises(ValueError):
            self.result([evidence("unknown", "PASS", "ok", ["log"])])
        with self.assertRaises(ValueError):
            self.result([evidence("a", "PASS", "ok", ["log"])] * 2)
