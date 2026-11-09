# Antigravity & T3 Code Dual-Mode Installer (`with` and `without` T3 Code) — Design

Status: draft (Gate 1 pending user approval, 2026-11-09). Supersedes Section 1.2 (Antigravity bullet) and Section 2.C of [2026-11-09-multi-host-install-design.md](./2026-11-09-multi-host-install-design.md).

## 1. Problem & Live Empirical Findings

`./install.sh` already installs cleanly for `opencode` (`~/.config/opencode`), `codex` (`~/.codex`), and `claude` (`~/.claude`) both with and without T3 Code. Only `--target antigravity` is defective, because the prior spec assumed T3 Code mounts `<appDataDir>/config/skills` from `~/.gemini/config` and that Antigravity ACP loads `plugins/oneshot-harness`.

Live verification against standalone Antigravity (`~/.gemini`) and T3 Code's Antigravity ACP runtime (`~/.t3/userdata/providers/antigravity/<id>`) established four ground-truth constraints:

1. **Dual `GEMINI_HOME` roots (without vs with T3 Code):**
   - **Without T3 Code (standalone Antigravity Desktop App & CLI):** `GEMINI_HOME` is `~/.gemini`, so global config lives at `${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config}`. T3 Code's UI skill picker also scans `~/.gemini/config/skills/`.
   - **With T3 Code:** T3 Code spawns each Antigravity ACP process with `GEMINI_HOME=${T3_USERDATA_DIR:-$HOME/.t3/userdata}/providers/antigravity/<instance-id>`, so the running agent reads `<instance-id>/config/skills/` and ignores `~/.gemini/config`. Neither `codex`, `opencode`, nor `claude` is redirected under `~/.t3/userdata/providers/`.
2. **Plugins and `rules/` in Antigravity:**
   - Plugins under `config/plugins/<name>/` are disabled by default in standalone Antigravity (`MIGRATION_ID_PLUGIN_ENABLEMENT` in `config.json`) and are completely inert in `antigravity-acp` (both standalone CLI ACP and T3 Code).
   - Flat `config/skills/<name>/SKILL.md` is loaded unconditionally in standalone Antigravity App, standalone `antigravity-cli`, T3 Code's UI picker, and T3 Code's spawned Antigravity agent with zero `config.json` mutation.
   - `config/rules/*.md` (`trigger: always_on`, `< 24 KB`) and `config/agents/*.md` remain useful for standalone Antigravity Desktop App surfaces, though `antigravity-acp` ignores them.
3. **`view_file` `realpath` sandbox in Antigravity ACP:**
   - Antigravity ACP's `view_file` pre-tool hook enforces an explicit directory allowlist: `<workspace>`, `<GEMINI_HOME>/antigravity-acp`, `<GEMINI_HOME>/config/skills`, `<GEMINI_HOME>/antigravity-cli/skills`, `<workspace>/.gemini/skills`, and `<workspace>/.agents/skills` — **after resolving symlinks (`realpath`)**.
   - Consequently:
     - **Symlinks fail at runtime:** symlinking `<GEMINI_HOME>/config/skills/<skill>` to `~/.config/opencode/skills/<skill>` lets the startup scanner list the skill in `<skills>`, then fails with `Access to path ... is denied` the moment `view_file` tries to read `SKILL.md` in any normal repository. Installed skills and contracts must be real regular files (`cp -p`), never symlinks.
     - **Paths outside `config/skills/` are unreadable:** `<GEMINI_HOME>/config/agents/*.md`, `<GEMINI_HOME>/config/plugins/...`, `~/.codex/agents/*.md`, and `~/.config/opencode/agents/*.md` are all blocked by `view_file` in Antigravity sessions.
     - **`config/skills/_harness/` is allowlisted and hidden from the skill picker:** Antigravity's skill scanner registers only immediate child directories containing a `SKILL.md` with valid YAML frontmatter. Real files under `<config>/skills/_harness/` (`HARNESS.md`, `PROVIDERS.md`, `NOTICE`, `LICENSE`, `agents/<seat>.md`) are never listed as a skill, yet sit inside `<GEMINI_HOME>/config/skills/` so `view_file` permits both Antigravity drivers and Antigravity child seats to read them in any repository.
