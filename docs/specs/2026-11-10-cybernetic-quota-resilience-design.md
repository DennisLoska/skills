# Cybernetic Quota Resilience & Majority-Provider Outage Tolerance - Design

Status: approved (2026-11-10).
Goal: Ensure the oneshot cybernetic harness remains operational, self-stabilizing, and robust even when a majority of providers (e.g. Codex and OpenCode) are down due to quota or plan exhaustion, with specific cybernetic guarantees for the Review Council, author-independence rules, task-reviewers, and backup ladders.

---

## 1. Problem Statement & Baseline Validation

During live operation in T3 Code, multiple upstream AI providers frequently hit usage limits simultaneously:
- **Codex:** `"You’ve hit your usage limit. Upgrade to Pro (...), visit (...) to purchase more credits or try again at 7:36 PM."` (Provider-wide 429/quota exhaustion)
- **OpenCode:** `"OpenCode Go weekly usage limit reached. Switch to a free model, or turn on Extra Usage on the Go page in OpenCode Console to keep going."` (Account-wide weekly plan exhaustion across all `opencode-go/*` models)

When both Codex and OpenCode are simultaneously down (2 out of 4 providers, or 2 out of 3 in `tri`), the remaining operational providers are:
1. `antigravity` (Google family: `gemini-4-argon`, `gemini-3.8-flash`; Anthropic family: `claude-opus-5-5`, `claude-sonnet-5-5`)
2. `claudeAgent` (Anthropic family: `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`)

This exposes 5 critical architectural failure points in the harness:

1. **Provider-Wide Quota Pool Blind Spot:**
   - `tri.md`, `quad.md`, and `opencode-go.md` lacked an `opencode` quota pool definition because earlier designs assumed individual per-model limits.
   - When an account-wide / weekly limit is hit, the harness defaulted to `<provider>/<model>` tracking and attempted every model sequentially, burning retries, latency, and quota attempts on dead endpoints.

