# Scheduled task templates

Prompt templates for daily T3 Code scheduled tasks. This folder is **separate from the harness**: `install.sh` copies only `agents/` and `skills/`, so nothing here is ever installed. The jobs themselves call the `oneshot` harness at runtime for every code change.

## Jobs

| Job | File | Outcome |
| --- | --- | --- |
| Security Vulnerability Inspector | `jobs/security-inspector.md` | Merged fix PR (via oneshot) or Urgent/High ticket |
| Codestyle Inspector | `jobs/codestyle-inspector.md` | Merged convergence PR or migration ticket |
| Garbage Collector | `jobs/garbage-collector.md` | Merged cleanup PR, plus closed dead PRs and deleted merged branches |
| Project Board Inspector | `jobs/project-board-inspector.md` | Reconciled Linear board, daily status update, and a triage ticket |

Every rendered prompt is `preamble.md` followed by the job body. The preamble holds the shared contract:

- the `outcome:` line;
- dedupe through the `sched:<job-id>` Linear label and the `sched/<job-id>/...` branch prefix;
- the fix-or-ticket rule;
- oneshot for every code change;
- caps of 1 PR and 5 tickets per run.

## Placeholders

| Placeholder | Source |
| --- | --- |
| `{{PROJECT}}` | `projects.tsv` column 1 |
| `{{REPO}}` | `projects.tsv` column 2 (`owner/name`) |
| `{{LINEAR_TEAM}}` | `projects.tsv` column 3 (team key) |
| `{{LINEAR_PROJECT}}` | `projects.tsv` column 4 (Linear project name) |
| `{{JOB_ID}}`, `{{JOB_TITLE}}`, `{{TEMPLATE_VERSION}}` | job front matter |

`projects.tsv` is gitignored because this repo is public. Copy `projects.example.tsv` and fill in your projects. The file is tab-separated.

## Render and schedule

```sh
scheduled-tasks/render.sh security-inspector lothendil
```

Pass the output as the `prompt` to T3 Code `schedule_task`, with these settings:

- the project's `projectId`;
- the target machine's `environmentId`;
- `schedule: {type: "fixed_time", timeOfDay: "HH:MM"}`;
- `bindToCurrentThread: false`, so each run gets its own thread.

When you change a template, bump `version` in its front matter, re-render, and update the existing task by `scheduledTaskId`. Do not create a second task.

## Default daily slots

Slots are staggered so oneshot runs do not compete for the same quota pools. The board inspector runs last, so it sees the tickets and PRs from the night's runs.

| Job | lothendil | telos | musy |
| --- | --- | --- | --- |
| security-inspector | 01:00 | 01:20 | 01:40 |
| codestyle-inspector | 02:30 | 02:50 | 03:10 |
| garbage-collector | 04:00 | 04:20 | 04:40 |
| project-board-inspector | 06:00 | 06:20 | 06:40 |
