# Verification

From the target root, after [interpreter setup](integration.md#interpreter),
verify the launcher in a fresh agent command session:

```sh
.factory/tooling/bin/cli help --json
```

Native Windows uses `.\.factory\tooling\bin\cli.cmd`. Require exit 0 and
machine-readable command discovery from the prepared environment. Separately
check the selected bundle's file inventory, references, executable permissions
and host discovery.

If an actual project profile exists, additionally validate actual configuration.
For a scope-limited configuration edit, load the candidate without CLI journal writes:

```sh
.factory/.venv/bin/python -B -c "from pathlib import Path; from factory.runtime.workflow_config import load_config; load_config(Path('.factory/factory.yaml')); print('configuration loaded')"
```

Native Windows uses the prepared `.factory\.venv\Scripts\python.exe` interpreter.
Read the selected profile/model/adapter fields needed by the request from this
loaded result; do not dump unrelated credentials. This verifies configuration
consistency, not backend availability or enforcement.

`cli workflow --config .factory/factory.yaml config` writes the diagnostic journal,
even when its main operation reads configuration. Do not run it in the target when
only factory.yaml or another bounded set of files is writable. Inspect CLI command
metadata before other validation too. For a needed journal-producing validation,
use a disposable external copy of the actual candidate, preserving its selected
profile, linked definitions, relative layout and applicable dependencies. Execute
there and label the evidence as candidate-copy validation; do not substitute a
fixture or claim a live run. Do not delete or overwrite target diagnostics, existing
caches or unrelated files to make a scope check pass. Disable Python bytecode writes
with `-B` for read-only imports.

Configuration loading requires the project profile. Report real-project readiness as
pending when the profile is absent. Do not generate a fake profile to claim project readiness.

Verify [exclusions](exclusions.md), interpreter/tool visibility and skill discovery.
Confirm the documented project installation is in effect: project files, dependency
resolution, skill discovery and MCP registration use the selected project. Do not
require every executable or package-manager cache to be physically under `.factory/`. Global-only discovery does not prove a local install. Check that no
user-wide host/PATH settings were changed; remote MCP endpoints are compatible with
local registration. Exclude local tool environments/packages from Git and Graphify.
Live native/ACP probes require authorized scope and consume quota. Verify model, authentication, permissions and resume only within the live probe scope.
Do not run app builds, full developer test suites or a production workflow as an
installation smoke check. Report three separate results: factory installed,
selected connections verified, project configured. List NOT_RUN checks honestly.
Context7 MCP is required: verify connection, discovered tools and a harmless public
library documentation lookup. Missing access/authorization remains a required pending
step, not full readiness. Other MCP not selected is not an installation failure. Report actual
connection/tool discovery per consuming environment; check worker/ACP access in the environments that consume it. Profile grants may remain pending until
the project/runtime profiles are configured.
