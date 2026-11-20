# Gemini 4 Neon Primary Implementer, Council Seat C, and Deep Last-Resort Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool to implement this plan task-by-task. Execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote `antigravity/gemini-4-neon` (`thinking_level=high`) to `implementer` primary (with `claudeAgent/claude-opus-5-5` fallback and terminal `codex/gpt-6.2-sol` last-resort) and replace `gemini-4-argon` with `gemini-4-neon` across `implementer-deep` last-resort, council `reviewer-a/b/c`, `## Backup ladder`, and `## Single-provider review` across all 6 shipped profiles and 15 generated `--providers` combinations.

**Architecture:** Apply Approach A from `docs/specs/2026-11-20-implementer-gemini-neon-primary-design.md`: update lines `2..102` identically across `providers/{quad,tri,antigravity,claude,codex,opencode-go}.md` while keeping `install.sh`, `AGENTS.md`, `skills/**`, and `agents/**` unchanged so `generate_dynamic_profile` (`sed '1d' "$SRC/providers/quad.md"`) propagates the canonical tables to all 15 `--providers` combinations automatically and preserves 3-rung quota-pool independence (`antigravity-gemini`, `claude-code`, `claude-fable`, `codex`). Synchronize policy/routing regression tests first (TDD Red), then update provider profiles, documentation, and `docs/assets/architecture.svg` (TDD Green), followed by full multi-shell verification.

**Tech Stack:** Markdown routing profiles, Bash (`>= 3.2`), AWK, Python 3 test harnesses, SVG.

---

## Scope & Constraints

- **Approved spec:** `docs/specs/2026-11-20-implementer-gemini-neon-primary-design.md`
- **Modified files (14 total):**
  - Tests (5): `test/all-profile-policy.sh`, `test/claude-provider-routing.sh`, `test/universal-routing.sh`, `test/single-reviewer-council.sh`, `test/install.sh`
  - Shipped profiles (6): `providers/quad.md`, `providers/tri.md`, `providers/antigravity.md`, `providers/claude.md`, `providers/codex.md`, `providers/opencode-go.md`
  - Docs & diagram (3): `README.md`, `docs/skill-model-routing.md`, `docs/assets/architecture.svg`
- **Untouched seams & invariants:**
  - Do **not** modify `install.sh`, `AGENTS.md`, `skills/**`, `agents/**`, or `scheduled-tasks/**`.
  - Preserve custom legacy/merge fixtures in `test/install.sh` at lines `1055–1056` (`no-pools-or-backups.md`), lines `1316` & `1330` (`antigravity-argon` ledger merge row), line `2889` (`esc-custom.md`), and line `3203` (`two-fam.md`).
  - Stage explicit file paths only (`git add <paths>`); never run `git add .` or `git add -A` because `scheduled-tasks/*` has unrelated local modifications.

---

### Task 1: TDD Policy & Routing Test Updates (Red Phase)

**Files:**
- Modify: `test/all-profile-policy.sh:23,122-127,144-167,204,218-220,238,277-279,300,350-353`
- Modify: `test/claude-provider-routing.sh:28,127-132,153-176,190-196,250,284`
- Modify: `test/universal-routing.sh:50-52,68-73,82-84`
- Modify: `test/single-reviewer-council.sh:137-140,148-158`
- Modify: `test/install.sh:2565,2632-2637,2650,2766-2776,3066,3076,3078,3091-3094,3101,3116-3136,3156`

**Seams preserved:** custom `--profile-file` neutrality (`test/install.sh:1055-1056`), quota-ledger merge history (`test/install.sh:1316,1330`), 3-rung pool independence, council effort ceiling (`xhigh` on Opus/Sol council only; `thinking_level=high` on Antigravity Gemini 4 Neon).

- [ ] **Step 1: Update `test/all-profile-policy.sh`, `test/claude-provider-routing.sh`, `test/universal-routing.sh`, `test/single-reviewer-council.sh`, and `test/install.sh`**
- [ ] **Step 2: Syntax-check all modified test scripts and verify intentional RED failure**

---

### Task 2: Provider Profiles, Documentation, and Architecture SVG Updates (Green Phase)

**Files:**
- Modify: `providers/quad.md:10,12,17,32-34,37,49,51,53,80,90`
- Modify: `providers/tri.md:10,12,17,32-34,37,49,51,53,80,90`
- Modify: `providers/antigravity.md:10,12,17,32-34,37,49,51,53,80,90`
- Modify: `providers/claude.md:10,12,17,32-34,37,49,51,53,80,90`
- Modify: `providers/codex.md:10,12,17,32-34,37,49,51,53,80,90`
- Modify: `providers/opencode-go.md:10,12,17,32-34,37,49,51,53,80,90`
- Modify: `README.md:157,293-294,299,303,327-329,356,403-404,408,410,425,430`
- Modify: `docs/skill-model-routing.md:7,21-22,26,40-42,45,49,62,66`
- Modify: `docs/assets/architecture.svg:112-136,155,161-162,178-179`

- [ ] **Step 1: Update `providers/{quad,tri,antigravity,claude,codex,opencode-go}.md` identically on lines `2..102`**
- [ ] **Step 2: Update `README.md`, `docs/skill-model-routing.md`, and `docs/assets/architecture.svg`**
- [ ] **Step 3: Verify GREEN across policy/routing suites and commit Task 1 + Task 2 files**

---

### Task 3: Full Verification Suite Execution

**Files:**
- Test: `install.sh`, `test/install.sh`, `test/all-profile-policy.sh`, `test/claude-provider-routing.sh`, `test/universal-routing.sh`, `test/single-reviewer-council.sh`, `test/council-effort.sh`, `test/council-availability.sh`, `test/design-planner-routing.sh`, `test/t3-harness-alignment.sh`

- [ ] **Step 1: Run shell syntax gates across `install.sh` and all test scripts**
- [ ] **Step 2: Run all specialized regression suites and `test/install.sh`**
