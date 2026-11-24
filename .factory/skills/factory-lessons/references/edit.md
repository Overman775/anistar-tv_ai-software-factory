# Edit a named lesson

Use the lessons CLI from the project root:
`.factory/tooling/bin/cli lessons packet EVENT`.
Read the request and locate the exact ID in the catalog. Run `wait-owner EVENT QUESTION` and ask for clarification
if it is absent or ambiguous. Preserve the card's ID, scope and every field outside the requested correction.
For a reported miss, reproduce the original symptom query first. For wrong advice,
compare the action against the cited case and nearest allowed case before editing. Use valid short Obsidian tags and keep roles separate.
When editing legacy terms, preserve their searchable concepts as valid tags.

Pass the full edited lesson JSON, omitting runtime-owned sources and edits, to
`publish EVENT - --revision HASH` using the packet revision. On conflict reread
the packet and compare before retrying. Confirm the stored edit. For a changed title, trigger or tags, check discovery with the original symptom query (or a natural query in the project language). For a corrected action, replay the reported example. If the check still fails, report the unresolved example. Park the edit with `wait-owner EVENT QUESTION` when an owner decision is needed. On success run
`complete EVENT`. An editorial change keeps the original incident evidence.
