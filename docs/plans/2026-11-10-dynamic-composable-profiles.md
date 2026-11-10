# Dynamic Composable Profiles & Cross-Provider Routing Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool (recommended) to implement this plan task-by-task. For standalone plans only, inline execution with batch checkpoints is also allowed. Under oneshot or `auto-approve: true`, execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make provider profiles dynamic and composable via `./install.sh --providers`, eliminate same-provider fallback quota traps, purge expensive OpenCode Go Pro models, enforce official providers for Claude/ChatGPT/Gemini, and configure Muse Spark 1.3 as Reviewer C primary with DeepSeek V4.1 Flash fallback.

**Tech Stack:** POSIX Shell / Bash >=3.2, Markdown, Git.

---

### Task 1: Re-architect Shipped Multi-Provider Profiles (`tri.md` and `quad.md`)
**Files:**
- Modify: `providers/tri.md`
- Modify: `providers/quad.md`

- [ ] **Step 1:** In `providers/tri.md` and `providers/quad.md`:
  - Set Seat C primary to `opencode-go/muse-spark-1.3-contributor` (`variant=xhigh`, `meta`, `trains`).
  - Set Seat C fallback to `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`, `ok`).
  - Set Seat B: default Claude from `antigravity` (`claude-opus-5-5`), fallback from `claudeAgent` (Anthropic in quad) or non-Anthropic fallback, eliminating same-pool traps.
  - Purge all expensive Pro models (`deepseek-v4-pro`, `kimi-k3.1-pro`, `mimo-v2.6-pro`, `minimax-m3`, `qwen3.8-max`). Use only flash/spark models.
  - Remove all Anthropic, Google, and OpenAI models from `opencode` provider rows.
- [ ] **Step 2:** Update quota pool and backup ladder tables to match.
- [ ] **Step 3:** Commit changes:
  `feat(providers): align tri and quad profiles with cross-provider fallbacks and muse-spark review`

---

### Task 2: Implement Dynamic Profile Composition in `install.sh`
**Files:**
- Modify: `install.sh`

- [ ] **Step 1:** Add `--providers <list>` CLI option parsing (e.g. `--providers antigravity,codex,claude,opencode`).
- [ ] **Step 2:** Implement composable profile builder that dynamically stitches primary, fallback, and backup ladders based on the exact set of user-selected providers.
- [ ] **Step 3:** Enforce strict provider invariants:
  - No `claude-*` under `opencode`.
  - No `gemini-*` under `opencode`.
  - No `gpt-*` under `opencode`.
  - Fallbacks avoid sharing the same quota pool.
- [ ] **Step 4:** Commit changes:
  `feat(install): add dynamic composable profile generation via --providers`

---

### Task 3: Contract Tests in `test/install.sh`
**Files:**
- Modify: `test/install.sh`

- [ ] **Step 1:** Add contract tests for `--providers` composition (e.g. 2-provider, 3-provider, and 4-provider combinations).
- [ ] **Step 2:** Assert no expensive Pro models or unauthorized third-party models in generated or shipped tables.
- [ ] **Step 3:** Run `bash test/install.sh` and `/bin/bash test/install.sh`.
- [ ] **Step 4:** Commit changes:
  `test(install): add contract tests for dynamic composable profiles and provider boundaries`

---

### Task 4: Documentation & Testing Badges
**Files:**
- Modify: `README.md`

- [ ] **Step 1:** Document `--providers` in the CLI options table and quickstart tracks.
- [ ] **Step 2:** Synchronize test assertion badges with actual suite output.
- [ ] **Step 3:** Commit changes:
  `docs(readme): document dynamic composable profiles and update test counts`
