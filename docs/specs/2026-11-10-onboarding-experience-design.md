# 10/10 Onboarding Experience & Installer Verification - Design

Status: proposed (2026-11-10).
Goal: Deliver a 10/10 onboarding experience for developers and agents using T3 Code or standalone providers (OpenCode, Codex, Antigravity, Claude Code).

## 1. Problem Statement & Friction Points

An audit of the repository against real-world developer onboarding revealed 4 key friction points:

1. **Zero-Argument Default Trap:**
   - Running `./install.sh` with no flags defaults to `--target opencode` and `--profile tri`.
   - When run inside a T3 Code environment or on a system without OpenCode installed (e.g. Antigravity or Codex users), the installer creates files only in `~/.config/opencode` while leaving the user's active host completely untouched.
   - Users are not warned that other targets exist or that T3 Code requires `--target all` (or `--target antigravity`).

2. **Absence of a Built-In Verification / Doctor Command:**
   - The README previously gave a manual 11-step `grep` and `test -f` shell one-liner that only verified `opencode` and `opencode.json`.
   - There was zero verification mechanism for Codex (`$CODEX_HOME`), Antigravity (`~/.gemini/config` + T3 instances), Claude Code (`$CLAUDE_CONFIG_DIR`), or cross-host shared state.

3. **OpenCode-Centric Documentation Bias:**
   - The README quickstart and installation sections immediately dove into OpenCode configuration (`opencode.json`), treating other providers as footnotes.
   - Users wanting to run Codex, Antigravity, or Claude Code alone lacked dedicated, copy-pasteable 3-step walkthroughs (Install -> Configure -> Verify -> Run).

4. **Documentation and Test Count Drift:**
   - The README badge and text claimed 117/117 passing tests, whereas the test suite contains 123 passing contract assertions.
   - `providers/tri.md` prose contained a contradiction: lines 11 and 43 described `reviewer-esc` starting on `mimo-v2.6-pro`, while the table (line 77) and budget note (line 44) placed `kimi-k3.1-pro` on primary and `mimo-v2.6-pro` on fallback.

---

## 2. Approaches Considered

### Approach A: Documentation-Only Update
- Update README text, badges, and add manual verification shell snippets for each host.
- *Pros:* Zero risk to shell installer scripts.
- *Cons:* Leaves CLI ergonomics weak (7/10). Does not solve the zero-argument trap or provide a robust, automated verification tool.

### Approach B: Interactive TUI Wizard
- Add whiptail/dialog or interactive prompts asking users to check off which hosts and profiles they have.
- *Pros:* Interactive guided setup.
- *Cons:* Breaks scripted non-interactive execution, CI environments, and agent dispatches. High complexity for Bash 3.2 compatibility.

### Approach C (Recommended): Unified `--verify` / `--doctor`, Environment Detection Notice, and Modular Per-Host Quickstart Tracks
- Add `--verify` (alias `--doctor`) to `install.sh`:
  - Inspects target directories (default: targets matching installed manifests, or explicitly specified `--target`).
  - Verifies manifest presence, installed files integrity (`test -f`), active profile binding, and host instruction wiring:
    - OpenCode: checks `opencode.json` for `HARNESS.md` and `PROVIDERS.md` in `"instructions"`.
    - Codex: checks `AGENTS.md` and `HARNESS.md` presence in `$CODEX_HOME`.
    - Antigravity: checks `rules/HARNESS.md`, `rules/PROVIDERS.md` (<24KB, always_on) and `skills/_harness/` bundle.
    - Claude Code: checks `CLAUDE.md` and `skills/`.
    - State: checks `state/` directory and `quota-ledger.tsv` reachability.
  - Outputs clear, colorized/formatted checkmarks (`ok:` / `missing:` / `warning:`) with non-zero exit code on failure.
