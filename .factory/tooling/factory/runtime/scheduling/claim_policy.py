"""Decide resource contention against an already validated checkout snapshot."""

from factory.runtime.contracts import Node, State
from factory.runtime.workflow_core import require
from factory.runtime.workflow_graph import overlaps


def check_contention(
    s: State, nodes: dict[str, Node], node: Node, pool_name: str, *, has_active_commands: bool
) -> None:
    busy = [k for k, v in s["nodes"].items() if v["status"] in {"reserved", "running", "unknown"}]
    used = sum(s["nodes"][k]["pool"] == pool_name for k in busy)
    require(used < s["config"]["_limits"][pool_name], "QUEUED_CAPACITY")
    for k in busy:
        other = nodes[k]
        require(node["agent"] != other["agent"], "One active turn per logical agent")
        require(
            not overlaps(node.get("owns", []), other.get("owns", [])),
            "QUEUED_OWNERSHIP",
        )
        require(
            not set(node.get("resources", [])) & set(other.get("resources", [])),
            "QUEUED_RESOURCE",
        )
        # Authoritative verification observes a quiescent shared checkout.
        require(
            not (
                (node["stage"] in {"verify", "review"} and other.get("owns"))
                or (other["stage"] in {"verify", "review"} and node.get("owns"))
            ),
            "QUEUED_SNAPSHOT",
        )
    require(
        not has_active_commands
        or not (node.get("owns") or "project-checks" in node.get("resources", [])),
        "QUEUED_COMMAND_RESOURCE",
    )
