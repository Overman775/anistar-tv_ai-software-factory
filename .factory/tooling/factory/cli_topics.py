"""Operating guidance shown alongside arguments from the live command parsers."""

from __future__ import annotations

import argparse

from factory.cli_metadata.lessons import LESSONS_HELP
from factory.cli_metadata.model import Details
from factory.cli_metadata.operations import OPERATIONS_HELP
from factory.cli_metadata.workflow import WORKFLOW_HELP
from factory.cli_output import CLI_ERROR_GUIDANCE, LAUNCHER

GUIDES = {
    "agents": """Factory CLI for agents

Run from the project root. Start at the step that matches your role and evidence.

New coordinator
  {cli} workflow config
  Use the returned pin for workflow read-instructions.
  Follow the intake sequence in `{cli} help start`.

Resuming coordinator
  {cli} workflow status --json
  Read result.runnable, result.acceptance, result.results, and result.blockers
  before deciding on the next transition. Run result.read_commands[NODE] for
  evidence about the named attempt. Use --after with the returned cursor when
  checking for changes in the same run.

Agent worker with an assignment
  Run the packet's read_command in its read_shell. Follow its instructions for
  reading each chunk and supplying the final acknowledgement to confirm_command.
  Follow the assigned role and scope. Delegate registered checks to the command
  worker using the issued run_command with the
  provided node, dispatch, check and request IDs. Review result.result before
  preparing a report. Use the execution IDs from checks results:
  {cli} workflow prepare-report NODE - EXECUTION_ID --json
  {cli} workflow prepare-report NODE DRAFT_ID EXECUTION_ID --json
  Send the returned report_id to the coordinator for workflow finish.

Blocked or missing a check response
  Read workflow status and copy the attempt command from result.read_commands.
  When the check printed an execution ID, read its durable result:
  {cli} checks results EXECUTION_ID --json
  If stdout was lost, repeat the issued checks run command with the original
  --request and --dispatch. This gets or reconciles the same execution. Reconcile an
  interrupted execution with checks reconcile EXECUTION_ID when directed by
  the evidence. Run `{cli} help errors CODE` for a coded block.

To inspect an archived attempt:
  {cli} workflow explain NODE --dispatch DISPATCH --run RUN --json
The report, events, checks and artifacts belong to that attempt.
An archived attempt is evidence, and its identifiers may differ from current
work. Use {cli} help COMMAND SUBCOMMAND for exact arguments or
{cli} help --json for the catalog. Workflow decisions stay with the coordinator.
""",
    "start": """Intake a new run from the project root

1. If the launcher reports that its Python environment needs setup, run
   {cli} setup
   This requires Python 3.14 and can install hash-locked dependencies into
   .factory/.venv. Use `{cli} setup --dev` when developing the tooling.
2. When resuming, start with {cli} workflow status. Continue from the
   returned run. For a fresh checkout a missing-current-run error indicates
   that there is no run to resume.
3. To start a new run, preview the configured workspace selection:
   {cli} workflow prepare-workspace --dry-run
   Apply workspace selection when authorized. If the command selects another
   checkout, use its workspace and config as explicit family options.
4. Obtain the configuration pin before reading instructions:
   {cli} workflow config
   {cli} workflow read-instructions CONFIG_PIN workflow/orchestration.md
   Replace CONFIG_PIN with the returned digest. Read and follow the pinned workflow
   instructions to prepare the graph and required source evidence.
5. Validate and initialize the approved graph:
   {cli} workflow validate PROPOSAL_ID
   {cli} workflow init PROPOSAL_ID --config-pin CONFIG_PIN
   Replace PROPOSAL_ID with the published graph proposal ID. Read workflow status for
   runnable nodes, results, acceptance work and blockers.

Put shared options between the family and the operation, for example
{cli} workflow --workspace WORKSPACE --config FACTORY_YAML status.
Run {cli} help agents to find the coordinator, worker and recovery entry points.
""",
    "concepts": """Workflow identities

A run pins the accepted graph, configuration, project policy, and source
snapshot. A node is a graph step. A dispatch identifies one attempt at that
node. A check execution identifies one request for an assigned check in that
dispatch. Use the IDs returned by the CLI.

Assignment packets carry inputs and the recipient. Read packet chunks in order,
acknowledge the previous chunk, and confirm the required materials when reading
is complete. Validate reports and verify receipts through the CLI. Accepted
history keeps the verified evidence for a terminal run.

Read current workflow status:
  {cli} workflow status --json
Copy the attempt command from result.read_commands to inspect that attempt.
Run {cli} help checks for the check command list.
""",
    "states": """Read the owning command's state before taking action

- Read workflow readiness with {cli} workflow status --json. Use the command
  in result.read_commands to inspect one node and dispatch. A queued reason is diagnostic guidance:
  use {cli} help errors CODE for the specific blocker.
- A running assignment holds its dispatch identity. An unknown outcome requires
  terminal evidence before resolution or retry. Check the actual runner or
  session before deciding.
- {cli} checks results EXECUTION_ID reads durable check results.
  {cli} checks reconcile EXECUTION_ID handles an interrupted execution. Read the
  result before retrying a check.
- PASS, FAIL, BLOCKED, and NOT_RUN describe gate evidence. Use the corresponding
  workflow or review command to interpret evidence in its current scope.
""",
    "errors": """Error codes come from CLI errors, workflow evidence and diagnostic events.
Run {cli} help errors CODE for recovery guidance. Inspect error.message in JSON mode or stderr in text mode,
then check the current state.
""",
    "exit-codes": """Exit codes

0 means the CLI operation succeeded. Inspect returned JSON for gate, workflow,
or transport status; a successful read can return a blocked or failed record.
1 generally means operation failure or a rejected action. Gate validators may
use 1 for a failed verdict.
2 means invalid CLI syntax or a gate command that explicitly distinguishes
blocked evidence. Read the returned error or verdict for the distinction.

For command-specific details run {cli} help COMMAND SUBCOMMAND.
""",
    "json": """Machine-readable output

Every command accepts --help and --json. To inspect a command without running it:
  {cli} workflow status --help --json
To run it and read the result:
  {cli} workflow status --json
  {cli} checks results EXECUTION_ID --json

A completed command in JSON mode writes one UTF-8 JSON value to stdout. Read the
owning command's fields and the process exit code. Progress goes to stderr.
CLI errors carry ok=false and error.code, error.message and, when known,
error.next_action. A checker or gate can return its own verdict with a nonzero
exit code. Reading a previously failed check can itself succeed.

Run {cli} help --json to discover commands, arguments, output formats, effects
and supports_dry_run. A supported preview accepts --dry-run --json. For the
default OTLP JSON Lines protocol, run `{cli} telemetry journal` without --json.
""",
    "dry-run": """Preview a supported operation with --dry-run

The command catalog exposes supports_dry_run for each operation. Run
{cli} help COMMAND SUBCOMMAND to see the supported preview and its prerequisites.
A preview checks available inputs and shows the proposed action. Actual actions
apply their own validation again because the runtime can change after a preview.

Examples with existing inputs:
  {cli} workflow claim NODE --dry-run
  {cli} checks run NODE CHECK --request REQUEST_ID --dispatch DISPATCH --dry-run
  {cli} workflow prepare-workspace --dry-run
  {cli} acpx setup CONNECTION --dry-run

Claim validates readiness without creating the assignment or reserving resources.
Check run validates the registered command and shows its planned stages without
starting a process or recording an execution. Workflow retry shows budget and
affected nodes without replacing the attempt. Workspace preparation and ACPX
setup preview their intended local changes without applying them.
""",
}


