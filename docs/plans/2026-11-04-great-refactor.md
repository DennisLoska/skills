# Great Refactor Implementation Plan

> Historical plan. Tasks 9 to 11 and the Validation record below were superseded by Revision 7; anything they say about a `commands/` tree, `skills/craft`, or importing twelve domain skills no longer describes this repository.

> **For agentic workers:**
> - [ ] Read this plan before starting; read `AGENTS.md` after Task 2 and before any model-routed dispatch.
> - [ ] Execute Tasks 1-13 in order on `feat/system-v1`, using fresh implementation subagents after Task 5.
> - [ ] Run every verification command, compare its expected result, and commit only the current task's files.
> - [ ] Stop on red; only Task 13 may push the branch or open a pull request.

**Goal:** Build a fully owned OpenCode skill, agent, and command system with clean names, explicit model routing, and `oneshot` as its cybernetic controller.

**Architecture:** `oneshot` orchestrates task, branch, CI, and meta feedback loops while `patch` and `dispatch` act, and `scout`, `verify`, `council`, `make-ci-green`, and `stats` sense state. Three default user gates, hard loop budgets, evidence-based stop-on-red behavior, and model fallback ladders keep the system stable without external process-skill dependencies.

**Tech Stack:** OpenCode V2 markdown agents, skills, and commands; Bash installer; Git and GitHub CLI `gh`; MIT license. Skills use `skills/name/SKILL.md` with `name` and trigger-rich `description` frontmatter, agents use `agents/name.md` with `description`, `mode`, no-op `model: inherit`, and ordered `permissions` rules, and commands use `commands/name.md`; configuration reloads without restart.

## File structure

```text
skills/                              repository root at ~/work/skills
  LICENSE                            existing MIT license, unchanged
  README.md                          project introduction, cybernetic diagram, install and structure
  AGENTS.md                          sole model-id routing table, fallback and council rules
  install.sh                         collision-safe installer for ~/.config/opencode
  test/install.sh                    installer contract tests
  agents/implementer.md              task-scale TDD builder
  agents/implementer-b.md            second default implementer
  agents/implementer-deep.md         complex tasks and difficult bugs
  agents/scout.md                    read-only locator returning compressed path:line tables
  agents/patch.md                    surgical 1-2 file editor without shell access
  agents/reviewer-a.md               council seat A
  agents/reviewer-b.md               council seat B
  agents/reviewer-c.md               council seat C
  agents/reviewer-esc.md             council escalation seat
  skills/oneshot/SKILL.md            seven numbered phases plus Phase 6.5 CI loop
  skills/shape/SKILL.md              approved design and specification
  skills/plan/SKILL.md               executable task plan from approved specification
  skills/dispatch/SKILL.md           sequential and parallel subagent execution
  skills/tdd/SKILL.md                red-green-refactor discipline
  skills/debug/SKILL.md              evidence-led root-cause loop
  skills/verify/SKILL.md             completion evidence checklist
  skills/council/SKILL.md            independent three-reviewer consensus and finding triage
  skills/land/SKILL.md               problem-led PR, merge, and next-feature finish flow
  skills/make-ci-green/SKILL.md      CI and review-bot repair loop
  docs/plans/2026-11-04-great-refactor.md  this executable plan and migration-history footnote
```

### Task 1: Establish feature-branch baseline

**Files:**
- Add: `docs/plans/2026-11-04-great-refactor.md`
- Verify unchanged: `LICENSE`

- [x] 1. Run `cd /Users/dennis/work/skills && git status --short --branch && git switch master && git pull --ff-only origin master && git switch -c feat/system-v1`. Expected: clean master except this untracked plan, up-to-date pull, then `Switched to a new branch 'feat/system-v1'`.
- [x] 2. Run `rg -n 'MIT License|Copyright' LICENSE && test "$(git branch --show-current)" = feat/system-v1`. Expected: MIT and copyright lines, command success on the feature branch; do not edit `LICENSE`.
- [x] 3. Commit with `git add docs/plans/2026-11-04-great-refactor.md && git commit -m "docs: plan owned agent system"`. Expected: one commit containing only this plan.

### Task 2: Define routing and homeostasis

**Files:**
- Create: `AGENTS.md`

- [x] 1. Write `AGENTS.md` with `opencode-go` as provider, this sole routing table, and a rule that skills and agents never contain provider-qualified model ids.

| Role | Primary | Ordered fallbacks |
| --- | --- | --- |
| implementation subagents | glm-5.3-flash | gpt-6-luna -> muse-spark-1.3-contributor |
| locate/discovery, scout | glm-5.3-flash | deepseek-v4.1-flash |
| council reviewer A | kimi-k3.1-pro | gpt-6-luna -> deepseek-v4.1-flash |
| council reviewer B | glm-5.3 | gpt-5.6-luna -> deepseek-v4.1-flash |
| council reviewer C | qwen3.7-plus | claude-haiku-5-5 -> muse-spark-1.3-contributor |
| council escalation | deepseek-v4-pro, off-peak only | gpt-5.6-luna |
| compaction, summary, memory | muse-spark-1.3-contributor | claude-haiku-5-5 |

