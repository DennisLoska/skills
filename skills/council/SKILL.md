---
name: council
description: Use when a change, branch, PR, or diff needs review before merge - says "council", "review this", or oneshot Phase 6. Three independent reviewers from different model families loop until consensus. Also carries receiving-side rigor for feedback.
---

# Council

Consensus review by 3 independent reviewers, followed by disciplined application of findings.

**Why:** One reviewer = one blind spot. Three independent model families = three different failure patterns. Agreement matters more than any single opinion.

**Model routing:** Reviewer roles A/B/C + escalation come from the active provider profile (`PROVIDERS.md`), routed by the `HARNESS.md` (`AGENTS.md`) Routing Rules (quota pools & ledger, failure classes, soft cap & reserve, backup ladder walk, and budget stop & resume) and Dispatch Adapter (if `HARNESS.md` and `PROVIDERS.md` are not already in context, read `../_harness/HARNESS.md` and `../_harness/PROVIDERS.md` or `../../HARNESS.md` and `../../PROVIDERS.md` relative to this skill's directory; quota ledger read/updated via shell at `../../state/quota-ledger.tsv`). Never hardcode IDs. On usage-limit/429 (`exhausted`), an `unreachable` rung, a failed `transient` retry, or a soft-cap skip: demote along that seat's ladder (and then `## Backup ladder` when all 3 rungs are gone), announce the demotion. Minimum 2 healthy independent families or stop and surface yellow.

## Step 0: Routing Bootstrap

<HARD-GATE>
Before dispatching ANY council reviewer or fixer subagent, verify all three bootstrap checks:
1. **Load `HARNESS.md` and `PROVIDERS.md` into context:** Check whether `# Cybernetic SDLC Harness` (`HARNESS.md`) AND the active provider profile routing table (`PROVIDERS.md`) are BOTH already loaded verbatim in this session. If either is missing, read `../_harness/HARNESS.md` and `../_harness/PROVIDERS.md` (or `../../HARNESS.md` and `../../PROVIDERS.md`) relative to this skill's directory NOW before taking any other action.
2. **Select the `HARNESS.md` Dispatch Adapter path (including lazy MCP servers):** Inspect both eager tools and any lazy-loaded MCP server schemas in your environment before choosing a subagent tool. Run the one-time session capability check required by `HARNESS.md` `## Dispatch Adapter` Path 1 when cross-provider orchestration tools are present (reading their lazy MCP schema files first when needed), and NEVER fall back to native same-session subagent tools while Path 1 orchestration tools are available.
3. **Forbid same-model council seats and author self-review:** Every dispatched council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`) MUST resolve its rung from `PROVIDERS.md` (carrying `Role contract:` + `Rung:` on non-autoloaded paths, or `Rung:` only on autoloaded pinned seats). Council shall not block if there are at least two different members who can review and are not the same model as the implementer. Never spawn native `inherit`/same-model subagents for council seats. Furthermore, no council seat may review code authored by the identical model. In nominal mode at least one PASS vote comes from a non-author family or distinct model, and whenever at least 2 (`>= 2`) distinct reviewer models differ from `author_models`, model-level independence applies; only when fewer than 2 distinct non-author models can review does council stop with `yellow: degraded council`. Reviewing one's own code without required model independence is a hard protocol violation.
</HARD-GATE>

## Request phase

1. Scope: diff of the branch (git diff against target), or PR, or given files. Read spec + plan when present.
2. Dispatch the three council seat roles through the AGENTS.md Dispatch Adapter, one fresh subagent each: `reviewer-a`, `reviewer-b`, `reviewer-c`. Same scope, same instructions, one independent model family per seat (every dispatch names a rung from the active provider profile, so no seat ever inherits the main session model).
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

4. Mid-round provider retry vs Round N+1 re-review: If a seat's rung is exhausted, unreachable, soft-cap reserved, or fails a transient retry mid-round: re-dispatch that SAME seat role on its next eligible ladder rung (or matching `## Backup ladder` row) from the active provider profile per AGENTS.md Routing Rules (mechanics below). Rerun only that failed seat to complete the current round. Conversely, whenever implementation fix subagents push new commits in Round N+1, ALL active council seats (all 3 in nominal, all 2 in degraded) MUST be re-dispatched against the new HEAD. Cherry-picking or re-dispatching only a single rejecting seat across rounds is strictly forbidden.
5. Confidentiality gate: if the review brief or referenced diff carries a confidential flag, the AGENTS.md Routing Rules privacy gate applies to every seat (`privacy: trains` rungs in the active provider profile auto-skip); demote to the next privacy-safe rung and announce.

6. Author-model & author-family rules: Read `author_models` and `author_families` (plus the author commit log) from `$(git rev-parse --git-dir)/info/oneshot-state.md` before dispatching seats. When any `reviewer-*` seat's primary (or candidate) rung `model` matches a recorded author model in `author_models`, skip that rung to the next eligible ladder or `## Backup ladder` rung and announce `demote: <seat> -> <provider>/<model> (author model conflict)` (`AGENTS.md` Routing Rules; if zero eligible non-author-model rungs remain for that seat, the seat is lost). Council shall not block if there are at least two different members who can review and are not the same model as the implementer. PASS requires at least one PASS from a non-author family or model-level independence (distinct reviewer models that differ from `author_models`). If all active healthy seats share an author family, accept model-level independence and record in state: `degraded council author vote: model-level independence (<model1>, <model2>)`. Only when fewer than 2 distinct non-author models can review does council stop with `yellow: degraded council`.

## Fallback mechanics

Every seat has a contract file (`agents/<seat>.md`) and a primary rung in the active provider profile. Before walking a seat's ladder, check `<dest>/state/quota-ledger.tsv`, per-run soft-cap counters, and `author_models` in `$(git rev-parse --git-dir)/info/oneshot-state.md` (`AGENTS.md` Routing Rules). When its rung returns a usage-limit or 429-style provider error (`exhausted`, recorded in the quota ledger), is `unreachable`, fails a `transient` retry, or conflicts with `author_models`:

```
re-dispatch: AGENTS.md Dispatch Adapter, role <seat>, rung <next ladder or backup rung>
announce: "seat <seat> demoted to <provider>/<model>" (or "backup: <seat> -> <provider>/<model>", or "demote: <seat> -> <provider>/<model> (author model conflict)")
```

- A demotion (including onto `## Backup ladder`) never breaks model independence: a seat may demote within its own family, but skip any rung whose model is in `author_models` or active on another council seat.
- A seat with zero healthy ladder and backup rungs = seat lost. Continue if at least 2 distinct non-author reviewer models remain; otherwise stop with `yellow: degraded council` (and report exhausted pools + `earliest resume` per `AGENTS.md` Routing Rules, budget stop & resume when quota exhaustion caused the stop).
- The escalation seat is a separate agent (`reviewer-esc`), routed by its rung in the active provider profile. It never substitutes a lost seat mid-round; it enters only after the round budget is spent, or to supply the author-family/model vote above.

## Verdict phase

- PASS = in `mode=nominal` (3-seat mode) at least 2 of 3 seats vote PASS, in `mode=degraded` unanimous 2 of 2 healthy seats vote PASS, or in post-round-3 `mode=escalation` (`round=esc`) the single `reviewer-esc` seat votes PASS on a model distinct from `author_models` and active council seats; ALL modes require zero unresolved confirmed red findings and green tests (`mode=nominal` allows the `no-tests` exception under `AGENTS.md` Review contracts; `mode=degraded` and `mode=escalation` require green tests), plus the non-author model vote above. A confirmed red from a single FAIL seat blocks PASS just the same, until it is fixed or rebutted with evidence.
- Fewer than 2 distinct non-author reviewer models healthy: STOP with `yellow: degraded council` per the canonical degraded-council rule in `AGENTS.md` Routing Rules (Degraded council).
- Merge findings into one list, severity sorted red -> yellow -> blue. Dedupe identical findings, keep the sharpest wording.
- Escalation seat independence: `reviewer-esc` never runs on a model in `author_models` or a model a council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) already used this PR. On conflict, demote along the `reviewer-esc` ladder (then `## Backup ladder`) until an eligible distinct non-author model is found, else stop and surface `yellow: degraded council`.

