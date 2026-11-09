# Antigravity & T3 Code Dual-Mode Installer + Standalone Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool (recommended) to implement this plan task-by-task. For standalone plans only, inline execution with batch checkpoints is also allowed. Under oneshot or `auto-approve: true`, execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix `./install.sh --target antigravity` (and `--target all`) to work both standalone (`~/.gemini/config`) and inside T3 Code (`~/.t3/userdata/providers/antigravity/*/config`) using real copied files and an allowlisted `skills/_harness/` bundle, enable standalone native execution across all four providers (`opencode`, `codex`, `antigravity`, `claude`), and enforce strict decoupling between `skills/`, `providers/`, and T3 Code.

**Architecture:** `install.sh` drops the inert `plugins/oneshot-harness/` layout in favor of flat `<dest>/{skills/<name>/..., skills/_harness/{HARNESS.md,PROVIDERS.md,NOTICE,LICENSE,agents/<seat>.md}, agents/<seat>.md, rules/{HARNESS,PROVIDERS}.md, HARNESS.md, PROVIDERS.md, NOTICE, LICENSE, state, .harness-manifest}`, auto-detects T3 Code Antigravity provider instances via `${T3_USERDATA_DIR-$HOME/.t3/userdata}/providers/antigravity/*/` under the existing two-pass atomic preflight loop (with `ANTIGRAVITY_CONFIG`-only isolation), and migrates/prunes legacy `plugins/oneshot-harness/`. `AGENTS.md` generalizes Path 3 native dispatch to all four standalone hosts while pointing `antigravity` seat contracts at `<skills-dir>/_harness/agents/<seat>.md`; `providers/{codex,antigravity,claude}.md` provide standalone single-provider profiles; and `skills/**` + `agents/*.md` carry zero provider or T3 Code names.

**Tech Stack:** Bash >= 3.2 (`set -euo pipefail`), POSIX `awk`, Markdown (`AGENTS.md`, `skills/**`, `providers/*.md`, `README.md`), hermetic shell test suite (`test/install.sh`).

---

## File Structure

| File | Action | Responsibility |
| --- | --- | --- |
| `install.sh` | Modify | Flat Antigravity layout + `skills/_harness/` bundle; legacy `plugins/oneshot-harness` profile inheritance & `--prune` cleanup; `T3_USERDATA_DIR` discovery, safety validation, env-override isolation, and multi-root atomic preflight |
| `test/install.sh` | Modify | Unset ambient host env vars; update Antigravity assertions; add hermetic tests for `skills/_harness/`, symlinked skill repair, legacy plugin prune, with-T3 / without-T3 discovery, env isolation, atomic T3 preflight, standalone profiles, and 3-way decoupling |
| `AGENTS.md` | Modify | Path 2 `<skills-dir>/_harness/agents/<seat>.md` contract path for `antigravity`; Path 3 standalone same-provider native dispatch on `opencode`, `codex`, `claudeAgent`, `antigravity`; single-family standalone `task-reviewer` fallback |
| `providers/codex.md` | Create | Validated standalone single-provider Codex profile (`--profile codex`) |
| `providers/antigravity.md` | Create | Validated standalone single-provider Antigravity profile (`--profile antigravity`) |
| `providers/claude.md` | Create | Validated standalone single-provider Claude Code profile (`--profile claude`) |
| `providers/tri.md` | Modify | Add `*` backup rows on `codex` and `antigravity` for standalone fallback; update prose for standalone + T3 setups |
| `providers/quad.md` | Modify | Add `*` backup rows on `codex`, `antigravity`, and `claudeAgent` for standalone fallback; update prose for standalone + T3 setups |
| `skills/oneshot/SKILL.md` | Modify | Remove host/provider/T3 names; add host-neutral `../_harness/` lookup fallback |
| `skills/dispatch/SKILL.md` | Modify | Remove host/provider/T3 names; add host-neutral `../_harness/` lookup fallback |
| `skills/dispatch/implementer-prompt.md` | Modify | Replace `<harness-dir>/agents/<seat>.md` with adapter-resolved `<contract-path>` |
| `skills/dispatch/tester-prompt.md` | Modify | Replace `<harness-dir>/agents/tester.md` with adapter-resolved `<contract-path>` |
| `skills/council/SKILL.md` | Modify | Remove `delegate_task` reference; add host-neutral `../_harness/` lookup fallback |
| `skills/land/SKILL.md` | Modify | Remove OpenCode / T3 Code names from worktree instructions |
| `skills/codebase-design/DESIGN-IT-TWICE.md` | Modify | Add host-neutral `../_harness/` lookup fallback |
| `docs/specs/2026-11-09-multi-host-install-design.md` | Modify | Add supersede notes on Sections 1.2 and 2.C referencing `2026-11-09-antigravity-t3-install-design.md` |
| `README.md` | Modify | Document flat Antigravity layout, `T3_USERDATA_DIR` auto-detection, standalone profiles (`opencode-go`, `codex`, `antigravity`, `claude`), and standalone vs T3 Code usage |

---

### Task 1: Flat Antigravity Layout, `skills/_harness/` Bundle, and Legacy Plugin Migration

**Files:**
- Modify: `install.sh:335-420`, `install.sh:784-971`, `install.sh:1080-1133`, `install.sh:1286-1356`
- Test: `test/install.sh:1-10`, `test/install.sh:1164-1270`, `test/install.sh:1330-1407`

- [ ] **Step 1: Write the failing tests in `test/install.sh`**