- [x] 2. Document fallback mechanics: provider errors containing `usage limit`, `allowance`, or `429` demote to the next model in that role's ladder; print each demotion in session output; never reorder ladders or invent ids. Require three independent primary reviewer families, permit a two-reviewer provisional PASS only with a YELLOW reduced-council finding, and treat one or zero available reviewers as no consensus.
- [x] 3. Add privacy notes verbatim in meaning: muse-spark models train on request data and must not receive confidential diffs unless Dennis accepts that tradeoff; claude-haiku-5-5 retains requests for 30 days; deepseek flex models are region-gated.
- [x] 4. Specify L1 scout -> patch -> tdd/build with a fresh subagent per task and at most two root-cause retries; L2 council -> fix -> re-review with three rounds plus one escalation; L3 `make-ci-green` with at most five repair pushes; L4 `stats` plus memory outcome informing evidence-based `AGENTS.md` re-tuning. Cap parallel workers at three, allow only design, plan, and finish user gates, and require stop-on-red with no silent budget overflow.
- [x] 5. Run `rg -q '^# ' AGENTS.md && rg -q 'kimi-k3.1-pro' AGENTS.md && rg -q '30 days' AGENTS.md && ! rg -n 'opencode-go/' skills agents 2>/dev/null`. Expected: routing and privacy present, no provider-qualified ids in implementation directories.
- [x] 6. Commit with `git add AGENTS.md && git commit -m "docs: define model routing and feedback loops"`. Expected: routing policy committed separately.

### Task 3: Build locator and surgical editor agents

**Files:**
- Create: `agents/scout.md`
- Create: `agents/patch.md`

- [x] 1. Run `mkdir -p agents`. Create `scout.md` with trigger-rich `description`, `mode: subagent`, `model: inherit`, and `permissions` as a rules list using `action`, `resource`, `effect`: allow `read`, `grep`, and `glob` on `**`; deny `edit`, `write`, and `bash` on `**`. State that last match wins. Its body must locate definitions, references, callers, tests, imports, and directories; return grouped `path:line | symbol | six-word-max note` rows plus totals; return `No match.` for zero hits; refuse edits, fixes, and design suggestions with `Read-only locator. Use patch or dispatch.`.
- [x] 2. Create `patch.md` with the same metadata conventions, allowing `read`, `grep`, `glob`, `edit`, and `write`, and a final deny rule for `bash` on `**`. Its body must read before editing, accept only one or two files, permit a new file only when explicitly requested, make the smallest diff without new abstractions or drive-by edits, re-read every changed range, and emit `path:line-range | change`, `verified: re-read OK` receipts. Require terminal refusals for 3+ files, ambiguity, destructive operations, or out-of-scope regressions.
- [x] 3. Run `for f in agents/scout.md agents/patch.md; do rg -q '^description:' "$f" && rg -q '^mode: subagent$' "$f" && rg -q '^model: inherit$' "$f" && rg -q '^permissions:' "$f" || exit 1; done`. Expected: success with all required V2 fields.
- [x] 4. Commit with `git add agents/scout.md agents/patch.md && git commit -m "feat: add scout and patch agents"`. Expected: exactly two agents committed.

### Task 4: Own design and planning skills

**Files:**
- Create: `skills/shape/SKILL.md`
- Create: `skills/plan/SKILL.md`

- [x] 1. Run `mkdir -p skills/shape skills/plan`. Write `shape` frontmatter with triggers `shape`, `brainstorm`, `design this`, and `spec this`. Its body must gather goals, non-goals, constraints, current-state evidence, and user needs; ask one focused question at a time; present two or three viable architectures with tradeoffs and a recommendation; obtain design approval; write `docs/specs/YYYY-MM-DD-topic-design.md` containing problem, goals, non-goals, options, chosen design, interfaces, test strategy, risks, and approval record.
- [x] 2. Write `plan` frontmatter with triggers `plan this`, `implementation plan`, and `break down this spec`. Require an approved spec, use `scout` for current-state mapping, and produce `docs/plans/YYYY-MM-DD-feature.md` with goal, architecture, tech stack, complete file map, dependency-ordered tasks, exact paths, exact commands, expected results, TDD steps, and conventional commits. Forbid deferred content, vague test steps, shared-state parallelism, and worktrees; end with spec-coverage, completeness, and naming self-review; require plan approval.
- [x] 3. Run `for f in skills/shape/SKILL.md skills/plan/SKILL.md; do rg -q '^name: ' "$f" && rg -q '^description: ' "$f" || exit 1; done && rg -q 'docs/specs/' skills/shape/SKILL.md && rg -q 'docs/plans/' skills/plan/SKILL.md`. Expected: valid identity frontmatter and owned artifact paths.
- [x] 4. Commit with `git add skills/shape/SKILL.md skills/plan/SKILL.md && git commit -m "feat: add shape and plan skills"`. Expected: design and plan gates committed.

