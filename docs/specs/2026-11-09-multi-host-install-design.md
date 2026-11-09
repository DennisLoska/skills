# Multi-host installer and Revision 3 profile rebalance - design

Status: approved (2026-11-09). Builds on
[2026-11-09-provider-decoupling-design.md](./2026-11-09-provider-decoupling-design.md),
[2026-11-09-role-rebalance-design.md](./2026-11-09-role-rebalance-design.md), and
[2026-11-09-budget-fallback-design.md](./2026-11-09-budget-fallback-design.md).

## 1. Architecture question: Does T3 Code have its own skills/agents directory, or does it load them from each provider?

**Verified against the local T3 Code (`~/.t3`), Antigravity (`~/.gemini/config`), Codex (`~/.codex`), and OpenCode (`~/.config/opencode`) installations:**

1. **T3 Code has no separate global `skills/` or `agents/` directory in `~/.t3/userdata`.** T3 Code runs each thread inside the selected provider's runtime (Antigravity ACP, Codex app-server, OpenCode server, or Claude Code agent) and exposes cross-provider subagent dispatch via the `t3-code` MCP server (`delegate_task` + `orchestrator_capabilities`).
2. **Each provider loads skills, rules/instructions, and agents from its own global config directory** (both when run standalone in its CLI/desktop app AND when run as a thread inside T3 Code):
   - **OpenCode (`opencode`):** `${OPENCODE_CONFIG:-$HOME/.config/opencode}` (`agents/`, `skills/`, `HARNESS.md`, `PROVIDERS.md`, `state/`, registered in `opencode.json` `"instructions"`).
   - **Codex (`codex`):** `${CODEX_HOME:-$HOME/.codex}` — discovers skills from `$CODEX_HOME/skills/*/SKILL.md` and global instructions from `$CODEX_HOME/AGENTS.md` (with `HARNESS.md`, `PROVIDERS.md`, `agents/`, and `state/` alongside so seat contracts and the quota ledger are always reachable).
   - **Antigravity (`antigravity`):** `${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config}` — discovers global plugins from `plugins/<name>/` (`plugin.json`, `skills/*/SKILL.md`, `agents/*.md` converted to Antigravity frontmatter, and `rules/HARNESS.md` + `rules/PROVIDERS.md` with `trigger: always_on`, capped at 24 KB per rule file). When T3 Code spawns an Antigravity session, it mounts `<appDataDir>/config/skills` from `~/.gemini/config`.
   - **Claude Code (`claude`):** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` — discovers skills from `skills/*/SKILL.md`, subagents from `agents/*.md` (Claude Code frontmatter), and global instructions from `CLAUDE.md` (or `@HARNESS.md` / `@PROVIDERS.md` imports).

### Best Architectural Decision

Keep **one canonical harness install + machine-wide state** at `${OPENCODE_CONFIG:-$HOME/.config/opencode}` (`HARNESS.md`, `PROVIDERS.md`, `agents/`, `skills/`, `state/quota-ledger.tsv`), and add **`--target <targets>`** to `./install.sh` (`opencode`, `codex`, `antigravity`, `claude`, or `all`, comma-separated; default `opencode` for 100% backwards compatibility):

- Every target gets its own manifest-tracked, collision-safe installation (`--force` and `--prune` work identically per target).
- All targets share the single machine-local quota ledger (`${OPENCODE_CONFIG:-$HOME/.config/opencode}/state/quota-ledger.tsv`, symlinked or referenced from non-OpenCode targets' `state/`) so a 429 in T3 Code, OpenCode, Codex, or Antigravity is visible everywhere on the machine.
- Works both **standalone** in each coding CLI/desktop app and **pooled inside T3 Code** regardless of which provider hosts the main driver thread.

## 2. Target Layouts (`--target opencode|codex|antigravity|claude|all`)

### A. `opencode` (default: `${OPENCODE_CONFIG:-$HOME/.config/opencode}`)
Unchanged: `agents/*.md` (with rendered `model:` pins from first `opencode` rung), `skills/**`, `HARNESS.md`, `PROVIDERS.md`, `NOTICE`, `LICENSE`, `state/`, `.harness-manifest`.

### B. `codex` (`${CODEX_HOME:-$HOME/.codex}`)
- `skills/<name>/...` — all 12 skills copied verbatim.
- `agents/<seat>.md` — all 9 role-contract files (so `<harness-dir>/agents/<seat>.md` is readable locally).
- `HARNESS.md` and `PROVIDERS.md` — byte copies of `AGENTS.md` and the selected profile.
- `AGENTS.md` — combined global instruction file (`HARNESS.md` + `PROVIDERS.md`, with `<harness-dir>` pointing to `$CODEX_HOME`) so standalone Codex CLI/app and T3 Codex threads load the harness and active profile automatically when no existing user `AGENTS.md` blocks it (collision-checked like every other target file).
- `NOTICE`, `LICENSE`, `state/`, and `.harness-manifest`.

### C. `antigravity` (`${ANTIGRAVITY_CONFIG:-$HOME/.gemini/config}/plugins/oneshot-harness`)
Packaged as a self-contained, reversible Antigravity plugin (`plugins/oneshot-harness/`), per Antigravity's plugin specification:
- `plugin.json` — `{"name":"oneshot-harness","displayName":"Oneshot Cybernetic Harness","version":"1.0.0","description":"Multi-provider cybernetic SDLC harness, 12 skills, and 9 role seats."}`.
- `skills/<name>/...` — all 12 skills (every `SKILL.md` already has valid `name` matching the folder name and non-empty `description`).
- `agents/<seat>.md` — all 9 seats rendered with Antigravity subagent frontmatter (`name: <seat>`, `description: ...`, `subagent: true`, `mainAgent: false`, `tools: [...]` mapped to `[read_file, run_command]` for read-only/reviewer seats, `[read_file, edit_file, write_file, run_command, manage_task, search_web]` for implementation/`tester` seats, and `[read_file, edit_file, write_file]` for `patch`) plus an embedded self-enforced `permissions:` YAML block and the full role contract body.
- `rules/HARNESS.md` and `rules/PROVIDERS.md` — each prefixed with `---\ntrigger: always_on\n---\n` (each file is well under Antigravity's 24 KB per-file rule cap: `AGENTS.md` is ~20.5 KB, `PROVIDERS.md` is ~11 KB, whereas concatenating both would exceed 24 KB).
- `HARNESS.md` and `PROVIDERS.md` at the plugin root for `<harness-dir>` path symmetry, plus `NOTICE`, `LICENSE`, `state/`, and `.harness-manifest`.

### D. `claude` (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}`)
- `skills/<name>/...` — all 12 skills.
- `agents/<seat>.md` — all 9 seats rendered with Claude Code subagent frontmatter (`name`, `description`, `tools: Read, Glob, Grep, Bash` for read-only seats; `Read, Edit, Write, Glob, Grep, Bash` for implementation/`tester` seats; `Read, Edit, Write, Glob, Grep` for `patch`) plus an embedded self-enforced `permissions:` YAML block and the full role contract body.
- `HARNESS.md`, `PROVIDERS.md`, `CLAUDE.md` (combined `HARNESS.md` + `PROVIDERS.md`), `NOTICE`, `LICENSE`, `state/`, and `.harness-manifest`.

## 3. Revision 3 Profile Rebalance (`tri` and `quad`)

Per user directives:
1. **`implementer` uses Argon `high`, Antigravity `claude-sonnet-5-5` as fallback, Codex `gpt-6.1-sol` as last-resort:**
   - `tri`: `antigravity` `gemini-4-argon` (`thinking_level=high`) -> `antigravity` `claude-sonnet-5-5` (`thinking_level=medium`) -> `codex` `gpt-6.1-sol` (`reasoningEffort=medium`).
   - `quad`: `antigravity` `gemini-4-argon` (`thinking_level=high`) -> `claudeAgent` `claude-sonnet-5-5` (`effort=medium`) -> `codex` `gpt-6.1-sol` (`reasoningEffort=medium`).
   - Because `implementer` has no `opencode` rung on its 3-rung ladder in `tri` or `quad`, it installs without a native `model:` pin (emitting the `note: implementer has no opencode rung...` line) and dispatches via `delegate_task`.
2. **Zero Google models and zero OpenAI (`gpt-*`) models routed through OpenCode Go in `tri` and `quad`:**
   - `opencode-go/gemini-4-argon` is removed from `tri` and `quad`.
3. **Argon never reviews its own code (`reviewer-a` and `reviewer-c` swapped; `deepseek-v4-pro` primary on Seat C):**
   - `reviewer-a` (OpenAI frontier lead / tie-breaker): `codex` `gpt-6-astra` (`reasoningEffort=high`) -> `codex` `gpt-6.1-sol` (`reasoningEffort=high`) -> `codex` `gpt-6-sol` (`reasoningEffort=high`). (No `opencode` rung -> unpinned in `tri`/`quad`.)
   - `reviewer-b` (Anthropic frontier):
     - `tri`: `antigravity` `claude-opus-5-5` (`thinking_level=high`) -> `antigravity` `claude-sonnet-5-5` (`thinking_level=high`) -> `opencode` `opencode-go/claude-haiku-5-5` (`variant=high`).
     - `quad`: `claudeAgent` `claude-opus-5-5` (`effort=high`) -> `antigravity` `claude-opus-5-5` (`thinking_level=high`) -> `claudeAgent` `claude-sonnet-5-5` (`effort=high`).
   - `reviewer-c` (Open-weight Pro — high budget): `opencode` `opencode-go/deepseek-v4-pro` (`-`, `deepseek`, ~1,040 req/5h) -> `opencode` `opencode-go/mimo-v2.6-pro` (`-`, `xiaomi`, ~3,250 req/5h) -> `opencode` `opencode-go/minimax-m3` (`-`, `minimax`, ~3,200 req/5h). (Native pin in `tri`/`quad`: `opencode-go/deepseek-v4-pro`.)
   - `reviewer-esc` (Escalation): `opencode` `opencode-go/mimo-v2.6-pro` (`-`, `xiaomi`) -> `opencode` `opencode-go/kimi-k3.1-pro` (`variant=high`, `moonshot`) -> `opencode` `opencode-go/qwen3.8-max` (`-`, `alibaba`). (Native pin in `tri`/`quad`: `opencode-go/mimo-v2.6-pro`.)
