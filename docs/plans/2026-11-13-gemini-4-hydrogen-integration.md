# Gemini 4 Hydrogen Integration & Architecture Diagram Refresh Implementation Plan

> **For agentic workers:** REQUIRED SKILL: invoke the dispatch skill via the skill tool to implement this plan task-by-task. Execution is subagent-driven only: never execute inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote `gemini-4-hydrogen` (`provider: antigravity`, `family: google`, `thinking_level=high`) to Council Seat C (`reviewer-c` primary) and `implementer-deep` fallback across all 6 provider profiles and the `install.sh` dynamic generator, replace every `gemini-4-argon` slot with `gemini-4-carbon`, and refresh `docs/assets/architecture.svg` and `README.md`.

**Architecture:** Update all six static profiles (`providers/{quad,tri,antigravity,codex,claude,opencode-go}.md`), the dynamic `--providers` generator in `install.sh`, and contract assertions in `test/install.sh` in Task 1 (mechanical constellation table update verified with red-green test runs). Update `docs/assets/architecture.svg` (Layer 2 sample rows + Layer 3 Antigravity card) and `README.md` tables/prose in Task 2. Keep zero hardcoded model IDs in `AGENTS.md`, `skills/`, and `agents/*.md`.

**Tech Stack:** POSIX shell, Bash, Awk, SVG, Markdown.

---

### Task 1: Update Provider Profiles, Dynamic Generator (`install.sh`), and Contract Assertions (`test/install.sh`)

*Mechanical constellation/routing-table update task (`implementer` executes the red assertion update, verifies the red failure, updates `install.sh` and `providers/*.md`, verifies green tests, and commits together).*

**Files:**
- Modify: `test/install.sh:2468,2665-2672,2941-2944,2993-3015`
- Modify: `install.sh:1487,1623-1745,1828-1830`
- Modify: `providers/quad.md:18-20,38-42,52-60,96-107`
- Modify: `providers/tri.md:8-10,34-36,46-51,61-69,101-112`
- Modify: `providers/antigravity.md:7-45,58-75,80`
- Modify: `providers/codex.md:10-12,21-26,36-44,66-74`
- Modify: `providers/claude.md:10-12,21-26,36-44,67-75`
- Modify: `providers/opencode-go.md:5-10,14-19,32-40,66-77`

- [ ] **Step 1: Update contract assertions in `test/install.sh` (Red step)**

Update `test/install.sh` at lines `2468`, `2665-2672`, and `2941-3015`:

```bash
# Line 2468:
    *antigravity*) [ "$(prov_reviewer_c_row "$prov_md" primary)" = "antigravity gemini-4-hydrogen" ] || fail "--providers $prov_combo puts Seat C primary on gemini-4-hydrogen" ;;

# Lines 2664-2672:
# Under --providers antigravity,claude the captain takes Fable on claudeAgent,
# Seat C takes gemini-4-hydrogen, and Seat B takes the remaining distinct family.
prov_test_home="$TMPROOT/prov-dual-home"
HOME="$prov_test_home" "$INSTALL" --providers antigravity,claude >/dev/null 2>&1
dual_md="$prov_test_home/.config/opencode/PROVIDERS.md"
[ "$(seat_cell "$dual_md" reviewer-a 5)" = "claude-fable-5-2" ] || fail "--providers antigravity,claude seat A (captain) primary is claude-fable-5-2"
[ "$(seat_cell "$dual_md" reviewer-a 4)" = "claudeAgent" ] || fail "--providers antigravity,claude seat A runs on claudeAgent"
[ "$(seat_cell "$dual_md" reviewer-b 7)" = "google" ] || fail "--providers antigravity,claude seat B primary family differs from seat A"
[ "$(seat_cell "$dual_md" reviewer-c 5)" = "gemini-4-hydrogen" ] || fail "--providers antigravity,claude seat C primary is gemini-4-hydrogen"

# Lines 2993-2995:
  if [ "$has_agy" -eq 1 ]; then
    [ "$(seat_cell "$md" reviewer-c 5)" = "gemini-4-hydrogen" ] || fail "80e: $label reviewer-c primary is gemini-4-hydrogen"
  fi

# Lines 3001-3015:
  for spec_row in \
    'implementer|fallback|antigravity|gemini-4-carbon|thinking_level=high|google|ok' \
    'implementer|last-resort|codex|gpt-6.1-sol|reasoningEffort=high|openai|ok' \
    'implementer-deep|primary|claudeAgent|claude-fable-5-2|effort=high|anthropic|ok' \
    'implementer-deep|fallback|antigravity|gemini-4-hydrogen|thinking_level=high|google|ok' \
    'implementer-deep|last-resort|codex|gpt-6.1-sol|reasoningEffort=high|openai|ok' \
    'reviewer-a|primary|claudeAgent|claude-fable-5-2|effort=high|anthropic|ok' \
    'reviewer-a|fallback|codex|gpt-6.1-terra|reasoningEffort=high|openai|ok' \
    'reviewer-a|last-resort|antigravity|gemini-4-carbon|thinking_level=high|google|ok' \
    'reviewer-b|primary|codex|gpt-6-astra|reasoningEffort=high|openai|ok' \
    'reviewer-b|fallback|antigravity|gemini-4-carbon|thinking_level=high|google|ok' \
    'reviewer-b|last-resort|claudeAgent|claude-sonnet-5-5|effort=high|anthropic|ok' \
    'reviewer-c|primary|antigravity|gemini-4-hydrogen|thinking_level=high|google|ok' \
    'reviewer-c|fallback|antigravity|claude-sonnet-5-5|thinking_level=high|anthropic|ok' \
    'reviewer-c|last-resort|codex|gpt-6.1-terra|reasoningEffort=high|openai|ok'; do
```

- [ ] **Step 2: Run `./test/install.sh` to confirm it fails on the updated assertions**

Run: `./test/install.sh`
Expected: FAIL on `--providers antigravity,codex,opencode puts Seat C primary on gemini-4-hydrogen` / `80e: providers/quad.md reviewer-c primary is gemini-4-hydrogen`.

- [ ] **Step 3: Update dynamic profile generator in `install.sh`**

In `install.sh`:
1. Line 1487: change `Seat C \`gemini-4-carbon\`` to `Seat C \`gemini-4-hydrogen\``.
2. Line 1624 (`driver`): remove the redundant `add_cand("antigravity", "gemini-4-argon", "thinking_level=high", "google", "ok")` line (since `gemini-4-carbon` is immediately above at line 1623 on the same `antigravity-gemini` pool).
3. Line 1645 (`scout`): change `gemini-4-argon` to `gemini-4-carbon`:
   `add_cand("antigravity", "gemini-4-carbon", "thinking_level=low", "google", "ok")`
4. Line 1659 (`implementer`): remove the redundant `add_cand("antigravity", "gemini-4-argon", "thinking_level=high", "google", "ok")` line (since `gemini-4-carbon` is at line 1655 on the same `antigravity-gemini` pool).
5. Lines 1664–1671 (`implementer-deep`): update comment and candidates so `gemini-4-hydrogen` is at line 1668 and `gemini-4-carbon` replaces `gemini-4-argon` at line 1671:
   ```awk
      # implementer-deep (3 rungs): Fable 5.2 high on Claude Code (Opus 5.5 on
      # Antigravity without Claude Code), then gemini-4-hydrogen and gpt-6.1-sol.
      add_cand("claudeAgent", "claude-fable-5-2", "effort=high", "anthropic", "ok")
      if (!has_cld) add_cand("antigravity", "claude-opus-5-5", "thinking_level=high", "anthropic", "ok")
      add_cand("antigravity", "gemini-4-hydrogen", "thinking_level=high", "google", "ok")
      add_cand("codex", "gpt-6.1-sol", "reasoningEffort=high", "openai", "ok")
      add_cand("codex", "gpt-6-astra", "reasoningEffort=high", "openai", "ok")
      add_cand("antigravity", "gemini-4-carbon", "thinking_level=high", "google", "ok")
   ```
