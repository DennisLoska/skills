# Design Spec: Gemini 4 Neon Primary `implementer`, Council `reviewer-c`, and `implementer-deep` Last-Resort

**Date:** 2026-11-20
**Status:** Approved (Gate 1 resolved with user refinement)

## 1. Purpose & Requirements

Update the `oneshot` harness model routing policy across all six shipped provider profiles (`providers/quad.md`, `providers/tri.md`, `providers/antigravity.md`, `providers/claude.md`, `providers/codex.md`, `providers/opencode-go.md`) and all 15 dynamically generated `--providers` combinations so that:

1. **`implementer` ladder (all at `high` effort):**
   - `primary`: `antigravity` / `gemini-4-neon` (`thinking_level=high`, `google`, `ok`)
   - `fallback`: `claudeAgent` / `claude-opus-5-5` (`effort=high`, `anthropic`, `ok`)
   - `last-resort` (terminal): `codex` / `gpt-6.2-sol` (`reasoningEffort=high`, `openai`, `ok`)
2. **`implementer-deep` ladder (replace `gemini-4-argon` with `gemini-4-neon`):**
   - `primary`: `claudeAgent` / `claude-fable-5-2` (`effort=high`, `anthropic`, `ok`)
   - `fallback`: `codex` / `gpt-6.2-sol` (`reasoningEffort=high`, `openai`, `ok`)
   - `last-resort` (terminal): `antigravity` / `gemini-4-neon` (`thinking_level=high`, `google`, `ok`)
3. **Council & Review (`reviewer-c`, council fallbacks, backup order `8`, and `## Single-provider review` replace `gemini-4-argon` with `gemini-4-neon`):**
   - `reviewer-a` (Captain): `claudeAgent/claude-opus-5-5` (`effort=xhigh`) $\rightarrow$ `codex/gpt-6.2-sol` (`reasoningEffort=xhigh`) $\rightarrow$ `antigravity/gemini-4-neon` (`thinking_level=high`)
   - `reviewer-b`: `codex/gpt-6.2-sol` (`reasoningEffort=xhigh`) $\rightarrow$ `antigravity/gemini-4-neon` (`thinking_level=high`) $\rightarrow$ `claudeAgent/claude-opus-5-5` (`effort=xhigh`)
   - `reviewer-c`: `antigravity/gemini-4-neon` (`thinking_level=high`) $\rightarrow$ `claudeAgent/claude-opus-5-5` (`effort=xhigh`) $\rightarrow$ `codex/gpt-6.2-sol` (`reasoningEffort=xhigh`)
   - `## Backup ladder` order `8`: `| 8 | reviewer-a,reviewer-b,reviewer-c | antigravity | gemini-4-neon | thinking_level=high | google | ok |`
   - `## Single-provider review` Antigravity row: `| antigravity | gemini-4-neon | thinking_level=high | google | ok |`
   - Closed review allowlist becomes `{'claude-opus-5-5', 'gpt-6.2-sol', 'gemini-4-neon'}` (replacing `gemini-4-argon`).

## 2. Approaches & Trade-Offs

### Approach A (Recommended): Direct Canonical Policy Update Across `providers/*.md` + Derived `--providers` Inheritance
Update the `implementer`, `implementer-deep`, `reviewer-a/b/c`, `## Backup ladder`, and `## Single-provider review` rows and load-split prose identically across all six shipped profiles (`providers/*.md`), leaving `install.sh` unchanged so `generate_dynamic_profile` (`sed '1d' "$SRC/providers/quad.md"`) propagates the policy to all 15 `--providers` combinations automatically, then synchronize documentation, `docs/assets/architecture.svg`, and policy/routing test assertions.
- **Pros:** Zero installer script churn; preserves custom `--profile-file` neutrality; automatically reuses existing `antigravity-gemini` (`gemini-*`), `claude-code` (`*`), and `codex` (`*`) quota pools with 3-rung pool independence.
- **Cons:** Requires keeping lines `2..102` synchronized across all six `providers/*.md` files (guarded by `test/all-profile-policy.sh` and `test/claude-provider-routing.sh`).

### Approach B: Add a Separate `antigravity-neon` Quota Pool Above `antigravity-gemini`
Apply Approach A plus prepend `| antigravity-neon | antigravity | gemini-4-neon* | 5h | - | - |` in `## Quota pools`.
- **Pros:** Isolates `gemini-4-neon` 429 ledger entries from other Antigravity Gemini models.
- **Cons:** Counterproductive when Antigravity Gemini models share a rolling quota bucket, and departs from the existing `antigravity-gemini` (`gemini-*`) pool structure.

### Approach C: Hardcode Shipped `implementer` / `reviewer-c` Model IDs Inside `install.sh`
Enforce `gemini-4-neon` inside `validate_profile` in `install.sh`.
- **Pros:** Rejects profiles with non-Neon `implementer` or `reviewer-c` primaries at install time.
- **Cons:** Breaks user-defined `--profile-file` customization and existing negative/positive validator tests in `test/install.sh` and `test/universal-routing.sh`.

**Chosen Approach:** **Approach A**.

## 3. Architecture & Component Changes

