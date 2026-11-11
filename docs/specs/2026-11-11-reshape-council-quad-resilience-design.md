# Reshape Council: Quad Profile Resilience & Model-Level Non-Blocking Review - Design

Status: proposed (2026-11-11).
Goal: Reshape the council and provider fallbacks:
1. In `providers/quad.md` (and related profiles where applicable), replace `mimo` and `glm` fallback rungs with `deepseek-v4.1-flash`.
2. Make `claude-sonnet-5-5` from Anthropic provider (`claudeAgent` / `antigravity`) the primary `reviewer-esc`.
3. Make `gemini-4-carbon` the first fallback for `reviewer-a` in `quad.md`.
4. Set the primary implementer to `gemini-4-argon`.
5. Update Council blocking rules in `HARNESS.md`, `AGENTS.md`, and `skills/council/SKILL.md`: The council shall not block as long as there are at least two distinct members who can review and are not the same model as the implementer (`gemini-4-argon`).

---

## 1. Problem Statement & Motivation

1. **Fallback Reliability & OpenCode Workhorses:**
   In `quad.md`, `mimo-v2.6-flash` and `glm-5.3-flash` were used across reviewer and council fallback rungs. `deepseek-v4.1-flash` is a much higher-allowance, robust open-weight model suited for fast adversarial review and surgical checks. Replacing mimo/glm fallback rungs with `deepseek-v4.1-flash` improves fallback consistency.
2. **Escalation Reviewer Authority:**
   `reviewer-esc` serves as the authoritative single reviewer after rounds 1-3 or when breaking deadlocks. Designating `claude-sonnet-5-5` (Anthropic provider) as `reviewer-esc` provides strong reasoning capabilities on escalation.
3. **Seat A Fallback:**
   `reviewer-a` is primary on Codex (`gpt-6-astra`). Setting `gemini-4-carbon` (`antigravity`, `thinking_level=high`) as its first fallback provides immediate frontier-grade reasoning if Codex hits rate limits or outages, ahead of open-weight fallbacks.
4. **Implementer Model & Council Independence:**
   With `gemini-4-argon` as the primary implementer (`google` family), strict family-level independence previously risked blocking reviews if another Google model (such as `gemini-4-carbon`) participated in review, or if Anthropic seats (`claude-opus-5-5` and `claude-sonnet-5-5`) were involved. The user rule requires: **Council shall not block if there are at least two different members who can review and are not the same model as the implementer (`gemini-4-argon`)**. Model-level independence ensures that distinct models from the same family (e.g. `gemini-4-carbon` reviewing `gemini-4-argon`, or `claude-sonnet-5-5` alongside `claude-opus-5-5`) can participate in consensus review without halting the pipeline.

---

## 2. Approaches & Trade-Offs

### Approach A: Strict Model-Level Independence with Preserved Diversity Preference (Recommended)
- **Design:** Keep the preference for cross-family review in nominal 3-seat operation, but relax hard-blocking gates: council continues whenever at least 2 distinct reviewer models are active and neither matches the author/implementer model (`gemini-4-argon`). Reviewer-esc is permitted to share a family with a council seat or author as long as its concrete model is distinct from the author model.
- **Pros:** Prevents false-positive blocks and unnecessary stops when frontier models like `gemini-4-carbon` and `claude-sonnet-5-5` are available; fully satisfies the user requirement.
- **Cons:** Requires updating wording in `HARNESS.md`, `AGENTS.md`, and `council/SKILL.md`.

### Approach B: Completely Abolish Model Families Across the Harness
- **Design:** Strip the concept of `family` entirely from all profiles and tables, matching solely on model strings.
- **Pros:** Simple string checks everywhere.
- **Cons:** Breaks existing validator invariants (`family` column in `PROVIDERS.md`), breaks dynamic profile composer checks, and discards useful diversity heuristics.

**Decision:** Proceed with **Approach A**.

---

## 3. Detailed Component Specifications

### 3.1 `providers/quad.md`
- **`implementer` & `implementer-deep`:**
  - `implementer`: primary `antigravity` / `gemini-4-argon` (`thinking_level=high`, `google`). Fallback: `claudeAgent` / `claude-sonnet-5-5`. Last-resort: `codex` / `gpt-6.1-sol`.
  - `implementer-deep`: primary `antigravity` / `gemini-4-argon` (`thinking_level=high`, `google`). Fallback: `claudeAgent` / `claude-opus-5-5`. Last-resort: `codex` / `gpt-6-astra`.
- **`reviewer-a`:**
  - Primary: `codex` / `gpt-6-astra` (`reasoningEffort=high`, `openai`).
  - Fallback (first fallback): `antigravity` / `gemini-4-carbon` (`thinking_level=high`, `google`).
  - Last-resort: `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`).
- **`reviewer-b`:**
  - Primary: `antigravity` / `claude-opus-5-5` (`thinking_level=high`, `anthropic`).
  - Fallback: `claudeAgent` / `claude-opus-5-5` (`effort=high`, `anthropic`).
  - Last-resort: `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`).
- **`reviewer-c`:**
  - Primary: `opencode` / `opencode-go/muse-spark-1.3-contributor` (`variant=xhigh`, `meta`, `trains`).
  - Fallback: `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`, `ok`).
  - Last-resort: `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=max`, `deepseek`, `ok`).
- **`reviewer-esc`:**
  - Primary: `claudeAgent` / `claude-sonnet-5-5` (`effort=high`, `anthropic`, `ok`).
  - Fallback: `antigravity` / `claude-sonnet-5-5` (`thinking_level=high`, `anthropic`, `ok`).
  - Last-resort: `opencode` / `opencode-go/deepseek-v4.1-flash` (`variant=high`, `deepseek`, `ok`).
- **`## Backup ladder`:**
  - Replace mimo and glm rows with `deepseek-v4.1-flash`.

### 3.2 Related Profiles (`providers/tri.md`, `providers/antigravity.md`)
- In `providers/tri.md`, replace mimo/glm fallbacks with `deepseek-v4.1-flash`, set `implementer` primary to `gemini-4-argon`, and align reviewer fallbacks.
- In `providers/antigravity.md`, set `implementer` primary to `gemini-4-argon`.

### 3.3 Council Rules (`HARNESS.md`, `AGENTS.md`, `skills/council/SKILL.md`)
- Update Step 0 Routing Bootstrap, Request phase Step 6, and Degraded council rules:
  - Council does not block if at least two distinct members can review and are not the same model as the author/implementer (`gemini-4-argon`).
  - Intra-family model-level independence is accepted whenever distinct models participate (e.g. Carbon reviewing Argon, or Sonnet reviewing alongside Opus).
  - Clarify that `reviewer-esc` may run on a distinct model from the author and active seats even if it shares a family.

### 3.4 Installer & Tests (`install.sh`, `test/install.sh`)
- Update `install.sh` dynamic candidate order for `reviewer-a`, `reviewer-esc`, and `implementer`.
- Update `test/install.sh` expectations for `quad` pins (`reviewer-a` opencode pin, `reviewer-b` opencode pin, `reviewer-esc` pin) and ensure all 146+ tests pass.

---

## 4. Verification & Success Criteria
1. `providers/quad.md` and related profiles correctly reflect the updated ladders.
2. `install.sh --force --prune --target all --profile quad` installs cleanly and passes `./install.sh --verify --target all`.
3. `./test/install.sh` passes 100% of test cases.
4. Git commit and PR creation, merge PR to master, and final install on flux.