1. At the top of `test/install.sh` (line 6), unset all host config overrides so ambient caller variables never leak:
```bash
unset OPENCODE_CONFIG CODEX_HOME ANTIGRAVITY_CONFIG CLAUDE_CONFIG_DIR T3_USERDATA_DIR
```

2. Update existing cases 63, 65, 67, 68, and 70 in `test/install.sh` from `$AGY/plugins/oneshot-harness` to flat `$AGY` with `skills/_harness/`:
   - In case 63 (`test/install.sh:1164-1190`), assert:
     ```bash
     rc=0
     ANTIGRAVITY_CONFIG="$TMPROOT/agy-config" "$INSTALL" --target antigravity >"$TMPROOT/agy.out" 2>&1 || rc=$?
     [ "$rc" -eq 0 ] || { cat "$TMPROOT/agy.out" >&2; fail "--target antigravity install exits 0"; }
     AGY_DEST="$TMPROOT/agy-config"
     [ ! -e "$AGY_DEST/plugin.json" ] || fail "antigravity target drops plugin.json"
     [ ! -e "$AGY_DEST/plugins/oneshot-harness" ] || fail "antigravity target drops plugins/oneshot-harness"
     [ -f "$AGY_DEST/skills/oneshot/SKILL.md" ] && [ ! -L "$AGY_DEST/skills/oneshot/SKILL.md" ] || fail "antigravity target writes real skills/oneshot/SKILL.md"
     [ -f "$AGY_DEST/skills/_harness/HARNESS.md" ] || fail "antigravity target writes skills/_harness/HARNESS.md"
     [ -f "$AGY_DEST/skills/_harness/PROVIDERS.md" ] || fail "antigravity target writes skills/_harness/PROVIDERS.md"
     [ -f "$AGY_DEST/skills/_harness/NOTICE" ] || fail "antigravity target writes skills/_harness/NOTICE"
     [ -f "$AGY_DEST/skills/_harness/LICENSE" ] || fail "antigravity target writes skills/_harness/LICENSE"
     [ -f "$AGY_DEST/skills/_harness/agents/implementer.md" ] || fail "antigravity target writes skills/_harness/agents/implementer.md"
     [ ! -e "$AGY_DEST/skills/_harness/SKILL.md" ] || fail "skills/_harness has no SKILL.md"
     [ -f "$AGY_DEST/agents/implementer.md" ] || fail "antigravity target writes agents/implementer.md"
     cmp -s "$AGY_DEST/agents/implementer.md" "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "skills/_harness/agents matches rendered agents"
     [ -f "$AGY_DEST/rules/HARNESS.md" ] || fail "antigravity target writes rules/HARNESS.md"
     [ -f "$AGY_DEST/rules/PROVIDERS.md" ] || fail "antigravity target writes rules/PROVIDERS.md"
     [ -f "$AGY_DEST/HARNESS.md" ] || fail "antigravity target writes root HARNESS.md"
     [ -f "$AGY_DEST/PROVIDERS.md" ] || fail "antigravity target writes root PROVIDERS.md"
     [ -d "$AGY_DEST/state" ] || fail "antigravity target writes state/"
     [ -f "$AGY_DEST/.harness-manifest" ] || fail "antigravity target writes .harness-manifest"
     grep -qxF 'trigger: always_on' "$AGY_DEST/rules/HARNESS.md" || fail "antigravity rules/HARNESS.md is always_on"
     grep -qxF 'trigger: always_on' "$AGY_DEST/rules/PROVIDERS.md" || fail "antigravity rules/PROVIDERS.md is always_on"
     [ "$(wc -c <"$AGY_DEST/rules/HARNESS.md")" -lt 24000 ] || fail "antigravity rules/HARNESS.md is under 24KB"
     [ "$(wc -c <"$AGY_DEST/rules/PROVIDERS.md")" -lt 24000 ] || fail "antigravity rules/PROVIDERS.md is under 24KB"
     grep -qxF 'subagent: true' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer is a subagent"
     grep -qxF 'mainAgent: false' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer is not a main agent"
     grep -q '^tools:' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer carries a tools frontmatter line"
     grep -qxF 'permissions:' "$AGY_DEST/skills/_harness/agents/implementer.md" || fail "antigravity implementer preserves the permissions policy block"
     grep -qxF 'permissions:' "$AGY_DEST/skills/_harness/agents/reviewer-a.md" || fail "antigravity reviewer-a preserves the permissions policy block"
     grep -qF 'Antigravity cannot narrow run_command in frontmatter' "$AGY_DEST/skills/_harness/agents/reviewer-a.md" || fail "antigravity reviewer-a documents the read-only run_command constraint"
     pass "--target antigravity installs flat skills, allowlisted skills/_harness bundle, always_on rules (<24KB), and Antigravity subagent contracts"
     ```
   - In cases 65, 67, 68, and 70, replace `/plugins/oneshot-harness/.harness-manifest` with `/.harness-manifest` and `/plugins/oneshot-harness/state/quota-ledger.tsv` with `/state/quota-ledger.tsv`.