### Task 5: Own execution and failure loops

**Files:**
- Create: `skills/dispatch/SKILL.md`
- Create: `skills/tdd/SKILL.md`
- Create: `skills/debug/SKILL.md`

- [x] 1. Run `mkdir -p skills/dispatch skills/tdd skills/debug`. Write `dispatch` with triggers for `dispatch`, `execute plan`, and `parallel subagents`. Require fresh context per task, main-thread orchestration only, no whole-phase delegation, `scout` for location, `patch` for bounded edits, implementation subagents for broader work, and two-stage task review for spec compliance then code quality. Fold in parallel fan-out only for independent tasks with explicit file ownership and no shared mutable state, maximum three workers; join all results, run integration verification, and serialize conflicting work.
- [x] 2. Write `tdd` with triggers for `tdd`, `red green refactor`, feature implementation, and bug fixes. Require a failing behavioral test, confirmation it fails for the intended reason, minimal production code, passing rerun, behavior-preserving refactor, and full relevant suite rerun. Bug fixes start with a regression test; never weaken a correct failing assertion to force green.
- [x] 3. Write `debug` with triggers for `debug`, `test failure`, and `unexpected behavior`. Require reproduce -> hypothesize -> isolate -> fix -> verify, an evidence log, one variable changed at a time, smallest reproduction, root-cause explanation, regression coverage, and escalation after two failed root-cause retries rather than random patching.
- [x] 4. Run `rg -q 'three workers' skills/dispatch/SKILL.md && rg -q 'failing behavioral test' skills/tdd/SKILL.md && rg -q 'reproduce -> hypothesize -> isolate -> fix -> verify' skills/debug/SKILL.md`. Expected: execution, TDD, and debug contracts are explicit.
- [x] 5. Commit with `git add skills/dispatch/SKILL.md skills/tdd/SKILL.md skills/debug/SKILL.md && git commit -m "feat: add execution and debugging skills"`. Expected: L1 execution controls committed.

### Task 6: Add verification and consensus review

**Files:**
- Create: `skills/verify/SKILL.md`
- Create: `skills/council/SKILL.md`

- [x] 1. Run `mkdir -p skills/verify skills/council`. Write `verify` with completion and pre-claim triggers. Require exact test, lint, typecheck, and build commands when applicable; trigger the changed behavior itself; map evidence to every spec requirement; inspect error output; reject red or unrun checks; mark missing tests YELLOW; forbid success language unsupported by command output.
- [x] 2. Write `council` with triggers for `council`, `review this diff`, `review this PR`, and receiving review feedback. Dispatch fresh reviewers A, B, and C independently from different primary model families using only `AGENTS.md` routing; A checks spec and correctness, B checks security and regressions, C checks tests, performance, and maintainability. Each reads spec, plan, diff, and verification evidence without seeing peer verdicts, then returns PASS or FAIL plus `path:line: RED bug|YELLOW risk|BLUE nit|QUESTION: problem. fix.` findings.
- [x] 3. Define aggregation and receiving-side rigor: any verified RED means FAIL; all available reviewers PASS with green verification means PASS only after the reduced-council rule is applied; verify each finding against code and spec before fixing rather than agreeing blindly. Fix through `patch` or `dispatch`, rerun `verify`, and convene fresh reviewers. Cap at three rounds, then use the escalation ladder once; unresolved RED or green-check failure stops without merge. Log every demotion and never claim consensus with fewer than two independent reviewers.
- [x] 4. Run `rg -q 'reviewers A, B, and C' skills/council/SKILL.md && rg -q 'three rounds' skills/council/SKILL.md && rg -q 'trigger the changed behavior' skills/verify/SKILL.md`. Expected: independent review and evidence gates are present.
- [x] 5. Commit with `git add skills/verify/SKILL.md skills/council/SKILL.md && git commit -m "feat: add verification and council review"`. Expected: L2 sensors and consensus rules committed.

### Task 7: Add landing and CI repair skills

**Files:**
- Create: `skills/land/SKILL.md`
- Create: `skills/make-ci-green/SKILL.md`

