---
name: land
description: Use when a branch is done and needs push, PR, merge decision, backlog tickets for deferred council findings, or the "next feature" handoff - says "land it", "file a PR", "next feature", "ship branch", or oneshot Phases 5 and 7.
---

# Land

**Context-scoped effort ceiling:** Non-council work, including driver sessions, defaults, advisory/design work, task-reviewer, fixing and testing, must never request or inherit effort above `high`. Only runtime council reviewer-a/b/c seats and fresh captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high, with maximum `xhigh`. `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent higher levels are forbidden everywhere. Verify provider capabilities before dispatch; use explicit provider-native options from `PROVIDERS.md`. Models without `xhigh` support use explicit `high` in council. Unknown/unsafe defaults require an explicit safe option or an unreachable rung; non-council defaults must be verified at most `high`. Shared reviewer contracts do not grant task reviews the council exception. Invoking a skill never changes the driver session or its ceiling.

Finish a development branch: PR body that leads with the problem, then the merge decision, the backlog tickets for deferred council findings, and the handoff back to default.

**Model routing:** no model calls of its own; it coordinates. Subagents come from the implementation roles (active provider profile, AGENTS.md Dispatch Adapter) when needed for fixes.

## Part 1 - File the PR (oneshot Phase 5)

1. Confirm clean tree, push feature branch: `git push -u origin <branch>`
2. Inspect whether the branch already has an open PR before creating one. Use `gh pr view` normally, then `gh pr create --title <short> --body-file /tmp/pr-body.md` only when none exists. If GraphQL rate limits block `gh pr create`, `gh pr view` or `gh pr checks`, use the REST recovery procedure below; always check for an existing PR before retrying creation.
3. PR body rules:
   - `## Summary` - 1-2 sentences. The problem it solves first, not an inventory of files touched
   - `## Changes` - bullets grouped by area, `path` in backticks
   - `## Test plan` - `[x]`/`[ ]` checklist, exact commands run and their results
   - `## Backlog` - present when the state artifact holds `backlog:` lines (findings the council captain deferred): one bullet per entry, `<finding line> (<reason>)`; council keeps it current between rounds
   - No emdash anywhere. No the word "delete" inside gh command text (use remove/trim/drop, applies to body strings on the same command line); if the body must mention the word, rephrase it; if a PR body edit is needed use `gh pr edit <number> --body-file <file>`, and for branch removal on merge use `gh pr merge` without such a flag, cleanup happens after
   - Local-only spec/plan (gitignored)? Reference them by path as local files
4. Save PR URL, announce it.

### T3 Code PR identity and REST recovery

In T3 Code, immediately after a PR is created, taken over or pushed, make the next tool call `link_pull_request` with the full PR URL; use `link_pull_requests` for multiple PRs and include every stack layer. Resolve a known-existing PR (resume, takeover, wakeup, or an existing open PR found before push) and its URL before the step 1 push so linking follows the push immediately. A fresh branch with no existing PR pushes first, then runs the check/create flow below. Links persist across pushes, but linking remains required after the work described here. Report a linking failure; do not silently substitute a title, branch name or bare PR number.

For GitHub GraphQL rate limits, use `gh api repos/{owner}/{repo}/pulls` through REST. Resolve `owner` and `repo` from the repository remote, `head_owner` from the pushed head repository, and `branch` from the head branch. Before creation, define `base` as the intended target branch: the user-chosen target, or the repository default resolved with `git symbolic-ref refs/remotes/origin/HEAD` (strip `refs/remotes/origin/`); if that symbolic ref is unset, fall back to `gh api repos/{owner}/{repo} --jq .default_branch`. For an existing PR, resolve `branch` and `base` from the actual PR branches. Use `gh api --method GET 'repos/{owner}/{repo}/pulls' -f state=open -f "head=$head_owner:$branch" -f "base=$base"` to check for an existing PR before retrying creation. Confirm the returned head repository, branch and `base.ref` match the intended PR before reusing its `html_url` and number; do not create a duplicate after an ambiguous CLI error.