3. Append new contract case 72 at the bottom of `test/install.sh` (before the final summary `printf`) testing:
   - Symlinked skill directory (`$AGY/skills/oneshot -> $TMPROOT/outside-skill`) refuses without `--force` and converts to a real directory of real files under `--force` without modifying `$TMPROOT/outside-skill`.
   - Legacy `plugins/oneshot-harness/` migration: pre-populate `$AGY_MIG/plugins/oneshot-harness` with `.harness-manifest` (`# harness deadbee`, `# profile quad`, `plugin.json`, `rules/HARNESS.md`), those files, a `state` symlink, plus a sibling user plugin `$AGY_MIG/plugins/user-plugin/keep.json`. Verify `ANTIGRAVITY_CONFIG="$AGY_MIG" OPENCODE_CONFIG="$TMPROOT/mig-oc" "$INSTALL" --force --prune --target antigravity` exits `0`, inherits `# profile quad` in `$AGY_MIG/.harness-manifest`, prints `pruned 2 stale file(s)`, removes `$AGY_MIG/plugins/oneshot-harness`, and preserves `$AGY_MIG/plugins/user-plugin/keep.json`.
   - Non-ledger file inside legacy `$AGY_BAD/plugins/oneshot-harness/state/foreign.db` refuses with exit `1` during preflight under `--force --prune` before writing `$AGY_BAD/.harness-manifest`.

- [ ] **Step 2: Run `bash test/install.sh` to verify failure**

Run: `bash test/install.sh`
Expected: FAIL at case 63 (`antigravity target drops plugin.json` / `plugins/oneshot-harness` still produced).

- [ ] **Step 3: Implement flat Antigravity layout, `skills/_harness/` staging, and legacy plugin migration in `install.sh`**

1. Remove the `plugins/oneshot-harness` destination suffix (`install.sh:335-339`): set `DEST="$DEST_CANON"` unconditionally.
2. Legacy manifest fallback (`install.sh:397-420` & `1343-1356`):
   - Define `LEGACY_AGY_DIR=""` and `LEGACY_AGY_MANIFEST=""`. When `TARGET_HOST = "antigravity"`:
     `LEGACY_AGY_DIR="$DEST/plugins/oneshot-harness"`
     `LEGACY_AGY_MANIFEST="$LEGACY_AGY_DIR/.harness-manifest"`
   - When `[ ! -f "$MANIFEST" ]` and `TARGET_HOST = "antigravity"` and `[ ! -L "$DEST/plugins" ] && [ -d "$DEST/plugins" ] && [ ! -L "$LEGACY_AGY_DIR" ] && [ -d "$LEGACY_AGY_DIR" ] && [ ! -L "$LEGACY_AGY_MANIFEST" ] && [ -f "$LEGACY_AGY_MANIFEST" ]`, read `prev_profile`, `prev_profile_file`, `prev_entry_present`, and `prev_sha` (`prev_manifest_present=1`) from `$LEGACY_AGY_MANIFEST`.
3. Flat Antigravity file staging (`install.sh:784-911`):
   - Remove `plugin_json` generation (`plugin.json` is dropped).
   - Keep `rules/HARNESS.md` and `rules/PROVIDERS.md` (`< 24000` bytes guard).
   - Stage `skills/_harness/HARNESS.md` (`$SRC/AGENTS.md`), `skills/_harness/PROVIDERS.md` (`$staged_profile`), `skills/_harness/NOTICE` (`$SRC/NOTICE`), and `skills/_harness/LICENSE` (`$SRC/LICENSE`).
   - After the agent render loop (`install.sh:970`), when `TARGET_HOST = "antigravity"`, append `skills/_harness/${rels[$i]}` pointing to the already-rendered `${srcs[$i]}` for every `agents/*.md` entry so `skills/_harness/agents/<seat>.md` is byte-identical to `agents/<seat>.md`.
4. Legacy plugin preflight & `--prune` cleanup (`install.sh:1084` & `1286-1336`):
   - During preflight when `TARGET_HOST = "antigravity"` and `prune = 1`:
     - If `[ -L "$DEST/plugins" ]` or `[ -L "$LEGACY_AGY_DIR" ]`, print `install.sh: refusing to prune through symlink: ...` on stderr and `exit 1`.
     - If `[ -d "$LEGACY_AGY_DIR" ]`:
       - If `[ -L "$LEGACY_AGY_MANIFEST" ]` or `{ [ -e "$LEGACY_AGY_MANIFEST" ] && [ ! -f "$LEGACY_AGY_MANIFEST" ]; }`, print `install.sh: manifest path is not a regular file: $LEGACY_AGY_MANIFEST` on stderr and `exit 1`.
       - If `[ -d "$LEGACY_AGY_DIR/state" ] && [ ! -L "$LEGACY_AGY_DIR/state" ]`, validate `$LEGACY_AGY_DIR/state` entries with the exact same `quota-ledger.tsv` / `quota-ledger.lock` / non-ledger refusal check as `$DEST/state`, plus `check_lock_path_preflight "$LEGACY_AGY_DIR/state/quota-ledger.lock"`.
   - During `--prune` execution (`install.sh:1286-1336`):
     - Track `had_any_manifest=0` (`1` if `[ -f "$MANIFEST" ]` or legacy `$LEGACY_AGY_MANIFEST` exists on `antigravity`). If `had_any_manifest = 0`, print `no previous manifest; prune skipped`; else accumulate `pruned=0` across `$MANIFEST` (if present) and `$LEGACY_AGY_MANIFEST` (if present on `antigravity`: prune safe manifest entries under `$LEGACY_AGY_DIR` with symlink-parent confinement up to `$LEGACY_AGY_DIR`, migrate any regular `$LEGACY_AGY_DIR/state/quota-ledger.tsv` into `$SHARED_STATE/quota-ledger.tsv` under locks or `rm -f` symlinked `$LEGACY_AGY_DIR/state`, `rm -f -- "$LEGACY_AGY_MANIFEST"`, `find "$LEGACY_AGY_DIR" -depth -type d -exec rmdir {} \; 2>/dev/null || true`, and `rmdir "$DEST/plugins" 2>/dev/null || true`), then print `pruned %d stale file(s)`.

