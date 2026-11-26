# Developing workflow graphs

Choose the graph that owns the change. Planning may sketch an execution plan.
Decompose emits dependencies between tasks. The four process definitions govern
which action the coordinator can offer in Planning, Decompose, Implement and
Code Review. In Lab, read `specs/workflow-graphs.md` from the selected variant
root for the node syntax, process entry points and persistence contract.

## Trace a route

1. Start in the [process definitions](../../../graphs/). In Implement, a blocked
   attempt goes through `correction_gate` before calling the recovery subgraph.
   [Parent definition](../../../graphs/implement.yaml)
2. In recovery, a Judge request for more checks can also match the general
   terminal-report rule. `requested_checks` (priority 30) wins over
   `terminal_worker` (20) and selects `add_checks`, which offers a Tester
   assignment. The handler checks authority and evidence again at execution.
   [Recovery routes](../../../graphs/implement-recovery.yaml) · [Implement operations and predicates](../../../tooling/factory/runtime/scheduling/orchestrator_graph.py)
3. Edit the YAML to reuse registered outcomes and operations. Add a predicate or
   handler in the owning process when the route needs a new fact or action.
   For changes to the graph language itself, follow the [definition loader](../../../tooling/factory/graphs/definition.py)
   and [Pydantic Graph compiler](../../../tooling/factory/graphs/program.py).

## Verify the change

Use a disposable checkout. Check the offered role and operation on an allowed
route and the hold when required evidence is missing. For overlapping rules,
check which target wins and what happens when different targets tie. Runs pin
their YAML in SQLite at creation. After a definition change, resume the old run
and start a new one to verify which route each uses. For an issued Implement
ticket, read the recorded route with `cli workflow explain NODE --dispatch TICKET --run RUN_ID`.
[Executable CLI and SQLite tests](../../../tooling/tests/factory/runtime/scheduling/test_declarative_graphs.py)

Run the regression suite from the checkout root with the development environment installed.

```sh
PYTHONPATH=.factory/tooling .factory/.venv/bin/python -m unittest tests.factory.runtime.scheduling.test_declarative_graphs
```

For builder steps and decisions, see [Pydantic Graph](https://pydantic.dev/docs/ai/graph/graph/).
For a worked example of calling a child workflow and inspecting its results, see [Fabro sub-workflows](https://docs.fabro.sh/tutorials/sub-workflow).
