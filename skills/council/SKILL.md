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
3. **Forbid same-model council seats:** Every dispatched council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`) MUST resolve its rung from `PROVIDERS.md` (carrying `Role contract:` + `Rung:` on non-autoloaded paths, or `Rung:` only on autoloaded pinned seats), with no two active seats sharing a model family and at least 2 (`>= 2`) healthy independent families overall (else stop with `yellow: degraded council`). Never spawn native `inherit`/same-model subagents for council seats.
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

4. If a seat's rung is exhausted, unreachable, soft-cap reserved, or fails a transient retry mid-round: re-dispatch the SAME seat role on its next eligible ladder rung (or matching `## Backup ladder` row) from the active provider profile per AGENTS.md Routing Rules (mechanics below). Rerun only that seat. Never fill a seat with a rung whose family is active on another council seat anywhere in this PR (AGENTS.md Routing Rules).
5. Confidentiality gate: if the review brief or referenced diff carries a confidential flag, the AGENTS.md Routing Rules privacy gate applies to every seat (`privacy: trains` rungs in the active provider profile auto-skip); demote to the next privacy-safe rung and announce.

6. Author-family rule: PASS also needs the author-family vote from the AGENTS.md Council Contract (at least one PASS from a council seat whose family is not an author family, or dual-family model-level independence in degraded council). Read the author families from the state artifact. If every seat's family is an author family: in nominal 3-seat mode dispatch `reviewer-esc` for the non-author vote on a rung whose family is neither a council-seat nor an author family (AGENTS.md Council Contract; one extra dispatch counted against the 14-dispatch guard); in degraded mode with 2 healthy families both in the author set, accept intra-family model-level independence (each seat's reviewer model must differ from the identical author model) and record in state: `degraded council author vote: dual-family model-level independence (<model1>, <model2>)`; if that is impossible, stop with `yellow: degraded council`.

## Fallback mechanics

Every seat has a contract file (`agents/<seat>.md`) and a primary rung in the active provider profile. Before walking a seat's ladder, check `<dest>/state/quota-ledger.tsv` and per-run soft-cap counters (`AGENTS.md` Routing Rules). When its rung returns a usage-limit or 429-style provider error (`exhausted`, recorded in the quota ledger), is `unreachable`, or fails a `transient` retry:

```
re-dispatch: AGENTS.md Dispatch Adapter, role <seat>, rung <next ladder or backup rung>
announce: "seat <seat> demoted to <provider>/<model>" (or "backup: <seat> -> <provider>/<model>")
```

- A demotion (including onto `## Backup ladder`) never breaks family independence: a seat may demote within its own family, but skip any rung whose family is active on another council seat anywhere in this PR or equals the `reviewer-esc` family (`AGENTS.md` Routing Rules, backup ladder walk).
- A seat with zero healthy ladder and backup rungs = seat lost. Continue if at least 2 independent families remain; otherwise stop with `yellow: degraded council` (and report exhausted pools + `earliest resume` per `AGENTS.md` Routing Rules, budget stop & resume when quota exhaustion caused the stop).
- The escalation seat is a separate agent (`reviewer-esc`), routed by its rung in the active provider profile. It never substitutes a lost seat mid-round; it enters only after the round budget is spent, or to supply the author-family vote above.

## Verdict phase

- PASS = in nominal 3-seat mode at least 2 of 3 seats vote PASS (or in degraded mode unanimous 2 of 2 healthy seats vote PASS) AND zero unresolved confirmed red findings from any seat, and tests green, or the no-tests rule satisfied, plus the author-family vote above. A confirmed red from a single FAIL seat blocks PASS just the same, until it is fixed or rebutted with evidence.
- Fewer than 2 families healthy: STOP with `yellow: degraded council` per the canonical degraded-council rule in `AGENTS.md` Routing Rules (Degraded council).
- Merge findings into one list, severity sorted red -> yellow -> blue. Dedupe identical findings, keep the sharpest wording.
- Escalation seat independence spans the whole PR: `reviewer-esc` never runs on a model family a council seat (`reviewer-a`, `reviewer-b`, `reviewer-c`) already used this PR (check the `family` column of the active provider profile per ladder rung). On conflict, demote along the `reviewer-esc` ladder in the profile until an unused family is found, else stop and surface `yellow: degraded council`.

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
    round N+1 review = 3 fresh reviewer seats
    PASS + green -> done
    streamed, no user pause
```

- Rounds exhausted -> escalation review on the `reviewer-esc` rung of the active provider profile (own family, not one already used).
- Escalation still FAIL -> STOP: report rounds, final findings, test output. This is one of the council stop points (alongside the degraded-council stop).
- Reviewer never fixes. Fixer never reviews. Fresh subagent each round, both ways.

## No test suite

See `AGENTS.md` Review contracts for the canonical `no-tests` gate rule. Operational steps: label a `no-tests` PASS `provisional: no-tests` in the verdict, have the reviewer flag `no tests: yellow` in findings, and never invent a test suite in council (that belongs to `tdd` in the task loop).

## Output format

```
Round N: [verdicts (3 nominal, or 2 active + lost seats in degraded)] -> merged findings (r red, y yellow, b blue, k rejected)
Verdict: PASS | FAIL | DEGRADED
```

Then on PASS: one-line summary. On FAIL: the merged finding list. Stop.