- Environment Detection Notice in `install.sh`:
  - When `./install.sh` is invoked with no `--target` specified and runs in a detected T3 Code environment (or when `~/.t3/userdata` or `T3_USERDATA_DIR` is present), print an informative tip advising that `--target all` is recommended for full T3 Code orchestration.
- Modular Quickstart in `README.md`:
  - 5 dedicated tracks:
    1. **T3 Code (All Providers / Multi-Subscription)**
    2. **OpenCode Standalone**
    3. **Codex Standalone**
    4. **Antigravity Standalone**
    5. **Claude Code Standalone**
  - Each track has: 1 Install command $\rightarrow$ 1 Verification command (`./install.sh --verify --target <target>`) $\rightarrow$ First Prompt.
- Fix Documentation Drift:
  - Update badges and test suite references to 123/123.
  - Fix `providers/tri.md` escalation prose to match the table.

---

## 3. Specification & Changes

### 3.1 `install.sh`
1. Support `--verify` and `--doctor` options in CLI parsing and usage (`-h`, `--help`).
2. `--verify` accepts `--target <targets>` to scope checks, or defaults to discovering installed targets from existing manifests across known default roots:
   - `${OPENCODE_CONFIG:-$HOME/.config/opencode}`
   - `${CODEX_HOME:-$HOME/.codex}`
   - `${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config}` and discovered T3 instances
   - `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`
3. For each target being verified:
   - Verify directory exists and `.harness-manifest` is present and valid.
   - Verify core harness files: `HARNESS.md`, `PROVIDERS.md`, `skills/oneshot/SKILL.md`, `skills/council/SKILL.md`.
   - Verify host-specific instruction configuration:
     - OpenCode: test if `opencode.json` contains `HARNESS.md` and `PROVIDERS.md`. If not, report warning with remediation JSON snippet.
     - Codex: check `AGENTS.md` exists.
     - Antigravity: check `rules/HARNESS.md` and `rules/PROVIDERS.md` exist and are < 24000 bytes.
     - Claude Code: check `CLAUDE.md` exists.
   - Verify state link: `state/` directory exists and points to or contains `quota-ledger.tsv`.
4. Exit code 0 if all inspected targets are healthy; exit 1 if any target has errors.
5. In standard install mode, when no `--target` was passed and T3 Code userdata is detected (`[ -d "$HOME/.t3/userdata" ]`), output an informative tip:
   `tip: T3 Code detected; pass '--target all' to install across all T3-connected providers (Antigravity, Codex, OpenCode, Claude).`

### 3.2 `README.md`
1. Update test badge and test count references from 117 to 123.
2. In the Installation section, present the 5 Host Quickstart tracks prominently.
3. Replace manual `grep` verification one-liner with `./install.sh --verify` (and show `--target <host>` examples).
4. Update `providers/tri.md` escalation prose to match the table (`kimi-k3.1-pro` primary, `mimo-v2.6-pro` fallback).

### 3.3 `test/install.sh`
1. Add contract tests for `--verify` / `--doctor`:
   - Verification succeeds after fresh install.
   - Verification detects missing instruction registration (e.g. missing `opencode.json` entries).
   - Verification detects missing manifest or pruned file.
   - Verification works with `--target` scoping.
2. Ensure full 100% test suite passes under both Bash and `/bin/bash` (Bash 3.2).

---

## 4. Acceptance Criteria

1. `./install.sh --verify` runs non-destructively, checks target installations, reports clear status per target, and exits 0 on valid install, 1 on broken install.
2. `./install.sh --help` documents `--verify` and `--doctor`.
3. Running `./install.sh` in a T3 Code environment without `--target` prints a helpful tip recommending `--target all`.
4. `README.md` provides clean, parallel onboarding instructions for T3 Code, OpenCode, Codex, Antigravity, and Claude Code.
5. Test counts in badges and text match actual test suite results (123+ assertions).
6. All existing and new tests pass on macOS Bash 3.2 and modern Bash.
