# Gemini 4 Carbon Integration Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool (recommended) to implement this plan task-by-task. For standalone plans only, inline execution with batch checkpoints is also allowed. Under oneshot or `auto-approve: true`, execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate `gemini-4-carbon` (`provider: antigravity`, `family: google`, `thinking_level=high`) into the cybernetic harness as primary planner/designer (`implementer` and `implementer-deep`) and primary Google-family council reviewer.

**Architecture:** Update dynamic profile generator in `install.sh` and static profiles `providers/tri.md`, `providers/quad.md`, and `providers/antigravity.md`. Retain zero model IDs in `skills/`, `AGENTS.md`, and `HARNESS.md`. Update contract tests in `test/install.sh` to enforce `gemini-4-carbon` ranking while preserving 100% test pass rate and byte cap <= 32,150.

**Tech Stack:** Bash, Awk, POSIX shell, Markdown.

---

### Task 1: Update Contract Tests in `test/install.sh` for Gemini 4 Carbon (TDD Red Step)

**Files:**
- Modify: `test/install.sh:2518-2533` and `test/install.sh:2630-2645`

- [ ] **Step 1: Write the failing tests in `test/install.sh`**

Update `test/install.sh` lines 2518-2521 so `--providers antigravity,claude` verifies:
1. `implementer primary` pool is `antigravity-gemini` (model `gemini-4-carbon`).
2. `implementer-deep primary` pool is `antigravity-gemini` (model `gemini-4-carbon`).
3. `implementer-deep fallback` pool is `antigravity-claude` (`claude-opus-5-5`), maintaining antigravity Claude preference over claudeAgent (`claude-code`).
4. `reviewer-a primary` model is `gemini-4-carbon` (Google-led Seat A).

- [ ] **Step 2: Run test to verify it fails**

Run: `./test/install.sh`
Expected: FAIL on `implementer-deep primary` / `gemini-4-carbon` assertions.

- [ ] **Step 3: Staged red tests**

Confirm failing test diff is staged or ready for implementation.

---

### Task 2: Implement Dynamic Profile Generation in `install.sh`

**Files:**
- Modify: `install.sh:1475-1645`

- [ ] **Step 1: Write minimal implementation in `install.sh`**

1. In `implementer` candidate list:
   Add `add_cand("antigravity", "gemini-4-carbon", "thinking_level=high", "google", "ok")` as candidate #1.
2. In `implementer-deep` candidate list:
   Add `add_cand("antigravity", "gemini-4-carbon", "thinking_level=high", "google", "ok")` as candidate #1.
3. In `driver`:
   Add `add_cand("antigravity", "gemini-4-carbon", "thinking_level=high", "google", "ok")` ahead of `gemini-4-argon`.
4. In council reviewer candidate lists:
   - `reviewer-a`: update Google candidate to `antigravity gemini-4-carbon` (`thinking_level=high`, `google`, `ok`).
   - `reviewer-b`: update Google candidate to `antigravity gemini-4-carbon` (`thinking_level=high`, `google`, `ok`).
   - `reviewer-c`: place `antigravity gemini-4-carbon` (`thinking_level=high`, `google`, `ok`) ahead of `gemini-3.8-flash`.
   - `reviewer-esc`: update Google candidate to `antigravity gemini-4-carbon` (`thinking_level=high`, `google`, `ok`).

- [ ] **Step 2: Run test to verify it passes**

Run: `./test/install.sh`
Expected: Dynamic profile test passes.

- [ ] **Step 3: Commit Task 1 and Task 2 together**

Run: `git commit -am "feat(providers): dynamic profile generation with gemini-4-carbon as primary planner and council reviewer"`

---

### Task 3: Update Static Profiles (`providers/tri.md`, `providers/quad.md`, `providers/antigravity.md`)

**Files:**
- Modify: `providers/tri.md`
- Modify: `providers/quad.md`
- Modify: `providers/antigravity.md`

- [ ] **Step 1: Update `providers/tri.md`**

1. Set `implementer | primary` to `antigravity | gemini-4-carbon | thinking_level=high | google | ok`.
2. Set `implementer-deep | primary` to `antigravity | gemini-4-carbon | thinking_level=high | google | ok`.
   Set `implementer-deep | fallback` to `codex | gpt-6-astra | reasoningEffort=high | openai | ok`.
   Set `implementer-deep | last-resort` to `antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok`.
3. Update prose:
   - "Implementation: implementer runs on Antigravity gemini-4-carbon (high)..."
   - "when Carbon authors code..."

- [ ] **Step 2: Update `providers/quad.md`**

1. Set `implementer | primary` to `antigravity | gemini-4-carbon | thinking_level=high | google | ok`.
2. Set `implementer-deep | primary` to `antigravity | gemini-4-carbon | thinking_level=high | google | ok`.
   Set `implementer-deep | fallback` to `claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok`.
   Set `implementer-deep | last-resort` to `codex | gpt-6-astra | reasoningEffort=high | openai | ok`.
3. Update prose:
   - "Implementation: implementer runs on Antigravity gemini-4-carbon (high)..."
   - Antigravity summary: focuses on Google models (implementer and implementer-deep primary gemini-4-carbon at high...)

- [ ] **Step 3: Update `providers/antigravity.md`**

1. Add `gemini-4-carbon` (`thinking_level=high`, `google`) as primary for `driver`, `implementer`, `implementer-deep`, and reviewer seats (`reviewer-b` primary, `reviewer-a` last-resort, `reviewer-esc` fallback).

- [ ] **Step 4: Verify profiles match requirements and size cap**

Run: `wc -c AGENTS.md providers/tri.md`
Expected: Total <= 32,150 bytes.

- [ ] **Step 5: Commit**

Run: `git commit -am "feat(providers): update tri, quad, and antigravity profiles for gemini-4-carbon"`

---

### Task 4: Complete Test Suite Verification and Invariant Checks

**Files:**
- Test: `test/install.sh`
- Verify: `AGENTS.md`, `skills/`, `agents/`

- [ ] **Step 1: Run full `./test/install.sh`**

Run: `./test/install.sh`
Expected: `all install tests passed (145 passed, 0 failed)` or greater.

- [ ] **Step 2: Run leak check**

Run: `grep -rnE 'opencode-go/|req/5h|#(low|medium|high|xhigh|max)\b|gpt-[0-9]|gemini-[0-9]|claude-(opus|sonnet|haiku|fable)' AGENTS.md skills agents`
Expected: No matches (zero exit).

- [ ] **Step 3: Check byte size limit**

Run: `[ $(( $(wc -c <AGENTS.md) + 2 + $(wc -c <providers/tri.md) )) -le 32150 ] && echo "PASS"`
Expected: PASS.
