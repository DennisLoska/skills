---
id: garbage-collector
title: Garbage Collector
version: 1
---
Remove what no longer earns its keep: dead code, unused dependencies, lint debt, dead PRs, and merged branches.

### 1. Lint, format, and type debt
- Run the project's own lint, format-check, and typecheck commands. Find them in `package.json` scripts, the `Makefile` or `justfile`, `AGENTS.md`, and the CI workflows.
- Autofixable and mechanical warnings are PR candidates. Errors that need judgment become a ticket.

### 2. Dead code and unused dependencies
- Use the tools that fit the ecosystem when they are available: `knip`, `depcheck`, `ts-prune`, `cargo machete` or `cargo udeps`, `staticcheck` / `deadcode`, `vulture`.
- Verify every candidate with a repo-wide search before deleting it. Watch for dynamic imports, reflection, string-based registration, framework conventions (routes, pages, migrations), the public API of published packages, and scripts referenced from CI.
- When in doubt, do not delete; ticket it instead.
- Also handle: commented-out code blocks, stale feature flags (fully rolled out or removed), and `TODO` / `FIXME` comments that reference Linear issues already closed.

### 3. Dead pull requests (housekeeping; no oneshot needed)
- Open PRs with no commits, comments, or reviews in 14 or more days that are not labeled `keep-open`: post one comment ("No activity for 14 days; this PR will be closed in 7 days unless updated or labeled `keep-open`."). Skip PRs that already have that comment.
- PRs that received that comment 7 or more days ago and have had no activity since: close them with a comment linking to the reminder.
- Dependabot or Renovate PRs that a newer PR for the same package supersedes: close them.
- Stalled `sched/*` PRs older than 7 days (left behind by earlier scheduled runs): close them, and file or update a ticket so the finding is not lost.
- Never close PRs labeled `keep-open`, or drafts created in the last 30 days.

### 4. Merged branches (housekeeping; no oneshot needed)
- Delete remote branches that are fully merged into the default branch and whose last commit is 30 or more days old: `gh api -X DELETE repos/{{REPO}}/git/refs/heads/<branch>`.
- Never delete the default branch, protected branches, `release/*`, `hotfix/*`, or the head branch of any open PR.

### Act
- Bundle code cleanup (sections 1 and 2) into one oneshot PR, kept to about 10 files or fewer. Ticket the remainder.
- Put housekeeping actions (sections 3 and 4) on the `housekeeping:` line.
- Type label: `chore`.
