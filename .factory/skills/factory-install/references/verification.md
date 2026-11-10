# Verification

Use the project launcher after [Python setup](../../../tools/README.md#python-setup),
from the target root. Native Windows uses python.cmd as documented there:

```sh
sh .factory/tools/python.sh -B .factory/tools/dry_run.py
```

Verify the launcher from a fresh agent command session without prior activation.
Require exit 0 and JSON PASS. The driver tests seven preparation stages with a
synthetic project/configuration: config loading, project context, workflow
reservation and native/ACP dispatch preparation. It cleans temporary files and
never dispatches models. Missing dependencies or files remain failures, not skips.
`--help` alone is not a substitute. See [driver contract](../../../tools/README.md).

The driver covers its fixture routes and required runtime inputs, not the integrity
of every installed skill. Separately check the selected bundle's file inventory,
references, executable permissions and host discovery. No install manifest/updater
or universal runtime freeze of all install references is implemented.

If an actual project profile exists, additionally validate actual configuration:

```sh
sh .factory/tools/python.sh .factory/tools/workflow.py --config .factory/factory.yaml config
```

Check CLI help if flags differ in the selected version. This command requires the
project profile. Its absence does not prevent fixture dry run; report real-project
readiness as pending. Do not generate a fake profile to claim project readiness.

Verify [exclusions](exclusions.md), interpreter/tool visibility and skill discovery.
Confirm the documented project installation is in effect: project files, dependency
resolution, skill discovery and MCP registration use the selected project. Do not
require every executable or package-manager cache to be physically under `.factory/`. Global-only discovery does not prove a local install. Check that no
user-wide host/PATH settings were changed; remote MCP endpoints are compatible with
local registration. Exclude local tool environments/packages from Git and Graphify.
Live native/ACP probes require authorized scope and consume quota. No real model,
authentication, permissions or resume guarantee follows from fixture success.
Do not run app builds, full developer test suites or a production workflow as an
installation smoke check. Report three separate results: factory installed,
selected connections verified, project configured. List NOT_RUN checks honestly.
Context7 MCP is required: verify connection, discovered tools and a harmless public
library documentation lookup. Missing access/authorization remains a required pending
step, not full readiness. Other MCP not selected is not an installation failure. Report actual
connection/tool discovery per consuming environment; fixture PASS and coordinator
discovery do not prove worker/ACP access. Profile grants may remain pending until
the project/runtime profiles are configured.