- [ ] **Step 4: Run `bash test/install.sh` to verify green**

Run: `bash test/install.sh`
Expected: PASS (all assertions exit `0`).

- [ ] **Step 5: Commit Task 1**

```bash
git add install.sh test/install.sh
git commit -m "feat(install): switch antigravity to flat layout with skills/_harness bundle"
```

---

### Task 2: T3 Code Instance Discovery (`T3_USERDATA_DIR`), Env Isolation, and Atomic Multi-Root Preflight

**Files:**
- Modify: `install.sh:23-68`, `install.sh:178-235`
- Test: `test/install.sh:1400+`

- [ ] **Step 1: Write the failing tests in `test/install.sh`**

Append contract cases in `test/install.sh` covering:
1. **Without T3 Code:** `HOME="$TMPROOT/no-t3-home"` `--target antigravity` and `--target all` exit `0`, populate `$TMPROOT/no-t3-home/.gemini/config/skills/_harness/HARNESS.md`, and do **not** create `$TMPROOT/no-t3-home/.t3`.
2. **With T3 Code (multiple `<id>` instances + stray file):** under `HOME="$TMPROOT/with-t3-home"`, create `.t3/userdata/providers/antigravity/hash-one`, `.t3/userdata/providers/antigravity/hash-two`, and regular file `.t3/userdata/providers/antigravity/metadata.json`. Run `HOME="$TMPROOT/with-t3-home" "$INSTALL" --target antigravity`:
   - Exits `0`; populates `.gemini/config`, `.t3/userdata/providers/antigravity/hash-one/config`, and `.t3/userdata/providers/antigravity/hash-two/config` with real files (`[ ! -L .../skills/oneshot/SKILL.md ]`), `skills/_harness/agents/implementer.md`, `.harness-manifest`, and `state` symlinks all resolving to `$TMPROOT/with-t3-home/.config/opencode/state`.
   - Mint a third instance `hash-three` and rerun `HOME="$TMPROOT/with-t3-home" "$INSTALL" --force --target all`; verify `hash-three/config/.harness-manifest` is populated too.
3. **Env-override isolation:** with `HOME="$TMPROOT/iso-home"` containing `.t3/userdata/providers/antigravity/hash-untouched`, running `HOME="$TMPROOT/iso-home" ANTIGRAVITY_CONFIG="$TMPROOT/iso-custom" OPENCODE_CONFIG="$TMPROOT/iso-oc" "$INSTALL" --target antigravity` installs into `$TMPROOT/iso-custom` only and leaves `hash-untouched/config` non-existent; passing `T3_USERDATA_DIR="$TMPROOT/iso-home/.t3/userdata"` alongside `ANTIGRAVITY_CONFIG="$TMPROOT/iso-custom"` populates both.
4. **Atomic preflight across standalone + T3 instances:** pre-create colliding file `$TMPROOT/atomic-t3-home/.t3/userdata/providers/antigravity/hash-b/config/HARNESS.md` alongside clean `hash-a` and clean `.gemini/config`. Run `HOME="$TMPROOT/atomic-t3-home" "$INSTALL" --target all` (no `--force`): exits `1` (`collision:`) and writes **nothing** to `.config/opencode`, `.gemini/config`, or `hash-a/config`.
5. **Unsafe `T3_USERDATA_DIR` & symlinked T3 instance refusals:**
   - `T3_USERDATA_DIR=""`, `T3_USERDATA_DIR="/"`, `T3_USERDATA_DIR="$HOME_DIR"`, and `T3_USERDATA_DIR="$ROOT"` each exit `1` (`install.sh: refusing unsafe T3 userdata directory:`) before writing anything.
   - Symlinked `.t3/userdata/providers/antigravity/hash-link -> $TMPROOT/outside` exits `1` (`install.sh: refusing symlinked T3 provider instance:`) before writing anything.

- [ ] **Step 2: Run `bash test/install.sh` to verify failure**

Run: `bash test/install.sh`
Expected: FAIL on multi-instance T3 discovery (`hash-one/config` not populated).

- [ ] **Step 3: Implement `T3_USERDATA_DIR` discovery, safety checks, and multi-job preflight in `install.sh`**

