# ACP / acpx adapter

Read [shared coordinator adapter rules](common.md) before dispatch.

This adapter implements configured `runner: acpx` through
`.factory/tools/acpx_adapter.py`; it shares the same orchestration/role contracts
as native agents. ACP is the protocol, acpx is the client, and `zcode-acp server`
is the configured bridge to ZCode. None is a replacement for workflow policy.

Syntax is based on acpx v0.21.0 at
`c0b9dfdfad12ed4fc000b8ef2efc4b5644f1c3dc` ([CLI](https://github.com/openclaw/acpx/blob/c0b9dfdfad12ed4fc000b8ef2efc4b5644f1c3dc/docs/CLI.md)).
Pin/install a compatible client and bridge in the consumer, authenticate the
backend, and inspect `acpx --version`/help and actual capabilities. Executables
are not bundled or automatically downloaded. No subscription limits are inferred
from three configured slots.

## Setup and preflight

```bash
sh .factory/tools/python.sh .factory/tools/acpx_adapter.py doctor
sh .factory/tools/python.sh .factory/tools/acpx_adapter.py setup zcode
```

Setup validates executable and merges only `agents.zcode.argv` into the consumer
`.acpxrc.json`. It refuses a conflicting alias and preserves other configuration.
This is a project file change; include it in installation scope, not a task's
secret-bearing history. Credentials stay in provider-managed storage, not YAML.
Doctor only reports executable discovery; it does not prove an authenticated
session or working model. Paths with spaces are individual argv values.

Check model selection, filesystem/terminal access, tool permission behavior,
workspace and session resume support before product work. `models.*.id: null`
accepts the configured default only when no exact user model is required. An
explicit ID is passed with acpx's capability-dependent `--model`; unsupported
selection blocks instead of guessing. Inspect returned `configOptions`/model
metadata and bridge/provider identity. Record actual model using workflow bind;
if identity cannot be established, do not send the task. Unsupported reasoning
mapping is blocked, not silently ignored. A configured alias is not proof of a
particular model/version. Recheck after reconnect or model switch.

## Dispatch

The current helper dispatches Implement graph nodes. Other processes keep their
own dispatch/staging; a context packet alone does not provide an ACP session driver.

1. Parent `claim`s a ready node. Native and connection pools each have three
   slots in shipped YAML, across all roles. Do not use one ACP session for
   parallel agents; ZCode can preempt a concurrent turn in the same session.
2. `acpx_adapter.py prepare NODE` uses the shared context builder to write role/contract,
   worker adapter, applicable stage rules, source assignment and actual required
   project documents to a unique prompt file. Coordinator policies stay with the parent.
   It returns the session name and command argv. Passing a filename without
   reading its content would not load instructions; the helper sends the content.
3. For a new logical agent epoch run `acpx_adapter.py run NODE create`, then
   `... run NODE show`. Creation is journalled first and cannot be blindly
   repeated. Inspect session/model/permission evidence. For continuation reuse
   the existing epoch/session; do not run create again.
4. `workflow.py bind NODE SESSION_NAME ACTUAL_MODEL` persists verified identity.
   For native this handle is a host ID; for this adapter it is the prepared
   unique `(connection, absolute cwd, session name)` identity.
5. `acpx_adapter.py run NODE prompt` launches the argv with `subprocess`, no shell.
   It journals dispatch before sending, stores stdout/stderr and never marks
   the node complete. Parent waits responsively, examines the actual response,
   validates role evidence and calls workflow finish.

The bridge's filesystem access is not limited by an instruction-owned-path list.
Use the consumer's actual sandbox/worktree permissions. No permission expansion
or provider authentication is fabricated by this adapter. The shipped
`approve-reads` + noninteractive `fail` blocks writes requiring interactive
approval. For unattended writers deliberately configure `approve-all` only in
an explicitly authorized isolated workspace, or supply an appropriate supported
policy after verifying its semantics. Do not silently add that flag on failure.

## Status, cancellation and uncertain outcomes

Distinguish the logical assignment, ACP session, prompt turn and local command
process/session. Completion of one does not establish the others' completion.
Use the exposed command wait mechanism; inspect backend status when reconciliation
requires it. Do not resend a prompt merely to request a progress update.

`... run NODE status|show` inspects; `cancel` requests cancellation; `close`
soft-closes the saved session. Parent uses cancel/close only when authorized by
checkpoint contract. These commands never release workflow ownership by
themselves. Local PID/session status is not definitive proof of backend
termination. Confirm terminal protocol result plus workspace/artifact state.

A nonzero create/prompt exit or interruption becomes `unknown`; slots and writes
stay reserved. Do not auto-send a second prompt or create a replacement agent.
Reconcile state/diff/backend; then accept actual evidence or use the bounded
recovery path. Request IDs are not an exactly-once guarantee. Silence is not
failure; one session has one active turn. Distinguish provider capacity feedback
from authentication/balance/model/tool failures; do not retry every HTTP 429.

Provider quotas may be below three. Nested ZCode workflow calls and aliases to
one account do not multiply available capacity. Multiple independent checkouts
need a common external admission owner if they share the same account; the
local ledger is not a distributed semaphore. Do not enable acpx flows as a
parallel/durable scheduler without separate verified support.

After terminalization preserve concise evidence in history; raw prompt/transport
logs are temporary and may contain sensitive source, so do not retain them all
by default. A real integration trial is still required in the consumer project.

ACP sends the frozen JSON assignment with `acpx prompt --file` after binding.
The helper validates the recorded hash and dispatch identity before submission.

## MCP configuration and backend differences

Profile `mcp` entries identify required permitted tools; they are not server
connection definitions and do not contain tool arguments. Resolve each server
alias against the harness tool catalog. Discover parameters via MCP tools/list
inputSchema and pass actual arguments through tools/call. A missing required
tool blocks dispatch; mentioning its name in a prompt does not install it.

The helper does not forward env or mcpServers from factory.yaml. Unsupported
connection fields are rejected. Configure stdio command/args/env or remote
url/headers and credentials in the actual harness, outside factory run state.
The acpx CLI supports --mcp-config, but this helper does not expose that option.
Do not add it as an ignored YAML field or assume ACP injection works in every bridge.

For the ZCode CLI, mcp.servers in ~/.zcode/cli/config.json configures servers;
plugin servers can also be discovered. The current ZCode bridge advertises model
configOptions values as providerId\modelId. Copy the exact advertised value,
including case, rather than substituting a generic model name. ZCode is the
harness; GLM is the model.

svkozak/pi-acp takes model IDs as provider/model. Its MCP parameters are accepted
and stored but not wired into Pi; configure a Pi MCP extension separately.
Pi executes file and terminal operations locally instead of delegating through
ACP fs/terminal. Consequently acpx permission replies and factory read/edit/
commands/web booleans do not establish a sandbox. after_failed_attempts is a
factory coordinator policy, not an ACP or backend retry parameter.

Primary references: [ZCode MCP](https://www.zcode.network/en/docs/mcp-services/),
[ZCode bridge model options](https://github.com/william0wang/zcode-acp/blob/main/src/config/options.ts),
[Pi ACP limitations](https://github.com/svkozak/pi-acp#limitations),
[ACP session setup](https://agentclientprotocol.com/protocol/v1/session-setup),
[MCP tool schema](https://modelcontextprotocol.io/specification/2025-11-25/server/tools).
