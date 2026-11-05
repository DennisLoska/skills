---
name: make-ci-green
description: Use when a PR should be watched through CI and review bots until green, and real findings fixed - says "make ci green", "watch the checks", "babysit the PR", or oneshot Phase 6.5.
---

# Make CI Green

Watch a PR through CI checks and bot reviews. Fix real findings. Kill flakes with evidence, not reruns.

**Model routing:** fixer subagents come from the AGENTS.md implementation role ladder. This skill never calls a model directly.

## Loop

```
while checks not green (bounded poll: run `gh pr checks <id>` in a loop with a 30-second wait, at most 10 minutes total; on timeout return `CI stalled at <sha>` and hand back to the controller):
  read state: gh pr checks <id>, gh pr view <id> --json reviews,labels
  classifier, for each failing/blocked item:
    - bot review finding -> real finding?
    - failing check -> root cause in log?
    - infra flake (network timeouts, rate limits, runner died on rerun) -> flake
  real finding:
    dispatch fresh fixer subagent from an implementation seat (`implementer` or `implementer-b`) (max 2 files), fixer runs tests before done
    verify checker: tests/lint/typecheck/build locally
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
- Fixer scope creep (2 files max; fixers come from the implementation seats (`implementer` or `implementer-b`); allow `patch` only for a finding that needs a 1-2 file edit with no test run)
- Silent reds (announcement each poll: state summary in one line)

## Exit

Green + no unresolved bot findings -> return `CI green at <sha>`, hand back to council flow. `fix_rounds` reaches 3 with checks still red -> STOP, report last failing log line, findings, what was tried.
