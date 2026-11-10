# Factory integration

## Bundle and host

Identify owned files from the selected source bundle and its documentation/version.
Install its roles, contracts, gates, workflow, own tools and factory skills with
required references/scripts/licenses. Do not copy all of `.factory/` blindly:
project settings, other skills, caches and credentials have different owners.
A Lab variant supplies files from `src/`, not its `meta/`, specs or experiments.
No global multi-project installation or automatic package updater is implemented.

## Project-local scope

Require a selected project root, which may be empty before the application is
formed. Use each tool's documented project installation mode from that root.
The vendor determines its project files, package/environment locations and host
registration. Do not invent a common installation directory or relocate vendor
files under `.factory/`. Install Graphify and its skill for this project; register
MCP in the host's supported project configuration. Do not invent installer flags.
Keep factory dependencies separate from application dependencies where the documented
method supports this; do not rewrite the vendor's layout to enforce our own.

Do not run global/user-wide package installs, register global MCP servers, or edit
user-wide host settings and shell PATH profiles. Existing host applications and base
interpreters may be used without changing them; this does not replace project-local
packages/configuration. If a required runtime or supported local method is absent,
report that prerequisite/blocker instead of silently installing globally.

Use project launch paths and the host's documented project configuration. Preserve
other projects and global settings. An existing global connection/tool alone does
not satisfy local setup. Do not delete it; configure a project-specific instance or
binding using supported precedence, without duplicate registrations in this project.
If the host cannot scope a required connection to this project, report it blocked.
If the host disables project configuration until the user trusts the directory,
explain the supported trust step and wait for the user to complete it in the host.
Do not bypass trust or change user-wide settings. Recheck the effective project
configuration after trust/reload; a file on disk or a global plugin is not proof.
A remote MCP endpoint may remain remote: its registration belongs to this project;
local scope does not require self-hosting the remote service. Use supported secret
storage without committing credentials; global registration is not a substitute.


Compare existing target files before replacing them. Preserve local changes;
show conflicts rather than overwriting. Do not use AniStar project/runtime settings
as defaults for another application. Preserve existing `factory.yaml`; for a new
configuration use the example as a schema guide, choosing actual available profiles,
models, adapters and permissions. Remove inapplicable sample MCP grants instead of
installing the sample's application tools. Never invent project commands or gates.
Finish this step with an explicit result: selected runtime profiles configured and
validated, or pending with missing inputs listed (host, model, permissions, project
profile). Do not fill gaps with sample AniStar settings. A project profile may remain
pending while factory files are installed; neither fixture PASS nor installed files
mean the actual profiles are runnable.

Read only the selected adapter. Check actual skill discovery in the host. Where
supported, use one canonical skill copy and host discovery links; preserve existing
`.claude/skills` and other host files. Do not generate persistent role wrappers.
Merge a necessary project entrypoint into existing instructions; never replace an
existing AGENTS.md or user host configuration. Explain a required host reload.

## Interpreter