ERROR_GUIDANCE = {
    **CLI_ERROR_GUIDANCE,
    "SOURCE_DRIFT": "Review the changed inputs. Use workflow reintake only after the owner authorizes the new source.",
    "RETRY_BUDGET_EXHAUSTED": "Read the recorded attempts and diagnosis. Escalate with evidence for an owner decision.",
    "QUEUED_CAPACITY": "Wait for a configured worker slot to become free and read workflow status again.",
    "QUEUED_OWNERSHIP": "Check the active owner and wait for its ownership release.",
    "QUEUED_RESOURCE": "Read current resource reservations and wait for the required capacity.",
    "QUEUED_SNAPSHOT": "Read the active snapshot gate and confirm the required source evidence.",
    "stale_dispatch": "Read workflow status. Use the dispatch from the current assignment and regenerate the request against it.",
    "check_request_conflict": "Use checks results for the existing execution. Submit changed commands only as a new authorized request.",
    "check_resource_missing": "Read the node's current resources and advance workflow scheduling until its project-checks reservation is held.",
    "unassigned_check": "Read the current packet or project checks and use the check ID assigned to this dispatch.",
    "dispatch_not_running": "Read workflow status. Bind the current assignment to the intended session before running checks or preparing a report.",
    "packet_pending": "Finish the outstanding packet read and confirmation before requesting checks.",
    "invalid_report_draft": "Correct the report to the current assignment's contract, then validate it again.",
    "report_evidence_exists": "Read the immutable report evidence. Use the workflow's supported correction path for changes.",
    "stale_report": "Read the active dispatch and pin the report to the current assignment.",
    "duplicate_receipt": "Submit each verified receipt only once.",
    "receipt_unavailable": "Use checks results to read the durable result and a completed receipt.",
    "stale_receipt": "Use the receipt from the current dispatch and matching declared check.",
    "packet_chunk_invalid": "Use the available packet ordinals beginning at chunk 1.",
    "packet_ack_mismatch": "Copy the previous chunk's exact ordinal and digest.",
    "packet_out_of_order": "Read the packet sequentially. Restart at chunk 1 when the delivery receipt was lost.",
    "packet_confirmation_invalid": "Confirm the final chunk's ordinal and digest and the exact mandatory materials.",
    "packet_recipient_mismatch": "Use the intended recipient from the current prepared packet.",
    "packet_bootstrap_mismatch": "Use current bootstrap fields from workflow prepare-packet.",
    "database_busy": "Wait for the current SQLite writer, then read status before retrying.",
    "database_constraint": "Read the rejection message and current workflow state before retrying.",
    "database_corrupt": "Preserve the affected database and restore from a verified backup before resuming.",
    "database_error": "Inspect workflow diagnostics and SQLite availability before retrying.",
    "database_schema": "Start in a clean workspace with a fresh factory database.",
    "receiver_auth": "Check the configured receiver credential source and authentication before retrying export.",
    "receiver_http": "Check the configured receiver endpoint and inspect its HTTP response.",
    "receiver_protocol": "Check the configured receiver's OTLP protocol and URL.",
    "receiver_rejected": "Inspect receiver logs and the configured OTLP endpoint for the rejected payload.",
    "receiver_unavailable": "Check receiver reachability and retry after recovery.",
    "io_error": "Check the command's input paths, permissions and disk state.",
    "missing_key": "Check required input keys against the command contract.",
    "invalid_operation": "Correct the input or state identified by the error message.",
    "runtime_error": "Read workflow diagnostics for the affected invocation and inspect the underlying runtime error.",
    "executable_unavailable": "Run acpx doctor and check the configured executable and local environment.",
}


