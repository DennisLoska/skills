---
name: council
description: Use when a change, branch, PR, or diff needs review before merge - says "council", "review this", or oneshot Phase 6. Available configured reviewers on distinct active models review in parallel, a review captain rules on every finding (accept, defer to backlog, reject), and fix rounds loop until consensus. Also carries receiving-side rigor for feedback.
---

# Council

**Context-scoped effort ceiling:** Non-council work, including driver sessions, defaults, advisory/design work, task-reviewer, fixing and testing, must never request or inherit effort above `high`. Only runtime council reviewer-a/b/c seats and fresh captain rulings may use profile-configured `xhigh`; council is the only skill permitting above high, with maximum `xhigh`. `max`, `ultra`, `ultrathink`, `ultracode`, and equivalent higher levels are forbidden everywhere. Verify provider capabilities before dispatch; use explicit provider-native options from `PROVIDERS.md`. Models without `xhigh` support use explicit `high` in council. Unknown/unsafe defaults require an explicit safe option or an unreachable rung; non-council defaults must be verified at most `high`. Shared reviewer contracts do not grant task reviews the council exception. Invoking a skill never changes the driver session or its ceiling.

Review by the available members of a configured three-seat council, a captain ruling on their findings, then disciplined application of what was accepted.

**Why:** One reviewer = one blind spot. Three distinct models = three different failure patterns. Agreement matters more than any single opinion, and a captain keeps valid-but-out-of-scope findings from blocking a change: they become backlog tickets instead of fix rounds.

