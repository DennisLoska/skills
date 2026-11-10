# Implementation Plan: Quad Provider Profile Refactor

Date: 2026-11-10. Branch: `feat/quad-claude-routing`.
Spec: `docs/specs/2026-11-10-quad-claude-routing-design.md`.

## Task Breakdown

### Task 1: Update `providers/quad.md`
- **File:** `providers/quad.md`
- **Actions:**
  - Update model catalog references to include `claude-fable-5-2` (T3 Code catalog ID) alongside `claude-fable-5-1`.
  - Update role distribution prose: Fable for advisory Architecture & Design; Sonnet 5.5 for implementer fallback and cross-family task-reviewer; Opus 5.5 for deep implementation and Seat B primary; Haiku 5.5 for compaction primary.
  - Purge expensive OpenCode models (`kimi-k3.1-pro`, `qwen3.8-max`, `deepseek-v4-pro`, `mimo-v2.6-pro`).
  - Wire Seat C primary to `opencode-go/muse-spark-1.3-contributor` (`variant=xhigh`, `meta`, `trains`, ~90k req/5h).
  - Wire `reviewer-esc` to high-volume OpenCode flash rungs: `mimo-v2.6-flash`, `glm-5.3-flash`, `deepseek-v4.1-flash`.
  - Update the table:
    - `task-reviewer` fallback: `claudeAgent` `claude-sonnet-5-5` (`effort=high`, `anthropic`).
    - `compaction` primary: `claudeAgent` `claude-haiku-5-5` (`effort=low`, `anthropic`).
    - `reviewer-c`: `opencode-go/muse-spark-1.3-contributor` -> `opencode-go/mimo-v2.6-flash` -> `opencode-go/glm-5.3-flash`.
    - `reviewer-esc`: `opencode-go/mimo-v2.6-flash` -> `opencode-go/glm-5.3-flash` -> `opencode-go/deepseek-v4.1-flash`.
  - Document Author Independence in `quad.md` prose.
  - Document separate Antigravity quota pools (`antigravity-claude` soft cap 6/run, 5h cooldown vs. `antigravity-gemini`).
- **Commit:** `feat(providers): refine quad profile for claude code and author independence`

### Task 2: Verify and Test Quad Profile
- **File:** `test/install.sh`, `README.md`
- **Actions:**
  - Assert that `quad.md` contains no expensive `kimi` or `qwen3.8-max` models.
  - Assert that `quad` pins `reviewer-c` to `opencode-go/muse-spark-1.3-contributor#xhigh` and `reviewer-esc` to `opencode-go/mimo-v2.6-flash`.
  - Assert that `task-reviewer` fallback is wired to `claudeAgent` `claude-sonnet-5-5`.
  - Update `README.md` quad summary table to reflect all seats.
  - Verify all 123+ tests in `./test/install.sh` pass.
- **Commit:** `test(install): verify updated quad profile and author independence wiring`

### Task 3: Land and Reinstall Harness
- **Actions:**
  - Push branch updates to PR #10.
  - Council round 2 re-review.
  - Merge PR on consensus.
  - Reinstall harness across all providers with `./install.sh --profile quad --target all`.
  - Verify all providers with `./install.sh --verify --target all`.
