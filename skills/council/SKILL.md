---
name: council
description: Use when a change, branch, PR, or diff needs review before merge - says "council", "review this", or oneshot Phase 6. Three reviewers on distinct models review in parallel, a review captain rules on every finding (accept, defer to backlog, reject), and fix rounds loop until consensus. Also carries receiving-side rigor for feedback.
---

# Council

Consensus review by 3 independent reviewers, a captain ruling on their findings, then disciplined application of what was accepted.

**Why:** One reviewer = one blind spot. Three distinct models = three different failure patterns. Agreement matters more than any single opinion, and a captain keeps valid-but-out-of-scope findings from blocking a change: they become backlog tickets instead of fix rounds.

**Model routing:** Reviewer seats `reviewer-a` (review captain), `reviewer-b`, and `reviewer-c` come from the active provider profile (`PROVIDERS.md`), routed by the `HARNESS.md` (`AGENTS.md`) Routing Rules (quota pools & ledger, failure classes, soft cap & reserve, same-model alternate, balanced seat fallback, seat distinctness, single-provider review, Anthropic effort cap, backup ladder walk, and budget stop & resume) and Dispatch Adapter (if `HARNESS.md` and `PROVIDERS.md` are not already in context, read `../_harness/HARNESS.md` and `../_harness/PROVIDERS.md` or `../../HARNESS.md` and `../../PROVIDERS.md` relative to this skill's directory; quota ledger read/updated via shell at `../../state/quota-ledger.tsv`). Never hardcode IDs. On usage-limit/429 (`exhausted`), an `unreachable` rung, a failed `transient` retry, or a soft-cap skip: re-seat per Fallback mechanics below and announce the demotion. Minimum 2 distinct non-author review models or stop and surface yellow.

## Step 0: Routing Bootstrap

<HARD-GATE>
Before dispatching ANY council reviewer, captain ruling, or fixer subagent, verify all three bootstrap checks:
1. **Load `HARNESS.md` and `PROVIDERS.md` into context:** Check whether `# Cybernetic SDLC Harness` (`HARNESS.md`) AND the active provider profile routing table (`PROVIDERS.md`) are BOTH already loaded verbatim in this session. If either is missing, read `../_harness/HARNESS.md` and `../_harness/PROVIDERS.md` (or `../../HARNESS.md` and `../../PROVIDERS.md`) relative to this skill's directory NOW before taking any other action.
2. **Select the `HARNESS.md` Dispatch Adapter path (including lazy MCP servers):** Inspect both eager tools and any lazy-loaded MCP server schemas in your environment before choosing a subagent tool. Run the one-time session capability check required by `HARNESS.md` `## Dispatch Adapter` Path 1 when cross-provider orchestration tools are present (reading their lazy MCP schema files first when needed), and NEVER fall back to native same-session subagent tools while Path 1 orchestration tools are available.
3. **Forbid same-model council seats and author self-review:** Every dispatched council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) and every captain ruling MUST resolve its rung from `PROVIDERS.md` (carrying `Role contract:` + `Rung:` on non-autoloaded paths, or `Rung:` only on autoloaded pinned seats). Seats run on pairwise-distinct models, none in `author_models`. Never spawn native `inherit`/same-model subagents for council seats. Council shall not block if at least 2 distinct healthy reviewer models differ from `author_models`; only when fewer remain does council stop with `yellow: degraded council`. Reviewing one's own code without model independence is a hard protocol violation.
</HARD-GATE>

## Request phase