**Model routing:** Reviewer seats `reviewer-a` (review captain), `reviewer-b`, and `reviewer-c` come from the active provider profile (`PROVIDERS.md`), routed by the `HARNESS.md` (`AGENTS.md`) Routing Rules (quota pools & ledger, failure classes, soft cap & reserve, same-model alternate, balanced seat fallback, seat distinctness, single-provider review, context-scoped effort ceiling, backup ladder walk, and budget stop & resume) and Dispatch Adapter (if `HARNESS.md` and `PROVIDERS.md` are not already in context, read `../_harness/HARNESS.md` and `../_harness/PROVIDERS.md` or `../../HARNESS.md` and `../../PROVIDERS.md` relative to this skill's directory; quota ledger read/updated via shell at `../../state/quota-ledger.tsv`). Never hardcode IDs. On usage-limit/429 (`exhausted`), an `unreachable` rung, a failed `transient` retry, or a soft-cap skip: re-seat per Fallback mechanics below and announce the demotion.

**Closed review eligibility:** Council seats and captain rulings use only the active profile's reviewer-a/b/c ladders, council backups, and single-provider rows. Task reviews use their separate task-reviewer ladders/backups at at most high; never use those rows to fill a council seat. Never introduce an excluded model to fill a seat. Self-review is allowed. Authorship never filters candidates or transfers captaincy. Unavailable members are skipped; remaining members proceed.

**Availability:** Try all configured seats and permitted fallbacks. Record `council_member: <seat> <provider/model> status=<reviewed|skipped> reason=<reason> head=<sha>` for attempted/skipped members. One available reviewer may PASS regardless of provider count, inside or outside oneshot. The sole reviewer is captain; rulings are fresh on that same captain. Obtain its final real `reviewer_vote: PASS|FAIL reviewer=<provider/model> head=<sha>` after rulings, never infer a vote. Require zero unresolved accepted findings and green actual checks (no no-tests exception).

Canonical single verdict: `council_verdict: PASS|FAIL round=<n> mode=single reviewer=<provider/model> head=<sha>`. Zero available reviewers means review skipped: `council_verdict: SKIPPED round=<n> mode=unavailable head=<sha>`, never PASS. Record every configured attempt/skip with reasons. A skipped review with green actual checks and matching local/remote HEAD permits land to merge; no no-tests exception. Availability cannot erase a prior FAIL or unresolved accepted findings. Provider counts and provider audits are not gates.

## Step 0: Routing Bootstrap

<HARD-GATE>
Before dispatching ANY council reviewer, captain ruling, or fixer subagent, verify all three bootstrap checks:
1. **Load `HARNESS.md` and `PROVIDERS.md` into context:** Check whether `# Cybernetic SDLC Harness` (`HARNESS.md`) AND the active provider profile routing table (`PROVIDERS.md`) are BOTH already loaded verbatim in this session. If either is missing, read `../_harness/HARNESS.md` and `../_harness/PROVIDERS.md` (or `../../HARNESS.md` and `../../PROVIDERS.md`) relative to this skill's directory NOW before taking any other action.
2. **Select the `HARNESS.md` Dispatch Adapter path (including lazy MCP servers):** Inspect both eager tools and any lazy-loaded MCP server schemas in your environment before choosing a subagent tool. Run the one-time session capability check required by `HARNESS.md` `## Dispatch Adapter` Path 1 when cross-provider orchestration tools are present (reading their lazy MCP schema files first when needed), and NEVER fall back to native same-session subagent tools while Path 1 orchestration tools are available.
3. **Resolve configured seats:** Every seat and captain ruling resolves an explicit rung from `PROVIDERS.md`, with `Role contract:` + `Rung:` where required. Simultaneously active seats use pairwise-distinct models. Self-review is allowed. Apply quota, reachability, privacy and effort checks; skip unavailable members without an availability stop.
</HARD-GATE>

## Request phase

1. **Scope:** diff of the branch (git diff against target), or PR, or given files. Read spec + plan when present.
2. **Seating:** Try configured seats and fallback ladders under HARNESS.md. When only one provider is reachable, its `## Single-provider review` rows remain recovery candidates. Never edit the profile or widen the allowlist. Record all attempted/skipped members with reasons and HEAD; choose mode from the remaining active seats.
3. **Captain:** `reviewer-a` holds the captaincy. If Seat A has no eligible rung, captaincy passes to the first healthy seat in order `reviewer-b`, `reviewer-c`. Write `captain: <seat> <provider>/<model>` with `head=<sha>` to the state artifact (update it whenever captaincy or the captain's rung changes).
4. **Dispatch all selected active seats in parallel** through the AGENTS.md Dispatch Adapter, one fresh subagent each: `reviewer-a`, `reviewer-b`, `reviewer-c`, with explicitly resolved configured rungs. Same scope, same instruction block (the captain reviews exactly like the other seats; its ruling comes later as a separate dispatch). Every dispatch names a rung from the active provider profile, so no seat ever inherits the main session model. In single mode the selected sole reviewer is the captain, when only one reviewer is available.

**T3 Code review dispatch:** Every task-review stage, council seat and captain ruling uses `delegate_task` with `role: "review"`, `mode: "async"`, `target: { providerInstanceId, model, options }` resolved from its permitted profile rung, a fresh `clientRequestId`, a self-contained `task` and `isolation: "shared"` for the stable review checkout. Never pass `modelSelection`, top-level `provider`, or `cwd`. Save the returned `taskId` with the reviewed HEAD, scope, seat/stage, rung and request ID; every re-check, replacement and round gets a new request ID and fresh dispatch.

**Delegate lifecycle:** Retain `childThreadId` as storage/reference only; never use `t3_thread_send`, `create_threads`, `t3_thread_launch`, or `t3_thread_interrupt` on it. Follow `next` and end the turn when awaiting a reactive completion wakeup. Never poll `task_status` before a completion wakeup. Timeout or missing output is neither approval nor child termination: call `task_cancel` with the saved `taskId` for replaced, timed-out or aborted runs before starting a replacement. A missing task ID requires recovery using the original request ID and authoritative tool schema, never a blind duplicate.

**Shared review scope:** No scoped-file edits while shared-checkout reviewers run. Driver and delegates wait for every active reviewer of that scope to finish or be cancelled before any fixer edits. Council seats may review the same frozen scope in parallel; task-review stages remain sequential. Overlapping parallel editing requires `isolation: "worktree"` and a fresh review of the integrated result.
5. **Reviewer instruction block:**

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

6. **Evidence:** Record `reviewer_vote: PASS|FAIL reviewer=<provider/model> head=<sha>` for every available seat. Bind every vote, captain ruling and actual verification receipt (commands, exit/status) to `git rev-parse HEAD`. Author metadata is audit-only. Record availability attempts and skips; never replace an actual review FAIL with availability SKIPPED.
7. **Mid-round provider retry vs round N+1 re-review:** if a seat's rung is exhausted, unreachable, soft-cap reserved, or fails a transient retry mid-round, re-seat that SAME role per Fallback mechanics and rerun only that seat to complete the current round. Whenever fixers push new commits, round N+1 re-dispatches ALL active seats (all 3, both in degraded mode, or the sole reviewer in mode=single) against the new HEAD. Re-dispatching only one seat across rounds is forbidden outside mode=single.
8. **Confidentiality gate:** if the review brief or referenced diff carries a confidential flag, the AGENTS.md Routing Rules privacy gate applies to every seat and the captain ruling (`privacy: trains` rungs auto-skip); demote to the next privacy-safe rung and announce.

## Fallback mechanics

Every seat has a contract file (`agents/<seat>.md`) and a primary rung in the active provider profile. Before walking a seat's ladder, check `<dest>/state/quota-ledger.tsv`, `soft_cap_counts` (per-pool dispatch counts this run, every pool) in the state artifact (`AGENTS.md` Routing Rules). When a seat's rung is exhausted, unreachable, fails a transient retry, holds a model already active on another seat:

1. **Same-model alternate:** a `## Backup ladder` row matching the seat with the identical `model` on another eligible pool.
2. **Balanced seat fallback:** otherwise, from the seat's remaining eligible ladder rungs and matching `## Backup ladder` rows, take the rung whose quota pool has the fewest dispatches this run (`soft_cap_counts`); ties break by ladder order, then backup `order`. Every candidate passes pool/ledger, soft-cap, privacy, effort, and seat-distinctness checks.
3. **Single-provider review** (Request phase step 2) overrides both when only one provider is left.

```
re-dispatch: AGENTS.md Dispatch Adapter, role <seat>, rung <chosen rung>
announce: "seat <seat> demoted to <provider>/<model>" (or "backup: <seat> -> <provider>/<model>")
```

- **Seat distinctness:** a demotion may cross families to balance load, but never lands on a model active on another seat.
- **Seat lost:** record exhausted/unreachable members and continue with remaining reviewers: two use degraded, one uses single, zero records SKIPPED/unavailable. A lost Seat A hands captaincy to the next healthy seat. Never budget-stop solely for reviewer availability.
- **Budget guard:** max 15 real reviewer dispatches per PR (9 seat, 3 captain rulings, 3 demotions). Budget skips and skipped rulings cost 0. A demoted seat keeps its new rung for the day.

## Merge phase

- Collect all seat verdicts, then merge findings into one list, severity sorted red -> yellow -> blue. Dedupe identical findings, keep the sharpest wording, and keep the attribution of every seat that raised it.
- Number them `F1..Fn` (stable within the round): `F<n> [<seats>]: path:line: emoji severity: problem. fix.`

## Captain ruling

**When:** after all seat verdicts are in, if any seat voted FAIL or any red/yellow finding exists. If every seat voted PASS with no red/yellow findings, skip the ruling (costs 0). If a required ruling is unavailable, retain FAIL and unresolved findings; availability cannot dismiss them.

**Dispatch:** a fresh subagent on the captain's rung (the captain seat's current rung; `Role contract:` = the `reviewer-a` contract, ruling mode), with the merged list, the diff, the spec, and the plan. Ruling brief: This is a new `role: "review"`, `mode: "async"` dispatch with a new `clientRequestId` and saved `taskId`; apply the review lifecycle and shared-scope freeze above.

```
Review captain ruling. Rule on every merged finding below (ids F1..Fn, seat
attribution), checking each against the diff, spec, and plan. Read code to decide.
For each finding output exactly one line:
  <finding-id>: accept | defer | reject: <one-line reason>
    accept = real and in scope (any severity); must be fixed before PASS
    defer  = valid but need not block this PR: unrelated, overengineering, not
             relevant, or out of scope; becomes a backlog ticket
    reject = wrong; cite path:line evidence
Never defer or reject a red that is an in-scope correctness, security, or
data-loss bug introduced by this diff.
Final line: Captain verdict: PASS | FAIL
  PASS only when every finding is deferred or rejected (nothing accepted).
No new findings. No praise.
```

**Limits on the captain (driver-enforced):**
- A red finding that the driver confirms against real code as an in-scope correctness, security, or data-loss bug introduced by this diff can never be deferred or rejected. The driver overrides such a ruling to `accept`, writes `captain overruled: <finding-id>` to the state artifact, and treats the captain verdict as FAIL.
- Green tests are always required; the captain can never waive a red test run.
- Every `accept`ed finding, red or yellow, is fixed before PASS in every mode; valid findings that need not block this PR are `defer`red to the backlog instead. Fixers address only `accept`ed findings. Deferred and rejected findings are never fixed in this PR.

**Backlog:** for every `defer`, write `backlog: <finding line> (<reason>)` to the state artifact (dedupe across rounds), and add the same entry to a `## Backlog` section in the PR body (create the section if missing; edit the body with `gh pr edit <number> --body-file <file>` per the `land` PR rules). After merge, `land` files one ticket per entry according to `backlog_tracker`.

## Verdict phase

Decide in this order, after applying driver overrules and receiving-side rigor:

| mode | PASS condition |
| --- | --- |
| `nominal` | 3 healthy seats, >= 2/3 PASS, zero unresolved accepted findings, green tests (or the `no-tests` exception) |
| `degraded` | 2 healthy seats (one lost), 2/2 PASS, zero unresolved accepted findings, green tests |
| `single` | 1 available configured reviewer final PASS, zero unresolved accepted findings, green actual checks; no no-tests exception |
| `captain` | captain verdict PASS overriding FAIL votes: every finding is deferred or rejected, zero unresolved accepted findings, green tests (no `no-tests` exception) |

- Captain mode is available in any round, with 2 or 3 healthy seats.
- Accepted findings always block: any unresolved `accept` (red or yellow) makes the round FAIL, even when the seat votes pass; fix it and re-review.
- Zero reviewers records SKIPPED/unavailable, subject to the availability evidence and verification contract above. Actual review FAIL and unresolved accepted findings still block.

## Receiving phase (rigor)

- For every accepted red: find the exact code it refers to and confirm the claim yourself before dispatching fixes. A wrong finding gets marked `rejected: <one-line why>` and is reported, not silently dropped.
- For every deferred or rejected red: check it against the captain limits above before accepting the ruling.
- Reject count is information: 3+ rejections in one round means a seat is misreading the codebase. Say so in the round report.

## Round loop (max 3 review rounds total)

Round 1 = the initial selected-seat review from the Request phase; rounds 2-3 = fix then re-review. Never exceed 3 review batches; count them out loud.

```
round N: parallel seat review -> merge -> captain ruling (unless skipped) -> verdict
  PASS -> write canonical mode=single verdict when selected (never mode=captain), otherwise normal council_verdict; done
  SKIPPED/unavailable -> record all configured attempts/skips; require green actual verification and no unresolved review failures; done
  FAIL, N < 3:
    dispatch fresh fixer subagents from the implementation seats (`implementer`, or `implementer-deep` for hard clusters; one per accepted-finding cluster, max 2 files each; see `AGENTS.md` Review contracts); allow `patch` only for a 1-2 file edit with no test run
    fixers address accepted findings only and run tests before declaring done
    re-run verify skill checks (tests, lint, typecheck, build)
    round N+1 review = all active fresh reviewer seats (sole reviewer only in mode=single) + a fresh captain ruling
    streamed, no user pause
  FAIL, N = 3:
    write council_verdict: FAIL round=3 mode=<nominal|degraded> head=<sha> (or the canonical mode=single line above)
    STOP: report rounds, final findings with rulings, backlog entries, test output
```

- There is no escalation seat: a round-3 FAIL always stops to the user.
- Reviewer never edits during review. Dispatch fresh fixers and reviewers each round; the same model may serve either role.

## No test suite

See `AGENTS.md` Review contracts for the canonical `no-tests` gate rule. Operational steps: label a `no-tests` PASS `provisional: no-tests` in the verdict (`mode=nominal` only; `mode=degraded`, `mode=captain` and `mode=single` require green tests), have the reviewer flag `no tests: yellow` in findings, and never invent a test suite in council (that belongs to `tdd` in the task loop).

## Output format

```
Round N: [seat verdicts (3, 2 active + lost seat, 1 in mode=single, or 0 in mode=unavailable)] captain <seat> -> merged findings (r red, y yellow, b blue) -> ruling (a accept, d defer, j reject, o overruled | skipped)
Verdict: PASS | FAIL | SKIPPED (mode=<nominal|degraded|captain|single|unavailable>)
Backlog: <n> deferred
```

**Lossless state updates:** Preserve all canonical keys in `$(git rev-parse --git-dir)/info/oneshot-state.md`: `dispatch_adapter`, `primary_rungs`, `phase`, `branch`, `pr_url`, `author_models`, `author_families`, `author_commits`, `tests_status`, `council_round`, `council_verdict`, `captain`, `backlog`, and `soft_cap_counts`. Preserve existing values unless the current event explicitly updates them, and preserve unknown keys, standing findings, `earliest_resume`, member attempts/skips, votes, rulings, backlog filing receipts and task lifecycle records. Use append for event history or read-merge-write for a keyed update, retaining unrelated content and the effective-last-verdict convention. Never overwrite the state artifact with a truncated summary. A council-only run creates missing state but merges with existing pipeline state; it never replaces routing or author history.

State artifact lines (`$(git rev-parse --git-dir)/info/oneshot-state.md`, creating `$(git rev-parse --git-dir)/info` if missing; standalone council runs in a git repo write them too):

- `council_verdict: PASS|FAIL round=<n> mode=<nominal|degraded|captain> head=<sha>` (`<n>` is `1..3`, `<sha>` is `git rev-parse HEAD`; consumers read the effective last line). On PASS append/update it, then output a one-line summary. On FAIL write it, output the merged finding list with rulings, and continue the round loop or stop.
- For zero reviewers use `council_verdict: SKIPPED round=<n> mode=unavailable head=<sha>` and member attempts/skips above. Never use this to replace an unresolved FAIL.
- For mode=single use the canonical additional verdict and member/vote lines above, bound to the reviewed HEAD.
- `captain: <seat> <provider>/<model>`
- `captain overruled: <finding-id>`
- `backlog: <finding line> (<reason>)`
- `single-provider review: <provider>` (while the mode is active)
