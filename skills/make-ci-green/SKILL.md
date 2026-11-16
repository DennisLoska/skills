---
name: make-ci-green
description: Use when a PR should be watched through CI and review bots until green, and real findings fixed - says "make ci green", "watch the checks", "babysit the PR", or oneshot Phase 6.5.
---

# Make CI Green

**Context-scoped effort ceiling:** Non-council work, including driver sessions, defaults, advisory/design work, task-reviewer, fixing and testing, must never request or inherit effort above `high`. Only runtime council reviewer-a/b/c seats and fresh captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high, with maximum `xhigh`. `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent higher levels are forbidden everywhere. Verify provider capabilities before dispatch; use explicit provider-native options from `PROVIDERS.md`. Argon uses explicit `thinking_level=high` because it has no xhigh support. Unknown/unsafe defaults require an explicit safe option or an unreachable rung; non-council defaults must be verified at most `high`. Shared reviewer contracts do not grant task reviews the council exception. Invoking a skill never changes the driver session or its ceiling.

Watch a PR through CI checks and bot reviews. Fix real findings. Kill flakes with evidence, not reruns.

**Model routing:** `tester` (script runner) reads CI logs and reruns checks locally to return a compressed pass/fail report; fixer subagents come from the implementation seats (`implementer`, or `implementer-deep` for hard clusters) in the active provider profile (`PROVIDERS.md`), dispatched through the AGENTS.md Dispatch Adapter (same-model alternate and backup ladder on exhausted rungs; every rung at or below `high` effort). This skill never calls a model directly.

## Shared finding and flake handling

These rules apply to both T3 Code reactive monitoring and the non-T3 CLI loop, with counters preserved across wakeups and polls:

- Classify each failing or blocked item: check bot review findings against the code; dispatch `tester` to read failing CI logs and reproduce locally, returning failing check/test names and a first-error excerpt. Treat confirmed infrastructure failures (network timeouts, rate limits, runner failure) as flakes only with log evidence.
- For real findings, dispatch a fresh implementation-seat fixer (`implementer`, or `implementer-deep` for hard clusters), limited to 2 files, and require tests before completion. Dispatch `tester` to verify tests/lint/typecheck/build locally. Push one conventional commit per finding cluster; CI reruns automatically on push.
- For a flake, document the run and log line in one PR comment, then rerun that single failed check with `gh run rerun <run-id> --failed` once. If a second flake fails in the same check, escalate to the user; never make a third blind rerun. Preserve the per-check rerun count across wakeups and polls.
- For a false bot finding, comment once with the claim, code evidence and requested clarification. Treat controversial findings as real and note the doubt in the comment.

Counter `fix_rounds`: initialized at 0, incremented once per fix commit on either monitoring path. Stop at 3 with the STOP behavior in Exit.

## T3 Code reactive monitoring

Use this path in T3 Code. Apply Shared finding and flake handling, including classification, fixer routing, the single evidence-backed flake rerun and the 3-round fixer cap. Inspect existing checks and comments first, including reviews and unresolved bot findings; do useful diagnosis before registering a watcher. Failing logs and local reproduction still go through tester, and confirmed findings still go through fresh implementation-seat fixers.

Only the parent thread owning the PR calls `watch_pull_request`; delegate_task children never call `watch_pull_request`. Children return the full PR URL, head SHA, check/review state and remaining blockers to their parent.

Finish any needed branch update and push before waiting. Immediately after a PR is created, taken over or pushed, call `link_pull_request` with the full PR URL as the next tool call; use `link_pull_requests` for multiple PRs. Resolve an existing PR URL before the push. Then use `watch_pull_request`, maintain one watcher per PR, and end the turn to await T3 Code's reactive wakeup. An existing watcher remains valid across pushes; do not create a duplicate.

Never run a manual 30-second `gh pr checks` polling loop in T3 Code. On wakeup, inspect the new checks/comments and current remote HEAD, classify new information, fix confirmed findings within the existing caps, and watch again only when work still waits on checks or reviews. Preserve fix counters and the monitored head across wakeups. Green evidence must match the final head.

When `gh pr checks` or `gh pr view` hits GraphQL rate limits, use `gh api repos/{owner}/{repo}/commits/{sha}/check-runs` for checks and REST PR, review and comment endpoints for the remaining evidence. Resolve the current remote PR head before querying check runs; paginate responses and inspect combined commit statuses when required. Do not infer green from an empty or incomplete check-runs response.

Call `unwatch_pull_request` before handback, stopping, or asking the user a question, and when monitoring completes or is cancelled. Ending a turn solely to await the requested reactive wakeup keeps the watcher active; completed handoff to council does not.

Outside T3 Code, use the bounded CLI loop below.

## Non-T3 CLI loop

Apply Shared finding and flake handling, including classification, fixer routing, the single evidence-backed flake rerun and the 3-round fixer cap.

```
while checks not green (bounded poll: run `gh pr checks <id>` in a loop with a 30-second wait, at most 10 minutes total; on timeout return `CI stalled at <sha>` and hand back to the controller):
  read state: gh pr checks <id>, gh pr view <id> --json reviews,labels
  apply Shared finding and flake handling to each failing/blocked item
  no new information since last poll -> re-poll at most 3 times with a short wait between attempts; after 3 polls with no change, return `CI stalled at <sha>` and hand back to the controller instead of waiting indefinitely.
```

## Prevents

- Blind rerun loops (no rerun without pointing at what changed)
- Chasing flakes with silence (evidence comment required)
- Faking green (skip: no disable-checks, no WIP labels, no [skip ci] commits)
- Fixer scope creep (2 files max; fixers come from the implementation seats (`implementer`, or `implementer-deep` for hard clusters); allow `patch` only for a finding that needs a 1-2 file edit with no test run)
- Silent reds (announce the state on each reactive wakeup or non-T3 CLI poll)

## Exit

Green + no unresolved bot findings -> return `CI green at <sha>`, hand back to council flow. `fix_rounds` reaches 3 with checks still red -> STOP, report last failing log line, findings, what was tried.

In T3 Code, call `unwatch_pull_request` before returning green to council or reporting a stop. Retain the watcher only when ending the turn to await its requested wakeup.
