---
name: land
description: Use when a branch is done and needs push, PR, merge decision, backlog tickets for deferred council findings, or the "next feature" handoff - says "land it", "file a PR", "next feature", "ship branch", or oneshot Phases 5 and 7.
---

# Land

Finish a development branch: PR body that leads with the problem, then the merge decision, the backlog tickets for deferred council findings, and the handoff back to default.

**Model routing:** no model calls of its own; it coordinates. Subagents come from the implementation roles (active provider profile, AGENTS.md Dispatch Adapter) when needed for fixes.

## Part 1 - File the PR (oneshot Phase 5)

1. Confirm clean tree, push feature branch: `git push -u origin <branch>`
2. If no PR exists: `gh pr create --title <short> --body-file /tmp/pr-body.md`
3. PR body rules:
   - `## Summary` - 1-2 sentences. The problem it solves first, not an inventory of files touched
   - `## Changes` - bullets grouped by area, `path` in backticks
   - `## Test plan` - `[x]`/`[ ]` checklist, exact commands run and their results
   - `## Backlog` - present when the state artifact holds `backlog:` lines (findings the council captain deferred): one bullet per entry, `<finding line> (<reason>)`; council keeps it current between rounds
   - No emdash anywhere. No the word "delete" inside gh command text (use remove/trim/drop, applies to body strings on the same command line); if the body must mention the word, rephrase it; if a PR body edit is needed use `gh pr edit <number> --body-file <file>`, and for branch removal on merge use `gh pr merge` without such a flag, cleanup happens after
   - Local-only spec/plan (gitignored)? Reference them by path as local files
4. Save PR URL, announce it.

## Part 2 - Finish options (oneshot Phase 7, Gate 3)

When `auto-approve: true` is present (read from the spec header, or from the dispatch prompt when oneshot passes it), skip the menu: default to Keep PR open, report the URL, and continue to the handoff without waiting.

Otherwise present exactly these, get user choice:

1. **Merge PR** - parse the effective last `council_verdict` line from `$(git rev-parse --git-dir)/info/oneshot-state.md` and require `council_verdict: PASS`, `mode` in `nominal|degraded|captain`, and `head=<sha>` matching local `git rev-parse HEAD` (or, for standalone runs outside oneshot where no state artifact exists, verify a Phase 6 Council consensus PASS on the current `HEAD` `<sha>` in the current session; otherwise run Phase 6 Council before merge), then enforce remote PR head match via `gh pr merge --squash --match-head-commit <sha> -t "<subject>"`, file backlog tickets (Part 4), and handoff (Part 3)
2. **Keep PR open** - done, report URL (backlog entries stay in the PR body's `## Backlog`; list them in the report)
3. **Keep branch** - done, report branch name
4. **Discard** - report state and stop; destructive removal only on explicit user instruction afterward

## Part 3 - Next-feature handoff

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
   - `github`: never inline model-written text into a shell command (findings carry backticks, `$()`, and quotes). Write the body (finding line, captain reason, PR link) to a temp file via a quoted heredoc, pass the title through a variable set the same way, and use `--body-file`:
     ```bash
     body=$(mktemp)
     cat > "$body" <<'EOF'
     <finding line>
     <captain reason>
     <PR link>
     EOF
     title=$(cat <<'EOF'
     <short title>
     EOF
     )
     if out=$(gh issue create --title "$title" --body-file "$body" --label backlog 2>&1); then
       printf '%s\n' "$out"
     else
       case $out in
         *label*) gh issue create --title "$title" --body-file "$body" ;;  # `backlog` label missing: retry without it
         *) printf '%s\n' "$out" >&2 ;;                                     # other failure: report it
       esac
     fi
     rm -f "$body"
     ```
   - `linear` / `jira`: create one issue per deferred finding through the connected Linear or Jira MCP tools. Infer the team/project from context (repo, recent issues, memory) or ask the user once per run; under auto-approve, an unresolvable team/project counts as a filing failure. Title `<short>`, description = finding line, captain reason, PR link.
   - `none`: file nothing.
4. **Record:** append `backlog filed: <ticket url or id> <finding line>` per ticket to the state artifact and list the links in the final report.
5. **Fallback:** with `none`, or on any filing failure, keep the PR body's `## Backlog` list as the record and report the unfiled entries (and the error) in the final report. Filing failures never undo or block the merge.

## Rules

- Under oneshot, merging parses the effective last `council_verdict` line in `$(git rev-parse --git-dir)/info/oneshot-state.md` and requires an audited Phase 6 `council_verdict: PASS` with `mode` in `nominal|degraded|captain` (`mode=nominal` >= 2/3, `mode=degraded` unanimous 2/2, or `mode=captain` captain verdict PASS overriding FAIL votes with every finding deferred or rejected; every mode with zero unresolved accepted findings and green tests) and `head=<sha>` matching both local `git rev-parse HEAD` and the remote PR head via `gh pr merge --squash --match-head-commit <sha>`. If the effective last `council_verdict` is `FAIL`, carries an unrecognized `mode`, or its `<sha>` differs from local `HEAD` or remote PR head, refuse to merge. For standalone runs outside oneshot (where no state artifact exists), allow a Phase 6 Council consensus PASS on the current `HEAD` `<sha>` in the current session (still passing `gh pr merge --squash --match-head-commit <sha>`). Never merge without verified Council consensus PASS.
- Never merge on red tests or open review findings
- Never create-PR-if-none when tests are red: verify first
- Never commit to master directly; master advances only via PR merge
- Merge decisions respect the AGENTS.md PR format rules verbatim
- Discard requires explicit user instruction in the current turn
- Every `gh` command in this skill must be a real subcommand; verify with `gh <cmd> --help` before using a new one.