1. Capture and clear internal single-root guard at startup (`install.sh:56-63`):
```bash
agy_single_root=0
if [ "${HARNESS_AGY_SINGLE_ROOT:-}" = "1" ]; then
  agy_single_root=1
fi
unset HARNESS_AGY_SINGLE_ROOT
```
2. Update `usage()` (`install.sh:34-36`) to note that `antigravity` installs standalone `${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config}` plus any T3 Code instances under `${T3_USERDATA_DIR:-$HOME/.t3/userdata}/providers/antigravity/*/config`.
3. Before the multi-target runner (`install.sh:178`), build two parallel arrays `job_targets=()` and `job_agy_configs=()`:
   - Helper `validate_t3_userdata_dir()` checks `T3_RAW`:
     - Compact whitespace/slashes -> empty refuses with `install.sh: refusing unsafe T3 userdata directory: $T3_RAW` (exit `1`).
     - Strip trailing slashes; `.|..|../*|*/..|*/../*` refuses (`a relative self or parent reference`, exit `1`).
     - Dangling symlink or existing non-directory refuses (exit `1`).
     - Resolve `T3_CANON="$(canonical_dest "$T3_STRIPPED")"`; refuse `/`, `$SRC`/`$SRC_PHYS` or inside `$SRC_PHYS`, and `$HOME`/`$HOME_PHYS` (exit `1`).
   - When `tok` in `selected_targets` is not `antigravity` (or `agy_single_root -eq 1`): append `(tok, "")`.
   - When `tok = "antigravity"` and `agy_single_root -eq 0`:
     - Primary root `agy_primary="${ANTIGRAVITY_CONFIG-$HOME/.gemini/config}"`; append `("antigravity", "$agy_primary")` (or `""` when `ANTIGRAVITY_CONFIG` is unset so default resolution runs identically, recording its canonical path when valid to deduplicate).
     - Discover T3 instances unless `[ -n "${ANTIGRAVITY_CONFIG+x}" ] && [ -z "${T3_USERDATA_DIR+x}" ]`:
       - If `[ -n "${T3_USERDATA_DIR+x}" ]`, always run `validate_t3_userdata_dir "$T3_USERDATA_DIR"`.
       - Else `T3_RAW="$HOME/.t3/userdata"`; if `[ -L "$T3_RAW" ] || [ -e "$T3_RAW" ]`, run `validate_t3_userdata_dir "$T3_RAW"`, else skip cleanly (no T3 Code installed).
       - When `T3_CANON` is set:
         - Check `$T3_CANON/providers` and `$T3_CANON/providers/antigravity`: if `[ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }`, print `install.sh: refusing unsafe T3 provider path: $p` >&2 and `exit 1`.
         - If `[ -d "$T3_CANON/providers/antigravity" ]`, iterate `$T3_CANON/providers/antigravity` entries matching `[!.]*` (with `nullglob` in `LC_ALL=C` order):
           - If `[ -L "$inst" ]`, print `install.sh: refusing symlinked T3 provider instance: $inst` >&2 and `exit 1`.
           - `[ -d "$inst" ] || continue`
           - Append `("antigravity", "$inst/config")` if its `canonical_dest` does not duplicate an already-queued `antigravity` root.
4. Execute `job_targets` / `job_agy_configs`:
   - Whenever `${#job_targets[@]} -gt 1`, run Pass 1 (with `HARNESS_PREFLIGHT_TOKEN_FILE` + `HARNESS_PREFLIGHT_TOKEN`, passing `ANTIGRAVITY_CONFIG="${job_agy_configs[$idx]}" HARNESS_AGY_SINGLE_ROOT=1` when `job_agy_configs[$idx]` is non-empty, or `HARNESS_AGY_SINGLE_ROOT=1` for primary `antigravity`), then `[ "$preflight_only" -eq 1 ] && exit 0`, then Pass 2!

- [ ] **Step 4: Run `bash test/install.sh` to verify green**

Run: `bash test/install.sh`
Expected: PASS (all cases exit `0`).

- [ ] **Step 5: Commit Task 2**

```bash
git add install.sh test/install.sh
git commit -m "feat(install): auto-detect T3 Code Antigravity instances with atomic preflight"
```

---

### Task 3: Standalone Provider Profiles, Multi-Host Native Dispatch Adapter, and Strict 3-Way Decoupling

**Files:**
- Create: `providers/codex.md`, `providers/antigravity.md`, `providers/claude.md`
- Modify: `providers/tri.md:91-98`, `providers/quad.md:78-85`, `AGENTS.md:24-56`, `skills/oneshot/SKILL.md:20-87`, `skills/dispatch/SKILL.md:45-186`, `skills/dispatch/implementer-prompt.md:6-11`, `skills/dispatch/tester-prompt.md:6-11`, `skills/council/SKILL.md:12-18`, `skills/land/SKILL.md:44-47`, `skills/codebase-design/DESIGN-IT-TWICE.md:10-12`
- Test: `test/install.sh:650-658`, `test/install.sh:1450+`

- [ ] **Step 1: Write the failing tests in `test/install.sh`**

1. Update case 40 (`test/install.sh:654`) expected sorted `available:` list from `opencode-go quad tri` to `antigravity claude codex opencode-go quad tri`.
2. Append contract assertions in `test/install.sh` verifying:
   - `--profile codex`, `--profile antigravity`, and `--profile claude` each exit `0` across `--target all` (into throwaway dirs), write valid manifests, and keep `rules/HARNESS.md` & `rules/PROVIDERS.md` `< 24000` bytes and Codex `AGENTS.md` / Claude `CLAUDE.md` `< 32768` bytes **without** triggering prose compaction (check `! grep -q 'compacting .* profile prose'` across `tri`, `quad`, `opencode-go`, `codex`, `antigravity`, and `claude`).
   - Strict 3-way decoupling check on source `skills/` and `agents/`:
     - `! grep -rnE 'opencode-go/|req/5h|#(low|medium|high|xhigh|max)\b' "$ROOT/AGENTS.md" "$ROOT/skills" "$ROOT/agents"`
     - `! grep -rnEi 'opencode|antigravity|codex|claude|t3[-_ ]code|delegate_task|orchestrator_capabilities' "$ROOT/skills" "$ROOT/agents"`

- [ ] **Step 2: Run `bash test/install.sh` to verify failure**

Run: `bash test/install.sh`
Expected: FAIL on case 40 (`available: antigravity claude codex opencode-go quad tri` missing new profiles) and decoupling grep matches.