4. **Cross-provider dispatch into Antigravity child seats:**
   - When a Codex, OpenCode, or Claude driver dispatches an `antigravity` rung via T3 Code `delegate_task`, substituting the driver's own `<harness-dir>/agents/<seat>.md` (e.g. `~/.codex/agents/implementer.md`) produces a path the Antigravity child cannot read. Every Antigravity session sees the exact path `<skills-dir>/oneshot/SKILL.md` in its `<skills>` system-prompt block, so `antigravity` rungs must reference `<skills-dir>/_harness/agents/<seat>.md` (resolved from `oneshot/SKILL.md` in the child's `<skills>` list).

## 2. Approaches Considered

1. **Approach 1 (Chosen): Unified `--target antigravity` with flat layout, `skills/_harness/` bundle, and automatic T3 instance population.**
   - Drop `plugins/oneshot-harness/`. Install flat `<dest>/{skills/<12-skills>/..., skills/_harness/{HARNESS.md,PROVIDERS.md,NOTICE,LICENSE,agents/<seat>.md}, agents/<seat>.md, rules/{HARNESS,PROVIDERS}.md, HARNESS.md, PROVIDERS.md, NOTICE, LICENSE, state, .harness-manifest}`.
   - `--target antigravity` (and `--target all`) always installs into `${ANTIGRAVITY_CONFIG-$HOME/.gemini/config}` and, whenever `${T3_USERDATA_DIR-$HOME/.t3/userdata}/providers/antigravity/<id>/` contains one or more provider instance directories, atomically preflights and installs the identical layout into every `<id>/config`. When `~/.t3` or `providers/antigravity/*` is absent ("without T3 Code"), it installs only into `~/.gemini/config` and exits `0`.
   - *Pros:* Zero new CLI flags; works identically with and without T3 Code; real copied files satisfy `view_file` `realpath` checks; single atomic preflight across standalone and T3 roots; legacy `plugins/oneshot-harness` is cleanly migrated on `--prune`.
   - *Cons:* If T3 Code later mints a new `<instance-id>` hash after a provider reset, the user reruns `./install.sh --force --target antigravity` (or `--target all`).
2. **Approach 2 (Rejected): Symlink `<instance-id>/config/skills/*` to `~/.gemini/config/skills` or `~/.config/opencode/skills`.**
   - *Why rejected:* Broken at runtime — `antigravity-acp` resolves symlinks before checking its `view_file` allowlist, denying reads to targets outside `<instance-id>/config/skills`.
3. **Approach 3 (Rejected): Split `--target antigravity` (standalone plugin) and `--target antigravity-t3` (T3 flat layout).**
   - *Why rejected:* Even standalone `antigravity-cli` uses ACP where plugins are disabled/inert and outside `view_file`'s allowlist; splitting targets leaks T3's internal `GEMINI_HOME` implementation detail into the user-facing CLI.

## 3. Architecture & Component Design

### 3.1 Flat Antigravity Layout (`DEST = $DEST_CANON`)

Every Antigravity root (`${ANTIGRAVITY_CONFIG-$HOME/.gemini/config}` and each discovered `$T3_ROOT/providers/antigravity/<id>/config`) uses `DEST="$DEST_CANON"` directly (matching `opencode`, `codex`, and `claude`) and installs:

