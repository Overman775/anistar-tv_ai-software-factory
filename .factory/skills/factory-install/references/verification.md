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

If an actual project profile exists, additionally validate actual configuration:

```sh
.factory/tooling/bin/cli workflow --config .factory/factory.yaml config
```

This command requires the project profile. Report real-project readiness as
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
