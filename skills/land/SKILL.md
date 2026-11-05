---
name: land
description: Use when a branch is done and needs push, PR, merge decision, or the "next feature" handoff - says "land it", "file a PR", "next feature", "ship branch", or oneshot Phases 5 and 7.
---

# Land

Finish a development branch: PR body that leads with the problem, then the merge decision, then the handoff back to default.

**Model routing:** no model calls of its own; it coordinates. Subagents come from the AGENTS.md implementation role when needed for fixes.

## Part 1 - File the PR (oneshot Phase 5)

1. Confirm clean tree, push feature branch: `git push -u origin <branch>`
2. If no PR exists: `gh pr create --title <short> --body-file /tmp/pr-body.md`
3. PR body rules:
   - `## Summary` - 1-2 sentences. The problem it solves first, not an inventory of files touched
   - `## Changes` - bullets grouped by area, `path` in backticks
   - `## Test plan` - `[x]`/`[ ]` checklist, exact commands run and their results
   - No emdash anywhere. No the word "delete" inside gh command text (use remove/trim/drop, applies to body strings on the same command line); if the body must mention the word, rephrase it; if a PR body edit is needed use `gh pr edit <number> --body-file <file>`, and for branch removal on merge use `gh pr merge` without such a flag, cleanup happens after
   - Local-only spec/plan (gitignored)? Reference them by path as local files
4. Save PR URL, announce it.

## Part 2 - Finish options (oneshot Phase 7, Gate 3)

When `auto-approve: true` is present (read from the spec header, or from the dispatch prompt when oneshot passes it), skip the menu: default to Keep PR open, report the URL, and continue to the handoff without waiting.

Otherwise present exactly these, get user choice:

1. **Merge PR** - `gh pr merge --squash -t "<subject>"` then handoff (Part 3)
2. **Keep PR open** - done, report URL
3. **Keep branch** - done, report branch name
4. **Discard** - report state and stop; destructive removal only on explicit user instruction afterward

## Part 3 - Next-feature handoff

Same menu as the standalone flow, reusable any time a PR is merged:

1. **Standard checkout (not a linked worktree, or default branch not checked out elsewhere):**
   - Checkout default branch: `git checkout master` (or repo default if different)
   - Pull: `git pull --ff-only`
   - Prune merged local branches only if user asked: `git branch -d <branch>` per branch, never a wildcard, never `git branch -D` without explicit user instruction.
   - Report: "Ready for next task on `<default branch>` at `<short-sha>`"
2. **Linked git worktree (where `<default branch>` is already checked out in the main repository root, e.g. a T3 Code worktree thread):**
   - Do not run `git checkout <default>` inside the linked worktree if git reports `<default>` is already used by another worktree. Instead, fast-forward the default branch ref via `git fetch origin <default>:<default>` (or `git fetch origin <default>`).
   - If the session is inside a temporary worktree the user asked to clean up, move the session back to the main checkout (`tools.opencode.session_move`) and remove the worktree (`tools.opencode.worktree_remove`), then prune the merged local branch if requested (`git branch -d <branch>`). Otherwise, detach HEAD at `origin/<default>` (`git checkout --detach origin/<default>`) so the merged feature branch is free and the worktree stays at the latest default commit.
   - Report: "Ready for next task on `<default branch>` at `<short-sha>`"

## Rules

- Never merge on red tests or open review findings
- Never create-PR-if-none when tests are red: verify first
- Never commit to master directly; master advances only via PR merge
- Merge decisions respect the AGENTS.md PR format rules verbatim
- Discard requires explicit user instruction in the current turn
- Every `gh` command in this skill must be a real subcommand; verify with `gh <cmd> --help` before using a new one.