Follow [Python setup](../../../tools/README.md#python-setup). Inventory Python first;
if missing or too old, obtain official OS/distribution installation instructions.
Do not assume Homebrew, a Python launcher, sudo or an existing PATH entry. Explain
any required user/system action; never overwrite system Python. This prerequisite
is separate from project packages and requires authorized scope.

Use the chosen Python 3.11+ only to run `tools/python_runtime.py setup`. That helper
creates the factory-owned `.factory/.venv/` and installs tools/requirements.txt there.
This standard Python environment does not change vendor project-install layouts.
Do not add factory packages to application manifests or install them globally.

All later factory Python commands use `sh .factory/tools/python.sh` on macOS/Linux,
or `.\.factory\tools\python.cmd` on native Windows, followed by the script and args.
Record this convention in the project's existing agent entrypoint without replacing
its content. Do not record machine-absolute paths or rely on activation. From a fresh
agent command session run launcher `--check` and the dry-run script; report actual
interpreter and results. Do not claim Windows/Linux verified from a macOS test.

## MCP

Context7 MCP is the required baseline, even before application code exists. Preserve
an existing working project-local connection; otherwise obtain the [official Context7 instructions](https://github.com/upstash/context7#installation)
and follow their MCP setup for the selected host. Choose MCP mode, not a CLI/skill
substitute; do not automatically install unrelated vendor bundles or rules. No local
server/runtime is required merely by this policy: use a supported connection method.
Verify tool discovery and a harmless public-library documentation lookup without
sending project code or secrets. Verify actual tool names rather than assuming aliases.

If authorization, host support or access is missing, continue independent installation
steps but report the required Context7 connection as pending/blocked; do not declare
full installation readiness. An explicit user exclusion is recorded as an exception.
Other MCP servers are optional: an unknown project does not require guessing them or
creating a placeholder profile. An MCP-only follow-up uses the existing installation.
Required connection availability does not automatically grant every role MCP access.

1. Identify Context7 plus any additionally selected servers and their consuming environments: coordinator,
   native workers or a particular ACP backend. Inspect existing connections first.
   A profile's `mcp` list grants tool use; it is not a package installation manifest.
2. Obtain the selected server's and host's official setup instructions at execution
   time. Local servers may need an executable/runtime; remote servers may need only
   an endpoint and authorization. Keep vendor recipes external. Unavailable sources
   block only the affected connection, not independent factory installation.
3. Configure the host's documented project scope in the selected target directory.
   A formed application or factory project profile is not required. Preserve other
   servers/settings; if project scoping is unsupported, report the connection blocked.
   Use provider authentication and secret storage, never tracked secrets.
4. Check connection/authentication and discover actual tool names in each intended
   consuming environment. Coordinator access does not prove worker or ACP access.
   Do not run write-capable business tools merely to test connectivity. If worker
   discovery requires a model call, perform it only within authorized scope or mark
   that environment NOT_RUN. Factory dry run does not test MCP.
5. When real profiles exist, reconcile selected tool grants with verified names and
   host alias mappings, without widening role permissions. Without profiles, report
   host connection readiness separately; grants remain pending. MCP availability
   does not grant every role access and `enforcement: instructions` is not isolation.

Report each selected connection as ready for the verified environment, awaiting
authorization, blocked or unverified. A later task requiring an unavailable MCP
remains blocked for that capability even if the factory installation succeeded.
Project-specific SDK/server prerequisites belong to project setup; report the
dependency rather than silently expanding factory installation into app setup.

## ACP

Read [the selected adapter](../../../adapters/acpx.md) and the upstream instructions
linked in [dependencies](dependencies.md). Install only the client and bridge for
the selected connection. The executable name does not necessarily name a package.
Use the selected config and the verified interpreter from the target root:

```sh
sh .factory/tools/python.sh .factory/tools/acpx_adapter.py --config .factory/factory.yaml doctor --connection CONNECTION
sh .factory/tools/python.sh .factory/tools/acpx_adapter.py --config .factory/factory.yaml setup CONNECTION
```

Replace CONNECTION with the actual selected alias; setup is a mutation, not diagnosis.
It preserves other registry entries and rejects conflicts. These commands require a
valid factory/project config; if it is pending, report ACP configuration as pending.
Doctor returns JSON with `errors`; exit 1 means at least one checked executable is
unavailable, exit 0 requires no errors. Without `--connection` it checks every
configured route; installation checks only selected routes plus the shared client.
Always inspect `errors`, including with older helpers that returned exit 0 on errors.
Doctor checks executable availability only, not MCP, authentication or a model call.
Keep authorization in provider/host
storage, not YAML, Git or chat. Do not change model, permission mode or tariff to
make a check pass. Do not install all clients named in example configurations.

Use native host capability discovery for native readiness; an unavailable optional
ACP route does not invalidate working native routes. Live sessions are checked only
within authorization, in a disposable workspace without application code. Verify
model, response and continuation separately, close only the created test session,
and inspect unknown outcomes before retrying. No live probe is implied by dry run.

## Skill discovery

Install factory-owned skills under `.factory/skills/`. Keep `.agents/skills/`
and `.claude/skills/` as real directories. For each selected factory skill create
a relative link directly to `../../.factory/skills/NAME`. Preserve other skills.
When replacing a legacy `.claude/skills -> ../.agents/skills` link, first inventory
all entries and create individual Claude links to every previously visible
third-party entry at `../../.agents/skills/NAME`; do not move it. Refuse occupied
conflicting names or unavailable symlink support and report each failure separately.
Test opening a skill, its linked contract and a script from each selected host.
If Markdown resolution follows the visible link rather than the real skill path,
open the canonical `.factory/skills/NAME/...` path explicitly. Scripts resolve
their own real path before deriving roots.