6. Line 1687 (`tester`): change `gemini-4-argon` to `gemini-4-carbon`:
   `add_cand("antigravity", "gemini-4-carbon", "thinking_level=medium", "google", "ok")`
7. Line 1702 (`patch`): change `gemini-4-argon` to `gemini-4-carbon`:
   `add_cand("antigravity", "gemini-4-carbon", "thinking_level=medium", "google", "ok")`
8. Line 1718 (`task-reviewer`): remove the redundant `add_cand("antigravity", "gemini-4-argon", "thinking_level=high", "google", "ok")` line (since `gemini-4-carbon` is immediately above at line 1717).
9. Lines 1723–1745 (`Council`):
   ```awk
      # Council: Seat A (captain) takes claude-fable-5-2, Seat B gpt-6-astra and
      # Seat C gemini-4-hydrogen whenever their provider is selected. A seat
      # whose spec model is missing takes a family no other seat holds when
      # possible, else a model no other seat holds; fallbacks avoid every seat
      # primary model and reuse no quota pool within a seat.
      split("", seat_fam_taken)
      split("", seat_model_taken)
      pa = (has_cld ? "claudeAgent:claude-fable-5-2" : "")
      pb = (has_cdx ? "codex:gpt-6-astra" : "")
      pc = (has_agy ? "antigravity:gemini-4-hydrogen" : "")
      if (pa != "") take_seat(pa)
      if (pb != "") take_seat(pb)
      if (pc != "") take_seat(pc)
      if (pa == "") { pa = pick_primary("antigravity:claude-opus-5-5 claudeAgent:claude-opus-5-5 codex:gpt-6.1-terra antigravity:gemini-4-carbon codex:gpt-6.1-sol opencode:opencode-go/deepseek-v4.1-flash opencode:opencode-go/glm-5.3-flash opencode:opencode-go/muse-spark-1.3-contributor"); take_seat(pa) }
      if (pb == "") { pb = pick_primary("codex:gpt-6.1-terra antigravity:gemini-4-carbon claudeAgent:claude-sonnet-5-5 antigravity:claude-sonnet-5-5 codex:gpt-6.1-sol claudeAgent:claude-opus-5-5 opencode:opencode-go/glm-5.3-flash opencode:opencode-go/deepseek-v4.1-flash opencode:opencode-go/muse-spark-1.3-contributor"); take_seat(pb) }
      if (pc == "") { pc = pick_primary("antigravity:gemini-4-carbon antigravity:claude-sonnet-5-5 codex:gpt-6.1-terra codex:gpt-6.1-sol claudeAgent:claude-opus-5-5 claudeAgent:claude-sonnet-5-5 opencode:opencode-go/muse-spark-1.3-contributor opencode:opencode-go/deepseek-v4.1-flash opencode:opencode-go/glm-5.3-flash"); take_seat(pc) }
      split("", seat_primary_model)
      seat_primary_model[substr(pa, index(pa, ":") + 1)] = 1
      seat_primary_model[substr(pb, index(pb, ":") + 1)] = 1
      seat_primary_model[substr(pc, index(pc, ":") + 1)] = 1
      emit_seat("reviewer-a", pa, "codex:gpt-6.1-terra antigravity:gemini-4-carbon claudeAgent:claude-sonnet-5-5 antigravity:claude-sonnet-5-5 codex:gpt-6.1-sol antigravity:gemini-4-hydrogen claudeAgent:claude-opus-5-5 opencode:opencode-go/glm-5.3-flash opencode:opencode-go/deepseek-v4.1-flash")
      emit_seat("reviewer-b", pb, "antigravity:gemini-4-carbon claudeAgent:claude-sonnet-5-5 codex:gpt-6.1-terra antigravity:claude-sonnet-5-5 codex:gpt-6.1-sol claudeAgent:claude-opus-5-5 opencode:opencode-go/deepseek-v4.1-flash opencode:opencode-go/glm-5.3-flash")
      emit_seat("reviewer-c", pc, "antigravity:claude-sonnet-5-5 codex:gpt-6.1-terra claudeAgent:claude-sonnet-5-5 antigravity:gemini-4-carbon codex:gpt-6.1-sol claudeAgent:claude-opus-5-5 opencode:opencode-go/deepseek-v4.1-flash opencode:opencode-go/glm-5.3-flash")
   ```