1. **Scope:** diff of the branch (git diff against target), or PR, or given files. Read spec + plan when present.
2. **Single-provider check:** if exactly one provider in the profile still has an eligible pool (all others exhausted per the quota ledger or unreachable per the Dispatch Adapter), announce `single-provider review: <provider>`, write that line to the state artifact, and seat every reviewer from that provider's `## Single-provider review` rows in `PROVIDERS.md`: pairwise-distinct models, none in `author_models`, Seat A first (it takes the first eligible row). This is a fallback condition, never a standing restriction: re-run this check at the start of every round and on every seat demotion, and leave the mode as soon as a second provider is eligible again. Profile rows are never edited.
3. **Captain:** `reviewer-a` holds the captaincy. If Seat A has no eligible rung, captaincy passes to the first healthy seat in order `reviewer-b`, `reviewer-c`. Write `captain: <seat> <provider>/<model>` to the state artifact (update it whenever captaincy or the captain's rung changes). The captain, like every seat, never runs on a model in `author_models`.
4. **Dispatch all seats in parallel** through the AGENTS.md Dispatch Adapter, one fresh subagent each: `reviewer-a`, `reviewer-b`, `reviewer-c`, with rungs resolved after the author rules in step 6. Same scope, same instruction block (the captain reviews exactly like the other seats; its ruling comes later as a separate dispatch). Every dispatch names a rung from the active provider profile, so no seat ever inherits the main session model.
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

6. **Author-model & author-family rules:** before resolving seat rungs, read `author_models` and `author_families` (plus the author commit log) from `$(git rev-parse --git-dir)/info/oneshot-state.md`. Any seat or captain-ruling rung whose `model` is in `author_models` is skipped to the next eligible rung per Fallback mechanics, announcing `demote: <seat> -> <provider>/<model> (author model conflict)`; a seat with zero eligible non-author rungs is lost. The author vote (Verdict phase) uses `author_families` and `author_models`.
7. **Mid-round provider retry vs round N+1 re-review:** if a seat's rung is exhausted, unreachable, soft-cap reserved, or fails a transient retry mid-round, re-seat that SAME role per Fallback mechanics and rerun only that seat to complete the current round. Whenever fixers push new commits, round N+1 re-dispatches ALL active seats (all 3, or both in degraded mode) against the new HEAD. Re-dispatching a single seat across rounds is forbidden.
8. **Confidentiality gate:** if the review brief or referenced diff carries a confidential flag, the AGENTS.md Routing Rules privacy gate applies to every seat and the captain ruling (`privacy: trains` rungs auto-skip); demote to the next privacy-safe rung and announce.

## Fallback mechanics

Every seat has a contract file (`agents/<seat>.md`) and a primary rung in the active provider profile. Before walking a seat's ladder, check `<dest>/state/quota-ledger.tsv`, `soft_cap_counts` (per-pool dispatch counts this run, every pool), and `author_models` in the state artifact (`AGENTS.md` Routing Rules). When a seat's rung is exhausted, unreachable, fails a transient retry, conflicts with `author_models`, or holds a model already active on another seat:

1. **Same-model alternate:** a `## Backup ladder` row matching the seat with the identical `model` on another eligible pool.
2. **Balanced seat fallback:** otherwise, from the seat's remaining eligible ladder rungs and matching `## Backup ladder` rows, take the rung whose quota pool has the fewest dispatches this run (`soft_cap_counts`); ties break by ladder order, then backup `order`. Every candidate passes pool/ledger, soft-cap, privacy, author-model, and seat-distinctness checks.
3. **Single-provider review** (Request phase step 2) overrides both when only one provider is left.

```
re-dispatch: AGENTS.md Dispatch Adapter, role <seat>, rung <chosen rung>
announce: "seat <seat> demoted to <provider>/<model>" (or "backup: <seat> -> <provider>/<model>", or "demote: <seat> -> <provider>/<model> (author model conflict)")
```

- **Seat distinctness:** a demotion may cross families to balance load, but never lands on a model active on another seat or listed in `author_models`.
- **Seat lost:** a seat with zero eligible rungs is lost. Continue in degraded mode while at least 2 distinct non-author reviewer models remain; otherwise stop with `yellow: degraded council` (report exhausted pools + `earliest resume` per `AGENTS.md` budget stop & resume when quota caused it). A lost Seat A hands the captaincy to the next healthy seat (Request phase step 3).
- **Budget guard:** max 15 real reviewer dispatches per PR (9 seat, 3 captain rulings, 3 demotions). Budget skips and skipped rulings cost 0. A demoted seat keeps its new rung for the day.

## Merge phase

- Collect all seat verdicts, then merge findings into one list, severity sorted red -> yellow -> blue. Dedupe identical findings, keep the sharpest wording, and keep the attribution of every seat that raised it.
- Number them `F1..Fn` (stable within the round): `F<n> [<seats>]: path:line: emoji severity: problem. fix.`

## Captain ruling

**When:** after all seat verdicts are in, if any seat voted FAIL or any red/yellow finding exists. If every seat voted PASS with no red/yellow findings, skip the ruling (costs 0).

**Dispatch:** a fresh subagent on the captain's rung (the captain seat's current rung; `Role contract:` = the `reviewer-a` contract, ruling mode), with the merged list, the diff, the spec, and the plan. Ruling brief:

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
| `captain` | captain verdict PASS overriding FAIL votes: every finding is deferred or rejected, zero unresolved accepted findings, green tests (no `no-tests` exception) |