If no matching PR exists, use `gh api --method POST 'repos/{owner}/{repo}/pulls' -f "title=$pr_title" -f "head=$head_owner:$branch" -f "base=$base" -F body=@/tmp/pr-body.md`. On a 422 from POST, re-query with `gh api --method GET 'repos/{owner}/{repo}/pulls' -f state=all -f "head=$head_owner:$branch" -f "base=$base"`, confirm the returned head repository, branch and `base.ref`, and report the existing PR, including a previously merged or closed one, instead of retrying creation. If none matches, report the 422 and stop creation recovery. The `pr_title` variable holds the intended PR title; the body remains in the previously written file. Recover PR details with `gh api --method GET "repos/{owner}/{repo}/pulls/$pr_number"`; use `html_url` for linking and `head.sha` for remote-head verification. If a PR body update hits the same GraphQL limit, use `gh api --method PATCH "repos/{owner}/{repo}/pulls/$pr_number" -F body=@/tmp/pr-body.md`. The `pr_number` variable is the number returned by the matching GET or successful POST.

For GraphQL-limited checks, inspect `gh api repos/{owner}/{repo}/commits/{sha}/check-runs` (`{owner}` and `{repo}` are `gh api` placeholders; `{sha}` is not a `gh` placeholder and must be substituted with the resolved remote head SHA, e.g. `commits/$sha/check-runs`) through REST with `--paginate --slurp` (aggregate all pages and reconcile the flattened check-run count against `total_count`), with `sha` set to the current remote PR head. Also inspect paginated combined commit statuses and review/comment endpoints when needed; check-runs alone do not prove every required check or review is satisfied. A REST transport fallback never relaxes the same-head merge, review or verification gates.

## Part 2 - Finish options (oneshot Phase 7, Gate 3)

**T3 Code watcher ownership:** Only the parent thread owning the PR calls `watch_pull_request`; delegate_task children never call `watch_pull_request`. If an authorized merge is waiting on checks or reviews, inspect checks and comments first, finish any needed branch update and push, immediately call `link_pull_request` with the full PR URL, then maintain one watcher per PR with `watch_pull_request` and end the turn for T3 Code's wakeup. Do not use a manual CLI polling loop in T3 Code. Revalidate the current remote head and existing merge evidence on wakeup.

For any watched PR, call `unwatch_pull_request` before handback, stopping, or asking the user a question, and before the next-feature handoff. The async turn ending solely to await a requested watcher wakeup keeps the watcher active; it is not a completed handback. Outside T3 Code, retain the existing CLI check and merge flow.

When `auto-approve: true` is present (read from the spec header, or from the dispatch prompt when oneshot passes it), skip the menu: default to Keep PR open, report the URL, and continue to the handoff without waiting.

Otherwise present exactly these, get user choice:

1. **Merge PR** - Apply the merge evidence rules below, then merge, file backlog tickets (Part 4), and handoff (Part 3).
2. **Keep PR open** - done, report URL (backlog entries stay in the PR body's `## Backlog`; list them in the report)
3. **Keep branch** - done, report branch name
4. **Discard** - report state and stop; destructive removal only on explicit user instruction afterward

## Part 3 - Next-feature handoff

Before this handoff in T3 Code, call `unwatch_pull_request` for each PR monitored by this parent thread.

Same menu as the standalone flow, reusable any time a PR is merged:

1. **Standard checkout (not a linked worktree, or default branch not checked out elsewhere):**
   - Checkout default branch: `git checkout master` (or repo default if different)
   - Pull: `git pull --ff-only`
   - Prune merged local branches only if user asked: `git branch -d <branch>` per branch, never a wildcard, never `git branch -D` without explicit user instruction.
   - Report: "Ready for next task on `<default branch>` at `<short-sha>`"
2. **Linked git worktree (where `<default branch>` is already checked out in the main repository root):**
   - Do not run `git checkout <default>` inside the linked worktree if git reports `<default>` is already used by another worktree. Instead, fast-forward the default branch ref via `git fetch origin <default>:<default>` (or `git fetch origin <default>`).
   - If the session is inside a temporary worktree the user asked to clean up, move the session back to the main checkout and remove the worktree (use the host's worktree tool when available, or `git worktree remove` from the main checkout), then prune the merged local branch if requested (`git branch -d <branch>`). Otherwise, detach HEAD at `origin/<default>` (`git checkout --detach origin/<default>`) so the merged feature branch is free and the worktree stays at the latest default commit.
   - Report: "Ready for next task on `<default branch>` at `<short-sha>`"

## Part 4 - Backlog tickets (after merge)

Run right after a successful merge in option 1, before the handoff. Each `backlog:` line in `$(git rev-parse --git-dir)/info/oneshot-state.md` (or, standalone, each bullet of the PR body's `## Backlog`) becomes one ticket. Skip entries already recorded as `backlog filed:` (resume safety).

1. **Read the tracker:** `backlog_tracker: <value>` from the `## Project management` section of the active provider profile (`PROVIDERS.md`); missing section or value -> `auto`.
2. **Resolve `auto`:** Linear MCP tools present -> `linear`; else Jira MCP tools present -> `jira`; else a GitHub remote with `gh` authenticated (`gh auth status`) and issues enabled (`gh repo view --json hasIssuesEnabled`) -> `github`; else `none`.
3. **File one ticket per entry:**
   - `github`: never route model-written text (findings carry backticks, `$()`, quotes, even a bare `EOF` line) through a heredoc or any shell literal. Two steps per entry, in order. (1) Write the files first. Run ONE shell call, `d=$(git rev-parse --absolute-git-dir)/info && mkdir -p "$d" && printf '%s\n' "$d"`, and use the printed absolute directory. Then, with the file-write tool (Write/Edit), not the shell, write the title to `<dir>/backlog-title.txt` and the body (finding line, captain reason, PR link) to `<dir>/backlog-body.txt` using those absolute paths, overwriting them for each entry (`info/` is local-only, never committed). Confirm both writes succeeded before step (2). (2) Then run the snippet below as ONE shell call; it derives the same paths with `--absolute-git-dir` and only reads the files (`"$(cat ...)"` output is not re-expanded). Retry without `--label` only when the error mentions the label. Exit 0 plus the printed ticket URL means filed (step 4); non-zero means filing failure (step 5), including missing or empty files, any other gh error, or a failed retry:
     ```bash
     rc=0
     d=$(git rev-parse --absolute-git-dir)/info; title_file=$d/backlog-title.txt; body=$d/backlog-body.txt
     [ -s "$title_file" ] && [ -s "$body" ] || { echo 'backlog files missing or empty' >&2; exit 1; }
     if out=$(gh issue create --title "$(cat "$title_file")" --body-file "$body" --label backlog 2>&1); then
       printf '%s\n' "$out"
     else
       case $out in
         *label*)  # `backlog` label missing: retry without it
           if out=$(gh issue create --title "$(cat "$title_file")" --body-file "$body" 2>&1); then
             printf '%s\n' "$out"
           else
             printf '%s\n' "$out" >&2; rc=1
           fi ;;
         *) printf '%s\n' "$out" >&2; rc=1 ;;  # other failure: report it
       esac
     fi
     rm -f "$body" "$title_file"; exit "$rc"
     ```
   - `linear` / `jira`: create one issue per deferred finding through the connected Linear or Jira MCP tools. Infer the team/project from context (repo, recent issues, memory) or ask the user once per run; under auto-approve, an unresolvable team/project counts as a filing failure. Title `<short>`, description = finding line, captain reason, PR link.
   - `none`: file nothing.
4. **Record:** append `backlog filed: <ticket url or id> <finding line>` per ticket to the state artifact and list the links in the final report.
5. **Fallback:** with `none`, or on any filing failure, keep the PR body's `## Backlog` list as the record and report the unfiled entries (and the error) in the final report. Filing failures never undo or block the merge.

## Rules

- Read the effective last `council_verdict` in `$(git rev-parse --git-dir)/info/oneshot-state.md` immediately before merge. Accept `council_verdict: PASS` with mode in `nominal|degraded|captain|single`, or `council_verdict: SKIPPED` with `mode=unavailable` and all configured attempted/skipped members and reasons recorded. Require `head=<sha>` matching local `git rev-parse HEAD` and remote PR head via `gh pr merge --squash --match-head-commit <sha>`. Verify the profile review allowlist, same-head available reviewer votes/rulings, zero unresolved accepted findings and green actual checks (no no-tests exception for single/unavailable). For mode=single, require the final real `reviewer_vote: PASS reviewer=<provider/model> head=<sha>` matching the verdict reviewer and captain. A skipped review never means PASS. Actual review FAIL, unresolved review failures, stale/missing evidence and unrecognized verdict/mode combinations refuse merge. Standalone uses the same evidence in the current session or state; run council if absent. Nominal alone retains the HARNESS.md no-tests exception. Authorship and provider counts are not gates.
- Never merge on red tests or open review findings
- Never create-PR-if-none when tests are red: verify first
- Never commit to master directly; master advances only via PR merge
- Merge decisions respect the AGENTS.md PR format rules verbatim
- Discard requires explicit user instruction in the current turn
- Every `gh` command in this skill must be a real subcommand; verify with `gh <cmd> --help` before using a new one.