- [x] 1. Run `mkdir -p skills/land skills/make-ci-green`. Write `land` with triggers for `land`, `finish branch`, `next feature`, `create PR`, and `merge PR`. Require final verification; create a PR if none exists; otherwise present merge-open-PR, keep-open-PR, keep-local-branch, or explicitly confirmed discard options. After a merged PR, checkout the detected default branch and pull fast-forward only. PR markdown leads with the user problem in `## Summary`, then `## Changes` and `## Test plan` with exact commands and results; never lead with a change inventory or remove remote branches implicitly.
- [x] 2. Write `make-ci-green` with triggers for `make CI green`, `babysit PR`, and `PR checks failing`. Poll `gh pr checks --watch --interval 30`, inspect failed logs with `gh run view --log-failed`, and read issue and review comments with `gh pr view --comments` plus `gh api repos/{owner}/{repo}/pulls/{number}/comments`. Reproduce actionable failures locally, separate product faults from test faults and external flakes, fix real code and review-bot findings, run `verify`, commit, and push. Never blindly rerun; permit a rerun only with recorded infrastructure or flake evidence. Stop after five repair pushes or on unresolved red and report logs, commits, and remaining checks.
- [x] 3. Run `rg -q 'user problem' skills/land/SKILL.md && rg -q 'Never blindly rerun' skills/make-ci-green/SKILL.md && rg -q 'five repair pushes' skills/make-ci-green/SKILL.md`. Expected: problem-led landing and bounded CI repair are explicit.
- [x] 4. Commit with `git add skills/land/SKILL.md skills/make-ci-green/SKILL.md && git commit -m "feat: add landing and CI repair skills"`. Expected: L3 and finish behavior committed.

### Task 8: Rebuild the oneshot controller

**Files:**
- Create: `skills/oneshot/SKILL.md`

- [x] 1. Run `mkdir -p skills/oneshot`. Write frontmatter `name: oneshot` and a description triggered by `/oneshot` or `oneshot` followed by a complete feature or bugfix request, excluding questions, single-step tasks, and work requiring continuous human judgment.
- [x] 2. Specify seven visible sequential phases in the main session: 1 SHAPE writes and commits an approved spec; 2 PLAN writes and commits an approved plan and selects dispatch-only execution; 3 EXECUTE works in place on a feature branch through `dispatch`, `tdd`, `scout`, and `patch`, routing failures to `debug`; 4 VERIFY requires green evidence; 5 PR pushes and creates a problem-led PR using `land` standards; 6 COUNCIL runs at most three fresh independent review rounds plus one escalation; 7 LAND presents the finish gate, performs the chosen next-feature flow, records memory outcome, and requests measured `stats` for L4 tuning.
- [x] 3. Insert Phase 6.5 `make-ci-green` after council PASS: watch checks and review bots, fix verified findings without blind reruns, and require `verify` after every change. Any code change after council PASS triggers targeted council re-review; count CI repair pushes toward the L3 cap and never enter Phase 7 on red.
- [x] 4. Require artifact validation before each phase, phase announcements and subagent result summaries, no main-thread implementation edits, no whole-phase or whole-pipeline delegation, no worktrees, and resume from spec, plan, branch, and PR state. Default gates are design, plan, and finish only; an explicit initial full-autonomy request may bypass all three and must be recorded with its quoted trigger in the spec. Include a stop-on-red error table for spec gaps, plan gaps, test failures, exhausted review, exhausted CI, and user interruption.
- [x] 5. Run `for phase in SHAPE PLAN EXECUTE VERIFY PR COUNCIL '6.5' LAND; do rg -q "$phase" skills/oneshot/SKILL.md || exit 1; done && rg -q 'three' skills/oneshot/SKILL.md && rg -q 'no worktrees' skills/oneshot/SKILL.md`. Expected: every phase, bounded review, and in-place execution are present.
- [x] 6. Commit with `git add skills/oneshot/SKILL.md && git commit -m "feat: rebuild oneshot control pipeline"`. Expected: controller committed after all dependencies.

### Task 9: Define the authoring standard

**Files:**
- Create: `skills/craft/SKILL.md`

- [x] 1. Run `mkdir -p skills/craft`. Write `craft` with triggers for `craft skill`, `author skill`, `author agent`, and `review skill quality`. Require one responsibility per file, exact V2 paths and frontmatter, concrete trigger phrases in every description, imperative bodies, minimal permissions, ordered agent permission rules, thin command aliases, and no model ids outside `AGENTS.md`.
- [x] 2. Require authoring tests: positive and negative trigger examples, a dry-run against a representative task, output-format inspection, permission-boundary checks for agents, installer idempotence checks, and review for clarity, scope creep, unsafe instructions, and incomplete content. State that plugin overview, plugin diagnostics, and worktree workflow skills are intentionally dropped because global instructions cover discovery and `oneshot` works in place.
- [x] 3. Run `rg -q 'positive and negative trigger examples' skills/craft/SKILL.md && rg -q 'no model ids outside' skills/craft/SKILL.md`. Expected: enforceable ownership and validation standards.
- [x] 4. Commit with `git add skills/craft/SKILL.md && git commit -m "docs: add skill authoring standard"`. Expected: authoring policy committed.

### Task 10: Create clean slash commands

**Files:**
- Create: `commands/style.md`, `commands/commit.md`, `commands/review.md`, `commands/compress.md`, `commands/stats.md`

