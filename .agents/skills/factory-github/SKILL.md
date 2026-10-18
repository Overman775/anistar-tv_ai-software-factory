---
name: factory-github
description: "GitHub connector or gh CLI operations for AniStar TV: create PR, commit, inspect diff/comments/reviews/checks, merge, approvals, pull request, GitHub, создай PR, закоммить, проверь проверки, комментарии, апрувы. Technical review uses factory-code-review. External writes require explicit user instruction."
---

# Factory GitHub

GitHub adaptation of the source VCS workflow: authentication, branch/merge policy,
readiness gates, PR commands and complete comment context. Read `AGENTS.md`,
`docs/vcs_guidelines.md`, `docs/melos_tooling.md`, task source, current diff and
fresh verification evidence. Select actual behavior documents through
`docs/specs/README.md`, `docs/adr/README.md` and affected package READMEs.

Commit, push, PR/comment/review publication, merge and release require explicit
user instruction. Prepare concrete content and target before the action; existing
explicit authorization is sufficient. A local review verdict does not authorize
publication or merge. Issue creation is not a local-task prerequisite.

## 1. Repository and authentication

Inspect `git remote -v`, current branch and actual connector/CLI capabilities.
Resolve owner/repository and host from the remote; never assume an old project ID.
For CLI use `gh --version`, `gh auth status` and installed subcommand `--help`.
Capture stderr and analyze failures. If CLI is missing/unauthenticated, use an
available connector with the required capability; do not silently change personal
credentials/settings. If neither can perform the operation, report the exact
blocked action and keep the useful local draft. Never print tokens.

CLI examples below use `OWNER/REPO`, `N`, `HEAD_SHA` and local body files as
placeholders. `gh api` has no `--repo`: use explicit `repos/OWNER/REPO/...`,
repository placeholders in this checkout, and `--hostname`/`GH_HOST` for Enterprise.

## 2. Branches and VCS standards

The existing primary branch is `main`; `develop`, mandatory epic branches,
and CI/CD are not configured. Read current rules before choosing target.

| Source | Target | Merge choice |
| --- | --- | --- |
| Ordinary feature/fix/tooling | `main` | Squash may preserve one logical change |
| Explicitly agreed stacked task | Agreed feature/integration branch | Preserve dependency SHA; no squash |
| Explicit release/hotfix | Agreed branch under current release scope | Choose from current VCS rules and repository capabilities |

Do not infer a stack/epic from change size or create branches/issues as mandatory
prerequisites. Use meaningful `feature/`, `fix/`, `chore/` or `codex/` names.
PR title and commit: `type(scope): description`, real package scope or `root`;
feature modules use `anistar_tv`. Include a task ID only when the task exists.

## 3. Merge readiness

Correct target and merge method alone do not establish readiness. Before an
explicitly requested merge, read current PR metadata and verify the head SHA,
target, draft/conflict/merge state and actual repository requirements.

For a deliberately partial stacked task, all `implemented` work must be complete,
relevant verification must pass, and each `deferred` entry must identify its
concrete `completed_by` owner. For a finished feature into `main`, required behavior
and acceptance criteria must be complete, no required work may remain deferred,
and reachable production flow must not contain temporary stubs/fixtures or
`UnimplementedError`. Permanent fallbacks belong in implemented behavior and
acceptance criteria. Check the real AniStar HTML/JSON5/cookie/mirror/native-HLS
contracts as applicable; fixture tests do not claim live verification. Live tests
require explicit scope.

Use fresh local gates from `docs/melos_tooling.md` (`check` → fixture `test:e2e` →
`build:android:prod:apk` where applicable), completed technical review and actual
remote checks/review requirements. Missing CI is not a green pipeline. List
missing evidence and do not merge until the applicable gate is satisfied. Never
bypass protections with `--admin` or enable future auto-merge implicitly. Select
an available merge method that preserves the agreed branch relationship; verify
HEAD again immediately before writing. Branch deletion is a separate scoped action.

## 4. Commands and PR evidence

Confirm installed help and actual connector alternatives before use. Read commands:

```bash
gh pr list --repo OWNER/REPO --limit 20
gh pr view N --repo OWNER/REPO --json number,url,title,body,baseRefName,baseRefOid,headRefName,headRefOid,headRepository,isCrossRepository,isDraft,mergeable,mergeStateStatus,reviews,statusCheckRollup
gh pr diff N --repo OWNER/REPO
gh pr checks N --repo OWNER/REPO
gh api --paginate --slurp 'repos/OWNER/REPO/pulls/N/files?per_page=100'
gh api --paginate --slurp 'repos/OWNER/REPO/pulls/N/reviews?per_page=100'
```

Record base/head repository, refs/SHA and merge-base, including forks. Paginate
files/comments/reviews fully. API patches may be missing/truncated: obtain complete
local/fetched bytes or state the unverified scope. Re-read head after fetching;
force-push invalidates earlier evidence. Never reset/stash user work to review.
Technical review follows `factory-code-review` modes/protocol; staged and unstaged
patches must not be combined as though they were an immutable branch diff.

Prepare the PR description: concrete problem/result, source,
fresh validation and limitations. Use body files to preserve actual newlines.
Only within explicit authorization, commands include:

```bash
gh pr create --repo OWNER/REPO --base main --head BRANCH --title 'type(scope): description' --body-file PR_BODY.md
gh pr comment N --repo OWNER/REPO --body-file COMMENT_BODY.md
gh pr review N --repo OWNER/REPO --approve --body-file REVIEW_BODY.md
gh pr merge N --repo OWNER/REPO --squash --match-head-commit HEAD_SHA
```

`--draft` and requested reviewer assignment are available when appropriate.
Use `--merge` for an explicitly agreed stack preserving dependency SHA, only if
supported by repository settings. Do not compensate for a wrong target with a
merge strategy. No implicit push, branch removal, approval or release.
Confirm write target and reviewed commit immediately before publication, then
read back the actual result. Attach created PRs with the host artifact tool.

### Remote checks

No GitLab pipeline commands or CI configuration are imported. If GitHub Actions
actually exists, inspect `gh run list --branch BRANCH --repo OWNER/REPO`, then
`gh run view RUN_ID --repo OWNER/REPO` and `--log-failed` for failed jobs. Report
provider/check names, commits and missing results accurately; local checks remain
separate evidence.

## 5. Comments, reviews and context

GitHub has distinct namespaces: issue comments (PR conversation), formal review
summaries, and inline review comments. Never try the same numeric ID in another
namespace after a failure. Preserve URL, author, time and full body. Inline comments
also carry path, side/line, commit/original position and `in_reply_to_id`; stale
coordinates require anchoring to the reviewed diff. REST inline roots are comment
IDs, not GraphQL discussion IDs; use GraphQL reviewThreads if resolution/outdated
state is needed. Issue comments have no REST reply thread.

Read-only helpers under `.agents/skills/factory-github/scripts/` retain source
lookup/context/recent-note capabilities with GitHub semantics. They use `gh api`
GET, paginate all pages and fail on API/parse/incomplete-thread errors:

```bash
python3 .agents/skills/factory-github/scripts/fetch_note.py review NOTE_ID N --repo OWNER/REPO
python3 .agents/skills/factory-github/scripts/fetch_note_context.py review NOTE_ID N --repo OWNER/REPO
python3 .agents/skills/factory-github/scripts/fetch_recent_notes.py issue N -n 10 --repo OWNER/REPO
```

The first two also accept a flat comment array on stdin when PR number is omitted;
pass `issue` explicitly for conversation comments. Recent helpers sort all pages
within the chosen namespace. Formal review summaries use `/pulls/N/reviews`.

A direct read of one known ID uses `/issues/comments/NOTE_ID` or
`/pulls/comments/NOTE_ID`; it cannot establish complete PR/thread context alone.
For an explicitly authorized inline reply, use the verified root comment ID:
`gh api --method POST repos/OWNER/REPO/pulls/N/comments/ROOT_ID/replies -F body=@REPLY_BODY.md`.
Conversation comments use `gh pr comment`; no fabricated `discussion_id`.

API semantics: [review comments](https://docs.github.com/en/rest/pulls/comments)
and [issue comments](https://docs.github.com/en/rest/issues/comments).