- [ ] **Step 3: Create standalone profiles, extend `tri`/`quad` backup ladders, update `AGENTS.md`, and decouple `skills/**`**

1. Create `providers/codex.md` (`provider: codex`, `family: openai`, `privacy: ok`):
   - All 10 required roles + `driver` + `compaction` using verified Codex models:
     - `driver`: `gpt-6.1-sol` (`reasoningEffort=medium`) -> `gpt-6-astra` (`reasoningEffort=medium`)
     - `scout`: `gpt-6-luna` (`reasoningEffort=low`) -> `gpt-6.1-terra` (`reasoningEffort=low`) -> `gpt-6.1-sol` (`reasoningEffort=low`)
     - `implementer`: `gpt-6.1-sol` (`reasoningEffort=medium`) -> `gpt-6-astra` (`reasoningEffort=medium`) -> `gpt-6.1-terra` (`reasoningEffort=high`)
     - `implementer-deep`: `gpt-6-astra` (`reasoningEffort=high`) -> `gpt-6.1-sol` (`reasoningEffort=high`) -> `gpt-6-sol` (`reasoningEffort=high`)
     - `tester` & `patch`: `gpt-6-luna` (`reasoningEffort=medium`) -> `gpt-6.1-terra` (`reasoningEffort=medium`) -> `gpt-6.1-sol` (`reasoningEffort=low`)
     - `task-reviewer`: `gpt-6.1-terra` (`reasoningEffort=high`) -> `gpt-6.1-sol` (`reasoningEffort=high`) -> `gpt-6-astra` (`reasoningEffort=high`)
     - `reviewer-a`: `gpt-6-astra` (`reasoningEffort=high`) -> `gpt-6.1-sol` (`reasoningEffort=high`) -> `gpt-6-sol` (`reasoningEffort=high`)
     - `reviewer-b`: `gpt-6.1-sol` (`reasoningEffort=high`) -> `gpt-6.1-terra` (`reasoningEffort=high`) -> `gpt-6-astra` (`reasoningEffort=medium`)
     - `reviewer-c`: `gpt-6.1-terra` (`reasoningEffort=high`) -> `gpt-6-sol` (`reasoningEffort=high`) -> `gpt-6-luna` (`reasoningEffort=high`)
     - `reviewer-esc`: `gpt-6-astra` (`reasoningEffort=high`) -> `gpt-6.1-sol` (`reasoningEffort=high`) -> `gpt-6-sol` (`reasoningEffort=high`)
     - `compaction`: `gpt-6-luna` (`reasoningEffort=low`)
   - `## Quota pools`: `codex | codex | * | 5h | - | -`
   - `## Backup ladder`: `1 | * | codex | gpt-6-luna | reasoningEffort=medium | openai | ok`

2. Create `providers/antigravity.md` (`provider: antigravity`, `google` + `anthropic` families, `privacy: ok`):
   - `driver`: `gemini-4-argon` (`thinking_level=high`, `google`) -> `claude-sonnet-5-5` (`thinking_level=medium`, `anthropic`)
   - `scout`: `gemini-3.8-flash` (`thinking_level=low`, `google`) -> `gemini-4-argon` (`thinking_level=low`, `google`) -> `claude-sonnet-5-5` (`thinking_level=low`, `anthropic`)
   - `implementer`: `gemini-4-argon` (`thinking_level=high`, `google`) -> `claude-sonnet-5-5` (`thinking_level=medium`, `anthropic`) -> `gemini-3.8-flash` (`thinking_level=high`, `google`)
   - `implementer-deep`: `claude-opus-5-5` (`thinking_level=high`, `anthropic`) -> `gemini-4-argon` (`thinking_level=high`, `google`) -> `claude-sonnet-5-5` (`thinking_level=high`, `anthropic`)
   - `tester` & `patch`: `gemini-3.8-flash` (`thinking_level=medium`, `google`) -> `gemini-4-argon` (`thinking_level=medium`, `google`) -> `claude-sonnet-5-5` (`thinking_level=low`, `anthropic`)
   - `task-reviewer`: `claude-sonnet-5-5` (`thinking_level=high`, `anthropic`) -> `gemini-3.8-flash` (`thinking_level=high`, `google`) -> `gemini-4-argon` (`thinking_level=high`, `google`)
   - `reviewer-a`: `claude-opus-5-5` (`thinking_level=high`, `anthropic`) -> `claude-sonnet-5-5` (`thinking_level=high`, `anthropic`) -> `gemini-4-argon` (`thinking_level=high`, `google`)
   - `reviewer-b`: `gemini-4-argon` (`thinking_level=high`, `google`) -> `gemini-3.8-flash` (`thinking_level=high`, `google`) -> `claude-sonnet-5-5` (`thinking_level=high`, `anthropic`)
   - `reviewer-c`: `claude-sonnet-5-5` (`thinking_level=high`, `anthropic`) -> `gemini-3.8-flash` (`thinking_level=high`, `google`) -> `claude-opus-5-5` (`thinking_level=medium`, `anthropic`)
   - `reviewer-esc`: `claude-opus-5-5` (`thinking_level=high`, `anthropic`) -> `gemini-4-argon` (`thinking_level=high`, `google`) -> `gemini-3.8-flash` (`thinking_level=high`, `google`)
   - `compaction`: `gemini-3.8-flash` (`thinking_level=low`, `google`)
   - `## Quota pools`: `antigravity-claude` (`claude-*`, `5h`, `6`, `reviewer-a,reviewer-b`) and `antigravity-gemini` (`gemini-*`, `5h`, `-`, `-`)
   - `## Backup ladder`: `1 | * | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok`