10. Lines 1827–1831 (`## Single-provider review` for `antigravity`):
   ```bash
  if [ "$has_agy" -eq 1 ]; then
    printf '| antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |\n'
    printf '| antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |\n'
    printf '| antigravity | gemini-4-carbon | thinking_level=high | google | ok |\n'
  fi
   ```

- [ ] **Step 4: Update all 6 static provider profiles (`providers/{quad,tri,antigravity,codex,claude,opencode-go}.md`)**

Across all 6 files (`providers/quad.md`, `providers/tri.md`, `providers/antigravity.md`, `providers/codex.md`, `providers/claude.md`, `providers/opencode-go.md`):
1. In the main role table:
   - `| implementer-deep | fallback | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |` (keeping `implementer | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |`)
   - `| reviewer-a | last-resort | antigravity | gemini-4-carbon | thinking_level=high | google | ok |`
   - `| reviewer-b | fallback | antigravity | gemini-4-carbon | thinking_level=high | google | ok |`
   - `| reviewer-c | primary | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |`
2. In `## Single-provider review`:
   - Replace the `antigravity` `gemini-4-carbon` and `gemini-4-argon` rows with `gemini-4-hydrogen` and `gemini-4-carbon`:
     ```markdown
     | antigravity | gemini-4-hydrogen | thinking_level=high | google | ok |
     | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
     | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
     ```
3. In `providers/antigravity.md` additionally:
   - `| scout | fallback | antigravity | gemini-4-carbon | thinking_level=low | google | ok |`
   - `| tester | fallback | antigravity | gemini-4-carbon | thinking_level=medium | google | ok |`
   - `| patch | fallback | antigravity | gemini-4-carbon | thinking_level=medium | google | ok |`
   - `## Backup ladder` row 1: `| 1 | implementer,implementer-deep | antigravity | gemini-4-carbon | thinking_level=high | google | ok |`
   - Update prose at lines 8–12 and 80 (`gemini-4-argon` -> `gemini-4-carbon`; `implementer-deep` demotes to `gemini-4-hydrogen`; Seat C `gemini-4-hydrogen`; single-provider review across `gemini-4-hydrogen`, `claude-opus-5-5`, and `gemini-4-carbon`).
4. In `providers/{quad,tri,codex,claude,opencode-go}.md` prose:
   - Update `## Role distribution` bullets so `implementer-deep` fallback names `gemini-4-hydrogen` and Council Seat C names `gemini-4-hydrogen`.

- [ ] **Step 5: Run `./test/install.sh` and reinstall/verify live targets**

Run:
```bash
./test/install.sh
./install.sh --force --target all
./install.sh --verify --target all
```
Expected: `all install tests passed (154 passed, 0 failed)` and `--verify` exits 0 with zero `[FAIL]` lines.

- [ ] **Step 6: Commit Task 1**

Run:
```bash
git add install.sh providers/quad.md providers/tri.md providers/antigravity.md providers/codex.md providers/claude.md providers/opencode-go.md test/install.sh
git commit -m "feat(providers): promote gemini-4-hydrogen to Seat C and deep implementer fallback, replace argon with carbon"
```

---

### Task 2: Refresh Architecture Diagram (`docs/assets/architecture.svg`) and `README.md`

*Mechanical SVG and documentation update task (`implementer` updates `docs/assets/architecture.svg` and `README.md`, verifies no `gemini-4-argon` references remain in live docs/profiles/generator, runs `./test/install.sh`, and commits).*

**Files:**
- Modify: `docs/assets/architecture.svg:100-172`
- Modify: `README.md:294,297,308,356,402-406,425-430`

- [ ] **Step 1: Update `docs/assets/architecture.svg` Layer 2 and Layer 3**

