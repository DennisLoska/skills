# Design Spec: `implementer` Ladder Update (`gemini-4-neon` Primary, `claude-opus-5-5` Fallback, `gpt-6.2-sol` Last-Resort)

**Date:** 2026-11-20
**Status:** Proposed (Gate 1 pending user approval)

## 1. Purpose & Requirements

Update the `oneshot` harness `implementer` role routing across all six shipped provider profiles (`providers/quad.md`, `providers/tri.md`, `providers/antigravity.md`, `providers/claude.md`, `providers/codex.md`, `providers/opencode-go.md`) and all 15 dynamically generated `--providers` combinations so that:

1. **`implementer` primary:** `antigravity` / `gemini-4-neon` (`thinking_level=high`, `google`, `ok`)
2. **`implementer` fallback:** `claudeAgent` / `claude-opus-5-5` (`effort=high`, `anthropic`, `ok`)
3. **`implementer` last-resort (terminal):** `codex` / `gpt-6.2-sol` (`reasoningEffort=high`, `openai`, `ok`)
4. **`implementer-deep`:** Remains unchanged (`claudeAgent/claude-fable-5-2` at `effort=high` $\rightarrow$ `codex/gpt-6.2-sol` at `reasoningEffort=high` $\rightarrow$ terminal `antigravity/gemini-4-argon` at `thinking_level=high`).
5. **Council composition:** Remains unchanged (`reviewer-a` Captain `claudeAgent/claude-opus-5-5` at `effort=xhigh`, `reviewer-b` `codex/gpt-6.2-sol` at `reasoningEffort=xhigh`, `reviewer-c` `antigravity/gemini-4-argon` at `thinking_level=high`).

## 2. Approaches & Trade-Offs

### Approach A (Recommended): Direct Canonical Policy Update Across `providers/*.md` + Derived `--providers` Inheritance
Update the `implementer` 3-rung ladder and load-split prose identically across all six shipped profiles (`providers/*.md`), leaving `install.sh` unchanged so `generate_dynamic_profile` (`sed '1d' "$SRC/providers/quad.md"`) propagates the policy to all 15 `--providers` combinations automatically, then synchronize documentation, `docs/assets/architecture.svg`, and policy/routing test assertions.
- **Pros:** Zero installer script churn; preserves custom `--profile-file` neutrality; automatically reuses existing `antigravity-gemini` (`gemini-*`), `claude-code` (`*`), and `codex` (`*`) quota pools with 3-rung pool independence.
- **Cons:** Requires keeping lines `2..102` synchronized across all six `providers/*.md` files (guarded by `test/all-profile-policy.sh` and `test/claude-provider-routing.sh`).

### Approach B: Add a Separate `antigravity-neon` Quota Pool Above `antigravity-gemini`
Apply Approach A plus prepend `| antigravity-neon | antigravity | gemini-4-neon* | 5h | - | - |` in `## Quota pools`.
- **Pros:** Isolates `gemini-4-neon` 429 ledger entries from other Antigravity Gemini models.
- **Cons:** Counterproductive when Antigravity Gemini models share a rolling quota bucket, and departs from the existing `antigravity-gemini` (`gemini-*`) pool structure.

### Approach C: Hardcode Shipped `implementer` Model IDs Inside `install.sh`
Enforce `gemini-4-neon` inside `validate_profile` in `install.sh`.
- **Pros:** Rejects profiles with non-Neon `implementer` primaries at install time.
- **Cons:** Breaks user-defined `--profile-file` customization and existing negative/positive validator tests in `test/install.sh` and `test/universal-routing.sh`.

**Chosen Approach:** **Approach A**.

## 3. Architecture & Component Changes

### 3.1 Provider Profiles (`providers/{quad,tri,antigravity,claude,codex,opencode-go}.md`)
- Update `## Role distribution` (**Implementation** bullet):
  - `- **Implementation:** Antigravity Gemini 4 Neon primary at high (falling back to Claude Code Opus 5.5 at high, then terminal Codex Sol at high), and Claude Code Fable 5.2 deep at high (falling back to Codex Sol at high, then terminal Antigravity Gemini Argon at high).`
- Update `## Budget facts and provider load split`:
  - Note that Claude Code carries Opus implementation fallback, Fable deep implementation, and the review captain.
- Update the `implementer` rows in the role table:
  ```markdown
  | implementer | primary | antigravity | gemini-4-neon | thinking_level=high | google | ok |
  | implementer | fallback | claudeAgent | claude-opus-5-5 | effort=high | anthropic | ok |
  | implementer | last-resort | codex | gpt-6.2-sol | reasoningEffort=high | openai | ok |
  ```

### 3.2 Quota Pool Independence & Error Handling
- Rung 1 (`antigravity/gemini-4-neon`) resolves to pool `antigravity-gemini`.
- Rung 2 (`claudeAgent/claude-opus-5-5`) resolves to pool `claude-code`.
- Rung 3 (`codex/gpt-6.2-sol`) resolves to pool `codex` (terminal operational `last-resort`).
- All three rungs use distinct quota pools and distinct model families (`google` $\rightarrow$ `anthropic` $\rightarrow$ `openai`) at `high` effort.

### 3.3 Documentation & Architecture Diagram
- **`README.md`:** Update the `Implementation` summary bullet, add `gemini-4-neon` to Antigravity example models in `Provider Setup Overview`, and update the `Default ladders` table and accompanying note.
- **`docs/skill-model-routing.md`:** Update the `implementer` row in `Roles in every shipped policy` and the `All 12 skills` table references (`council`, `debug`, `dispatch`, `make-ci-green`, `tdd`).
- **`docs/assets/architecture.svg`:** Update the `implementer` Layer 2 cells to `antigravity / gemini-4-neon · high` $\rightarrow$ `claudeAgent / claude-opus-5-5 · high` $\rightarrow$ `codex / gpt-6.2-sol · high`.

### 3.4 Test Suite Updates
- **`test/all-profile-policy.sh`:** Assert `implementer` primary is `gemini-4-neon` on `antigravity`, fallback is `claude-opus-5-5`, and last-resort is `gpt-6.2-sol`.
- **`test/claude-provider-routing.sh`:** Assert the full `implementer` ladder (`antigravity/gemini-4-neon` at `thinking_level=high` $\rightarrow$ `claudeAgent/claude-opus-5-5` at `effort=high` $\rightarrow$ `codex/gpt-6.2-sol` at `reasoningEffort=high`).
- **`test/universal-routing.sh`:** Update the live mutation fixture guard from `| implementer | primary | claudeAgent | claude-opus-5-5 | effort=high |` to `| implementer | primary | antigravity | gemini-4-neon | thinking_level=high | google | ok |` and its self-review captain mutation test.
- **`test/install.sh`:** Update `implementer` primary/fallback/last-resort row and pool assertions in sections 77, 78, 80e, and 80f.