## Receiving phase (rigor)

- For every red: find the exact code it refers to and confirm the claim yourself before dispatching fixes. A wrong finding gets marked `rejected: <one-line why>` and is reported, not silently dropped.
- Reject count is information: 3+ rejections in one round means the reviewer family is misreading the codebase. Say so in the round report.

## Round loop (max 3 review rounds total)

round 1 = the initial three-seat review from the Request phase (no extra batches); rounds 2-3 = fix then re-review. In round terms: verdict of round N FAIL -> dispatch fresh fixers -> round N+1 review. Never exceed 3 total review batches; count them out loud.

```
total review batches = 3, counted out loud:
  round 1 = the initial three-seat review from the Request phase (no extra batch)
  verdict of round N FAIL, N < 3:
    dispatch fresh fixer subagents from the implementation seats (`implementer`, or `implementer-deep` for hard clusters; one per finding cluster, max 2 files each; see `AGENTS.md` Review contracts for fixer seat routing); allow `patch` only for a finding that needs a 1-2 file edit with no test run
    implementation-seat fixers run tests before declaring done
    re-run verify skill checks (tests, lint, typecheck, build)
    round N+1 review = all active fresh reviewer seats (all 3 in nominal, all 2 in degraded; never a single seat)
    PASS + green -> done
    streamed, no user pause
```