In `docs/assets/architecture.svg`:
1. In Layer 2 (`2 · PROVIDER PROFILE`, lines 101–137), expand the sample table to 5 rows (`implementer`, `impl-deep`, `tester`, `reviewer-a ★`, `reviewer-c`) at 20px row spacing (`y="406"`, `y="426"`, `y="446"`, `y="466"`, `y="486"`) with the Layer 2 box height increased slightly (`height="208"`, `y="322"` to `y="530"`), the chips at `y="498"` (`text y="514"`), the delegate arrow from `y1="532"` to `y2="556"`, and Layer 3 at `y="560"`:
   ```xml
  <!-- ============ LAYER 2: PROFILE ============ -->
  <rect x="60" y="322" width="1260" height="208" rx="16" fill="#111C2E" stroke="#2A3B57" stroke-width="1.5"/>
  <text class="sans title" x="84" y="352">2 · PROVIDER PROFILE</text>
  <text class="sans sub" x="266" y="352">PROVIDERS.md · primary → fallback → last-resort per role · validated before install writes</text>

  <text class="sans col" x="84" y="378">ROLE</text>
  <text class="sans col" x="224" y="378">PRIMARY</text>
  <text class="sans col" x="600" y="378">FALLBACK</text>
  <text class="sans col" x="960" y="378">LAST RESORT</text>
  <line x1="84" y1="386" x2="1296" y2="386" stroke="#243450" stroke-width="1"/>

  <g class="mono">
    <text class="cell" x="84" y="406">implementer</text>
    <text class="cell" x="224" y="406">antigravity / claude-opus-5-5 · high</text>
    <text class="cellMuted" x="600" y="406">antigravity / gemini-4-carbon · high</text>
    <text class="cellMuted" x="960" y="406">codex / gpt-6.1-sol · high</text>

    <text class="cell" x="84" y="426">impl-deep</text>
    <text class="cell" x="224" y="426">claudeAgent / claude-fable-5-2 · high</text>
    <text class="cellMuted" x="600" y="426">antigravity / gemini-4-hydrogen · high</text>
    <text class="cellMuted" x="960" y="426">codex / gpt-6.1-sol · high</text>

    <text class="cell" x="84" y="446">tester</text>
    <text class="cell" x="224" y="446">opencode / deepseek-v4.1-flash · high</text>
    <text class="cellMuted" x="600" y="446">codex / gpt-6-luna · medium</text>
    <text class="cellMuted" x="960" y="446">antigravity / gemini-3.8-flash · medium</text>

    <text class="cell" x="84" y="466">reviewer-a ★</text>
    <text class="cell" x="224" y="466">claudeAgent / claude-fable-5-2 · high</text>
    <text class="cellMuted" x="600" y="466">codex / gpt-6.1-terra · high</text>
    <text class="cellMuted" x="960" y="466">antigravity / gemini-4-carbon · high</text>

    <text class="cell" x="84" y="486">reviewer-c</text>
    <text class="cell" x="224" y="486">antigravity / gemini-4-hydrogen · high</text>
    <text class="cellMuted" x="600" y="486">antigravity / claude-sonnet-5-5 · high</text>
    <text class="cellMuted" x="960" y="486">codex / gpt-6.1-terra · high</text>
  </g>

  <g>
    <rect x="84" y="496" width="120" height="24" rx="6" fill="#0F2230" stroke="#1F4A56"/>
    <text class="mono sub" x="144" y="512" text-anchor="middle">## Quota pools</text>
    <rect x="214" y="496" width="130" height="24" rx="6" fill="#0F2230" stroke="#1F4A56"/>
    <text class="mono sub" x="279" y="512" text-anchor="middle">## Backup ladder</text>
    <rect x="354" y="496" width="180" height="24" rx="6" fill="#0F2230" stroke="#1F4A56"/>
    <text class="mono sub" x="444" y="512" text-anchor="middle">state/quota-ledger.tsv</text>
  </g>
  <text class="sans sub" x="550" y="512">shared buckets + soft caps · same-model + backup safety net · single-provider review · ledger</text>

  <!-- delegate arrow -->
  <line x1="690" y1="532" x2="690" y2="556" stroke="#94A3B8" stroke-width="1.75" marker-end="url(#arrow)"/>
  <text class="sans sub" x="706" y="548">native pin on OpenCode, or T3 Code delegate_task(provider, model, effort)</text>
   ```
