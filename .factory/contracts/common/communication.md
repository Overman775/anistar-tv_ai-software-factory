# Communication

Use Telegraphic for coordinator, worker and user messages. Compress while
preserving meaning and order. Omit filler and redundant grammar. Use the
shortest clear wording without prefixes, announcements or forced fragments.
No external skill or activation is required. Explicit user instructions apply
within scope. Preserve permissions and active confirmation requirements.

## Language and format

- Internal messages use English only. Skip duplicate translations.
- User replies use the dialogue language or, if unclear, the current request's
  language. Quotes and delegated messages do not determine it.
- Use English for reusable factory instructions, skills, templates, configuration
  comments and tool messages. Preserve the assigned language of project profiles,
  rules, skills, documents and data. Unicode tests may use non-English input.
- Artifacts follow the task or project language and format, then the dialogue
  language. Delegators supply the language. Workers flag consequential gaps.
  Internal report prose may use English. Human-facing fields use the reader's
  language. Keep schema keys, required headings and machine values exact.
  JSON-only output contains only JSON.
- Saved prose uses plain sentences and its required format. Logged chat stays
  Telegraphic.

## Accuracy and obligations

Keep exact code, commands, paths, API names, errors, IDs, UI strings, source
quotes, numbers and units. Preserve conditions, negations, exceptions, open
questions and uncertainty. Distinguish observations, inferences and decisions.
Use one term per thing. Avoid invented abbreviations and arrows. Keep existing
comments intact unless asked to change them. Show changed code with enough
context. State each fact once per message. In a handoff, state each applicable
requirement or restriction separately from the observed result.

Preserve schemas, Done Signals, required evidence, findings and blockers.
Host and process update requirements take precedence. Keep routine tool updates
to a line before and after a run. Add updates when direction changes or a
confirmation, security issue or irreversible step requires attention. Style sets
no message quota or new approval requirement.

Use full sentences for warnings, irreversible steps, ambiguity, confusion,
user questions and choices, and whenever the user asks for detail. Explain
enough for the next decision. Resume Telegraphic when clear.

## Context

Give each assignment a full current scoped packet. Keep originals available.
Keep approved sources, required reading and independent evidence. Use summaries
and translations as supplements. A filename does not show that the recipient read
it. Never infer memory from brevity. Keep files, transport and history intact.

Example handoff

AC-07 requires preserving next_page(cursor). Its signature stayed unchanged.
12 unit tests passed. Network NOT_RUN.
Cause of intermittent timeout unconfirmed. Evidence: artifacts/unit.log.
