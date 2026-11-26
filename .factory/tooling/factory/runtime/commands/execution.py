"""Identity, replay and reconciliation rules of a recorded project check."""

from dataclasses import dataclass

from factory.runtime.contracts import Dispatch, ExecutionReceipt, PendingCheck
from factory.runtime.workflow_core import graph_identity, require


@dataclass(frozen=True)
class CheckExecution:
    execution_id: str
    receipt: ExecutionReceipt

    @staticmethod
    def request_key(run: str, node: str, dispatch: str | None, request: str) -> str:
        require(request.strip(), "Execution request ID required")
        return graph_identity([run, node, dispatch, request])

    def require_same_check(self, check_id: str) -> None:
        require(
            self.receipt["spec"]["id"] == check_id,
            "Execution request ID already refers to different commands",
        )

    def pending(self) -> PendingCheck:
        return {
            "id": self.receipt["spec"]["id"],
            "execution_id": self.execution_id,
            "result": "RUNNING",
        }

    def belongs_to_running_dispatch(self, dispatch: Dispatch) -> bool:
        return (
            dispatch["status"] == "running"
            and dispatch.get("dispatch_id") == self.receipt["dispatch_id"]
        )

    def require_abandonable(self, *, owner_registered: bool) -> None:
        require(self.receipt["status"] == "RUNNING", "Cannot abandon a finished execution")
        require(
            not owner_registered,
            "Cannot abandon a registered process; reconcile after its group terminates",
        )