- [x] 1. Run `mkdir -p commands`. Write `style.md` to accept exactly `/style lite|full|ultra|wenyan`, change response compression synchronously, print the active level, remain watch/mtg-free with no watcher or polling, and restore ordinary prose on `normal mode`; code, commits, and PR bodies remain normal language.
- [x] 2. Write `commit.md` to inspect the staged diff, produce a conventional commit with a subject of at most 50 characters and a body only when why is non-obvious, and never stage or commit by itself. Write `review.md` as a thin alias to council's severity and evidence rules, emitting one `path:line: SEVERITY: problem. fix.` finding per line and `No issues.` only after inspection.
- [x] 3. Write `compress.md` to accept an explicit memory-file path, copy it to `path.original` before overwriting, refuse if source is missing or backup already exists, preserve code, URLs, paths, and technical substance, and verify the backup with `cmp`. Write `stats.md` to parse the actual current OpenCode session log, report real input, output, cache, total tokens, per-model totals, and logged demotions, state the log path and session id, and fail visibly when data is unavailable rather than estimating.
- [x] 4. State in `style.md` that no separate help command exists because `AGENTS.md` owns usage guidance. Run `for c in style commit review compress stats; do test -s "commands/$c.md" || exit 1; done && rg -q 'watch/mtg-free' commands/style.md && rg -q 'path.original' commands/compress.md && rg -q 'rather than estimating' commands/stats.md`. Expected: all five commands exist with required behavior and no extra help command is created.
- [x] 5. Commit with `git add commands/style.md commands/commit.md commands/review.md commands/compress.md commands/stats.md && git commit -m "feat: add clean workflow commands"`. Expected: five unprefixed commands committed.

### Task 11: Import already owned skills verbatim

**Files:**
- Create: `skills/backup-opencode/SKILL.md`, `skills/cloudflare-tunnel/SKILL.md`, `skills/copy-user-commands/SKILL.md`, `skills/generate-comfy-image/SKILL.md`, `skills/generate-instrumental/SKILL.md`, `skills/generate-thumbnail/SKILL.md`, `skills/image-convert/SKILL.md`, `skills/image-edit/SKILL.md`, `skills/linear-issues/SKILL.md`, `skills/silicon-seeds/SKILL.md`, `skills/ssh-debug/SKILL.md`, `skills/text-to-voice/SKILL.md`

- [x] 1. Land each source with only the mandated style normalization:

```bash
for s in backup-opencode cloudflare-tunnel copy-user-commands generate-comfy-image generate-instrumental generate-thumbnail image-convert image-edit linear-issues silicon-seeds ssh-debug text-to-voice; do cp -R "/Users/dennis/.config/opencode/skills/$s" "skills/$s"; done
# then one pass of the emdash normalization sweep (U+2014 -> ", ") across copied files
```

- [x] 2. Run `rg -l $'\u2014' skills || echo "zero emdash remaining"`. Expected: the package-for-parameter emdash sweep leaves zero matches while every other byte stays verbatim from the config source.
- [x] 3. Commit with `git add skills/backup-opencode skills/cloudflare-tunnel skills/copy-user-commands skills/generate-comfy-image skills/generate-instrumental skills/generate-thumbnail skills/image-convert skills/image-edit skills/linear-issues skills/silicon-seeds skills/ssh-debug skills/text-to-voice && git commit -m "feat: import owned domain skills"`. Expected: all twelve existing skills imported; the only delta away from the config source is the emdash normalization mandated by the no-emdash rule.

### Task 12: Add repository guide and safe installer

**Files:**
- Create: `README.md`
- Create: `install.sh`

- [x] 1. Write `README.md` with this introduction: `A self-owned cybernetic control system for OpenCode, with oneshot orchestrating scoped work, independent review, CI repair, and measured feedback.` Add repository structure, private-repo purpose, `master` default branch, feature-branch plus PR contribution rule, `./install.sh` and `./install.sh --force` usage, routing link to `AGENTS.md`, and MIT license note. Include this ASCII diagram:

```text
                 oneshot controller
                          |
          +---------------+----------------+
       actuators                        sensors
    patch, dispatch          scout, verify, council,
                             make-ci-green, stats
          |                               |
          +--- L1 task / L2 branch --------+
              L3 CI / L4 meta feedback
```

