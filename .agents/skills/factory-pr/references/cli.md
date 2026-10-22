# CLI fallback

Read only when the GitHub plugin cannot perform the requested operation. This
reference supplements the authorization, evidence and merge rules in `SKILL.md`.

## Setup and reads

Check `gh --version`, `gh auth status` and installed subcommand `--help`. Resolve
the host/repository from the actual remote or supplied PR URL. Never print tokens
or silently change credentials. `gh api` has no `--repo`; use an explicit endpoint
and `--hostname`/`GH_HOST` for Enterprise.

The examples use `OWNER/REPO`, `N`, `BRANCH`, `BASE` and `HEAD_SHA` as placeholders:

```bash
gh pr view N --repo OWNER/REPO --json number,url,title,body,baseRefName,baseRefOid,headRefName,headRefOid,headRepository,isCrossRepository,isDraft,mergeable,mergeStateStatus,reviews,statusCheckRollup
gh pr diff N --repo OWNER/REPO
gh pr checks N --repo OWNER/REPO
gh api --paginate --slurp 'repos/OWNER/REPO/pulls/N/files?per_page=100'
gh api --paginate --slurp 'repos/OWNER/REPO/pulls/N/reviews?per_page=100'
```

For GitHub Actions, use `gh run list --branch BRANCH --repo OWNER/REPO`, then
`gh run view RUN_ID --repo OWNER/REPO` and `--log-failed` for the failing run.
Associate results with the actual commit; do not infer successful CI from absence.

## Authorized writes

Write exact multiline content to a body file, then pass `--body-file`. Do not
interpolate it into shell code. Check the current target/head before writing and
read back the result. Examples are alternatives, not a script to execute in full:

```bash
gh pr create --repo OWNER/REPO --base BASE --head BRANCH --title 'type(scope): description' --body-file PR_BODY.md
gh pr comment N --repo OWNER/REPO --body-file COMMENT_BODY.md
gh pr review N --repo OWNER/REPO --approve --body-file REVIEW_BODY.md
gh pr merge N --repo OWNER/REPO --squash --match-head-commit HEAD_SHA
```

Use `--draft` when appropriate. Choose `--merge` instead of `--squash` when the
agreed stack requires dependency SHA preservation and repository settings allow
it. A PR request does not authorize approval, merge, branch deletion or release.

## Existing read-only comment helpers

The retained scripts use `gh api` GET, paginate all pages and fail on API,
parse or incomplete-thread errors. Run from the checkout root:

```bash
python3 .agents/skills/factory-pr/scripts/fetch_note.py review NOTE_ID N --repo OWNER/REPO
python3 .agents/skills/factory-pr/scripts/fetch_note_context.py review NOTE_ID N --repo OWNER/REPO
python3 .agents/skills/factory-pr/scripts/fetch_recent_notes.py issue N -n 10 --repo OWNER/REPO
```

The first two also accept a flat comment array on stdin when PR number is omitted.
Use `issue` for conversation comments and `review` for inline comments. Recent
helpers sort all pages before limiting; formal reviews use `/pulls/N/reviews`.

A known conversation comment uses `/issues/comments/NOTE_ID`; an inline comment
uses `/pulls/comments/NOTE_ID`. Issue comments have no REST reply thread. For an
authorized inline reply, verify the root comment ID, then use:

```bash
gh api --method POST repos/OWNER/REPO/pulls/N/comments/ROOT_ID/replies -F body=@REPLY_BODY.md
```

Use GraphQL reviewThreads for resolved/outdated state; a REST comment ID is not
a GraphQL thread ID. API semantics: [review comments](https://docs.github.com/en/rest/pulls/comments)
and [issue comments](https://docs.github.com/en/rest/issues/comments).
