"""Workflow rules that can be checked without a database, transport or worker."""

import unittest
from copy import deepcopy

from factory.runtime import teacher
from factory.runtime.commands.execution import CheckExecution
from factory.runtime.contracts import Dispatch
from factory.runtime.knowledge.teacher_models import TeacherJob, decode_event
from factory.runtime.packets.delivery import PacketDelivery
from factory.runtime.scheduling import dispatch
from factory.runtime.scheduling.escalation_policy import RetryBudget
from factory.runtime.workflow_core import Invalid


class DomainTransitionTests(unittest.TestCase):
    def test_waiting_preserves_typed_teacher_identity(self) -> None:
        raw = {
            "kind": "retro",
            "operation": "capture",
            "incident": "issue-7",
            "source": "review",
            "user_sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        }
        key = TeacherJob.model_validate(raw).key()
        job = decode_event(key, raw)
        self.assertIs(teacher.Event, TeacherJob)
        with self.assertRaises(Invalid):
            job.wait_for_owner("  ")
        self.assertIsNone(job.waiting_for)
        job.wait_for_owner("  Which version?  ")
        self.assertEqual(job.waiting_for, "Which version?")
        self.assertEqual(job.key(), key)
        job.done = True
        before = job.model_dump()
        with self.assertRaises(Invalid):
            job.wait_for_owner("Another question?")
        self.assertEqual(before, job.model_dump())

    def test_unknown_dispatch_requires_evidence_and_keeps_sent_assignment(self) -> None:
        attempt: Dispatch = {"attempt": 1, "status": "running", "handle": "worker"}
        dispatch.mark_unknown(attempt, "connection lost")
        for target, evidence in (("reserved", "disconnect"), ("running", ""), ("done", "exit")):
            with self.subTest(target=target), self.assertRaises(Invalid):
                dispatch.reconcile(attempt, target, evidence)
            self.assertEqual(attempt["status"], "unknown")
        dispatch.reconcile(attempt, "running", "worker confirmed")
        self.assertEqual(attempt["status"], "running")
        sent: Dispatch = {"attempt": 1, "status": "unknown", "prompt_submitted": True}
        original = deepcopy(sent)
        with self.assertRaises(Invalid):
            dispatch.reconcile(sent, "reserved", "transport closed")
        self.assertEqual(sent, original)

    def test_retry_spends_only_the_selected_counter(self) -> None:
        counters = {"task:docs": 2}
        budget = RetryBudget("task:tests", 1, counters)
        budget.spend()
        with self.assertRaisesRegex(Invalid, "RETRY_BUDGET_EXHAUSTED"):
            budget.spend()
        self.assertEqual(counters, {"task:docs": 2, "task:tests": 1})
        self.assertEqual(budget.remaining, 0)

    def test_delivery_replay_preserves_acknowledgements(self) -> None:
        for served, acknowledged in ((1, 2), (-1, 0), (1, -1), (3, 0)):
            with self.subTest(served=served, acknowledged=acknowledged), self.assertRaises(Invalid):
                PacketDelivery(served, acknowledged)
        with self.assertRaises(Invalid):
            PacketDelivery(0, 0).confirm(0)
        first = PacketDelivery(0, 0).serve(1)
        self.assertEqual(first, PacketDelivery(1, 0))
        with self.assertRaises(Invalid):
            first.confirm(2)
        with self.assertRaises(Invalid):
            first.serve(3)
        second = first.serve(2)
        self.assertEqual(second.serve(1), PacketDelivery(2, 1))
        complete = second.confirm(2)
        self.assertEqual(complete, PacketDelivery(2, 2))
        self.assertEqual(complete.confirm(2), complete)

    def test_check_request_keeps_its_persisted_key(self) -> None:
        self.assertEqual(
            CheckExecution.request_key("run", "node", "attempt", "request"),
            "5faef22d90a022fdceb46a6694ac62988e81ccb64b227e2ec302817c10d5e166",
        )
        with self.assertRaisesRegex(Invalid, "request ID required"):
            CheckExecution.request_key("run", "node", "attempt", " ")
