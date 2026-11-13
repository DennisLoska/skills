# Gemini 4 Hydrogen Integration & Architecture Diagram Refresh - Design

Status: pending approval (2026-11-13).
Goal: Promote Google's newly released `gemini-4-hydrogen` to Council Seat C (`reviewer-c` primary) and `implementer-deep` fallback across all provider constellations, promote `gemini-4-carbon` into every slot previously held by `gemini-4-argon`, and refresh `docs/assets/architecture.svg` and `README.md` to reflect the updated architecture and routing tables.

---

## 1. Problem Statement & Motivation

1. **Google Frontier Upgrade (`gemini-4-hydrogen`)**:
   - Google released `gemini-4-hydrogen` on the `antigravity` provider (`thinking_level` `low|medium|high`, `google` family).
   - Council Seat C (`reviewer-c` primary) and the deep implementation fallback (`implementer-deep` fallback) require the highest-reasoning Google frontier model (`gemini-4-hydrogen` at `thinking_level=high`).
2. **Tier Shift (`gemini-4-argon` -> `gemini-4-carbon`)**:
   - With `gemini-4-hydrogen` taking the top Google reasoning slots (`reviewer-c` primary and `implementer-deep` fallback), `gemini-4-carbon` steps into all slots previously occupied by `gemini-4-argon` (`reviewer-a` last-resort, `reviewer-b` fallback, `## Single-provider review` secondary Google row, and `antigravity` profile/generator fallbacks for `scout`, `tester`, `patch`, and `## Backup ladder`).
   - Standard `implementer` fallback remains on `gemini-4-carbon` (`thinking_level=high`).
3. **Architecture Visual & Documentation Drift (`docs/assets/architecture.svg`, `README.md`)**:
   - `docs/assets/architecture.svg` (rendered at the top of `## 🧭 Cybernetic Architecture` in `README.md`) still lists `antigravity / gemini-4-argon · high` on `reviewer-a ★` and `gemini-4-carbon · argon (high)` in the Antigravity provider card, and omits `impl-deep` and `reviewer-c` from the Layer 2 profile table.
   - `README.md` prose, provider catalog table, default ladders table, and override example still reference `gemini-4-carbon` as Seat C / `implementer-deep` fallback and `gemini-4-argon` as council fallback.

---

## 2. Approaches Considered

