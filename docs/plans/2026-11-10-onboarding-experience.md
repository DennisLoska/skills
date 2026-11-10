# 10/10 Onboarding Experience & Installer Verification Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool (recommended) to implement this plan task-by-task. For standalone plans only, inline execution with batch checkpoints is also allowed. Under oneshot or `auto-approve: true`, execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a 10/10 developer onboarding experience by adding `--verify` / `--doctor` health checks and a T3 environment tip to `install.sh`, creating modular 5-host quickstart tracks in `README.md`, fixing `providers/tri.md` prose, and asserting `--verify` in `test/install.sh`.

**Auto-approved:** auto-approve: true "approved and I approve upcoming plan as well just proceed without asking"

**Architecture:** Extend `install.sh` with a modular verification runner that inspects targets for manifest integrity, required files, host instruction wiring (`opencode.json`, `AGENTS.md`, `CLAUDE.md`, Antigravity `rules/`), and shared state health. Add contract assertions in `test/install.sh`. Restructure `README.md` into 5 parallel 10/10 onboarding tracks with unified `./install.sh --verify` validation.

**Tech Stack:** POSIX Shell / Bash >=3.2, Markdown, Git.

---

### Task 1: Add `--verify` / `--doctor` and T3 detection tip to `install.sh`

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Write the failing test**
In `test/install.sh`, add a test case verifying `./install.sh --verify` exits 0 on healthy installs and exits 1 on broken installs or missing configurations.

- [ ] **Step 2: Run test to verify it fails**
Run: `bash test/install.sh`
Expected: FAIL on unrecognized `--verify` flag or missing verify implementation.

- [ ] **Step 3: Implement `--verify` / `--doctor` and T3 detection tip in `install.sh`**
Implement:
1. CLI option parsing for `--verify` and `--doctor`.
2. Target verification routine: checks directory, `.harness-manifest`, required files (`HARNESS.md`, `PROVIDERS.md`, `skills/oneshot/SKILL.md`), host instruction wiring (e.g. `opencode.json` instructions array, Codex `AGENTS.md`, Antigravity rules size & trigger, Claude `CLAUDE.md`), and `state/quota-ledger.tsv`.
3. Informative T3 Code tip when zero `--target` flag is passed and T3 userdata is detected.
4. Update usage text in `install.sh`.

- [ ] **Step 4: Run test to verify it passes**
Run: `bash test/install.sh`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add install.sh
git commit -m "feat(install): add --verify and --doctor health checks with T3 Code detection tip"
```

---

### Task 2: Comprehensive test assertions in `test/install.sh`

**Files:**
- Modify: `test/install.sh`

- [ ] **Step 1: Write additional contract test cases**
Add assertions for:
1. `./install.sh --verify` with default and `--target` scoping.
2. `./install.sh --doctor` alias.
3. Verification failure detection when `opencode.json` lacks `"instructions"`.
4. Verification failure detection when a manifest file is missing.
5. T3 Code tip output check when `~/.t3/userdata` exists and no `--target` is specified.

- [ ] **Step 2: Run test suite to verify tests pass**
Run: `bash test/install.sh && /bin/bash test/install.sh`
Expected: All tests pass (0 failures).

- [ ] **Step 3: Commit**
```bash
git add test/install.sh
git commit -m "test(install): add contract assertions for --verify, --doctor, and T3 tip"
```

---

### Task 3: Align `providers/tri.md` escalation prose with routing table

**Files:**
- Modify: `providers/tri.md:11-45`

- [ ] **Step 1: Update prose in `providers/tri.md`**
Change lines 11 & 43 to correctly state that `reviewer-esc` starts on `opencode-go/kimi-k3.1-pro` (~588 req/5h, `moonshot`) and falls back to `opencode-go/mimo-v2.6-pro` (~13,000 req/5h, `xiaomi`) and `opencode-go/qwen3.8-max` (`alibaba`), matching line 44, line 77, and `README.md`.

- [ ] **Step 2: Run test suite to verify consistency**
Run: `bash test/install.sh`
Expected: PASS

- [ ] **Step 3: Commit**
```bash
git add providers/tri.md
git commit -m "docs(providers): align tri escalation prose with routing table"
```

---

### Task 4: Modular 10/10 Onboarding Tracks and Test Count Badges in `README.md`

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update badges and test count references**
Update badge on line 20 and text on lines 575 & 674 to reflect exact passing test assertion count from `test/install.sh`.

- [ ] **Step 2: Restructure Installation section into 5 clear host quickstart tracks**
Add structured, copy-pasteable tracks:
- Track 1: T3 Code (Multi-Provider Orchestration: Antigravity + Codex + OpenCode [+ Claude])
- Track 2: OpenCode V2 Standalone
- Track 3: Codex Standalone
- Track 4: Antigravity Standalone
- Track 5: Claude Code Standalone
Each track featuring:
- 1-line installation command
- 1-line verification check (`./install.sh --verify --target <target>`)
- Clear first prompt to run.

- [ ] **Step 3: Verify and run tests**
Run: `bash test/install.sh`
Expected: PASS

- [ ] **Step 4: Commit**
```bash
git add README.md
git commit -m "docs(readme): add 10/10 onboarding tracks, --verify instructions, and update test badges"
```