- `skills/<name>/...` — all 12 harness skills copied as real regular files (`cp -p`).
- `skills/_harness/HARNESS.md`, `skills/_harness/PROVIDERS.md`, `skills/_harness/NOTICE`, `skills/_harness/LICENSE`, and `skills/_harness/agents/<seat>.md` — real regular files inside `skills/_harness/` (no `SKILL.md` anywhere under `skills/_harness/`) so Antigravity drivers and child seats can always read harness instructions, the active profile, and rendered seat contracts via `view_file`.
- `agents/<seat>.md` — all 9 seats rendered with Antigravity subagent frontmatter (`name`, `description`, `subagent: true`, `mainAgent: false`, `tools: [...]`), self-enforced `## Permissions policy (self-enforced)` YAML block, and the read-only `run_command` constraint note on read-only seats (identical content to `skills/_harness/agents/<seat>.md`).
- `rules/HARNESS.md` and `rules/PROVIDERS.md` — `trigger: always_on` frontmatter (`< 24000` bytes each; exits `2` with `install.sh: antigravity rule file exceeds 24000 bytes` before writing if exceeded), supporting standalone Antigravity Desktop App rule loading.
- `HARNESS.md`, `PROVIDERS.md`, `NOTICE`, `LICENSE` — root copies for `<dest>` symmetry across all four host targets.
- `state` — unmanaged symlink to `${OPENCODE_CONFIG-$HOME/.config/opencode}/state` (sharing `quota-ledger.tsv` machine-wide across standalone and T3 sessions, with locked ledger merge if a real `state/` directory already exists).
- `.harness-manifest` — `# harness <sha>`, `# profile <name>` (or `# profile-file <abs path>`), and every managed relative file path above (`plugin.json` is gone).

### 3.2 T3 Code Discovery & Isolation Seam (`T3_USERDATA_DIR`)

1. **Discovery rule:** When `antigravity` is selected (directly or via `all`) and internal recursion guard `HARNESS_AGY_SINGLE_ROOT` is not `1`:
   - Standalone root `${ANTIGRAVITY_CONFIG-$HOME/.gemini/config}` is always included.
   - **Env-override isolation:** If `ANTIGRAVITY_CONFIG` is explicitly set in the environment (`[ -n "${ANTIGRAVITY_CONFIG+x}" ]`) and `T3_USERDATA_DIR` is **not** set (`[ -z "${T3_USERDATA_DIR+x}" ]`), T3 discovery is skipped so isolated `ANTIGRAVITY_CONFIG=/custom/dir` runs never touch the caller's real `$HOME/.t3/userdata`.
   - Otherwise, `T3_RAW="${T3_USERDATA_DIR-$HOME/.t3/userdata}"`.
   - When `T3_USERDATA_DIR` is explicitly set, validate `T3_RAW` with the same degenerate / `.` / `..` / `/` / dangling-symlink / non-directory / `$SRC` / `$HOME` checks (`install.sh: refusing unsafe T3 userdata directory: ...`, exit `1`). When `T3_USERDATA_DIR` is unset and `$HOME/.t3/userdata` does not exist, treat as a setup without T3 Code (zero T3 roots, no error).
   - Check `$T3_CANON/providers` and `$T3_CANON/providers/antigravity`:
     - If either path is a symlink or a non-directory existing file, refuse with exit `1` before any write (`install.sh: refusing unsafe T3 provider path: <path>`).
     - If `$T3_CANON/providers/antigravity` does not exist, zero T3 roots are added (setup without T3 Code).
     - If `$T3_CANON/providers/antigravity` is a real directory, iterate `$T3_CANON/providers/antigravity/[!.]*` in `LC_ALL=C` order:
       - If an entry is a symlink (`[ -L "$inst" ]`), refuse with exit `1` (`install.sh: refusing symlinked T3 provider instance: <path>`).
       - If an entry is not a directory (`[ ! -d "$inst" ]`), skip it (ignores stray metadata files).
       - Otherwise add `$inst/config` as an `antigravity` install root (deduplicated by canonical path against the standalone root and prior instances).
2. **Unified atomic preflight & execution:**
   - Generalize the existing multi-target execution loop (`install.sh:182-214`) into a list of `(target_host, custom_agy_config)` jobs.
   - Whenever the expanded job list has `> 1` job (e.g. `--target all`, `--target opencode,codex`, or `--target antigravity` when `>= 1` T3 instance exists), run the nonce-guarded preflight pass (`HARNESS_PREFLIGHT_TOKEN_FILE` + `HARNESS_PREFLIGHT_TOKEN`) across **all** jobs before mutating **any** root, passing `ANTIGRAVITY_CONFIG="$job_cfg" HARNESS_AGY_SINGLE_ROOT=1` to each Antigravity sub-invocation (and always clearing `HARNESS_AGY_SINGLE_ROOT` at startup after reading it, just like `HARNESS_PREFLIGHT_TOKEN`).