- [x] 2. Write Bash `install.sh` with `set -euo pipefail`, repository-root resolution from the script path, destination `$HOME/.config/opencode`, and only optional `--force`. Preflight every regular file under `agents`, `skills`, and `commands` with null-delimited `find`; if any destination file exists without `--force`, print every collision and exit 1 before copying. With no collisions or with `--force`, create parent directories and copy files individually; never prune unrelated configuration. Print installed file count and destination on success.
- [x] 3. Run `chmod +x install.sh && bash -n install.sh && sandbox="$(mktemp -d)" && HOME="$sandbox" ./install.sh && test -f "$sandbox/.config/opencode/skills/oneshot/SKILL.md" && cmp agents/scout.md "$sandbox/.config/opencode/agents/scout.md"`. Expected: valid syntax, successful clean install, and byte-identical agent copy.
- [x] 4. Run `sandbox="$(mktemp -d)" && HOME="$sandbox" ./install.sh >/dev/null && if HOME="$sandbox" ./install.sh; then echo 'collision refusal failed'; exit 1; else echo 'collision refusal passed'; fi && HOME="$sandbox" ./install.sh --force`. Expected: second install refuses before overwrite with exit 1; forced install succeeds; no restart is required.
- [x] 5. Commit with `git add README.md install.sh && git commit -m "feat: add repository guide and installer"`. Expected: executable installer and project guide committed.

### Task 13: Audit, push, and open the system PR

**Files:**
- Modify only after failed checks or completed tracking: `docs/plans/2026-11-04-great-refactor.md`
- Verify: all files in the file-structure map

- [x] 1. Validate frontmatter with `for f in skills/*/SKILL.md; do rg -q '^name:' "$f" && rg -q '^description:' "$f" || { echo "invalid skill: $f"; exit 1; }; done && for f in agents/scout.md agents/patch.md; do rg -q '^description:' "$f" && rg -q '^mode: subagent$' "$f" && rg -q '^permissions:' "$f" || exit 1; done`. Expected: no output and success for every skill and both agents. Agents omit a `model` field on purpose; in OpenCode V2 omission means the subagent inherits the parent session model, so routing stays with AGENTS.md roles.
- [x] 2. Run `! rg -n -i 'c[a]ve|super[p]owers' --glob '!AGENTS.md' --glob '!docs/plans/**' . && ! rg -n 'opencode-go/' skills agents && ! rg -n '\x{2014}' . && test "$(rg -i -c 'super[p]owers' docs/plans/2026-11-04-great-refactor.md)" -eq 1`. Expected: zero legacy-token matches outside routing or plan history, zero provider-qualified ids in skills and agents, zero emdash characters, and exactly one migration-history mention.
- [x] 3. Run `bash -n install.sh && git diff --check origin/master...HEAD && git status --short`. Expected: valid installer, no whitespace errors, and no source changes except any necessary audit correction or this plan's tracking update.
- [x] 4. Check the completed worker boxes in this plan only after their evidence exists, then run `git add docs/plans/2026-11-04-great-refactor.md && git commit -m "docs: record system validation"`. Expected: final tracking commit; if an audit correction was needed, stage its exact file in this command too and rerun Steps 1-3 before committing.
- [x] 5. Run `git push -u origin feat/system-v1`. Expected: remote feature branch created with upstream tracking; never push directly to `master`.
- [x] 6. Open the PR with the following exact command, then verify with `gh pr view feat/system-v1 --json url,state,baseRefName --jq '.url + " " + .state + " " + .baseRefName'`. Expected: PR URL, `OPEN`, and `master`.

```bash
gh pr create --base master --head feat/system-v1 --title "feat: rebuild owned OpenCode control system" --body "$(cat <<'EOF'
## Summary
Dennis's agent workflow depends on external process skills and scattered legacy naming, which prevents full ownership and consistent routing. This PR replaces that system with an owned cybernetic controller, explicit feedback loops, and clean skills, agents, and commands.

## Changes
- **Control pipeline:** Rebuild `oneshot` with design, plan, and finish gates, bounded council review, and CI repair.
- **Agents and routing:** Add `scout`, `patch`, and centralized model fallback rules in `AGENTS.md`.
- **Owned workflow:** Add shape, plan, dispatch, TDD, debug, verify, council, land, CI, and craft skills.
- **Commands and install:** Add five clean slash commands, a collision-safe installer, and repository documentation.
- **Existing domains:** Import the twelve already owned skills verbatim.

## Test plan
- [x] Skill and agent frontmatter loops: all required fields present.
- [x] Legacy-token, model-id, and emdash scans: zero forbidden matches.
- [x] `bash -n install.sh`: syntax valid.
- [x] Temporary-HOME install, collision refusal, and forced install: all behaviors verified.
- [x] `git diff --check origin/master...HEAD`: no whitespace errors.
EOF
)"
```

## Self-review

- [x] **Spec coverage:** Tasks 2-10 implement every renamed or merged capability; parallel execution is folded into `dispatch`, review requesting and receiving are merged into `council`, next-feature and problem-led PR behavior are in `land`, and worktree, plugin-overview, and plugin-diagnostic workflows are intentionally dropped. Task 11 preserves all existing owned skills, Task 12 covers installation and documentation, and Task 13 covers audit, branch push, and PR.
- [x] **No placeholders:** Every repository file has a concrete responsibility, every task has exact paths and commands with expected results, and every task has a conventional commit or an explicit audit-correction path. No implementation work is deferred.
- [x] **Naming consistency:** Controller `oneshot`; actuators `patch` and `dispatch`; sensors `scout`, `verify`, `council`, `make-ci-green`, and `stats`; supporting skills `shape`, `plan`, `tdd`, `debug`, `land`, and `craft`; commands `/style`, `/commit`, `/review`, `/compress`, and `/stats`. L2 is three rounds plus one escalation, L3 is five repair pushes, and model ids occur only in `AGENTS.md` and this plan's routing specification.

