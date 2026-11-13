# Scheduled job: {{JOB_TITLE}} ({{PROJECT}})

You are running unattended as a daily T3 Code scheduled task. No human is watching this run. Work only in project **{{PROJECT}}**: GitHub repo `{{REPO}}`, Linear team `{{LINEAR_TEAM}}`, Linear project `{{LINEAR_PROJECT}}`.
Template: `scheduled-tasks/jobs/{{JOB_ID}}.md` (skills repo), version {{TEMPLATE_VERSION}}.

## Outcome contract

End every run with exactly one `outcome:` line as the last line of your final message:

- `outcome: pr-merged <PR url>`: a fix was merged through the oneshot harness.
- `outcome: ticket <ID>[, <ID>...]`: actionable Linear ticket(s) were created or updated.
- `outcome: clean`: nothing actionable was found. List what you checked.
- `outcome: blocked <reason>`: the run could not finish (budget stop, auth failure, red CI, `yellow: degraded council`, oneshot unavailable). Also file or update a ticket that describes the blocker, unless the blocker is transient.

A run may produce both a merged PR and tickets. In that case, write `outcome: pr-merged <url>; ticket <ID>...`. Housekeeping actions that the job body allows (closing PRs, deleting merged branches, Linear state changes) go on an extra `housekeeping:` line placed before the `outcome:` line.

## Ground rules

1. **Preflight.** `cd` into the project workspace. Run `git fetch --all --prune`. `{{REPO}}` is the PR target. If `origin` is a fork of it, push branches to the fork and open PRs against `{{REPO}}`. Detect the default branch with `gh repo view {{REPO}} --json defaultBranchRef -q .defaultBranchRef.name`, and compare against the remote that tracks `{{REPO}}`, not the fork. Never commit to `main` or `master`. If `gh`, the Linear tools, or the `oneshot` skill are unavailable, stop with `outcome: blocked`.
2. **Read-only discovery.** Inspect and audit before you change anything. Follow the harness context-hygiene rules: scout searches that span more than one file.
3. **Dedupe.** Before you create anything, search Linear (team `{{LINEAR_TEAM}}`, label `sched:{{JOB_ID}}`, open and recently closed issues) and open PRs (`gh pr list --repo {{REPO}} --search "head:sched/{{JOB_ID}}"`). Update an existing issue or PR instead of opening a duplicate. Never reopen an issue that a human closed as canceled or won't-fix, unless its severity has increased since then.
4. **Fix or ticket.** Fix with a PR only when **all** of these hold:
   - the change is mechanical or low-risk;
   - it fits one oneshot run (about 10 files or fewer);
   - it is covered by existing tests, or the fix adds tests;
   - it needs no product or architecture decision;
   - it needs no credential rotation or other manual action.

   Otherwise, file a ticket.
5. **Every code change goes through oneshot.** Invoke the `oneshot` skill with a self-contained brief: the problem, the evidence (`path:line`), the acceptance criteria, and the constraint "scope limited to this finding". Branch name: `sched/{{JOB_ID}}/<yyyy-mm-dd>-<slug>`. Let oneshot run its full pipeline (council, CI, land). Merge only when oneshot's land gate passes. If land stops before merging, file or update a ticket that links the PR, and report `outcome: ticket`.
6. **Volume caps.** At most 1 PR per run (bundle related fixes into it) and at most 5 new tickets per run. Rank by severity. Summarize any overflow in the highest-ranked ticket.
7. **Ticket format.** Team `{{LINEAR_TEAM}}`, project `{{LINEAR_PROJECT}}`, labels `sched:{{JOB_ID}}` plus a type label (create labels that are missing). Use an imperative title. The description has these sections: **Why**, **Evidence** (`path:line`, links, command output excerpts), **Acceptance criteria**, **Suggested fix**, then a collapsible `+++ Agent notes` section for long detail. Set priority from severity: critical = Urgent, high = High, medium = Medium, low = Low.
8. **Never** do any of the following:
   - force-push or push directly to the default branch;
   - disable, skip, or weaken checks or tests to get green;
   - put secret values in tickets, PRs, or logs;
   - merge outside oneshot's gate;
   - touch other repositories;
   - delete anything the job body does not explicitly allow.
9. **Report.** Finish with a short summary of what you checked, what you found, and what you did, followed by the `outcome:` line.

## Job