def collect_command_help(*declarations: tuple[str, Details]) -> dict[str, Details]:
    commands: dict[str, Details] = {}
    for command, details in declarations:
        if command in commands:
            raise ValueError(f"Duplicate CLI help declaration for {command!r}")
        commands[command] = details
    return commands


COMMAND_HELP = collect_command_help(*OPERATIONS_HELP, *WORKFLOW_HELP, *LESSONS_HELP)


def help_details(path: tuple[str, ...]) -> Details:
    command = " ".join(path)
    if command not in COMMAND_HELP:
        raise ValueError(f"Missing CLI help declaration for {command!r}")
    return COMMAND_HELP[command]


def command_summary(path: tuple[str, ...]) -> str:
    details = help_details(path)
    return details.summary or details.description


def guide(path: list[str], parser: argparse.ArgumentParser) -> str:
    if path[0] == "errors":
        if len(path) == 1:
            return GUIDES["errors"] + "\nKnown codes:\n  " + "\n  ".join(sorted(ERROR_GUIDANCE))
        if len(path) != 2 or path[1] not in ERROR_GUIDANCE:
            parser.error(f"unknown error code; see `{LAUNCHER} help errors`")
        return f"{path[1]}\n\n{ERROR_GUIDANCE[path[1]]}"
    if len(path) != 1:
        parser.error(f"unexpected argument for help {path[0]}")
    return GUIDES[path[0]].replace("{cli}", LAUNCHER)
