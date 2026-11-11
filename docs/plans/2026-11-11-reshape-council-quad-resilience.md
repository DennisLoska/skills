# Reshape Council: Quad Profile Resilience & Model-Level Non-Blocking Review Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool to implement this plan task-by-task. Execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reshape council review and quad profile routing to prioritize DeepSeek 4.1 flash over mimo/glm, set Sonnet 5.5 as escalation reviewer, set Carbon as first fallback for reviewer-a, set Argon as implementer, and allow council to proceed without blocking whenever >= 2 distinct reviewer models differ from the implementer.

**Architecture:** Update `providers/quad.md` (and related `tri.md` / `antigravity.md`), update harness and council rules in `AGENTS.md`, `HARNESS.md`, and `skills/council/SKILL.md`, and align `install.sh` dynamic generation and `test/install.sh` assertions.

**Tech Stack:** Bash, Awk, Markdown, Git, GitHub CLI.

---

### Task 1: Reshape `providers/quad.md` and Related Profiles

**Files:**
- Modify: `providers/quad.md`
- Modify: `providers/tri.md`
- Modify: `providers/antigravity.md`

- [ ] **Step 1: Write test assertion / verify current diff in test/install.sh**
  Verify the current test expectations for `quad` pins and fallback rungs.

- [ ] **Step 2: Update `providers/quad.md`**
  - Set `implementer` primary to `antigravity` / `gemini-4-argon` (`thinking_level=high`, `google`).
  - Set `implementer-deep` primary to `antigravity` / `gemini-4-argon` (`thinking_level=high`, `google`).
  - Set `reviewer-a` fallbacks: 1st fallback `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`), last-resort `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`).
  - Set `reviewer-b` last-resort: `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`).
  - Set `reviewer-c` fallbacks: `deepseek-v4.1-flash` for fallback and last-resort (`variant=high` and `variant=max`).
  - Set `reviewer-esc`: primary `claudeAgent` / `claude-sonnet-5-5` (`effort=high`, `anthropic`), fallback `antigravity` / `claude-sonnet-5-5` (`thinking_level=high`, `anthropic`), last-resort `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`).
  - Set `## Backup ladder`: replace mimo and glm rows with `deepseek-v4.1-flash`.
  - Update prose in `providers/quad.md` to match.

- [ ] **Step 3: Update `providers/tri.md` and `providers/antigravity.md`**
  - In `providers/tri.md`, replace mimo/glm fallbacks with `deepseek-v4.1-flash`, set `implementer` to `gemini-4-argon`, and update prose.
  - In `providers/antigravity.md`, set `implementer` primary to `gemini-4-argon`.

- [ ] **Step 4: Verify profile table syntax**
  Run `install.sh` syntax validation on the modified profiles.

---

### Task 2: Update Council Non-Blocking Model Independence in Harness & Council Skills

**Files:**
- Modify: `AGENTS.md`
- Modify: `skills/council/SKILL.md`
- Modify: `skills/oneshot/SKILL.md`

- [ ] **Step 1: Update `AGENTS.md`**
  - In `## Routing Rules` (Degraded council & Council Contract): specify that council shall not block as long as there are at least two different members who can review and are not the same model as the implementer (`gemini-4-argon`).
  - Clarify intra-family model-level independence and reviewer-esc eligibility when models are distinct from author models.

- [ ] **Step 2: Update `skills/council/SKILL.md`**
  - In Step 0 (Routing Bootstrap) and Request phase Step 6, document the non-blocking condition when at least two different reviewer members differ from the implementer model.
  - In Fallback mechanics and Verdict phase, state that dual healthy distinct reviewer models satisfy the council progress gate.

- [ ] **Step 3: Update `skills/oneshot/SKILL.md`**
  - Align Phase 6 Council gates with model-level non-blocking independence.

---

### Task 3: Update Dynamic Profile Generator in `install.sh` and Test Suite in `test/install.sh`

**Files:**
- Modify: `install.sh`
- Modify: `test/install.sh`

- [ ] **Step 1: Update `install.sh`**
  - In `generate_dynamic_profile`, update candidate ordering for `reviewer-a` (place `gemini-4-carbon` as first fallback after `gpt-6-astra`), `reviewer-esc` (place `claude-sonnet-5-5` as primary), and `implementer` (place `gemini-4-argon` as primary).
  - Update backup ladder generation in `install.sh` to use `deepseek-v4.1-flash` instead of mimo/glm.

- [ ] **Step 2: Update `test/install.sh`**
  - Update the expected native pins for `quad` in `test/install.sh`:
    - `reviewer-a` opencode pin: `model: opencode-go/deepseek-v4.1-flash#high`
    - `reviewer-b` opencode pin: `model: opencode-go/deepseek-v4.1-flash#high`
    - `reviewer-esc` opencode pin: `model: opencode-go/deepseek-v4.1-flash#high`
  - Update any backup ladder tests expecting mimo or glm in quad.

- [ ] **Step 3: Run `./test/install.sh`**
  Verify all 146+ tests pass cleanly.

---

### Task 4: Push Branch, Create Pull Request, Run Council Review, Merge & Install on Flux

**Files:**
- PR on GitHub
- Installation on `flux`

- [ ] **Step 1: Push feature branch and create PR**
  - `git push -u origin feat/reshape-council-quad-resilience`
  - `gh pr create` with clear summary, changes, and test plan.
  - Link PR using `link_pull_request`.

- [ ] **Step 2: Run Council Review**
  - Verify Council consensus PASS on HEAD.

- [ ] **Step 3: Merge PR to master**
  - `gh pr merge --squash --delete-branch` (or standard merge) to `master`.
  - Checkout `master` and `git pull`.

- [ ] **Step 4: Install `quad` profile on `flux`**
  - Run `./install.sh --force --prune --target all --profile quad`.
  - Run `./install.sh --verify --target all`.
