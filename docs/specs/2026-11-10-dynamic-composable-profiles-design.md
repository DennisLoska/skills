# Dynamic Composable Provider Profiles & Cross-Provider Routing Architecture - Design

Status: approved (2026-11-10).
Auto-approved: auto-approve: true "Yes, proceed with dynamic composable profiles via `./install.sh --providers`, cross-provider fallbacks, and the reviewer rules."
Goal: Make provider profiles dynamic and composable based on user provider selections, eliminate same-provider fallback traps that share quota pools, purge expensive OpenCode Go Pro models, enforce official providers for Claude/ChatGPT/Gemini, and configure Muse Spark 1.3 on reviewer Seat C.

---

## 1. Problem Statement & Friction Points

An architectural review of the 6 shipped static profiles (`tri`, `quad`, `opencode-go`, `codex`, `antigravity`, `claude`) revealed 5 key systemic flaws:

1. **Rigid Static Profiles vs. User Subscriptions:**
   - Users are forced into arbitrary hardcoded profiles (`tri`, `quad`, etc.).
   - A user who has e.g. Antigravity + Claude Code, or Codex + OpenCode, or all 4 has no clean way to compose their exact stack without manually hand-editing a markdown table.
   - Profile generation must be dynamic and composable based on the user's enabled providers (e.g. `--providers antigravity,codex,claude,opencode`).

2. **Same-Provider Quota Fallback Trap:**
   - In several existing profiles (e.g. `reviewer-a` falling back from `gpt-6-astra` to `gpt-6.1-sol` in `codex`, or `reviewer-b` falling back from `claude-opus-5-5` to `claude-sonnet-5-5` within `antigravity`), fallbacks share the exact same provider quota pool (`codex` or `antigravity-claude`).
   - When the primary hits rate limits or 429 quota exhaustion, attempting another model in the same provider pool fails immediately with the same 429, wasting dispatches and causing premature council failure.
   - **Rule:** Fallback rungs must switch provider pools whenever alternative providers are available.

3. **Expensive OpenCode Go Models Starving Allowances:**
   - `tri.md` uses expensive OpenCode Go Pro models with small quotas (`deepseek-v4-pro` ~4,200 req/5h, `kimi-k3.1-pro` ~588 req/5h, `qwen3.8-max` ~640 req/5h).
   - These burn through OpenCode allowances rapidly and hit plan limits.
   - OpenCode usage must be restricted to high-allowance, cost-effective models (flash/spark models) and purge expensive Pro models.

4. **Third-Party Model Proxy Pollution (Anthropic, Google, OpenAI via OpenCode):**
   - The user has established strict provider boundary policies:
     - **Anthropic Claude models:** Default to `antigravity` (`claude-opus-5-5`, `claude-sonnet-5-5`), with fallback to official Anthropic (`claudeAgent`). **Never** route Anthropic models through `opencode`.
     - **Google Gemini models:** Run only via `antigravity` (`gemini-4-argon`, `gemini-3.8-flash`). **Never** route Google models through `opencode`.
     - **ChatGPT / OpenAI models:** Run only via official OpenAI `codex` provider (`gpt-6-*`). **Never** route OpenAI models through `opencode`.

5. **Reviewer Seat C Model Specialization:**
   - Seat C must use **`muse-spark-1.3-contributor`** (`meta`, high allowance) as the primary reviewer.
   - For Seat C, **`deepseek-v4.1-flash`** is approved as the designated fallback (exception).

---

## 2. Dynamic Composable Architecture

### 2.1 Dynamic Profile Generator (`install.sh --providers <list>`)
Instead of static-only profiles, `install.sh` supports dynamic composition:
`./install.sh --providers antigravity,codex,claude,opencode [options]`

- Accepts any combination of: `antigravity`, `codex`, `claude`, `opencode`.
- Shipped named presets (`tri`, `quad`, `codex`, `antigravity`, `claude`, `opencode-go`) become dynamic aliases or composed presets:
  - `tri`: `antigravity,codex,opencode`
  - `quad`: `antigravity,codex,claude,opencode`
  - `codex`: `codex`
  - `antigravity`: `antigravity`
  - `claude`: `claude`
  - `opencode-go`: `opencode`

### 2.2 Cross-Provider Fallback Rule & Quota Isolation
Ladders are ordered across disjoint provider quota pools:
- **`reviewer-a` (OpenAI primary):**
  - Primary: `codex` (`gpt-6-astra`)
  - Fallback: switches provider if available (e.g. `opencode/opencode-go/mimo-v2.6-flash` or `claudeAgent`), avoiding codex quota deadlock.
- **`reviewer-b` (Claude primary):**
  - Primary: `antigravity` (`claude-opus-5-5` or `claude-sonnet-5-5`)
  - Fallback: `claudeAgent` (`claude-opus-5-5` or `claude-sonnet-5-5`) from Anthropic.
  - Zero OpenCode Anthropic rungs.
- **`reviewer-c` (Meta primary):**
  - Primary: `opencode` (`opencode-go/muse-spark-1.3-contributor`)
  - Fallback: `opencode` (`opencode-go/deepseek-v4.1-flash`) [explicit allowed exception]
- **`reviewer-esc` (Escalation):**
  - High-allowance open weight: `opencode/opencode-go/mimo-v2.6-flash` -> fallback `glm-5.3-flash`.

---

## 3. Provider Boundary Invariants
1. `opencode` provider shall NEVER contain:
   - `claude-*`
   - `gemini-*`
   - `gpt-*`
2. `antigravity` provides:
   - Google family (`gemini-4-argon`, `gemini-3.8-flash`)
   - Claude family (`claude-opus-5-5`, `claude-sonnet-5-5`)
3. `claudeAgent` provides:
   - Official Anthropic Claude Code models
4. `codex` provides:
   - Official OpenAI models (`gpt-6-astra`, `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6-luna`)

---

## 4. Acceptance Criteria
1. `./install.sh --providers <list>` generates and installs a valid composable profile matching the requested providers.
2. Shipped profiles (`tri.md`, `quad.md`, etc.) are updated to eliminate same-provider fallback traps and purge expensive OpenCode models.
3. Seat C in multi-provider profiles has primary `opencode-go/muse-spark-1.3-contributor` and fallback `opencode-go/deepseek-v4.1-flash`.
4. Claude reviewer rungs default to `antigravity` with fallback to `claudeAgent` (Anthropic), with 0 Anthropic models on `opencode`.
5. Zero Google models on `opencode`; zero OpenAI models on `opencode`.
6. Contract test suite in `test/install.sh` validates composable profiles, quota pool independence, and boundary constraints.
