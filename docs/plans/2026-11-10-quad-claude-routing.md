# Implementation Plan: Quad Provider Profile Refactor

Date: 2026-11-10. Branch: `feat/quad-claude-routing`.
Spec: `docs/specs/2026-11-10-quad-claude-routing-design.md`.

## Task Breakdown

### Task 1: Update `providers/quad.md`
- **File:** `providers/quad.md`
- **Actions:**
  - Update model catalog references to include `claude-fable-5-2` (the T3 Code catalog ID) alongside `claude-fable-5-1`.
  - Update role distribution prose to detail Fable for Architecture & Design (`shape`, `domain-modeling`, `codebase-design`) and qualitative council review; Sonnet 5.5 for implementer fallback and task-reviewer; Opus 5.5 for deep implementation and Seat B primary; Haiku 5.5 for compaction primary and scout/patch fallback.
  - Update the table:
    - `task-reviewer` fallback: `claudeAgent` `claude-sonnet-5-5` (`effort=high`, `anthropic`).
    - `compaction` primary: `claudeAgent` `claude-haiku-5-5` (`effort=low`, `anthropic`).
  - Document the Author Independence invariant in `quad.md` prose.
  - Document separate Antigravity quota pools (`antigravity-claude` soft-capped at 6 vs. `antigravity-gemini` high allowance).
- **Commit:** `feat(providers): refine quad profile for claude code and author independence`

### Task 2: Verify and Test Quad Profile
- **File:** `test/install.sh`
- **Actions:**
  - Verify that `./test/install.sh` passes 100% with the updated `quad.md`.
  - Ensure table validation regexes, backup ladder checks, and quad installation checks succeed.
- **Commit:** `test(install): verify updated quad profile and author independence wiring`

### Task 3: Land and Reinstall Harness
- **Actions:**
  - Run `verify` checks.
  - Push branch `feat/quad-claude-routing` and open PR.
  - Run Council review on PR.
  - On merge, reinstall harness across all providers with `./install.sh --profile quad --target all`.
  - Verify all providers with `./install.sh --verify --target all`.