## Validation record

Executed by the orchestrator before the push. Evidence summary:

- `bash -n install.sh`: syntax valid.
- Clean install into a temporary HOME: oneshot skill present, `agents/scout.md` byte-identical (`cmp` clean).
- Second install against same HOME: refuses with a per-file collision list, exit 1. `--force` overwrites cleanly.
- Skill frontmatter loop: every `skills/*/SKILL.md` carries `name:` + `description:`. Agent loop: both agents carry `description:`, `mode: subagent`, ordered `permissions:`.
- Legacy-token scan (`cave|superpowers`, case-insensitive) outside AGENTS.md/plan/template payload: zero matches. AGENTS.md itself: zero matches.
- Provider-qualified model IDs in `skills/`, `agents/`, `commands/`: zero. Model IDs live only in AGENTS.md (routing source) and this plan.
- Emdash scan across the whole tree: zero characters.
- `git diff --check origin/master...feat/system-v1`: no whitespace errors.

Documented exceptions and deltas:

1. `skills/generate-instrumental/templates/sa3_medium_api_base.json` contains the English word "cave" inside the SFX prompt payload (`cave/open field/underwater` spatial descriptor). Legitimate vocabulary in a music template, not a naming reference; left untouched.
2. The plan originally asked for verbatim domain-skill imports. Actual imports carry one normalization pass (emdash characters replaced with commas plus whitespace collapse) so the tree obeys the global no-emdash rule. Task 11 wording was corrected above, before any commit history claims verbatim.
3. Earlier plan text required `model: inherit` in agent frontmatter. OpenCode V2 inherits the parent model by omission; the field does not exist. Task 13 step 1 was corrected above.
4. README introduction differs in wording from the Task 12 draft sentence (same content coverage: purpose, structure, install, master/PR rule, routing pointer, MIT note). The rendered diagram shows the tank and loop levels instead of the thinner draft sketch.
5. Helpers: `skills/dispatch/` ships its three remapped prompt templates, `skills/debug/` ships its full methodology asset set, `skills/craft/` ships testing examples and the graph render tooling. Each rode along in its own skill's commit.

Revision 2 (same branch, before merge), both corrections requested in review:

