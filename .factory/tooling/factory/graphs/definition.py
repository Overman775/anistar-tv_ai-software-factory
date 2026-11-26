"""Load the transitive closure of one process. Identifiers are local to a definition."""

from collections.abc import Callable, Iterable
from graphlib import CycleError, TopologicalSorter
from pathlib import Path
from typing import Annotated, Self

from pydantic import BaseModel, ConfigDict, Field, PositiveInt, model_validator

from factory.project.profile_io import parse_yaml

type Name = Annotated[str, Field(pattern=r"^[a-z][a-z0-9_-]*$")]


class Record(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", frozen=True)


class Route(Record):
    outcome: Name
    target: Name
    priority: int = 0
    requires: list[Name] = Field(default_factory=list)


class Action(Record):
    operation: Name
    after: Name | None = None
    limit: PositiveInt | None = None


class Selection(Record):
    decision: Name
    routes: list[Route] = Field(min_length=1)
    limit: PositiveInt | None = None


class Call(Record):
    call: Name
    after: Name | None = None
    limit: PositiveInt | None = None


type Node = Action | Selection | Call


def targets(node: Node) -> tuple[str, ...]:
    if isinstance(node, Selection):
        return tuple(dict.fromkeys(route.target for route in node.routes))
    return (node.after,) if node.after else ()


class Definition(Record):
    id: Name
    entry: Name
    nodes: dict[Name, Node] = Field(min_length=1)
    assignments: dict[Name, Name] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_paths(self) -> Self:
        if self.entry not in self.nodes:
            raise ValueError(f"{self.id}: unknown entry {self.entry}")
        edges = {name: targets(node) for name, node in self.nodes.items()}
        for name, children in edges.items():
            missing = set(children) - self.nodes.keys()
            if missing:
                raise ValueError(f"{self.id}/{name}: unknown target {sorted(missing)}")

        def visit(start: Iterable[str], links: dict[str, tuple[str, ...]]) -> set[str]:
            seen: set[str] = set()
            pending = list(start)
            while pending:
                item = pending.pop()
                if item not in seen:
                    seen.add(item)
                    pending.extend(links[item])
            return seen

        unused = self.nodes.keys() - visit([self.entry], edges)
        if unused:
            raise ValueError(f"{self.id}: unreachable nodes {sorted(unused)}")
        parents: dict[str, list[str]] = {name: [] for name in edges}
        for name, children in edges.items():
            for child in children:
                parents[child].append(name)
        exits = [name for name, children in edges.items() if not children]
        trapped = self.nodes.keys() - visit(exits, {k: tuple(v) for k, v in parents.items()})
        if trapped:
            raise ValueError(f"{self.id}: nodes without exit {sorted(trapped)}")
        try:
            TopologicalSorter(
                {k: v for k, v in edges.items() if self.nodes[k].limit is None}
            ).prepare()
        except CycleError as exc:
            raise ValueError(f"{self.id}: cycle without a finite limit: {exc.args[1]}") from exc
        return self


def parse(name: str, raw: str) -> Definition:
    try:
        definition = Definition.model_validate(parse_yaml(raw))
    except ValueError as exc:
        raise ValueError(f"Invalid workflow definition {name}: {exc}") from exc
    if name != definition.id:
        raise ValueError(f"{name}: declared graph ID is {definition.id}")
    return definition


def load(directory: Path, entry: str) -> dict[str, str]:
    """Capture exact YAML text, including nested definitions, before creating a run."""

    def read(name: str) -> str:
        path = directory / f"{name}.yaml"
        if path.is_symlink() or directory.is_symlink() or path.parent != directory:
            raise ValueError(f"Invalid workflow definition path: {name}")
        try:
            return path.read_bytes().decode("utf-8")
        except (OSError, UnicodeError) as exc:
            raise ValueError(f"Cannot load workflow definition {name}: {exc}") from exc

    return closure(entry, read)


def closure(entry: str, read: Callable[[str], str]) -> dict[str, str]:
    documents: dict[str, str] = {}

    def capture(name: str, ancestors: tuple[str, ...]) -> None:
        if name in ancestors:
            raise ValueError("Recursive workflow calls: " + " -> ".join((*ancestors, name)))
        if name in documents:
            return
        raw = read(name)
        definition = parse(name, raw)
        documents[name] = raw
        calls = {key: node.call for key, node in definition.nodes.items() if isinstance(node, Call)}
        for key, target in [*calls.items(), *definition.assignments.items()]:
            try:
                capture(target, (*ancestors, name))
            except ValueError as exc:
                raise ValueError(f"{name}/{key}: {exc}") from exc

    capture(entry, ())
    return documents