- Captain mode is available in any round, with 2 or 3 healthy seats.
- **Author vote:** PASS also needs >= 1 PASS vote from a non-author family or model-level independence (reviewer models distinct from `author_models`). In captain mode the captain's PASS is that vote. If all active seats share an author family, record `degraded council author vote: model-level independence (<model1>, <model2>)`.
- Accepted findings always block: any unresolved `accept` (red or yellow) makes the round FAIL, even when the seat votes pass; fix it and re-review.
- Fewer than 2 distinct non-author reviewer models healthy: STOP with `yellow: degraded council` (`AGENTS.md` Routing Rules, Degraded council).

## Receiving phase (rigor)

- For every accepted red: find the exact code it refers to and confirm the claim yourself before dispatching fixes. A wrong finding gets marked `rejected: <one-line why>` and is reported, not silently dropped.
- For every deferred or rejected red: check it against the captain limits above before accepting the ruling.
- Reject count is information: 3+ rejections in one round means a seat is misreading the codebase. Say so in the round report.

## Round loop (max 3 review rounds total)

Round 1 = the initial three-seat review from the Request phase; rounds 2-3 = fix then re-review. Never exceed 3 review batches; count them out loud.

```
round N: parallel seat review -> merge -> captain ruling (unless skipped) -> verdict
  PASS -> write council_verdict, done
  FAIL, N < 3:
    dispatch fresh fixer subagents from the implementation seats (`implementer`, or `implementer-deep` for hard clusters; one per accepted-finding cluster, max 2 files each; see `AGENTS.md` Review contracts); allow `patch` only for a 1-2 file edit with no test run
    fixers address accepted findings only and run tests before declaring done
    re-run verify skill checks (tests, lint, typecheck, build)
    round N+1 review = all active fresh reviewer seats (never a single seat) + a fresh captain ruling
    streamed, no user pause
  FAIL, N = 3:
    write council_verdict: FAIL round=3 mode=<nominal|degraded> head=<sha>
    STOP: report rounds, final findings with rulings, backlog entries, test output
```

- There is no escalation seat: a round-3 FAIL always stops to the user.
- Reviewer never fixes. Fixer never reviews. Fresh subagent each round, both ways.

## No test suite

See `AGENTS.md` Review contracts for the canonical `no-tests` gate rule. Operational steps: label a `no-tests` PASS `provisional: no-tests` in the verdict (`mode=nominal` only; `mode=degraded` and `mode=captain` require green tests), have the reviewer flag `no tests: yellow` in findings, and never invent a test suite in council (that belongs to `tdd` in the task loop).

## Output format

```
Round N: [seat verdicts (3, or 2 active + lost seat)] captain <seat> -> merged findings (r red, y yellow, b blue) -> ruling (a accept, d defer, j reject, o overruled | skipped)
Verdict: PASS | FAIL | DEGRADED (mode=<nominal|degraded|captain>)
Backlog: <n> deferred
```

State artifact lines (`$(git rev-parse --git-dir)/info/oneshot-state.md`, creating `$(git rev-parse --git-dir)/info` if missing; standalone council runs in a git repo write them too):

- `council_verdict: PASS|FAIL round=<n> mode=<nominal|degraded|captain> head=<sha>` (`<n>` is `1..3`, `<sha>` is `git rev-parse HEAD`; consumers read the effective last line). On PASS append/update it, then output a one-line summary. On FAIL write it, output the merged finding list with rulings, and continue the round loop or stop.
- `captain: <seat> <provider>/<model>`
- `captain overruled: <finding-id>`
- `backlog: <finding line> (<reason>)`
- `single-provider review: <provider>` (while the mode is active)
- `degraded council author vote: model-level independence (<model1>, <model2>)` (when it applies)