3. Create `providers/claude.md` (`provider: claudeAgent`, `family: anthropic`, `privacy: ok`):
   - `driver`: `claude-sonnet-5-5` (`effort=medium`) -> `claude-opus-5-5` (`effort=medium`)
   - `scout`: `claude-haiku-5-5` (`effort=low`) -> `claude-sonnet-5-5` (`effort=low`) -> `claude-fable-5-1` (`effort=low`)
   - `implementer`: `claude-sonnet-5-5` (`effort=high`) -> `claude-opus-5-5` (`effort=medium`) -> `claude-haiku-5-5` (`effort=high`)
   - `implementer-deep`: `claude-opus-5-5` (`effort=high`) -> `claude-sonnet-5-5` (`effort=high`) -> `claude-fable-5-1` (`effort=high`)
   - `tester` & `patch`: `claude-haiku-5-5` (`effort=medium`) -> `claude-sonnet-5-5` (`effort=medium`) -> `claude-fable-5-1` (`effort=medium`)
   - `task-reviewer`: `claude-sonnet-5-5` (`effort=high`) -> `claude-opus-5-5` (`effort=high`) -> `claude-haiku-5-5` (`effort=high`)
   - `reviewer-a`: `claude-opus-5-5` (`effort=high`) -> `claude-sonnet-5-5` (`effort=high`) -> `claude-haiku-5-5` (`effort=high`)
   - `reviewer-b`: `claude-sonnet-5-5` (`effort=high`) -> `claude-fable-5-1` (`effort=high`) -> `claude-haiku-5-5` (`effort=high`)
   - `reviewer-c`: `claude-fable-5-1` (`effort=high`) -> `claude-haiku-5-5` (`effort=high`) -> `claude-sonnet-5-5` (`effort=medium`)
   - `reviewer-esc`: `claude-opus-5-5` (`effort=high`) -> `claude-sonnet-5-5` (`effort=high`) -> `claude-fable-5-1` (`effort=high`)
   - `compaction`: `claude-haiku-5-5` (`effort=low`)
   - `## Quota pools`: `claude-code | claudeAgent | * | 5h | - | -`
   - `## Backup ladder`: `1 | * | claudeAgent | claude-haiku-5-5 | effort=medium | anthropic | ok`

4. Extend `## Backup ladder` in `providers/tri.md` and `providers/quad.md`:
   - In `providers/tri.md`, append:
     ```markdown
     | 4 | * | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
     | 5 | * | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
     ```
   - In `providers/quad.md`, append:
     ```markdown
     | 4 | * | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
     | 5 | * | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
     | 6 | * | claudeAgent | claude-sonnet-5-5 | effort=medium | anthropic | ok |
     ```