### 3.1 Provider Profiles (`providers/{quad,tri,antigravity,claude,codex,opencode-go}.md`)
- Update `## Role distribution`:
  - `- **Implementation:** Antigravity Gemini 4 Neon primary at high (falling back to Claude Code Opus 5.5 at high, then terminal Codex Sol at high), and Claude Code Fable 5.2 deep at high (falling back to Codex Sol at high, then terminal Antigravity Gemini 4 Neon at high).`
  - `- **Review:** Closed allowlist of Claude Code Opus 5.5 (`effort=xhigh`, Seat A / review captain), Codex Sol (`reasoningEffort=xhigh`, Seat B), and Antigravity Gemini 4 Neon (`thinking_level=high`, Seat C), plus a separate per-task reviewer ladder (`gpt-6.2-sol` -> `gpt-6.2-astra` -> `claude-fable-5-2` at high effort).`
- Update `## Budget facts and provider load split`:
  - Note that Claude Code carries Opus implementation fallback, Fable deep implementation, and the review captain, and Antigravity carries Gemini 4 Neon for primary implementation, deep implementation last-resort, and council Seat C.
- Update the role table, backup ladder, and single-provider review table:
  ```markdown
  | implementer | primary | antigravity | gemini-4-neon | thinking_level=high | google | ok |
  | implementer | fallback | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
  | implementer | last-resort | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
  | implementer-deep | primary | claudeAgent | claude-fable-5-2 | effort=high | anthropic | ok |
  | implementer-deep | fallback | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
  | implementer-deep | last-resort | antigravity | gemini-4-neon | thinking_level=high | google | ok |
  | reviewer-a | primary | claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
  | reviewer-a | fallback | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
  | reviewer-a | last-resort | antigravity | gemini-4-neon | thinking_level=high | google | ok |
  | reviewer-b | primary | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
  | reviewer-b | fallback | antigravity | gemini-4-neon | thinking_level=high | google | ok |
  | reviewer-b | last-resort | claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
  | reviewer-c | primary | antigravity | gemini-4-neon | thinking_level=high | google | ok |
  | reviewer-c | fallback | claudeAgent | claude-opus-5-5 | effort=xhigh | anthropic | ok |
  | reviewer-c | last-resort | codex | gpt-6.2-sol | reasoningEffort=xhigh | openai | ok |
  ```
  - `## Backup ladder` order `8`:
    `| 8 | reviewer-a,reviewer-b,reviewer-c | antigravity | gemini-4-neon | thinking_level=high | google | ok |`
  - `## Single-provider review` Antigravity row:
    `| antigravity | gemini-4-neon | thinking_level=high | google | ok |`

### 3.2 Quota Pool Independence & Error Handling
- `implementer` rungs resolve to `antigravity-gemini` (`google`) $\rightarrow$ `claude-code` (`anthropic`) $\rightarrow$ `codex` (`openai`).
- `implementer-deep` rungs resolve to `claude-fable` (`anthropic`) $\rightarrow$ `codex` (`openai`) $\rightarrow$ `antigravity-gemini` (`google`).
- Council seats `reviewer-a/b/c` resolve across `claude-code` (`anthropic`), `codex` (`openai`), and `antigravity-gemini` (`google`), with `gemini-4-neon` using `thinking_level=high` (its maximum supported thinking level).

### 3.3 Documentation & Architecture Diagram
- **`README.md`:** Update `Implementation` and `Review` summary bullets, Antigravity example models in `Provider Setup Overview`, `Default ladders` table (`implementer`, `implementer-deep`, `reviewer-a (Captain)`, `reviewer-b`, `reviewer-c`), and council composition bullets.
- **`docs/skill-model-routing.md`:** Update `Roles in every shipped policy` (`implementer`, `implementer-deep`, `reviewer-a`, `reviewer-b`, `reviewer-c`), `Council and Per-Task Review Routing`, `All 12 skills` table references, and `How to change a role's model`.
- **`docs/assets/architecture.svg`:** Update Layer 2 `implementer` and `implementer-deep` cells and Layer 3 `reviewer-a`, `reviewer-b`, `reviewer-c`, and closed allowlist labels from `gemini-4-argon` to `gemini-4-neon`.

### 3.4 Test Suite Updates
- **`test/all-profile-policy.sh`:** Update `ALLOWED_REVIEW_MODELS` to include `gemini-4-neon` instead of `gemini-4-argon`, update `implementer` primary/fallback/last-resort assertions, `implementer-deep` last-resort assertion, `reviewer-c` primary assertion, `single_provider_review` tuple assertion, and council effort tuple check.
- **`test/claude-provider-routing.sh`:** Update `ALLOWED_REVIEW_MODELS` to `{'claude-opus-5-5', 'gpt-6.2-sol', 'gemini-4-neon'}`, update `implementer` and `implementer-deep` ladder checks, `reviewer-c` primary check, and council effort tuple check.
- **`test/universal-routing.sh`:** Update `implementer` and `reviewer-c` mutation fixtures, `allowed` review model set, and `Single-provider review` tuple set from `gemini-4-argon` to `gemini-4-neon`.
- **`test/single-reviewer-council.sh`:** Update `Single-provider review` Antigravity check and `primaries['reviewer-c']` assertion from `gemini-4-argon` to `gemini-4-neon`.
- **`test/install.sh`:** Update `implementer`, `implementer-deep`, `reviewer-c`, council allowlist, and single-provider review assertions in sections 77, 78, and 80f (preserving lines 1055–1056 legacy pin fixture and lines 1316/1330 quota-ledger merge test fixture).