1. **Approach A — Full Constellation + Generator + SVG Layer 2/3 Refresh (Recommended)**:
   - Update all 6 shipped profiles (`providers/{quad,tri,antigravity,codex,claude,opencode-go}.md`), the dynamic `--providers` generator in `install.sh`, `docs/assets/architecture.svg` (expanding Layer 2 to show `implementer`, `impl-deep`, `tester`, `reviewer-a ★`, and `reviewer-c`, and updating Layer 3's Antigravity card to `gemini-4-hydrogen · carbon (high)`), `README.md`, and `test/install.sh`.
   - *Pros*: Every static profile, dynamic `--providers` composition, visual diagram row, and test assertion stays 100% consistent.
   - *Cons*: Slightly more SVG coordinate adjustments in Layer 2 (5 sample rows instead of 3).
2. **Approach B — Minimal Text-Only Swap in SVG (3 Rows Only)**:
   - Same profile and `install.sh` changes, but only edit the 2 existing text strings in `docs/assets/architecture.svg` (`reviewer-a ★` last-resort and the Antigravity provider box) without adding `impl-deep` or `reviewer-c` rows to Layer 2.
   - *Pros*: Fewer line changes in `docs/assets/architecture.svg`.
   - *Cons*: The Layer 2 table in the architecture screenshot wouldn't directly display `impl-deep` or `reviewer-c` routing to `gemini-4-hydrogen`.
3. **Approach C — Static Profiles Only (Skip Dynamic Generator)**:
   - Update `providers/*.md`, `docs/assets/architecture.svg`, and `README.md`, leaving `install.sh` `--providers` composition unchanged.
   - *Pros*: Smaller diff.
   - *Cons*: Violates parity between shipped profiles and `--providers` dynamic compositions verified by `test/install.sh`.

**Chosen Approach**: **Approach A** — keeps static profiles, dynamic `--providers` compositions, `test/install.sh` invariants, `README.md`, and `docs/assets/architecture.svg` completely aligned.

---

## 3. Architecture & Design

### 3.1 Provider Profiles (`providers/{quad,tri,antigravity,codex,claude,opencode-go}.md`)

1. **Shared Implementation & Council Ladders (all 6 profiles)**:
   - `implementer` `fallback`: remains `antigravity | gemini-4-carbon | thinking_level=high | google | ok`.
   - `implementer-deep` `fallback`: `antigravity | gemini-4-carbon | thinking_level=high | google | ok` -> `antigravity | gemini-4-hydrogen | thinking_level=high | google | ok`.
   - `reviewer-a` `last-resort`: `antigravity | gemini-4-argon | thinking_level=high | google | ok` -> `antigravity | gemini-4-carbon | thinking_level=high | google | ok`.
   - `reviewer-b` `fallback`: `antigravity | gemini-4-argon | thinking_level=high | google | ok` -> `antigravity | gemini-4-carbon | thinking_level=high | google | ok`.
   - `reviewer-c` `primary`: `antigravity | gemini-4-carbon | thinking_level=high | google | ok` -> `antigravity | gemini-4-hydrogen | thinking_level=high | google | ok`.
2. **`## Single-provider review` Antigravity Rows (all 6 profiles)**:
   - Replace the three `antigravity` rows (`gemini-4-carbon`, `claude-opus-5-5`, `gemini-4-argon`) with:
     - `| antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |`
     - `| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |`
     - `| antigravity | gemini-4-carbon | thinking_level=high | google | ok |`
3. **Antigravity Single-Subscription Profile (`providers/antigravity.md`)**:
   - `driver` `primary`: remains `gemini-4-carbon` (`thinking_level=high`).
   - `scout` `fallback`: `gemini-4-argon` (`thinking_level=low`) -> `gemini-4-carbon` (`thinking_level=low`).
   - `tester` `fallback`: `gemini-4-argon` (`thinking_level=medium`) -> `gemini-4-carbon` (`thinking_level=medium`).
   - `patch` `fallback`: `gemini-4-argon` (`thinking_level=medium`) -> `gemini-4-carbon` (`thinking_level=medium`).
   - `task-reviewer` `last-resort`: remains `gemini-4-carbon` (`thinking_level=high`).
   - `## Backup ladder` order `1` (`implementer,implementer-deep`): `gemini-4-argon` (`thinking_level=high`) -> `gemini-4-carbon` (`thinking_level=high`).
   - Prose in `## Role distribution` and `## Runtime behavior and privacy` updated to match.
4. **Prose in `providers/{quad,tri,codex,claude,opencode-go}.md`**:
   - Update `## Role distribution` bullets to state `implementer-deep` falls back to `gemini-4-hydrogen` (while `implementer` falls back to `gemini-4-carbon`) and Council Seat C runs on `gemini-4-hydrogen`.

---

### 3.2 Dynamic Profile Generator (`install.sh`)

1. **Header Prose (`install.sh:1487`)**:
   - Update Seat C description from `gemini-4-carbon` to `gemini-4-hydrogen`.
2. **Role Candidate Lists (`install.sh:1620-1721`)**:
   - `driver`: keep `add_cand("antigravity", "gemini-4-carbon", "thinking_level=high", "google", "ok")`; remove the redundant `gemini-4-argon` line on the same `antigravity-gemini` pool.
   - `scout`: replace `gemini-4-argon` (`thinking_level=low`) with `gemini-4-carbon` (`thinking_level=low`).
   - `implementer`: keep `gemini-4-carbon` (`thinking_level=high`); remove the redundant `gemini-4-argon` line on the same `antigravity-gemini` pool.
   - `implementer-deep`: replace `gemini-4-carbon` (`thinking_level=high`) at line 1668 with `gemini-4-hydrogen` (`thinking_level=high`), and replace `gemini-4-argon` (`thinking_level=high`) at line 1671 with `gemini-4-carbon` (`thinking_level=high`).
   - `tester`: replace `gemini-4-argon` (`thinking_level=medium`) with `gemini-4-carbon` (`thinking_level=medium`).
   - `patch`: replace `gemini-4-argon` (`thinking_level=medium`) with `gemini-4-carbon` (`thinking_level=medium`).
   - `task-reviewer`: keep `gemini-4-carbon` (`thinking_level=high`); remove the redundant `gemini-4-argon` line on the same `antigravity-gemini` pool.
3. **Council Seat Assignment & Fallbacks (`install.sh:1723-1745`)**:
   - `pc = (has_agy ? "antigravity:gemini-4-hydrogen" : "")`.
   - In `pick_primary` lists for `pa`, `pb`, `pc` (lines 1736–1738): replace `antigravity:gemini-4-argon` with `antigravity:gemini-4-carbon`.
   - In `emit_seat` fallback lists (lines 1743–1745):
     - `reviewer-a`: replace `antigravity:gemini-4-argon` with `antigravity:gemini-4-carbon` and `antigravity:gemini-4-carbon` with `antigravity:gemini-4-hydrogen`.
     - `reviewer-b`: replace `antigravity:gemini-4-argon` with `antigravity:gemini-4-carbon`.
     - `reviewer-c`: replace `antigravity:gemini-4-argon` with `antigravity:gemini-4-carbon`.
4. **Generated `## Single-provider review` (`install.sh:1827-1831`)**:
   - Emit `gemini-4-hydrogen`, `claude-opus-5-5`, and `gemini-4-carbon` for `antigravity`.

---

### 3.3 Architecture Diagram (`docs/assets/architecture.svg`) & `README.md`

1. **`docs/assets/architecture.svg`**:
   - **Layer 2 (`2 · PROVIDER PROFILE`)**: display 5 representative role ladders (`implementer`, `impl-deep`, `tester`, `reviewer-a ★`, `reviewer-c`) with clean vertical spacing:
     - `implementer`: `antigravity / claude-opus-5-5 · high` | `antigravity / gemini-4-carbon · high` | `codex / gpt-6.1-sol · high`
     - `impl-deep`: `claudeAgent / claude-fable-5-2 · high` | `antigravity / gemini-4-hydrogen · high` | `codex / gpt-6.1-sol · high`
     - `tester`: `opencode / deepseek-v4.1-flash · high` | `codex / gpt-6-luna · medium` | `antigravity / gemini-3.8-flash · medium`
     - `reviewer-a ★`: `claudeAgent / claude-fable-5-2 · high` | `codex / gpt-6.1-terra · high` | `antigravity / gemini-4-carbon · high`
     - `reviewer-c`: `antigravity / gemini-4-hydrogen · high` | `antigravity / claude-sonnet-5-5 · high` | `codex / gpt-6.1-terra · high`
   - **Layer 3 (`3 · PROVIDER INSTANCES` -> `Antigravity` box)**:
     - Update model line from `gemini-4-carbon · argon (high)` to `gemini-4-hydrogen · carbon (high)`.
2. **`README.md`**:
   - Lines 294, 297, 308: update `tri`/`quad` workload split and council Seat C prose (`gemini-4-hydrogen` for Council Seat C and `implementer-deep` fallback; `gemini-4-carbon` for `implementer` fallback).
   - Line 356 (`Provider Setup Overview`): list `gemini-4-hydrogen`, `gemini-4-carbon`, `gemini-3.8-flash`, `claude-opus-5-5`, `claude-sonnet-5-5` for Antigravity.
   - Lines 402–406 (`Default ladders (all profiles)`): update `implementer-deep` fallback to `gemini-4-hydrogen`, `reviewer-a` last-resort to `gemini-4-carbon`, `reviewer-b` fallback to `gemini-4-carbon`, and `reviewer-c` primary to `gemini-4-hydrogen`.
   - Lines 425–430 (`One-row override example`): update example swapping `reviewer-c` primary to `gemini-4-carbon`.

---

### 3.4 Contract & Integration Tests (`test/install.sh`)

1. **`--providers` Seat C Assertions (`test/install.sh:2468, 2672`)**:
   - Assert `reviewer-c` primary is `antigravity gemini-4-hydrogen` (`gemini-4-hydrogen`).
2. **Test 80e Council & Implementer Invariants (`test/install.sh:2941-3017`)**:
   - Line 2994: assert `seat_cell "$md" reviewer-c 5` is `gemini-4-hydrogen` when `has_agy=1`.
   - Lines 3001–3015 (`spec_row` loop across all 6 shipped profiles):
     - `implementer|fallback|antigravity|gemini-4-carbon|thinking_level=high|google|ok`
     - `implementer-deep|fallback|antigravity|gemini-4-hydrogen|thinking_level=high|google|ok`
     - `reviewer-a|last-resort|antigravity|gemini-4-carbon|thinking_level=high|google|ok`
     - `reviewer-b|fallback|antigravity|gemini-4-carbon|thinking_level=high|google|ok`
     - `reviewer-c|primary|antigravity|gemini-4-hydrogen|thinking_level=high|google|ok`

---

## 4. Invariants & Acceptance Criteria

1. **Provider-Neutral Harness Core**: Zero hardcoded model IDs in `skills/`, `AGENTS.md`, or `agents/*.md`.
2. **No Remaining `gemini-4-argon` in Live Profiles or Generator**: `providers/*.md`, `install.sh`, `README.md`, and `docs/assets/architecture.svg` contain zero `gemini-4-argon` references.
3. **Test Suite Green**: `./test/install.sh` passes 100% of assertions.
4. **Live Reinstall & Verification**: `./install.sh --force --target all` and `./install.sh --verify --target all` succeed with zero errors.