5. Update `AGENTS.md` (lines 28-35 & line 49) concisely (keeping `wc -c AGENTS.md < 21500` and `AGENTS.md + tri.md < 32768`):
   - Path 2 (`delegate_task`): define `<contract-path>` as `<skills-dir>/_harness/agents/<seat>.md` (`<skills-dir>` is the parent of `oneshot/SKILL.md` in the child's `<skills>` list) when `provider` is `antigravity`, and `<harness-dir>/agents/<seat>.md` (`<harness-dir>` holds `HARNESS.md`) otherwise.
   - Path 3 (standalone same-provider native dispatch when T3 tools are absent and `provider` matches the current host):
     - `opencode`: `subagent`/`task` with explicit `model` override `<model>` (`#<value>` when effort id is `variant`; `type general` for `task-reviewer`/`design`).
     - `codex`: `spawn_agent` + `wait` with explicit `model` and `reasoning_effort` (from `reasoningEffort=<value>`).
     - `claudeAgent`: `Agent` (`run_in_background: false`, seat subagent or general-purpose for `task-reviewer`/`design`) with explicit `model`.
     - `antigravity`: `invoke_subagent` (`self` for write-capable seats, `research` for read-only/`task-reviewer`/`design`, contract at `<skills-dir>/_harness/agents/<seat>.md`) mapping `<model>` to `Model: inherit` (same model) or tier `flash_lite|flash|pro` **only** when the rung's `family` matches the active session's family (cross-family rungs without T3 tools hit Path 4 `unreachable`).
     - Announce the standalone native rung; include the Path 2 `Role contract:` (seats) and `Rung:` lines.
   - Line 49 (`Author independence`): add that if skipping the author/`tester` family leaves zero reachable `task-reviewer` rungs **solely** because all non-author families are `unreachable` on a standalone single-family host (never when skipped for `exhausted` quota or soft-cap), use the first reachable same-family `task-reviewer` rung and announce `degraded task-review: single-family host (<family>)`.

6. Decouple all 9 host/provider/T3 lines in `skills/**`:
   - `skills/oneshot/SKILL.md`:
     - Line 20: remove `(the adapter picks the native or delegate_task path per rung)`.
     - Line 22: add host-neutral lookup fallback: `If HARNESS.md and PROVIDERS.md are not already in context, read ../_harness/HARNESS.md and ../_harness/PROVIDERS.md (or ../../HARNESS.md and ../../PROVIDERS.md) relative to this skill's directory (quota ledger at ../../state/quota-ledger.tsv).`
     - Line 53: replace OpenCode / T3 Code worktree examples with `(use the host's worktree tool when available, or a linked git worktree). When already inside a dedicated feature worktree/branch, reuse its branch.`
     - Line 86: replace `(native pin rendered at install for seats with an opencode rung; seats without one are reached only through delegate_task, see the Dispatch Adapter)` with `(routed by the AGENTS.md Dispatch Adapter)`.
   - `skills/dispatch/SKILL.md`:
     - Line 45: replace `(created with the host's worktree tool, e.g. OpenCode ... or a T3 Code worktree thread)` with `(created with the host's worktree tool when available, or git worktree)`.
     - Line 109: replace `(which chooses the native or delegate_task path per rung)` with `(which selects the host dispatch path per rung; if HARNESS.md and PROVIDERS.md are not already in context, read ../_harness/HARNESS.md and ../_harness/PROVIDERS.md or ../../HARNESS.md and ../../PROVIDERS.md relative to this skill's directory)`.
     - Line 185: replace `~/.config/opencode/hooks/` example string with `~/.config/my-tool/hooks/`.
   - `skills/dispatch/implementer-prompt.md:9` and `skills/dispatch/tester-prompt.md:9`: replace `<harness-dir>/agents/<seat>.md` / `<harness-dir>/agents/tester.md` with `<contract-path>` (adding `(<contract-path> per AGENTS.md Dispatch Adapter)` on line 6).
   - `skills/council/SKILL.md`:
     - Line 12: append `(if HARNESS.md and PROVIDERS.md are not already in context, read ../_harness/HARNESS.md and ../_harness/PROVIDERS.md or ../../HARNESS.md and ../../PROVIDERS.md relative to this skill's directory)`.
     - Line 17: remove `(the adapter picks the native or delegate_task path per rung)`.
   - `skills/land/SKILL.md`:
     - Lines 44 & 46: replace `e.g. a T3 Code worktree thread` and `e.g. OpenCode ... or close the T3 Code worktree thread` with host-neutral worktree wording (`use the host's worktree tool when available`).
   - `skills/codebase-design/DESIGN-IT-TWICE.md:11`: append `(if HARNESS.md and PROVIDERS.md are not already in context, read ../_harness/HARNESS.md and ../_harness/PROVIDERS.md or ../../HARNESS.md and ../../PROVIDERS.md relative to this skill's directory)`.

- [ ] **Step 4: Run `bash test/install.sh` to verify green**

Run: `bash test/install.sh`
Expected: PASS (all contract and decoupling assertions exit `0`).

- [ ] **Step 5: Commit Task 3**

```bash
git add AGENTS.md providers/ skills/ test/install.sh
git commit -m "feat(harness): add standalone provider dispatch/profiles and decouple skills"
```

---

### Task 4: Documentation & Superseded Spec Updates

**Files:**
- Modify: `docs/specs/2026-11-09-multi-host-install-design.md:1-6`, `16`, `39-46`
- Modify: `README.md:317-335`, `399-410`, `445-450`, `497-505`, `511-560`
- Modify: `providers/tri.md:99-106`, `providers/quad.md:86-93`

- [ ] **Step 1: Update `docs/specs/2026-11-09-multi-host-install-design.md`**

Add an explicit supersede note in the header and at Sections 1.2 (Antigravity bullet) and 2.C noting that T3 Code sets `GEMINI_HOME=~/.t3/userdata/providers/antigravity/<id>` rather than mounting `~/.gemini/config`, and pointing to [2026-11-09-antigravity-t3-install-design.md](./2026-11-09-antigravity-t3-install-design.md).

- [ ] **Step 2: Update `README.md`, `providers/tri.md`, and `providers/quad.md`**

1. In `README.md`:
   - Update `Which profile do I pick?` table (`lines 323-332`) to list standalone single-provider profiles (`opencode-go`, `codex`, `antigravity`, `claude`) alongside multi-provider profiles (`tri`, `quad`), and explain standalone native execution (without T3 Code, including single-family `task-reviewer` fallback and `yellow: degraded council` when `< 2` families are reachable) vs cross-provider T3 Code orchestration (`delegate_task`).
   - Update `Hosts (T3 Code + Standalone Multi-Host Architecture)` (`lines 399-407`) and `Installation` (`lines 497-560`) to replace `plugins/oneshot-harness` with the flat Antigravity layout (`skills/`, `skills/_harness/`, `agents/`, `rules/`, `state/`), document automatic T3 instance population under `${T3_USERDATA_DIR:-$HOME/.t3/userdata}/providers/antigravity/*/config` alongside standalone `${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config}`, list `T3_USERDATA_DIR` among env overrides, and list all 6 built-in profiles (`tri`, `quad`, `opencode-go`, `codex`, `antigravity`, `claude`).
2. In `providers/tri.md` (`lines 99-105`) and `providers/quad.md` (`lines 86-92`), note that standalone hosts without T3 Code run same-provider rungs natively (or use single-provider `--profile opencode-go|codex|antigravity|claude`) while T3 Code sessions dispatch across all connected providers.

- [ ] **Step 3: Run `bash test/install.sh` to verify green (including byte-size caps after `tri.md`/`quad.md` prose edits)**

Run: `bash test/install.sh`
Expected: PASS (all assertions exit `0`, no prose compaction triggered).

- [ ] **Step 4: Commit Task 4**

```bash
git add README.md docs/specs/2026-11-09-multi-host-install-design.md providers/tri.md providers/quad.md
git commit -m "docs: document standalone and T3 Code Antigravity install and profiles"
```
