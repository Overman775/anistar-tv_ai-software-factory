# Dependencies and upstream instructions

Read the linked instructions at execution time for the selected version/platform.
If unavailable, report the missing source; never invent a package or command.
Keep working compatible installs. Record resolved versions; a compatibility range
is not an exact lock. Factory requirements come from this bundle, not app pins.
All new factory-managed tool installations and MCP registrations use the selected
project directory; follow [local scope](integration.md#project-local-scope).
Vendor global defaults are not authorization for global installation.

| Component | Needed when | Source / verification |
| --- | --- | --- |
| Python 3.11+, PyYAML and Pydantic v2 | Own factory tools | [Python](https://www.python.org/downloads/), [venv](https://docs.python.org/3/library/venv.html); [requirements](../../../tooling/requirements.txt), [tool usage](../../../tooling/README.md); run dry run with that interpreter |
| uv | Only if chosen to manage Python/tools | [Installation](https://docs.astral.sh/uv/getting-started/installation/); not mandatory when a working isolated interpreter exists |
| Git | Repository operations | [Installation](https://git-scm.com/downloads); inspect path/version, no repository mutations for diagnosis |
| ripgrep | Standard factory dependency for source discovery and debt-marker search | [Installation](https://github.com/BurntSushi/ripgrep#installation); preserve working `rg`, install if absent, verify path/version and a local search from the agent environment |
| Host integration | Selected native host | Actual exposed capabilities and local adapter: [Codex](../../../adapters/codex.md), [Claude](../../../adapters/claude.md); do not install every host |
| Context7 MCP | Required baseline, independent of project stack | [Official setup](https://github.com/upstash/context7#installation); preserve working project-local connection, verify discovery and a public documentation lookup; [MCP integration](integration.md#mcp) |
| Other MCP servers | Only selected additional connections; may be decided later | Obtain official server and host instructions once selected; [MCP integration](integration.md#mcp). Project-scoped setup requires a target directory, not a formed project profile |
| acpx and selected backend/bridge | Selected ACP route | [Official quickstart](https://github.com/openclaw/acpx/blob/main/docs/quickstart.md), then chosen backend's official instructions; [factory integration](integration.md#acp) |
| Node/package manager | Only if required by selected external tool | Follow that tool's supported versions and official runtime installation links; not a universal prerequisite |
| Graphify | Optional project discovery | [Official installation](https://github.com/Graphify-Labs/graphify#readme), project-local CLI/environment and skill, then read the installed skill; [factory exclusions](exclusions.md) |
| GitHub access / gh | GitHub PR capability | Prefer exposed authenticated plugin; [gh installation](https://cli.github.com/manual/installation) only for needed CLI fallback; plugin authorization does not authenticate gh |

Graphify absence does not block native factory use. No project-specific Graphify
patches or pins are universal requirements. Do not silently replace an existing
patched installation; resolve compatibility before changing it. Graphify's own
instructions own installation and graph refresh; our instructions own corpus policy.

Do not add unrelated third-party skills to this list merely because they are
present beside factory skills. Vendor hooks, indexing, extra clients and model
requests are separate optional actions, not implied by opening vendor instructions.