2. **The 3-Seat Council Deadlock under Bounded Variety (Ashby's Law):**
   - With Codex and OpenCode down, only **two** independent model families exist in the entire available system: `google` and `anthropic`.
   - The Review Council strictly required 3 independent model families (`reviewer-a`, `reviewer-b`, `reviewer-c`).
   - Seat C (Meta/Open-weight) had all rungs on OpenCode, and backup ladders lacked cross-provider entries for remaining operational models, causing Seat C to be lost and deadlocking consensus.

3. **The Author-Family Deadlock in Degraded State:**
   - In a dual-family operational state (`google` + `anthropic`), one family authored the implementation (e.g. `gemini-4-argon` is `google`).
   - If a test author (`tester`), prior round fixer, or secondary implementer touched code using the second family (`anthropic`), **all healthy families** are marked as author families in the state artifact.
   - The existing author-family rule required at least one PASS from a non-author family and attempted to dispatch `reviewer-esc` to break ties. Because no 3rd family existed, the council stalled at `yellow: degraded council`.

4. **Task-Reviewer Author Deadlock in Phase 3:**
   - In `dispatch`, `task-reviewer` was forbidden from running on the author family, with an exception allowed *solely* for "unreachable on a standalone single-family host".
   - When non-author families were exhausted (HTTP 429 / usage limit), `task-reviewer` refused to degrade to an alternative model within the author family, halting Phase 3 at `budget stop: task-reviewer`.

5. **Dynamic Profile Generator Invariant Violation (`--providers`):**
   - In `install.sh`, generating dynamic profiles for 2 providers (such as `--providers antigravity,claude`) assigned both `reviewer-a` and `reviewer-b` to the `anthropic` family as primaries, violating the hard gate that no two council seats may share a model family.

---

## 2. Cybernetic Architecture & Operating Regimes

Guided by cybernetic principles (Ashby's Law of Requisite Variety, Beer's Viable System Model homeostatic regulation, and ultrastable multi-loop adaptation), the harness is restructured around explicit operating regimes:

### 2.1 Operating Regimes

```
+--------------------------------------------------------------------------------+
| Regime 1: Full Nominal Operation (>= 3 independent healthy families)           |
| - Standard 3-seat Review Council (reviewer-a, reviewer-b, reviewer-c)          |
| - Strict cross-family author independence                                     |
| - Quorum: >= 2 of 3 seats PASS + >= 1 non-author vote                         |
+--------------------------------------------------------------------------------+
                                       |
                   [Majority Providers Down / Quota Hit]
                                       v
+--------------------------------------------------------------------------------+
| Regime 2: Degraded Dual-Family Operation (Exactly 2 healthy families)         |
| - Adaptive Dual-Seat Review Council (2 independent families, e.g. google+anth) |
| - Lost seat explicitly acknowledged: "seat reviewer-c lost (zero eligible)"   |
| - Quorum: UNANIMOUS PASS (2 of 2 healthy seats PASS) + zero red findings      |
| - Author Independence Adaptation:                                              |
|   * If 1 seat is non-author: standard non-author vote satisfies gate          |
|   * If BOTH healthy families are authors: intra-family model-level            |
|     independence (e.g. Claude Opus reviews Sonnet, Gemini Flash reviews Argon) |
|     with explicit declaration: "degraded council author vote: dual-family     |
|     model-level independence"                                                  |
| - Task-Reviewer Adaptation: degrades to distinct model in available family     |
|   when non-author families are exhausted                                       |
+--------------------------------------------------------------------------------+
                                       |
                         [Another Provider Down]
                                       v
+--------------------------------------------------------------------------------+
| Regime 3: Degraded Single-Family Operation (< 2 healthy families)              |
| - Honest halt: "yellow: degraded council (< 2 independent families)"           |
+--------------------------------------------------------------------------------+
```

---

## 3. Detailed Component Improvements

### 3.1 Quota Pools & Fast Ledger Feedback
1. **Define `opencode-go` quota pool across all profiles:**
   In `tri.md`, `quad.md`, and dynamic generator:
   ```markdown
   | pool | provider | models | window | soft-cap | reserve |
   | opencode-go | opencode | * | 5h | - | - |
   ```
2. **Provider-Wide Limit Detection:**
   When an error summary matches `"weekly usage limit"`, `"usage limit reached"`, `"plan limit"`, or HTTP 429 across provider-level error responses, the pool is immediately flagged in `<dest>/state/quota-ledger.tsv`, preventing subsequent rungs from wasting network roundtrips.

### 3.2 Dynamic Profile Generation (`install.sh --providers`)
1. Ensure `generate_dynamic_profile` partitions council seats A, B, C across distinct model families:
   - For `antigravity,claude`: Seat A primary = `google` (`gemini-4-argon`), Seat B primary = `anthropic` (`claude-opus-5-5`), Seat C primary = `anthropic` fallback or designated degraded seat.
   - Automatically emit `opencode-go` pool whenever `opencode` is among the enabled providers.
   - Add universal backup rungs for all enabled providers.

### 3.3 Council Consensus & Quorum in Degraded Dual-Family Mode
1. **Adaptive Quorum:**
   When a council seat is lost due to exhaustion of all candidate rungs and backup rungs:
   - If 2 healthy independent families remain, the council continues with the 2 active seats.
   - PASS requires **2 of 2 (unanimous)** votes from the healthy seats, 0 unresolved confirmed red findings, and green tests.
2. **Author-Family Resolution:**
   - If both remaining families have authored code (e.g. `tester` was Anthropic and `implementer` was Google):
     The council requires that the reviewing model on each seat was not the identical authoring model (intra-family model-level independence) and records:
     `degraded council author vote: dual-family model-level independence (<model1>, <model2>)`.

### 3.4 Task-Reviewer Resilience in Phase 3
In `AGENTS.md` and `skills/dispatch/SKILL.md`:
- If skipping the author family leaves zero rungs because non-author families are `exhausted` or `unreachable`:
  `task-reviewer` demotes to an available rung with a distinct model from the author rung (e.g. `gemini-3.8-flash` reviewing `gemini-4-argon`), announcing:
  `degraded task-review: non-author families exhausted/unreachable (reviewed by <model>)`.

### 3.5 Backup Ladder Variety
Update `tri.md`, `quad.md`, and composable profiles so `## Backup ladder` has representation from all providers in the profile, ensuring that when OpenCode and Codex are down, backup rows exist for both Google (`gemini-3.8-flash`) and Anthropic (`claude-sonnet-5-5` or `claude-opus-5-5`).

---

## 4. Verification and Acceptance Criteria
1. `test/install.sh` contract test suite passes 100% with new profile generation and pool invariants.
2. Live validation baseline: with Codex and OpenCode exhausted in T3 Code, the harness successfully dispatches implementation, task-review, and council review across Antigravity and Claude Code without deadlocking or crashing.
3. Successful council consensus review on this feature branch, PR land, and installation to local flux and deployment targets.
