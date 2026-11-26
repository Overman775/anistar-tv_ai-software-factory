"""Ownership of physical sessions within one workflow run."""

from dataclasses import dataclass

from factory.runtime.contracts import Session, State
from factory.runtime.workflow_core import require


@dataclass
class RunSessions:
    """Operate on the run snapshot held by the caller under its workflow lock."""

    state: State

    def acp_name(self, agent_id: str) -> str:
        epoch = self.state.get("epochs", {}).get(agent_id, 0)
        return f"{self.state['run_id']}-{agent_id}-e{epoch}"

    def _require_owner(self, agent_id: str, handle: str) -> None:
        state = self.state
        require(
            handle not in state.get("retired_handles", []),
            "Retired physical session cannot be rebound",
        )
        if handle in state.get("acp_created", {}):
            require(
                handle == self.acp_name(agent_id),
                "ACP session belongs to a different agent or epoch",
            )
        owner = state["handle_owners"].get(handle)
        require(
            owner is None or owner == agent_id,
            "Session previously belonged to a different logical agent",
        )
        for other, session in state["sessions"].items():
            require(
                other == agent_id or session["handle"] != handle,
                "Physical session shared between logical agents",
            )

    def bind(self, agent_id: str, handle: str, model: str, *, expected_model: str | None) -> None:
        require(handle and model, "Actual handle and model required")
        self._require_owner(agent_id, handle)
        require(
            expected_model is None or expected_model == model,
            "Actual model differs from requested model",
        )
        old = self.state["sessions"].get(agent_id)
        if old is not None:
            require(old["handle"] == handle, "Use explicit session replacement with handoff")
            require(
                old["model"] == model,
                "Effective model changed; replace physical session with handoff",
            )
        self.state["sessions"][agent_id] = {"handle": handle, "model": model}
        self.state["handle_owners"][handle] = agent_id

    def replace(self, agent_id: str) -> Session | None:
        state = self.state
        previous = state["sessions"].get(agent_id)
        require(
            previous is not None or self.acp_name(agent_id) in state.get("acp_created", {}),
            "No session/creation attempt to replace",
        )
        if previous is not None:
            state.setdefault("retired_handles", []).append(previous["handle"])
            del state["sessions"][agent_id]
        epochs = state.setdefault("epochs", {})
        epochs[agent_id] = epochs.get(agent_id, 0) + 1
        return previous

    def request_acp_creation(self, agent_id: str) -> None:
        name = self.acp_name(agent_id)
        require(
            name not in self.state.get("acp_created", {}),
            "Session creation already attempted; reconcile instead of creating again",
        )
        self._require_owner(agent_id, name)
        self.state.setdefault("acp_created", {})[name] = "requested"

    def confirm_acp_creation(self, name: str) -> None:
        require(name in self.state.get("acp_created", {}), "ACP session creation was not requested")
        self.state["acp_created"][name] = "created"
