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
   - No emdash anywhere. No the word "delete" inside gh command text (use remove/trim/drop, applies to body strings on the same command line); use `gh pr remove` style alternatives or quote around it, and for branch removal on merge use `gh pr merge` without such a flag, cleanup happens after
   - Local-only spec/plan (gitignored)? Reference them by path as local files
4. Save PR URL, announce it.

## Part 2 - Finish options (oneshot Phase 7, Gate 3)

Present exactly these, get user choice:

1. **Merge PR** - `gh pr merge --squash -t "<subject>"` then handoff (Part 3)
2. **Keep PR open** - done, report URL
3. **Keep branch** - done, report branch name
4. **Discard** - report state and stop; destructive removal only on explicit user instruction afterward

## Part 3 - Next-feature handoff

Same menu as the standalone flow, reusable any time a PR is merged:

1. Checkout default branch: `git checkout master` (or repo default if different)
2. Pull: `git pull --ff-only`
3. Prune merged local branches only if user asked
4. Report: "Ready for next task on `<default branch>` at `<short-sha>`"

## Rules

- Never merge on red tests or open review findings
- Never create-PR-if-none when tests are red: verify first
- Never commit to master directly; master advances only via PR merge
- Merge decisions respect the AGENTS.md PR format rules verbatim
- Discard requires explicit user instruction in the current turn