### 3.3 Legacy `plugins/oneshot-harness` Upgrade & Prune

To upgrade existing `--target antigravity` installations cleanly:

1. **Profile & SHA inheritance:** On `TARGET_HOST = "antigravity"`, when `$DEST/.harness-manifest` does not exist yet, check `$DEST/plugins/oneshot-harness/.harness-manifest` (only when `$DEST/plugins` and `$DEST/plugins/oneshot-harness` are real non-symlink directories and `.harness-manifest` is a regular non-symlink file). Reuse its `# profile` / `# profile-file` (and `# harness <sha>` for drift reporting) just as if it were the previous manifest.
2. **Manifest-scoped legacy cleanup under `--prune`:** When `TARGET_HOST = "antigravity"` and `--prune` is passed:
   - During preflight (before any write), if `$DEST/plugins` or `$DEST/plugins/oneshot-harness` is a symlink, or if `$DEST/plugins/oneshot-harness/state` is a real directory containing non-ledger files, refuse with exit `1` so preflight stays atomic.
   - If `$DEST/plugins/oneshot-harness/.harness-manifest` is a regular file under real directories:
     - Prune every safe manifest-recorded relative entry inside `$DEST/plugins/oneshot-harness/` using the existing `normalize_rel`, `/*|..` filter, and symlink-parent confinement walk, incrementing `pruned`.
     - For `$DEST/plugins/oneshot-harness/state`: if it is a symlink, `rm -f` it; if it is a real directory, apply the same ledger safety check (refuse non-ledger files; merge any regular `quota-ledger.tsv` into `$SHARED_STATE/quota-ledger.tsv` under locks, then remove empty `state`).
     - Remove `$DEST/plugins/oneshot-harness/.harness-manifest`, then `rmdir` empty directories depth-first inside `$DEST/plugins/oneshot-harness` and `$DEST/plugins` (`2>/dev/null || true`, leaving any user-owned files or sibling plugins untouched).
     - Count the legacy manifest as a previous manifest so `pruned N stale file(s)` is printed instead of `no previous manifest; prune skipped`.

### 3.4 Runtime Routing & Contract Lookup (`AGENTS.md` & Skills)

1. **`AGENTS.md` Dispatch Adapter (Path 2) & `skills/dispatch/{implementer,tester}-prompt.md`:**
   - Update the `Role contract:` path rule: for `provider` `antigravity`, the controller writes literal `<skills-dir>/_harness/agents/<seat>.md (<skills-dir> is the parent of oneshot/SKILL.md in your <skills> list)` instead of substituting the driver's `<harness-dir>/agents/<seat>.md`. For all other providers (`opencode`, `codex`, `claudeAgent`), `<harness-dir>/agents/<seat>.md` (`<harness-dir>` holds `HARNESS.md`) is unchanged.
2. **`skills/oneshot/SKILL.md`, `skills/dispatch/SKILL.md`, `skills/council/SKILL.md`, `skills/codebase-design/DESIGN-IT-TWICE.md`:**
   - Add a concise lookup note where `HARNESS.md` / `PROVIDERS.md` are referenced: when `HARNESS.md` and `PROVIDERS.md` are not already pre-loaded in context (as in Antigravity ACP), read `../_harness/HARNESS.md` and `../_harness/PROVIDERS.md` relative to the skill directory (with the shared quota ledger at `../../state/quota-ledger.tsv`).

### 3.5 Documentation Updates

- `docs/specs/2026-11-09-multi-host-install-design.md`: add an explicit supersede note on Sections 1.2 and 2.C correcting the T3 `GEMINI_HOME` behavior and pointing to this spec.
- `README.md`, `providers/tri.md`, `providers/quad.md`, and `install.sh` `--help`: update `--target antigravity` documentation to describe the flat layout (`skills/`, `skills/_harness/`, `agents/`, `rules/`, `state/`), `T3_USERDATA_DIR` auto-detection for setups with and without T3 Code, and standalone vs T3 runtime behavior.

## 4. Error Handling Matrix