2. In Layer 3 (`3 · PROVIDER INSTANCES` -> `Antigravity` box, line 151):
   Change:
   `<text class="mono pmodels" x="104" y="668">gemini-4-carbon · argon (high)</text>`
   to:
   `<text class="mono pmodels" x="104" y="668">gemini-4-hydrogen · carbon (high)</text>`

- [ ] **Step 2: Update `README.md` prose, tables, and override example**

In `README.md`:
1. Line 294:
   `- **Antigravity**: \`implementer\` on Anthropic \`claude-opus-5-5\` (\`high\`), then Google \`gemini-4-carbon\`; Council Seat C (\`gemini-4-hydrogen\`); the \`implementer-deep\` fallback (\`gemini-4-hydrogen\`).`
2. Line 297:
   `- **Claude Code rungs**: the captain (\`reviewer-a\`) and \`implementer-deep\` prefer \`claude-fable-5-2\` on Claude Code; without that subscription those rungs are unreachable and demote (captain to \`gpt-6.1-terra\`, \`implementer-deep\` to \`gemini-4-hydrogen\`).`
3. Line 308:
   `- **Seat C (\`reviewer-c\`)**: Google \`gemini-4-hydrogen\` via Antigravity.`
4. Line 356 (`Provider Setup Overview`):
   `| **Antigravity** | \`antigravity\` | \`thinking_level\` (\`low\|medium\|high\`) | \`gemini-4-hydrogen\`, \`gemini-4-carbon\`, \`gemini-3.8-flash\`, \`claude-opus-5-5\`, \`claude-sonnet-5-5\` | \`/status\` in Antigravity (rolling 5-hour window) |`
5. Lines 400–406 (`Default ladders (all profiles)`):
   ```markdown
   | role | primary | fallback | last-resort |
   | --- | --- | --- | --- |
   | `implementer` | `claude-opus-5-5` (Antigravity; Claude Code in `claude`) | `gemini-4-carbon` | `gpt-6.1-sol` |
   | `implementer-deep` | `claude-fable-5-2` (Claude Code) | `gemini-4-hydrogen` | `gpt-6.1-sol` |
   | `reviewer-a` (captain) | `claude-fable-5-2` (Claude Code) | `gpt-6.1-terra` | `gemini-4-carbon` |
   | `reviewer-b` | `gpt-6-astra` (Codex) | `gemini-4-carbon` | `claude-sonnet-5-5` (Claude Code) |
   | `reviewer-c` | `gemini-4-hydrogen` (Antigravity) | `claude-sonnet-5-5` (Antigravity) | `gpt-6.1-terra` |
   ```
6. Lines 425–431 (`One-row override example`):
   ```markdown
   **One-row override example** (swapping `reviewer-c` primary to `gemini-4-carbon`):

   ```text
   | role | rung | provider | model | effort | family | privacy |
   | --- | --- | --- | --- | --- | --- | --- |
   | reviewer-c | primary | antigravity | gemini-4-carbon | thinking_level=high | google | ok |
   ```
   ```

- [ ] **Step 3: Verify SVG validity, zero `gemini-4-argon` in live files, and test suite pass**

Run:
```bash
! grep -rn 'gemini-4-argon' providers/ install.sh README.md docs/assets/architecture.svg
./test/install.sh
```
Expected: Zero matches for `gemini-4-argon` across `providers/`, `install.sh`, `README.md`, and `docs/assets/architecture.svg`, and all install tests pass.

- [ ] **Step 4: Commit Task 2**

Run:
```bash
git add docs/assets/architecture.svg README.md
git commit -m "docs(readme): update architecture diagram and ladders for gemini-4-hydrogen and carbon"
```