- Rounds exhausted -> escalation review on the `reviewer-esc` rung of the active provider profile (non-author family, unused by council seats, model not in `author_models`): if `reviewer-esc` votes PASS with zero unresolved confirmed red findings and green tests, write `council_verdict: PASS round=esc mode=escalation head=<sha>` to `$(git rev-parse --git-dir)/info/oneshot-state.md`.
- Escalation still FAIL -> write `council_verdict: FAIL round=esc mode=escalation head=<sha>` to `$(git rev-parse --git-dir)/info/oneshot-state.md`, then STOP: report rounds, final findings, test output. This is one of the council stop points (alongside the degraded-council stop).
- Reviewer never fixes. Fixer never reviews. Fresh subagent each round, both ways. Never re-dispatch only one rejecting seat in round N+1; all active seats must evaluate the fixed code together.

## No test suite

See `AGENTS.md` Review contracts for the canonical `no-tests` gate rule. Operational steps: label a `no-tests` PASS `provisional: no-tests` in the verdict (`mode=nominal` only; `mode=degraded` and `mode=escalation` require green tests), have the reviewer flag `no tests: yellow` in findings, and never invent a test suite in council (that belongs to `tdd` in the task loop).

## Output format

```
Round N: [verdicts (3 nominal, 2 active + lost seats in degraded, or 1 reviewer-esc in escalation)] -> merged findings (r red, y yellow, b blue, k rejected)
Verdict: PASS | FAIL | DEGRADED
```

State artifact verdict schema: `council_verdict: PASS|FAIL round=<n> mode=<nominal|degraded|escalation> head=<sha>` (where `<n>` is `1..3` for nominal/degraded rounds or `esc` for escalation, and `<sha>` is `git rev-parse HEAD`). On PASS: Phase 6 (and standalone council when a git repo is present) appends/updates `council_verdict: PASS round=<n> mode=<nominal|degraded|escalation> head=<sha>` in `$(git rev-parse --git-dir)/info/oneshot-state.md` (creating `$(git rev-parse --git-dir)/info` if missing), then outputs a one-line summary. On FAIL: write `council_verdict: FAIL round=<n> mode=<nominal|degraded|escalation> head=<sha>` when updating the state artifact, output the merged finding list, and stop.