| Condition | Behavior |
| --- | --- |
| T3 Code not installed (`~/.t3/userdata/providers/antigravity` absent) | Installs standalone `${ANTIGRAVITY_CONFIG-$HOME/.gemini/config}` only; exits `0` |
| T3 Code installed with 1..N `<id>/` dirs under `providers/antigravity/` | Atomically preflights and installs standalone root + every `<id>/config`; exits `0` |
| Collision in any T3 `<id>/config` without `--force` | Preflight aborts with `collision: ...` (exit `1`) before standalone or any other target is written |
| Pre-existing symlinked skill dir (`config/skills/oneshot -> ...`) | Refuses without `--force` (`parent symlink under destination`); under `--force`, unlinks symlink and writes real directory + real files |
| Explicit `T3_USERDATA_DIR` is empty, `/`, `.`, `..`, `$HOME`, inside `$SRC`, dangling symlink, or non-dir | Refuses with `install.sh: refusing unsafe T3 userdata directory: ...` (exit `1`) before writing |
| Symlinked `$T3_CANON/providers[/antigravity]` or `<id>` | Refuses with exit `1` before writing |
| `ANTIGRAVITY_CONFIG` set without `T3_USERDATA_DIR` | Installs only to `$ANTIGRAVITY_CONFIG`; never touches `$HOME/.t3/userdata` |
| Oversized Antigravity rule (`>= 24000` bytes) | Exits `2` before writing any file in standalone or T3 roots |

## 5. Verification & Test Plan (`test/install.sh`)

1. Unset `CODEX_HOME`, `ANTIGRAVITY_CONFIG`, `CLAUDE_CONFIG_DIR`, and `T3_USERDATA_DIR` at top of `test/install.sh` alongside `OPENCODE_CONFIG`.
2. Update existing cases 63, 65, 67, 68, 70 for the flat Antigravity layout (`$AGY/skills/oneshot/SKILL.md`, `$AGY/skills/_harness/{HARNESS.md,PROVIDERS.md,agents/implementer.md}`, `$AGY/agents/implementer.md`, `$AGY/rules/{HARNESS,PROVIDERS}.md`, `$AGY/state`, `$AGY/.harness-manifest`, no `plugin.json`, no `SKILL.md` under `skills/_harness`).
3. Add new hermetic contract cases:
   - **Setup without T3 Code:** `HOME="$TMPROOT/no-t3-home"` `--target antigravity` and `--target all` succeed with no `.t3` directory present and do not create `.t3`.
   - **Setup with T3 Code (multi-instance):** `HOME="$TMPROOT/with-t3-home"` with two provider hash dirs `providers/antigravity/hash-a` and `providers/antigravity/hash-b` (plus a stray non-dir file in `providers/antigravity/`) populates `~/.gemini/config`, `hash-a/config`, and `hash-b/config` with real files (no symlinks under `skills/`), shared `state/quota-ledger.tsv`, and per-root `.harness-manifest`.
   - **Env isolation:** `ANTIGRAVITY_CONFIG="$TMPROOT/custom-agy"` with a populated `$HOME/.t3/userdata/providers/antigravity/hash-x` leaves `hash-x` untouched unless `T3_USERDATA_DIR` is also passed.
   - **Atomic preflight across T3 instances:** a pre-existing colliding file inside `hash-b/config` aborts `--target antigravity` and `--target all` with exit `1` before `~/.gemini/config`, `hash-a/config`, or `opencode` is modified.
   - **Symlinked skill directory repair:** symlinked `config/skills/oneshot -> /outside` refuses without `--force` and converts cleanly to a real directory of real files under `--force` without mutating `/outside`.
   - **Legacy `plugins/oneshot-harness` upgrade & `--prune`:** pre-existing `plugins/oneshot-harness` with `# profile quad` (plus a sibling `plugins/user-plugin/keep.json`) inherits `quad` on `--force --prune --target antigravity`, removes `oneshot-harness` cleanly, and preserves `plugins/user-plugin/keep.json`.
   - **Unsafe `T3_USERDATA_DIR` and symlinked instance refusals:** exit `1` with zero writes.
