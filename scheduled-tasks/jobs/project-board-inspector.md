---
id: project-board-inspector
title: Project Board Inspector
version: 1
---
Make Linear project `{{LINEAR_PROJECT}}` reflect what is actually happening in `{{REPO}}`. This job writes to Linear only. It never changes code, so it does not invoke oneshot. If you spot code work, ticket it.

### 1. Gather reality (last 7 days)
- Merged PRs: `gh pr list --repo {{REPO}} --state merged --search "merged:>=<date-7d>" --json number,title,headRefName,body,mergedAt,url`.
- Open PRs, including drafts and their review state, plus CI status on the default branch.
- Commits on the default branch.
- Releases and tags.
- Issue IDs referenced in branch names, PR titles and bodies, and commit messages (pattern: team key + number, for example `{{LINEAR_TEAM}}-123`).

### 2. Gather the board
- All non-completed issues in project `{{LINEAR_PROJECT}}`, issues completed in the last 7 days, the active cycle, milestones, and the latest project status update.
- Read comments (`list_comments`) before you change any issue.

### 3. Reconcile
Every state change needs unambiguous evidence. Post a comment with that evidence (PR or commit link) on each issue you change.

- **Work merged, issue still open:** move it to Done. A PR is open and linked: move it to In Review, or the team's equivalent status (check `list_issue_statuses`).
- **PR or branch exists, issue still in Backlog or Todo:** move it to In Progress, and attach the PR link.
- **In Progress with no commit or PR activity for 7 or more days:** add the label `stale`, and comment asking for status. Skip this if the issue already has that comment and nothing has changed since.
- **Merged PRs with no linked issue:** list them in the status update. Do not create issues for them after the fact.
- **`sched:*` tickets whose finding is fixed** (the fix is merged and the evidence is gone): close them with evidence.
- **Clear-cut duplicates** (same root cause, same scope): mark the newer issue as a duplicate of the older one.
- **Hygiene:** issues in an active cycle or milestone that lack acceptance criteria or priority get one comment listing what is missing. Do not edit their content.
- **Milestones or the cycle at risk** (target date within 7 days and less than 70% done): flag them in the status update.
- Never change assignees, never delete issues, and never edit an issue description that a human wrote.

### 4. Report
- Post one Linear project status update per day on `{{LINEAR_PROJECT}}`. Set health to on track, at risk, or off track. Cover: shipped this week, in flight, stale, at risk, and drift corrected.
- Gaps that need a human decision (scope conflicts, priority clashes, orphaned epics) go into one triage ticket, deduped by the `sched:project-board-inspector` label. Create a new one only when no open triage ticket exists; otherwise, update the existing one.
- Put board changes on the `housekeeping:` line.
- If you made no changes and there is no triage ticket, use `outcome: clean` and include the status update link.
- Type label: `triage`.
