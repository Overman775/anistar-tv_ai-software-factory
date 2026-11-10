# Python tooling

Target: Python 3.11+, factory-owned tools, gates, skill scripts and tests, including
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
- Keep justified Any at dynamic boundaries. No blanket ignore_missing_imports,
  ignore_errors or test exclusions. Ignores name a code and reason; remove stale ones.
- Negative tests do not label invalid fixtures as valid domain values. A deliberate
  typed-API violation may use a narrow, explained ignore.
- Use a small Protocol for an actual replaceable dependency, including test doubles;
  do not require a fake to implement an entire external library.
- Keep the coupled core and process implementations in `factory_tooling`;
  process subpackages retain their own responsibilities. The factory is installed
  as a bundle; running a skill separately does not imply its folder is self-contained.
- An autonomous skill helper may stay in that skill's `scripts/`; moving every new
  script into the package is not required. Shared code stays with its package owner.
  Apply the same relevant checks to local scripts.
- No sys.path mutation in working modules; necessary bootstrap stays at entry points.
  Keep CLI entry points thin. Preserve existing commands and callers.

Implement, Decompose and Review freeze the entire `factory_tooling` package and
their executable wrappers alongside other run dependencies. Any package change,
including an unrelated module, blocks continuation as drift. Compatibility of saved
runs with an updated factory is not automatic.

## Target checks

- Ruff lint and format check: py311, line length 100, double quotes, spaces,
  preview off. Rules: E4, E7, E9, F, I, B, UP, RUF100, PGH003, PGH004,
  S307, S506, S602. Explain narrow exceptions. No automatic unsafe fixes.
  Use `--no-cache` for direct Ruff commands; format only authorized paths.
- Mypy: strict=true, python_version=3.11, disallow_any_unimported=true;
  include tests and compatible dependency stubs. Pin checker version.
- Unittest: all applicable tools/skill suites. Zero tests in an expected suite
  is a discovery failure. Test contracts, meaningful failures and boundaries.
- Coverage.py: explicit source scope, including unexecuted modules; branch reporting
  and verified subprocess collection through the actual launcher. No universal quota.
- Safe dry run: shipped entry points, temporary project profile, no live models,
  credentials, network or changes to working project data. Verify these restrictions.
- Pip-audit: separate online audit of resolved runtime/dev dependencies when they
  change and before delivery. Unavailable advisory data is not a successful audit.

Import-linter enforces the shipped dependency contracts for the `factory_tooling`
namespace. Update a contract only when the intended ownership changes. Retain runtime import-side-effect tests. Deptry, Pylint, Vulture,
standalone Bandit and a second type checker are not mandatory.

## Execution and environments

Use [Python setup and launchers](../../../tools/README.md); do not fall back to a
global interpreter. Run `check.py` through that launcher after explicit `setup --dev`.
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
Test Python 3.11 and the selected current supported version; verify launchers on
their respective operating systems. Local success does not prove other platforms.
