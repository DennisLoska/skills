# Design Specification: Enforce Harness Compliance, Context Hygiene, and Council Integrity

## 1. Problem Statement & Background

A systematic review of recent T3 Code threads revealed significant variances in how autonomous agent sessions interact with the `oneshot` harness. While well-structured tasks like [TEL-14: In-process AI SDK & typed TS tools migration](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:launch:5677cc1efc14bade3ef676ebdd3f03453a80bf37c94dbb2cfae1bf7ff4b6417b) and [oneshot: integrate gemini-4-carbon as designer, planner, and council seat](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:801c0405-fe5e-4cc8-8af7-441d811f9814) demonstrated exemplary fidelity (strict Step 0 bootstrap, subagent task routing, formal specs, and rigorous council consensus), several production threads suffered from severe protocol degradation:

1. **Trigger & Lifecycle Bypasses:** In [Declutter Music and Playlist UI](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/d3069743-7ee7-4955-bdfd-5ef1f1d8615a), the prompt requested *"Use the one-shot skill aka the one-shot harness to facilitate all of this"*, but the agent bypassed Phase 1 (Shape) and Phase 2 (Plan) entirely. In [feat(pwa): Progressive Web App & Offline Audio Caching](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:b71e0597-b04f-4482-949a-30ef7cab40a1), the agent implemented and pushed PR #5 without oneshot until the user explicitly intervened.
2. **Context Hygiene Collapse (Inline Execution):** Across [Declutter Music and Playlist UI](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/d3069743-7ee7-4955-bdfd-5ef1f1d8615a), [LOT-60 Overhaul mobile app layout, ergonomics, and safe-area polish](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:859f156e-fe02-4ec9-bbf4-dfd0a951bc65), [feat(lyrics): Synchronized Scrolling Lyrics & Karaoke View](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:68f2da1e-0864-460f-b07b-97bbeb0eedc3), and [feat(pwa): Progressive Web App & Offline Audio Caching](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:b71e0597-b04f-4482-949a-30ef7cab40a1), main orchestrator sessions wrote and edited implementation code directly inline, cluttering context and skipping `tester` / `implementer` subagent isolation.
3. **Single-Seat Re-Review Loops:** In [Declutter Music and Playlist UI](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/d3069743-7ee7-4955-bdfd-5ef1f1d8615a) (PR #8), the driver dispatched only Seat A, then repeatedly re-dispatched only Seat A across 4 rounds after inline fixes, never consulting Seats B and C.
4. **Author Independence Violations:** In [LOT-60 Overhaul mobile app layout, ergonomics, and safe-area polish](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:859f156e-fe02-4ec9-bbf4-dfd0a951bc65), the driver (`gemini-3.8-flash`) authored code inline and then dispatched Reviewer A as `gemini-3.8-flash`—reviewing its own work.
5. **Pre-Merge Council Verification Missing:** In [feat(lyrics): Synchronized Scrolling Lyrics & Karaoke View](t3-thread://v2/0b8c5d53-f340-4ed9-9af8-aa62c47569dc/mcp:68f2da1e-0864-460f-b07b-97bbeb0eedc3), the agent merged PR #6 without ever executing Phase 6 Review Council.

---

## 2. Root Cause Analysis

1. **`skills/dispatch/SKILL.md` Manual Execution Escape Hatch:**
   The `when_to_use` flowchart contained a legacy branch:
   `"Tasks mostly independent?" -> "Manual execution" [label="no - tightly coupled"];`
   along with a "vs manual execution" comparison section. Agents used this to justify inline coding under the rationale that tasks were "coupled".
2. **`skills/council/SKILL.md` Ambiguity on "Rerun only that seat":**
   Line 42 stated: *"If a seat's rung is exhausted, unreachable, soft-cap reserved, or fails a transient retry mid-round: re-dispatch the SAME seat role on its next eligible ladder rung ... Rerun only that seat."*
   Agents conflated infrastructure retries mid-round with multi-round review iterations after code fixes, leading to single-seat review loops.
3. **Missing Author Independence Checks in Council Step 0:**
   The Council `<HARD-GATE>` enforced inter-seat independence (no two seats sharing a family), but failed to enforce author-vs-reviewer family and model independence at dispatch time.
4. **Permissive Merge in `skills/land/SKILL.md`:**
   `land` checked for red tests and open review comments, but lacked an explicit requirement for an audited Phase 6 Council consensus PASS in `$(git rev-parse --git-dir)/info/oneshot-state.md` prior to merge.
5. **Overly Restrictive Description in `skills/oneshot/SKILL.md`:**
   Trigger patterns focused on prefix phrases (`"oneshot <task>"`), ignoring trailing instructions, ticket handoffs, and conversational commands.

---

## 3. Approaches Considered

### Approach A: Advisory Prompt Warnings
Add warning paragraphs in `AGENTS.md` reminding models not to edit code inline and not to skip council seats.
- *Pros:* Minimal diff.
- *Cons:* Ineffective. Models routinely ignore non-gated advice when task complexity rises or quota pressure occurs.

### Approach B: Structural Protocol Hardening & Explicit Hard-Gates (Selected)
1. Remove all references to "Manual execution" from `skills/dispatch/SKILL.md`. Add a mandatory `<HARD-GATE>` in `dispatch` prohibiting inline driver production edits.
2. In `skills/council/SKILL.md`, clarify that "Rerun only that seat" applies solely to provider infrastructure failures mid-round. Any new review round following code modifications MUST re-evaluate across all active council seats.
3. Add author-family and model-level independence enforcement directly into the Council Step 0 `<HARD-GATE>`.
4. In `skills/land/SKILL.md`, add an explicit hard gate requiring recorded Council consensus PASS in the state artifact before merging.
5. Broaden trigger frontmatter in `skills/oneshot/SKILL.md` to capture trailing requests, "use oneshot", and issue ticket handoffs.
- *Pros:* Closes every identified hole with deterministic protocol gates; preserves existing test suite and byte-size limits.
- *Cons:* Requires coordinated updates across skills and `AGENTS.md`.

---

## 4. Architectural Design & Detailed Changes

### A. `skills/dispatch/SKILL.md`
- Remove `"Tasks mostly independent? -> Manual execution"` from `when_to_use` flowchart.
- Replace "vs manual execution" with an explicit architectural statement:
  *In the cybernetic harness, the driver orchestrates and NEVER writes implementation code inline. All implementation occurs via isolated `implementer` or `implementer-deep` subagents.*
- Add `<HARD-GATE>` rule: Driver inline edits to production files during dispatch are a hard protocol violation.

### B. `skills/council/SKILL.md`
- Step 0 `<HARD-GATE>`: Forbid author-family and identical-model review. Council seats must be independent of author families recorded on the branch commits. In degraded dual-family mode where authoring cannot be avoided, require strict model-level divergence (e.g. `gemini-4-carbon` reviewing `gemini-3.8-flash` or different provider family).
- Clarify Section 4 & Round Loop: Differentiate mid-round provider failover ("rerun only that seat") from Round N+1 code re-review ("re-dispatch all active council seats against the new HEAD"). Forbid single-seat review loops.

### C. `skills/land/SKILL.md`
- Gate 3 Pre-Merge Validation: In Part 2 (Finish options), add rule:
  *Never merge without an audited Phase 6 Council consensus PASS (nominal $\ge 2/3$ or degraded unanimous $2/2$) recorded in `$(git rev-parse --git-dir)/info/oneshot-state.md`.*

### D. `skills/oneshot/SKILL.md`
- Update YAML description frontmatter:
  `description: Use when user says "oneshot", "use oneshot", "use the oneshot harness", or requests end-to-end autonomous implementation of a feature, bugfix, or ticket.`
- Update Phase 3 and Phase 6 descriptions to reinforce the hard gates.

### E. `AGENTS.md`
- Synchronize review and council contracts with the strengthened dispatch, council, and land gates.
- Verify `AGENTS.md` byte count stays $\le 24,000$ bytes.

---

## 5. Verification Plan

1. **Automated Test Suite:**
   Run `./test/install.sh` to ensure all 145 tests pass cleanly and size constraints remain satisfied.
2. **Reinstallation & Doctor:**
   Run `./install.sh --force --target all` and `./install.sh --verify` on `flux` to confirm proper distribution and instruction wiring across all hosts (Antigravity, Codex, OpenCode, Claude).
