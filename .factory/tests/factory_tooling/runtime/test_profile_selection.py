"""Default assignment routing and its independent transition guards."""

from copy import deepcopy
from unittest import TestCase

from factory_tooling.runtime.workflow_core import Invalid, atomic_json
from tests.factory_tooling.runtime import test_workflow


class AssignmentLineageTests(TestCase):
    def setUp(self) -> None:
        self.f = test_workflow.WorkflowTests()
        self.f.setUp()
        self.addCleanup(self.f.doCleanups)
        self.f.g["agents"]["author"] = {"role": "developer", "profile": "middle-developer"}
        self.f.require_fixture_review()

    def test_senior_start_is_invalid_for_either_specialty(self) -> None:
        for role in ("developer", "test-writer"):
            self.f.g["agents"]["author"] = {"role": role, "profile": "senior-" + role}
            with (
                self.subTest(role=role),
                self.assertRaisesRegex(Invalid, "requires profile middle"),
            ):
                self.f.init()

    def test_started_assignment_rejects_new_identity_through_revise_or_reintake(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        state = f.ledger.read()
        graph = deepcopy(state["graph"])
        graph["agents"]["replacement"] = graph["agents"]["author"]
        graph["nodes"][0]["agent"] = "replacement"
        with self.assertRaisesRegex(Invalid, "Started assignments"):
            f.ledger.revise(graph, "new worker")
        with self.assertRaisesRegex(Invalid, "Started assignments"):
            f.ledger.reintake(graph, "new worker", "approved source")
        self.assertEqual(state, f.ledger.read())

    def test_replacement_cannot_accept_an_unregistered_profile(self) -> None:
        f = self.f
        f.init()
        f.start("write-label")
        f.ledger.finish("write-label", f.report("write-label"))
        state = f.ledger.read()
        state["graph"]["agents"]["author"]["profile"] = "senior-developer"
        atomic_json(f.ledger.path, state)
        with self.assertRaisesRegex(Invalid, "requires profile middle"):
            f.ledger.replace_session("author", "replace", "terminal", "details")
        with self.assertRaisesRegex(Invalid, "requires profile middle"):
            f.ledger.claim("verify-label")
