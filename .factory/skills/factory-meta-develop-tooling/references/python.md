# Python tooling

Target: Python 3.14, factory-owned tools, gates, skill scripts and tests, including
hidden `.factory/` paths. Explicitly exclude venvs, caches, run output and third-party
code. Read actual configuration before
running checks. This bundle ships the checker, explicit configuration and resolved runtime/dev dependency locks.
A check result applies only to its tested source state and environment.

## Contracts and imports

- Annotate function arguments/results; infer ordinary locals. Keep types with their
  contract owner. Results have predictable shapes; readable typed tuples are valid.
- Use TypedDict or dataclass for stable records according to operations and
  serialization needs. Use Literal/Enum for finite states when appropriate.
- Accept external data as object or an explicit JSON type, validate at the boundary,
  then pass typed records internally. An annotation or cast does not validate data.
- Use Pydantic v2 at structured input, publication and persistence boundaries.
  Reuse owned TypedDict contracts with TypeAdapter when mutable dictionaries suit
  consumers. Use standard-library TypedDict where supported by the installed Pydantic version.
  Validate before serializing and hashing new evidence. Check persisted byte
  digests before reading evidence into its typed form.
- Closed factory records use strict types and forbid extra keys in nested records.
  Specify defaults, missing versus null, and any open external projection explicitly.
  Report field and reason without printing raw inputs or exception context.
- Keep authority, workflow and evidence checks with their owners. Keep Markdown/diff
  parsing, duplicate YAML detection, path safety, locks and atomic writes.
- Keep justified Any at dynamic boundaries. No blanket ignore_missing_imports,
  ignore_errors or test exclusions. Ignores name a code and reason; remove stale ones.
- Negative tests do not label invalid fixtures as valid domain values. A deliberate
  typed-API violation may use a narrow, explained ignore.
- Use a small Protocol for an actual replaceable dependency, including test doubles;
  do not require a fake to implement an entire external library.
- Keep the coupled core and process implementations in `factory`;
  process subpackages retain their own responsibilities. The factory is installed
  as a bundle; running a skill separately does not imply its folder is self-contained.
- An autonomous skill helper may stay in that skill's `scripts/`; moving every new
  script into the package is not required. Shared code stays with its package owner.
  Apply the same relevant checks to local scripts.
- No sys.path mutation in working modules; necessary bootstrap stays at entry points.
  Keep CLI entry points thin. Preserve existing commands and callers.

Implement, Decompose and Review freeze the entire `factory` package and
their executable wrappers alongside other run dependencies. Any package change,
including an unrelated module, blocks continuation as drift. Compatibility of saved
runs with an updated factory is not automatic.

Trace a command from the [CLI registry](../../../tooling/factory/cli.py) or
the [Ledger API](../../../tooling/factory/runtime/workflow.py) to its owning
feature. Place a new module with that feature and follow its tests.
When moving code, check callers, CLI wrappers, input locks, import contracts and
eval fixtures for paths assembled from directory and file names.

## Application and storage boundaries

Keep use-case preconditions in the application function or coordinator. CLI handlers
parse arguments, read inputs and render results. Select infrastructure at the
entry point and pass the operations a use case consumes through arguments.
Name each Protocol for its responsibility and its implementation for the technology
or source. Keep SQL and transaction handling inside the database adapter.

Specify which writes succeed or fail together. Preserve each atomic operation across
adapters and retries. Use a shared Unit of Work when one use case must coordinate
separate repository calls in the same transaction. Run the same observable storage
contract tests against every backend alongside its driver-specific integration tests.

Place a transition with the smallest owner that can check all of its conditions.
For example, a dispatch can decide whether it may leave the unknown state. Only
the run can decide whether another agent owns its session handle. Keep the
existing persisted record and test the rule with plain values where possible.
[Dispatch recovery](../../../tooling/factory/runtime/scheduling/dispatch.py)

Two examples from the installed tooling:

- For workflow status, follow the Teacher repository from CLI construction through
  both the finalizer and the pending queue. When testing a new branch, give the
  injected repository a distinguishable result so a fallback to the default
  backend becomes visible. [CLI](../../../tooling/factory/runtime/workflow_cli.py) · [Status query](../../../tooling/factory/runtime/workflow_query.py)
- For an archive change, reopen the same isolated store through a fresh adapter,
  retry the operation and check the history and number of Teacher jobs. A child
  CLI resolves its own backend. If the test starts one, configure that process
  explicitly or exercise the public Python entry point in the test process.
  [RunRepository](../../../tooling/factory/runtime/run_repository.py) · [Shared contract suite](../../../tooling/tests/factory/runtime/test_run_repository_contract.py)

The design rationale comes from *Architecture Patterns with Python*.
[Service Layer](https://www.cosmicpython.com/book/chapter_04_service_layer.html) · [Dependency Injection](https://www.cosmicpython.com/book/chapter_13_dependency_injection.html) · [Repository](https://www.cosmicpython.com/book/chapter_02_repository.html) · [Unit of Work](https://www.cosmicpython.com/book/chapter_06_uow.html)

## Target checks

- Ruff lint and format check: py314, line length 100, double quotes, spaces,
  formatter preview off; lint preview enabled only for explicitly selected rules.
  Rules: E4, E7, E9, F, I, B, UP, RUF100, PGH003, PGH004, S307, S506,
  S602, S110, S112, SIM107, RUF012, PLW1510, C901, PLW1514, RUF018.
  Factory text artifacts use UTF-8. Explain narrow exceptions. No automatic unsafe fixes.
  Use `--no-cache` for direct Ruff commands; format only authorized paths.
- Mypy: strict=true, python_version=3.14, disallow_any_unimported=true;
  include tests and compatible dependency stubs. Pin checker version.
- Unittest: all applicable tools/skill suites. Zero tests in an expected suite
  is a discovery failure. Test contracts, meaningful failures and boundaries.
- Coverage.py: explicit source scope, including unexecuted modules; branch reporting
  and verified subprocess collection through the actual launcher. No universal quota.
- Preparation tests use shipped entry points and temporary project profiles without
  live models, credentials, network or changes to working project data.
- Pip-audit: separate online audit of resolved runtime/dev dependencies when they
  change and before delivery. Unavailable advisory data is not a successful audit.

Import-linter enforces the shipped dependency contracts for the `factory`
namespace. Update a contract only when the intended ownership changes. Retain runtime import-side-effect tests. Deptry, Pylint, Vulture,
standalone Bandit and a second type checker are not mandatory.

## Execution and environments

Use the [project launcher](../../factory-install/references/integration.md#interpreter)
for `cli setup --dev` and `cli tooling check`. Run `cli tooling check --help`
for checker arguments.
Use `--stage` for a focused check and `--stage audit` for the separate online audit.
Keep retained reports in an explicitly selected directory outside the factory.
Factory checks use explicit factory configuration, not the consumer application's.
Check failures/blockers produce nonzero aggregate status; preserve individual results.
Expose stages separately; CI uses the same entry point before integration.

Declare runtime/dev dependencies separately. Pin resolved transitive versions and
stubs reproducibly. Explicit setup may install packages within authorized scope;
normal checks are offline and never install or rewrite source.
Verify runtime in a clean runtime-only environment as well as the dev environment.
Verify the installed copy with a temporary profile, without Lab/specs or AniStar inputs.
Test Python 3.14; verify launchers on
their respective operating systems. Local success does not prove other platforms.