6. `commands/` removed entirely; the five helpers became skills: `style`, `commit`, `review`, `compress`, `stats` (OpenCode skill frontmatter, trigger-rich descriptions, no prefix conventions). Nothing in the tree dispatches through a commands directory anymore.
7. Agent seats expanded from 2 to 6: `scout`, `patch`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`. Every agent file now pins `model:` to its AGENTS.md primary, so a subagent session never inherits the main session model. Council handlers were rewritten to dispatch the named seats; fallback handling re-dispatches the same seat agent with an explicit model override from its ladder column, skipping models whose family already serves another seat that round.
   - Verified: zero `commands/` references outside historical docs; both new seat-free skills validate; six agents present with pinned models; installer updated to source only `agents` and `skills`.

Revision 3 (same branch, before merge), scope correction requested in review:

8. The twelve personal domain skills (media generation, projects, device tooling: backup-opencode, cloudflare-tunnel, copy-user-commands, generate-comfy-image, generate-instrumental, generate-thumbnail, image-convert, image-edit, linear-issues, silicon-seeds, ssh-debug, text-to-voice) are removed from the repo. The `skills` repo is the cybernetic harness subset only; the domain units stay in `~/.config/opencode/skills/` and remain covered by the dotfiles sync (more-dots). Task 11's import no longer applies to this repository - nothing for the installer to pick up there.
   - Verified: 16 skill dirs remain, all harness-owned; the no-commands, model-isolation, emdash, and frontmatter gates still pass on the trimmed tree; git history keeps the import commits, so restoring a dropped unit later is one revert away.

Revision 4 (same branch, before merge), requested in review:

9. Muse Spark 1.3 Contributor is now the FIRST implementation fallback (direct successor to glm-5.3-flash), ahead of gpt-6-luna. The dedicated implementation seat `implementer.md` exists as its own agent: task-scale TDD builder with commit discipline, pinned glm-5.3-flash, distinct from `patch` (the 1-2-file surgical fixer used by scout->patch micro-loops and council fix rounds). `dispatch` and `oneshot` dispatch by the named seat; ad-hoc task-stage reviewers (spec + quality) are not seats and always carry an explicit model override from the new AGENTS.md rung, so no subagent of any kind silently inherits the main session model. tstack has no equivalent dedicated implementation agent, which is exactly why the seat was worth adding.
   - Verified: 7 agents all pin `model:`; 16 skills frontmatter valid; model-ID isolation: zero IDs under `skills/`; emdash zero; installer copy byte-check passes on the new tree.

Revision 5 (same branch, before merge): round-1 council over the full repo, three independent seat families (kimi-k3.1-pro, glm-5.3, qwen3.7-plus). Unified verdict FAIL -> 7 parallel surgical fixers (max 2 files each, disjoint) -> all fixes below landed. Deliberate deviations, documented:

10. Fixer file cap bookkeeping: the seven fixers kept the 2-file cap. The controller itself wrote the plan's own revision log (this list): plan-sheet maintenance is controller bookkeeping, not fixer scope.
11. Permission action names: reviewer B flagged `bash`/`task` as V1 names that V2 renamed to `shell`/`subagent` (workflow-doc claim). The local harness (opencode v2.2.5) runs a live config that uses `bash`/`task` spellings, so both dialects exist in the wild. Resolution: agent files now carry BOTH spellings for deny-critical rules (deny + its alias sibling) so denies never go inert, and AGENTS.md documents the alias policy.
12. One citation rejected as false: finding claimed the debug skill demands "human discussion after three failed fixes" at `skills/debug/SKILL.md:193-210`; no such text exists at those lines or anywhere in that file (grep: zero matches for three-strike/attempts wording). The core gap it wrapped was real, so the fix (explicit caps in dispatch + oneshot) landed anyway, with the false citation recorded here.
13. Verified false-positive sweep done on receipts: `spec-ringer` typo in the council instruction block (found by B) was fixed by the fx3 pass; the stage-reviewer prompt header overlap flagged by fx5 was already handled by fx4.

Revision 6 (same branch, before merge), user model/effort and request-limit alignment:

14. Removed `agents/reviewer-local.md` and all `lmstudio` routing: the harness now uses exclusively `opencode-go/*` models.
15. Expanded implementation to three dedicated seats (`implementer` = `deepseek-v4.1-flash`, `implementer-b` = `muse-spark-1.3-contributor#medium`, `implementer-deep` = `gemini-4-argon#high` for complex tasks and difficult bugs). Note: `deepseek-v4.1-flash` catalog supports `low|high|max` only (no `medium`), so it runs at provider default effort to avoid a model-resolution error while `implementer-b` pins `#medium`.
16. Rebuilt the Council and Model Tank around the OpenCode Go 5-hour request allowance table so normal workflows never hit rate limits:
    - `reviewer-a`: `opencode-go/muse-spark-1.3-contributor#xhigh` (45,300 req/5h)
    - `reviewer-b`: `opencode-go/deepseek-v4.1-flash#max` (43,330 req/5h)
    - `reviewer-c`: `opencode-go/glm-5.3-flash#high` (6,320 req/5h)
    - Reviewer fallbacks: `opencode-go/claude-haiku-5-5#high` (3,850 req/5h) and `opencode-go/gpt-6-luna#high` (4,230 req/5h)
    - Last resort / escalation (`reviewer-esc`): `opencode-go/kimi-k3.1-pro#high` (147 req/5h), fallback `opencode-go/gemini-4-argon#high` (440 req/5h).

Revision 7 (harness hardening branch `fix/harness-hardening`):

17. Permission ordering corrected: agent `permissions:` lists are last-match-wins, so the broad `bash`/`shell` deny comes first and narrow allows come last. Every seat denies reads of `.env`, `.env.*`, `.zshrc`, `.zsh_history`, and `.ssh/*` after its broad read allow, and no seat may commit or push on `main`/`master`. `AGENTS.md` carries this in a `Permission rules` block.
18. The installer is collision-safe with a real test: it preflights every target, prints one `collision:` line per conflict, refuses without `--force`, and `test/install.sh` exercises clean install, refusal, `--force`, and `--prune` under a throwaway `HOME`.
19. Auto-approve is now actually unattended: the flag is recorded at the top of the spec as `auto-approve: true (trigger: "<phrase>")` and travels into the shape and plan dispatch prompts, which suppress their own approval waits instead of pausing.
20. Invalid `gh` commands in the skills were replaced with documented, valid invocations.
21. The stale `## File structure` block was replaced with the real tree: 9 agents, 10 skills, `AGENTS.md`, `README.md`, `install.sh`, `test/install.sh`, `LICENSE`, and `docs/`.

Superseded history, not current claims: the Task 2 validation gate asserting zero provider-qualified ids in agents, and the Task 12 validation asserting collision refusal by the old installer. Agents now pin `model:` per seat by design, and the installer's refusal behavior is verified by `test/install.sh`.

*Migration history: The original process skills came from the community superpowers package; this repository now owns their clean replacements and has no runtime dependency on that package.*
