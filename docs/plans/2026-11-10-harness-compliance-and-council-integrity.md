# Harness Compliance and Council Integrity Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool (recommended) to implement this plan task-by-task. For standalone plans only, inline execution with batch checkpoints is also allowed. Under oneshot or `auto-approve: true`, execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate protocol bypasses, enforce strict subagent context hygiene in dispatch, prevent single-seat council review loops, enforce author-family independence in council, and require audited council consensus before merging in land.

**Architecture:** Harden skill instructions (`dispatch`, `council`, `land`, `oneshot`) with deterministic `<HARD-GATE>` checks and unambiguous routing rules, synchronize the unified contracts in `AGENTS.md` within the 24,000-byte cap, and assert behavioral rules via `./test/install.sh`.

**Tech Stack:** Bash, Markdown, Git, T3 Code MCP tools.

---

### Task 1: Harden `skills/dispatch/SKILL.md` Against Inline Driver Execution

**Files:**
- Modify: `skills/dispatch/SKILL.md`

- [ ] **Step 1: Write failing assertion in `./test/install.sh`**
Add an assertion in `test/install.sh` verifying that `skills/dispatch/SKILL.md` contains the context hygiene `<HARD-GATE>` and contains no references to "Manual execution" in the flowchart or comparison text.

- [ ] **Step 2: Run test to verify it fails**
Run: `./test/install.sh`
Expected: FAIL with missing dispatch hard-gate assertion.

- [ ] **Step 3: Update `skills/dispatch/SKILL.md`**
- In `when_to_use` flowchart: Replace `"Tasks mostly independent? -> Manual execution [label="no - tightly coupled"]"` with subagent-only routing.
- In Section 2: Replace "vs manual execution" with an explicit architectural statement:
  *In the cybernetic harness, the driver orchestrates and NEVER writes implementation code inline. All implementation occurs via isolated `implementer` or `implementer-deep` subagents.*
- In Step 0 `<HARD-GATE>`: Add Check 4 explicitly forbidding inline driver edits to production code files during oneshot execution.

- [ ] **Step 4: Run test to verify it passes**
Run: `./test/install.sh`
Expected: PASS

- [ ] **Step 5: Commit**
`git commit -m "fix(dispatch): eliminate manual execution loophole and add driver hygiene hard-gate"`

---

### Task 2: Harden `skills/council/SKILL.md` Against Single-Seat Loops and Author Violations

**Files:**
- Modify: `skills/council/SKILL.md`

- [ ] **Step 1: Write failing assertion in `./test/install.sh`**
Add an assertion in `test/install.sh` verifying that `skills/council/SKILL.md` Step 0 `<HARD-GATE>` explicitly requires author-family independence, forbids identical-model review, and restricts single-seat reruns to mid-round provider failover only.

- [ ] **Step 2: Run test to verify it fails**
Run: `./test/install.sh`
Expected: FAIL with missing council assertion.

- [ ] **Step 3: Update `skills/council/SKILL.md`**
- In Step 0 `<HARD-GATE>`: Expand Check 3 to forbid self-review: no council seat may share a family or model with an author of branch commits recorded in state. In degraded dual-family mode where authoring cannot be avoided, require model-level divergence (e.g., `gemini-4-carbon` reviewing `gemini-3.8-flash`).
- In Section 4 (Request phase) and Fallback mechanics: Clarify that *"Rerun only that seat"* applies exclusively to mid-round provider infrastructure failures (`exhausted`, `unreachable`, `transient`). For code re-reviews in Round N+1 after implementation fixes, all active seats (all 3 in nominal, all 2 in degraded) MUST be re-dispatched against the new commit. Forbid single-seat review loops across rounds.

- [ ] **Step 4: Run test to verify it passes**
Run: `./test/install.sh`
Expected: PASS

- [ ] **Step 5: Commit**
`git commit -m "fix(council): enforce author independence in hard-gate and prohibit single-seat round loops"`

---

### Task 3: Strengthen `skills/land/SKILL.md`, `skills/oneshot/SKILL.md`, and `AGENTS.md`

**Files:**
- Modify: `skills/land/SKILL.md`
- Modify: `skills/oneshot/SKILL.md`
- Modify: `AGENTS.md`

- [ ] **Step 1: Write failing assertions in `./test/install.sh`**
Add assertions in `test/install.sh` verifying:
1. `skills/land/SKILL.md` requires recorded Phase 6 Council consensus PASS before merge.
2. `skills/oneshot/SKILL.md` description frontmatter recognizes "use oneshot", "use the oneshot harness", and ticket handoffs.
3. `AGENTS.md` size stays <= 24,000 bytes.

- [ ] **Step 2: Run test to verify it fails**
Run: `./test/install.sh`
Expected: FAIL on missing assertions.

- [ ] **Step 3: Implement updates**
- In `skills/land/SKILL.md`: In Part 2 (Finish options) and Rules, add mandatory rule:
  *Under oneshot or cybernetic harness, merging requires an audited Phase 6 Council consensus PASS (nominal >= 2/3 or degraded unanimous 2/2) recorded in `$(git rev-parse --git-dir)/info/oneshot-state.md`. Never merge without Council consensus PASS.*
- In `skills/oneshot/SKILL.md`:
  - Broaden YAML description:
    `description: Use when user says "oneshot", "use oneshot", "use the oneshot harness", or requests end-to-end autonomous implementation of a feature, bugfix, or ticket. Runs the entire SDLC pipeline autonomously. NOT for single-step tasks, questions, or tasks needing human judgment per step.`
  - Emphasize Phase 3 subagent enforcement and Phase 6 council pre-merge gate.
- In `AGENTS.md`: Synchronize review contracts, council contracts, and context hygiene definitions with these strengthened rules. Confirm `wc -c < AGENTS.md` <= 24,000 bytes.

- [ ] **Step 4: Run test to verify it passes**
Run: `./test/install.sh`
Expected: PASS

- [ ] **Step 5: Commit**
`git commit -m "fix(harness): require council consensus in land, broaden oneshot triggers, and sync AGENTS.md"`

---

### Task 4: Full Suite Verification & Reinstallation on Flux

**Files:**
- Test: `./test/install.sh`
- Installation: `./install.sh --force --target all`
- Verification: `./install.sh --verify`

- [ ] **Step 1: Run full test suite**
Run: `./test/install.sh`
Verify: 100% pass rate (all test cases passing cleanly).

- [ ] **Step 2: Install to all target hosts on flux**
Run: `./install.sh --force --target all`
Verify: Clean install across `opencode`, `codex`, `antigravity` (both standalone and T3 Code instances), and `claude`.

- [ ] **Step 3: Verify target health**
Run: `./install.sh --verify`
Verify: All manifests, required files, profile bindings, instruction wiring, and shared state report `[OK]`.
