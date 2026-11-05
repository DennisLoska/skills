---
name: council
description: Use when a change, branch, PR, or diff needs review before merge - says "council", "review this", or oneshot Phase 6. Three independent reviewers from different model families loop until consensus. Also carries receiving-side rigor for feedback.
---

# Council

Consensus review by 3 independent reviewers, followed by disciplined application of findings.

**Why:** One reviewer = one blind spot. Three independent model families = three different failure patterns. Agreement matters more than any single opinion.

**Model routing:** Reviewer roles A/B/C + escalation come from AGENTS.md "Model Tank" rows. Never hardcode IDs. On usage-limit/429: demote along that seat's ladder, announce the demotion. Minimum 2 healthy independent families or stop and surface yellow.

## Request phase

1. Scope: diff of the branch (git diff against target), or PR, or given files. Read spec + plan when present.
2. Dispatch the three council seat agents via the `subagent` tool (some builds register this tool as `task`; use whichever the session exposes), one fresh subagent each: `reviewer-a`, `reviewer-b`, `reviewer-c`. Same scope, same instructions, one independent model family per seat (each agent file pins its seat model, so no seat ever inherits the main session model).
3. Reviewer instruction block:

```
Adversarial reviewer. Assume the change is broken. Hunt for: spec compliance
gaps, edge cases, error handling, security, performance, test holes, regressions,
diff-vs-plan drift. Verify by reading code, not by trusting the task description.
If GLOSSARY.md exists, flag terminology drift and any new term the glossary does not define.
Output:
  Verdict: PASS | FAIL
  One line per finding: path:line: emoji severity: problem. fix.
    red = bug, yellow = risk, blue = nit (nits only if requested)
  Tests status: green | red | no-tests
No praise. No "looks good". No scope creep.
```

4. If a seat's model is exhausted mid-round: re-dispatch the SAME seat agent id with an explicit `model` field set to the seat's next ladder entry from AGENTS.md "Model Tank" (mechanics below). Rerun only that seat. Never fill a seat with a model from a family already used anywhere in this PR.
5. Confidentiality gate: if the review brief or referenced diff carries a confidential flag, any rung marked as training on request data in AGENTS.md Privacy Footnotes auto-skips for every seat; demote to the next privacy-safe rung and announce.

## Fallback mechanics

Every seat lives in an agent file with a pinned primary model. When its primary returns a usage-limit or 429-style provider error:

```
re-dispatch: subagent: agent <seat>, model <next ladder entry>
announce: "seat <seat> demoted to <model>"
```

- A demotion never breaks family independence: skip any ladder entry whose family already serves another seat used anywhere in this PR.
- A seat with zero healthy ladder entries = seat lost. Continue if at least 2 independent families remain; otherwise stop with `yellow: degraded council`.
- The escalation seat is a separate agent (`reviewer-esc`), pinned to the AGENTS.md escalation row. It never substitutes a lost seat mid-round; it enters only after the round budget is spent.

## Verdict phase

- PASS = at least 2 of 3 seats vote PASS AND zero unresolved confirmed red findings from any seat, and tests green, or the no-tests rule satisfied. A confirmed red from a single FAIL seat blocks PASS just the same, until it is fixed or rebutted with evidence.
- Fewer than 2 families healthy: STOP with `yellow: degraded council` per the canonical degraded-council rule in `AGENTS.md` Review contracts.
- Merge findings into one list, severity sorted red -> yellow -> blue. Dedupe identical findings, keep the sharpest wording.
- Escalation seat independence spans the whole PR: `reviewer-esc` never runs on a model family another seat already used this PR (check AGENTS.md family map per ladder rung). On conflict, demote along the `reviewer-esc` ladder in AGENTS.md until an unused Go family is found, else stop and surface `yellow: degraded council`.

## Receiving phase (rigor)

- For every red: find the exact code it refers to and confirm the claim yourself before dispatching fixes. A wrong finding gets marked `rejected: <one-line why>` and is reported, not silently dropped.
- Reject count is information: 3+ rejections in one round means the reviewer family is misreading the codebase. Say so in the round report.

## Round loop (max 3 review rounds total)

round 1 = the initial three-seat review from the Request phase (no extra batches); rounds 2-3 = fix then re-review. In round terms: verdict of round N FAIL -> dispatch fresh fixers -> round N+1 review. Never exceed 3 total review batches; count them out loud.

```
total review batches = 3, counted out loud:
  round 1 = the initial three-seat review from the Request phase (no extra batch)
  verdict of round N FAIL, N < 3:
    dispatch fresh fixer subagents from the implementation seats (`implementer` or `implementer-b`; one per finding cluster, max 2 files each; see `AGENTS.md` Review contracts for fixer seat routing); allow `patch` only for a finding that needs a 1-2 file edit with no test run
    implementation-seat fixers run tests before declaring done
    re-run verify skill checks (tests, lint, typecheck, build)
    round N+1 review = 3 fresh reviewer seats
    PASS + green -> done
    streamed, no user pause
```

- Rounds exhausted -> escalation review on the AGENTS.md escalation row (own family, not one already used).
- Escalation still FAIL -> STOP: report rounds, final findings, test output. This is one of the council stop points (alongside the degraded-council stop).
- Reviewer never fixes. Fixer never reviews. Fresh subagent each round, both ways.

## No test suite

See `AGENTS.md` Review contracts for the canonical `no-tests` gate rule. Operational steps: label a `no-tests` PASS `provisional: no-tests` in the verdict, have the reviewer flag `no tests: yellow` in findings, and never invent a test suite in council (that belongs to `tdd` in the task loop).

## Output format

```
Round N: [3 verdicts] -> merged findings (r red, y yellow, b blue, k rejected)
Verdict: PASS | FAIL | DEGRADED
```

Then on PASS: one-line summary. On FAIL: the merged finding list. Stop.
