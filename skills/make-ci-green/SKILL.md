---
name: make-ci-green
description: Use when a PR should be watched through CI and review bots until green, and real findings fixed - says "make ci green", "watch the checks", "babysit the PR", or oneshot Phase 6.5.
---

# Make CI Green

**Context-scoped effort ceiling:** Non-council work, including driver sessions, defaults, advisory/design work, task-reviewer, fixing and testing, must never request or inherit effort above `high`. Only runtime council reviewer-a/b/c seats and fresh captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high, with maximum `xhigh`. `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent higher levels are forbidden everywhere. Verify provider capabilities before dispatch; use explicit provider-native options from `PROVIDERS.md`. Argon uses explicit `thinking_level=high` because it has no xhigh support. Unknown/unsafe defaults require an explicit safe option or an unreachable rung; non-council defaults must be verified at most `high`. Shared reviewer contracts do not grant task reviews the council exception. Invoking a skill never changes the driver session or its ceiling.

Watch a PR through CI checks and bot reviews. Fix real findings. Kill flakes with evidence, not reruns.

**Model routing:** `tester` (script runner) reads CI logs and reruns checks locally to return a compressed pass/fail report; fixer subagents come from the implementation seats (`implementer`, or `implementer-deep` for hard clusters) in the active provider profile (`PROVIDERS.md`), dispatched through the AGENTS.md Dispatch Adapter (same-model alternate and backup ladder on exhausted rungs; every rung at or below `high` effort). This skill never calls a model directly.

## T3 Code reactive monitoring

Use this path in T3 Code. Inspect existing checks and comments first, including reviews and unresolved bot findings; do useful diagnosis before registering a watcher. Failing logs and local reproduction still go through tester, and confirmed findings still go through fresh implementation-seat fixers.

Only the parent thread owning the PR calls `watch_pull_request`; delegate_task children never call `watch_pull_request`. Children return the full PR URL, head SHA, check/review state and remaining blockers to their parent.

Finish any needed branch update and push before waiting. Immediately after a PR is created, taken over or pushed, call `link_pull_request` with the full PR URL as the next tool call; use `link_pull_requests` for multiple PRs. Resolve an existing PR URL before the push. Then use `watch_pull_request`, maintain one watcher per PR, and end the turn to await T3 Code's reactive wakeup. An existing watcher remains valid across pushes; do not create a duplicate.

Never run a manual 30-second `gh pr checks` polling loop in T3 Code. On wakeup, inspect the new checks/comments and current remote HEAD, classify new information, fix confirmed findings within the existing caps, and watch again only when work still waits on checks or reviews. Preserve fix counters and the monitored head across wakeups. Green evidence must match the final head.

When `gh pr checks` or `gh pr view` hits GraphQL rate limits, use `gh api repos/{owner}/{repo}/commits/{sha}/check-runs` for checks and REST PR, review and comment endpoints for the remaining evidence. Resolve the current remote PR head before querying check runs; paginate responses and inspect combined commit statuses when required. Do not infer green from an empty or incomplete check-runs response.

Call `unwatch_pull_request` before handback, stopping, or asking the user a question, and when monitoring completes or is cancelled. Ending a turn solely to await the requested reactive wakeup keeps the watcher active; completed handoff to council does not.

Outside T3 Code, use the bounded CLI loop below.

## Non-T3 CLI loop

```
while checks not green (bounded poll: run `gh pr checks <id>` in a loop with a 30-second wait, at most 10 minutes total; on timeout return `CI stalled at <sha>` and hand back to the controller):
  read state: gh pr checks <id>, gh pr view <id> --json reviews,labels
  classifier, for each failing/blocked item:
    - bot review finding -> real finding?
    - failing check -> dispatch `tester` (script runner) to read CI logs / reproduce locally and return a compressed report (failing check/test names + first-error excerpt) -> root cause in log?
    - infra flake (network timeouts, rate limits, runner died on rerun) -> flake
  real finding:
    dispatch fresh fixer subagent from an implementation seat (`implementer`, or `implementer-deep` for hard clusters) (max 2 files), fixer runs tests before done
    verify checker: dispatch `tester` to run tests/lint/typecheck/build locally
    push fix: one commit per finding cluster, conventional message
    CI reruns automatically on push; no manual rerun needed
  flake:
    document evidence in the PR (one comment: which run, which log line)
    rerun that single check via gh run rerun <run-id> --failed, once
    second flake in same check -> escalate to user, never a third blind rerun
  bot finding smells false:
    confirm against code yourself
    false -> one PR comment: claim, one-line evidence, requested-clarification
      true -> treat as real finding
    controversial (not clearly either) -> treat as real, note the doubt in the comment
  no new information since last poll -> re-poll at most 3 times with a short wait between attempts; after 3 polls with no change, return `CI stalled at <sha>` and hand back to the controller instead of waiting indefinitely.
```
Counter `fix_rounds`: initialized at 0, incremented once per fix commit. Stop at 3 with the STOP behavior in Exit.

## Prevents

- Blind rerun loops (no rerun without pointing at what changed)
- Chasing flakes with silence (evidence comment required)
- Faking green (skip: no disable-checks, no WIP labels, no [skip ci] commits)
- Fixer scope creep (2 files max; fixers come from the implementation seats (`implementer`, or `implementer-deep` for hard clusters); allow `patch` only for a finding that needs a 1-2 file edit with no test run)
- Silent reds (announce the state on each reactive wakeup or non-T3 CLI poll)

## Exit

Green + no unresolved bot findings -> return `CI green at <sha>`, hand back to council flow. `fix_rounds` reaches 3 with checks still red -> STOP, report last failing log line, findings, what was tried.

In T3 Code, call `unwatch_pull_request` before returning green to council or reporting a stop. Retain the watcher only when ending the turn to await its requested wakeup.
