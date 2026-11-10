# Project checks

Read the selected profile command rules and current project command definitions.
Populate required_checks from the resolver plus task-specific acceptance checks.
Never replace missing project tools with fixtures. Commands retain exact argv, cwd,
timeout and mandatory inputs. Add exact task-specific input files (command definitions,
configuration, tests and dependencies outside task scope); never remove profile inputs.
The runner snapshots their union with task scope. Unknown applicability blocks execution.

Slice tests remain mandatory. Run-wide checks belong to the final verification
assignment (the sole task in a one-task run). Final Judge verifies then reviews;
an eligible solo Generalist retains SELF_REVIEW. Serialize shared project checks.
The profile adds requirements, never changes role permissions or verdict authority.

## Diagnose before a broad rerun


After a failure, inspect the actual error, expected behavior, test setup and
runtime assumptions. Under the existing assignment, permissions and command
reservation, use the smallest scenario that can expose the suspected cause.
A broad diagnostic run is appropriate when the failure requires suite interactions
or cannot be isolated; state that reason. Do not repeat a broad run blindly.
Route corrections to their owner through the coordinator and existing retry budgets.
After correction, rerun the selected scenario, then satisfy the applicable final
gates on the final tree. Focused success does not replace full-suite acceptance.
Use the current project's supported selectors; do not invent flags or wrappers.
Match evidence to the actual affected boundary; isolated fixtures do not establish live behavior.
