# Integrate Gemini 4 Carbon into Cybernetic Harness - Design

Status: approved (2026-11-10).
Goal: Integrate `gemini-4-carbon` (provider: `antigravity`, family: `google`, `thinking_level=high`) into the cybernetic harness as the primary planner and designer (top-tier candidate for `implementer-deep` and `implementer`) and as the primary Google-family council seat across reviewer roles.

---

## 1. Problem Statement & Motivation

The Google DeepMind Gemini model family has introduced `gemini-4-carbon`, featuring extended reasoning and high-fidelity planning capabilities via `thinking_level=high`. Within our cybernetic harness:
1. **Planning & Architectural Design:**
   Design alternatives (`codebase-design`, design-it-twice) and complex task implementations walk `implementer-deep` and `implementer` across independent families. Previously, `gemini-4-argon` or Anthropic models held primary rungs for implementation and deep reasoning. `gemini-4-carbon` is suited to lead as the primary planner, designer, and actuation workhorse.
2. **Review Council Representation:**
   The Review Council enforces multi-family consensus across Seats A, B, and C. In profiles or compositions where Google leads a council seat (such as Seat A under `--providers antigravity,claude`, or as a candidate for Seats B, C, and escalation), `gemini-4-carbon` should serve as the primary Google candidate.
3. **Cybernetic Decoupling & Invariants:**
   All model bindings must remain decoupled: zero hardcoded concrete model IDs in `skills/`, `AGENTS.md`, or `HARNESS.md`. Routing rules reference roles, while `providers/*.md` and `install.sh` define the mappings. File size limits (`AGENTS.md` + `providers/tri.md` <= 32,150 bytes) and 100% test pass rate in `./test/install.sh` must be maintained.

---

## 2. Architecture & Design

### 2.1 Provider Profiles (`providers/tri.md`, `providers/quad.md`, `providers/antigravity.md`)

1. **`providers/tri.md`:**
   - **`implementer` primary:** `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`). Fallback: `claude-sonnet-5-5`. Last-resort: `gpt-6.1-sol`.
   - **`implementer-deep` primary:** `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`). Fallback: `codex` / `gpt-6-astra` (`openai`). Last-resort: `antigravity` / `claude-opus-5-5` (`anthropic`).
     - Ensures disjoint quota pools: `antigravity-gemini` -> `codex` -> `antigravity-claude`.
   - **Text & Prose:** Update descriptions to reflect `gemini-4-carbon` on `implementer` and `implementer-deep`, and reference Carbon as the authoring family when explaining council non-author seats.

2. **`providers/quad.md`:**
   - **`implementer` primary:** `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`). Fallback: `claudeAgent` / `claude-sonnet-5-5`. Last-resort: `codex` / `gpt-6.1-sol`.
   - **`implementer-deep` primary:** `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`). Fallback: `claudeAgent` / `claude-opus-5-5` (`effort=high`, `anthropic`). Last-resort: `codex` / `gpt-6-astra` (`openai`).
     - Ensures disjoint quota pools: `antigravity-gemini` -> `claude-code` -> `codex`.
   - **Text & Prose:** Update descriptions to reflect `gemini-4-carbon` on `implementer` and `implementer-deep`.

3. **`providers/antigravity.md`:**
   - Add `gemini-4-carbon` (`thinking_level=high`) as primary for `driver`, `implementer`, `implementer-deep`, and primary Google candidate for reviewer seats (`reviewer-a` last-resort, `reviewer-b` primary, `reviewer-esc` fallback).

### 2.2 Dynamic Profile Generator (`install.sh`)

In `install.sh` (`generate_dynamic_profile` awk generator):
1. **`implementer` (3 rungs):**
   - Candidate #1: `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`, `ok`).
2. **`implementer-deep` (3 rungs):**
   - Candidate #1: `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`, `ok`).
   - Candidate #2: `antigravity` / `claude-opus-5-5` (`thinking_level=high`, `anthropic`, `ok`).
   - Candidate #3: `claudeAgent` / `claude-opus-5-5` (`effort=high`, `anthropic`, `ok`).
   - Candidate #4: `codex` / `gpt-6-astra` (`reasoningEffort=high`, `openai`, `ok`).
   - Candidate #5: `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=max`, `deepseek`, `ok`).
3. **Council Seats & Reviewers:**
   - `reviewer-a`: Google candidate is `antigravity` / `gemini-4-carbon` (`thinking_level=high`).
   - `reviewer-b`: Google candidate is `antigravity` / `gemini-4-carbon` (`thinking_level=high`).
   - `reviewer-c`: Google candidate is `antigravity` / `gemini-4-carbon` (`thinking_level=high`) placed ahead of `gemini-3.8-flash`.
   - `reviewer-esc`: Google candidate is `antigravity` / `gemini-4-carbon` (`thinking_level=high`).
4. **`driver`:**
   - Add `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`, `ok`) to candidate list ahead of `gemini-4-argon`.

### 2.3 Contract & Integration Tests (`test/install.sh`)

1. In `test/install.sh`:
   - Under `--providers antigravity,claude`:
     - Assert `implementer primary` pool is `antigravity-gemini` (model `gemini-4-carbon`).
     - Assert `implementer-deep primary` pool is `antigravity-gemini` (model `gemini-4-carbon`).
     - Assert `implementer-deep fallback` pool is `antigravity-claude` (`claude-opus-5-5`), validating that `antigravity` Claude is ordered before `claudeAgent` Claude (`claude-code`).
     - Assert `reviewer-a primary` model is `gemini-4-carbon` (Google-led Seat A).
2. All 145+ tests must pass cleanly.
3. Combined file size limit test: `AGENTS.md` + `providers/tri.md` <= 32,150 bytes.

---

## 3. Invariants & Acceptance Criteria

1. **Planner & Designer Top-Tier:** `gemini-4-carbon` is primary candidate for `implementer` and `implementer-deep` in `tri.md`, `quad.md`, and dynamic generation.
2. **Review Council Primary Google Seat:** `gemini-4-carbon` is the Google candidate on `reviewer-a`, `reviewer-b`, `reviewer-c`, and `reviewer-esc`.
3. **Zero Hardcoded Model IDs:** No model IDs in `skills/`, `AGENTS.md`, or `HARNESS.md`.
4. **Size Constraint:** Combined size of `AGENTS.md` + `providers/tri.md` <= 32,150 bytes.
5. **100% Test Pass Rate:** `./test/install.sh` passes completely with zero failures.
6. **Reinstallation & Verification:** `./install.sh --force --target all` and `./install.sh --verify` pass on flux.
