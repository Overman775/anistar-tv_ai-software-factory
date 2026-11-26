"""Command help for lessons and Teacher jobs."""

from factory.cli_metadata.model import CONFIG, details
from factory.cli_output import LAUNCHER

TEACHER = (
    f"A current Teacher job in this checkout. Use the event ID from `{LAUNCHER} lessons pending`."
)

TEACHER_WRITE = TEACHER + " For a run event, use the bound Teacher assignment dispatch."

LESSONS_HELP = (
    details(
        "lessons",
        "Search lessons and coordinate Teacher jobs.",
        "A project checkout.",
        "Depends on the selected command.",
        "search 'retry project checks'",
        summary="Find lessons and coordinate Teacher jobs",
    ),
    details(
        "lessons retune",
        "Recover a direct Teacher assignment for the selected cases.",
        "Case, counterexample and procedure bytes together with the owner instructions.",
        "Stores independently observed paired trials and the Teacher comparison in SQLite.",
        "status --run ASSIGNMENT_ID",
        writes=("workflow-state",),
    ),
    details(
        "lessons search",
        "Search active lessons and accepted historical evidence.",
        "A query; use --run and --dispatch for an active assignment.",
        "Reads lesson data and can refresh the index and record search evidence.",
        "'retry project checks'",
        writes=("lesson-cache", "diagnostics"),
    ),
    details(
        "lessons telemetry",
        "Read local lesson evidence.",
        "A project checkout with a local lesson projection.",
        "Prints lesson records as JSON.",
        "--limit 10",
        writes=("diagnostics",),
    ),
    details(
        "lessons capture-case",
        "Send demonstrated reuse to Teacher.",
        "An accepted result reference and the observed evidence of reuse.",
        "Enqueues a Teacher job.",
        "RUN NODE DISPATCH 'The approved check resolved repeated failure'",
        writes=("teacher-queue", "diagnostics"),
    ),
    details(
        "lessons feedback",
        "Read lesson searches for an accepted incident.",
        TEACHER,
        "Prints the incident's search evidence.",
        "EVENT INCIDENT",
        writes=("diagnostics",),
    ),
    details(
        "lessons pending",
        "List current Teacher jobs ready for work.",
        "A project checkout.",
        "Prints pending jobs as JSON.",
        "",
        writes=("diagnostics",),
    ),
    details(
        "lessons waiting",
        "List current Teacher jobs waiting on the owner.",
        "A project checkout.",
        "Prints parked jobs as JSON.",
        "",
        writes=("diagnostics",),
    ),
    details(
        "lessons route",
        "Resolve routing for a Teacher job.",
        TEACHER,
        "Computes the Teacher route.",
        "EVENT",
        writes=("diagnostics",),
    ),
    details(
        "lessons reply",
        "Answer the open question on a Teacher event.",
        "Waiting event and owner reply reference.",
        "Resumes the same event. An identical redelivery preserves the original answer.",
        "EVENT MESSAGE 'Use the observed case'",
        writes=("teacher-queue", "diagnostics"),
    ),
    details(
        "lessons wait-owner",
        "Park a Teacher job for an owner decision.",
        TEACHER_WRITE + " The exact question to resolve.",
        "Moves the job to the owner queue.",
        "EVENT 'Which repeated failure should become a lesson?' --dispatch DISPATCH",
        writes=("teacher-queue", "diagnostics"),
    ),
    details(
        "lessons teacher-launch",
        "Reserve or reconcile a Teacher event assignment.",
        CONFIG,
        "Grants one launch per event attempt. Repeats return the existing dispatch. With no event, inspect the configured profile.",
        "EVENT",
        writes=("teacher-queue", "diagnostics"),
    ),
    details(
        "lessons retro",
        "Enqueue an owner-confirmed retrospective finding.",
        "The user's confirmation for this finding and the source evidence.",
        "Enqueues a retrospective Teacher job.",
        "INCIDENT retro.md 'Check ownership was unclear' --confirmed",
        writes=("teacher-queue", "diagnostics"),
    ),
    details(
        "lessons user",
        "Enqueue an owner-requested lesson operation.",
        "The owner request and source evidence.",
        "Enqueues the selected Teacher operation.",
        "INCIDENT owner-message.txt 'Capture this recurring outcome' --capture",
        writes=("teacher-queue", "diagnostics"),
    ),
    details(
        "lessons packet",
        "Read the packet for a Teacher job.",
        TEACHER,
        "Prints the Teacher context packet.",
        "EVENT",
        writes=("diagnostics",),
    ),
    details(
        "lessons complete",
        "Complete a Teacher job.",
        TEACHER_WRITE,
        "Records the outcome and closes the job.",
        "EVENT --reason 'No reusable lesson found' --dispatch DISPATCH",
        writes=("teacher-queue", "diagnostics"),
    ),
    details(
        "lessons publish",
        "Publish or update a validated lesson card.",
        TEACHER_WRITE
        + " A lesson proposal ID from graph_inputs.propose_lesson. Updates require the expected revision hash.",
        "Writes the lesson card and records its publication.",
        "EVENT LESSON_ID --dispatch DISPATCH",
        writes=("teacher-queue", "lesson-files", "diagnostics"),
    ),
    details(
        "lessons delete",
        "Delete the exact lesson revision authorized by the owner.",
        TEACHER_WRITE + " The owner-authorized target and current revision hash.",
        "Removes the target lesson through the Teacher job.",
        "EVENT --revision SHA256 --dispatch DISPATCH",
        writes=("teacher-queue", "lesson-files", "diagnostics"),
    ),
)
