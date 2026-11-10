---
name: factory-install
description: "Install, configure, diagnose, update or recover the factory itself and its selected dependencies. Invoked by the user; independent of the application's technology stack."
---

# Factory Install

The user invokes this skill directly, including by asking an agent to read this
file from a downloaded bundle before host discovery is configured. No orchestrator,
project profile, Python or active workflow is needed for initial inventory.
Read [communication](../../contracts/common/communication.md).

## Scope

Own the factory bundle, its Python dependencies, host integration and selected
external capabilities. Do not prepare the application's SDKs, packages, builds,
generated files or domain-specific MCP servers. A target directory may be an
application checkout without making its stack an installation dependency.
Directory membership alone does not make another skill part of the factory.
Install into the selected project directory: factory dependencies, Graphify and MCP
configuration are project-local, never global/user-wide. A target directory is
required even before application code or a project profile exists. See integration
for supported local methods; do not silently fall back to global installation.

## Procedure

1. Determine install, diagnose, update or repair mode; source bundle/version,
   destination, OS/CPU, shell and actual agent host. Distinguish source from target;
   never copy a directory onto itself. Inspect existing files, settings, tool paths,
   versions and active runs. Inventory must not bootstrap tools or download engines.
2. Read [dependencies](references/dependencies.md). Select the host and optional
   capabilities from the request and actual configuration. Open the relevant
   official installation instructions; do not copy vendor recipes into this skill.
   Show exact missing/incompatible components, versions, destinations and changes.
   Existing user authorization applies. Ask only for missing choices or changes
   beyond that authorization; a timeout is not consent.
3. Follow [integration](references/integration.md) to place the owned bundle,
   prepare its interpreter and configure discovery. Preserve user/project/runtime
   settings and unrelated skills. Install only selected dependencies. Use upstream
   instructions for the selected OS/version; their optional steps do not expand scope.
   Context7 MCP is required independently of the project; preserve an existing working
   connection or configure it through the official instructions. Other MCP servers
   are optional and may be selected later. Later requests may configure only MCP through
   [MCP integration](references/integration.md#mcp), without reinstalling the bundle.
4. Apply [exclusions](references/exclusions.md) before any graph build. Keep factory
   and project settings indexable while excluding factory implementation and local
   artifacts. Graph construction and hooks require inclusion in the authorized scope.
5. Run [verification](references/verification.md), including the disposable dry run
   with the actual interpreter available to the agent. Report installed, configured,
   verified and blocked capabilities separately; do not claim live checks from fixtures.

For updates or repair also read [maintenance](references/maintenance.md).
Diagnosis performs read-only inspection; the dry run may create only its disposable
temporary data. Never run a version/doctor command that silently installs missing tools.
Report actual versions, changes, checks and remaining user actions in chat. No automatic
commit, push, publication, project setup, global system upgrade or migration to current.
