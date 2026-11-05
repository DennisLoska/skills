# Harness Hardening Implementation Plan

Status: executed on branch fix/harness-hardening; see git log.

> **For agentic workers:** execute tasks in order. Each task is file-disjoint. Commit once per task with the message given.

**Goal:** fix every verified red and yellow from council round 1 so that all three seats score 9/10 or higher.

**Architecture:** markdown harness plus one bash installer. No build step. Each contract gets one canonical statement in `AGENTS.md`; skills reference it instead of restating it.

**Spec:** `docs/specs/2026-11-05-harness-hardening-design.md`

**Revision note:** The shipped installer (`install.sh`) implements `--prune` as manifest-scoped (`<dest>/.harness-manifest`) rather than source-diff pruned against all files under `skills/` and `agents/`, as a deliberate safer deviation so user-owned agents and skills in the destination directory are never removed.

---

### Task 1: Permission layer (agents)

**Files:** `agents/implementer.md`, `agents/implementer-b.md`, `agents/implementer-deep.md`, `agents/patch.md`, `agents/scout.md`, `agents/reviewer-a.md`, `agents/reviewer-b.md`, `agents/reviewer-c.md`, `agents/reviewer-esc.md`

- 1. In `scout`, `reviewer-a`, `reviewer-b`, `reviewer-c`, `reviewer-esc`: move the broad `bash: "*"` and `shell: "*"` deny rules ABOVE the narrow `git diff|log|show` allows. Delete the duplicated narrow allows that are not needed.
- 2. In all five read-only seats add, after the broad `read: "*"` allow, deny rules for `read` on `.env`, `.env.*`, `**/.env`, `**/.env.*`, `**/.zshrc`, `**/.zsh_history`, `**/.ssh/*`.
- 3. In `implementer*` and `patch`: add the same `read` deny block after the broad allow; in `implementer*` add deny rules for `bash`/`shell` on `rm -fr *`, `rm -r *`, `rm -rf /*`, `git clean *`, `git push *`, `git push --force*`, `pkill *`, `killall *`, and enforce default-branch protection with the Step 0 `git branch --show-current` check in every implementer seat.
- 4. Add a short body line to every agent: "Permissions are last-match-wins; the broad deny comes first."
- 5. Verify: `python3 - <<'PY'`-free check is not needed; run `rg -n 'action: (read|bash|shell)' -A2 agents/` and confirm visually that no broad allow appears after a narrow deny that must win, and read-only seats put the narrow allow last.

### Task 2: Installer and its test

**Files:** `install.sh`, `test/install.sh`, `README.md` (install section only)

- 1. Rewrite `install.sh`: `--force` and `--prune` flags, null-delimited preflight over `agents`, `skills`, plus `AGENTS.md` -> `HARNESS.md`; collect collisions, print each, exit 1 before copying unless `--force`.
- 2. With `--prune`, remove destination files under `skills/` and `agents/` that no longer exist in source, and say how many were pruned.
- 3. Write `test/install.sh` covering: clean install into `mktemp -d`, byte-identical copy, second run exits 1 and names the collision, `--force` succeeds, dropped source file is pruned, `OPENCODE_CONFIG` is honored.
- 4. Update README install section to document `--force`, `--prune`, and the test command.
- 5. Verify: `bash -n install.sh && bash -n test/install.sh && bash test/install.sh`.

### Task 3: Controller autonomy (oneshot, shape, plan)

**Files:** `skills/oneshot/SKILL.md`, `skills/shape/SKILL.md`, `skills/plan/SKILL.md`

- 1. `oneshot`: replace `A || B && C` with an explicit `if ! git check-ignore -q "$spec"; then git add "$spec" && git commit ...; fi`. Do this for both spec and plan.
- 2. `oneshot`: remove the double commit. shape owns the spec commit; Phase 1 no longer commits.
- 3. `shape` and `plan`: add an "Auto-approve" section that reads `auto-approve: true` from the spec header or the dispatch prompt and suppresses the user review gate, the visual-companion offer, and (in plan) the execution-choice question, noting `auto-approved` in the artifact.
- 4. `plan`: when invoked from oneshot or with auto-approve, remove the inline option entirely.
- 5. All three: replace "via the `task` tool" with "via the `subagent` tool" and note the build alias in one line.
- 6. `oneshot`: replace the `memory add` shell line with the memory tool call (`mode: "add"`). Move the state artifact to `.git/info/oneshot-state.md` when `docs/` is tracked, and state that it is never committed.
- 7. Verify: `rg -n 'task` tool|memory add|check-ignore' skills/` returns only corrected forms.

### Task 4: CI, land, council contracts

**Files:** `skills/land/SKILL.md`, `skills/make-ci-green/SKILL.md`, `skills/council/SKILL.md`, `skills/dispatch/SKILL.md`, `skills/tdd/SKILL.md`

- 1. `land`: remove `gh pr remove`. Replace with: strip the blocked word from PR body via `gh pr edit`; branch cleanup via local `git branch -d`.
- 2. `make-ci-green`: fix `gh pr view <id> --json reviews,labels`, add an explicit fix-round counter, route test-running fixers to `implementer` (not `patch`), and replace the "wait for next wake" instruction with a bounded re-poll rule.
- 3. `council`: state one degraded rule only (fewer than 2 independent families means stop, no provisional PASS), make no-tests a provisional PASS that blocks the standard gate, and route fixers that must run tests to `implementer`.
- 4. `dispatch`: replace the unactionable "rung" complexity language with an explicit seat matrix (task class -> seat), and correct the `task` tool naming.
- 5. `tdd`: change "no warnings" to "no new warnings".
- 6. Verify: `rg -n 'gh pr (remove|view)' skills/` shows only valid forms; `rg -n 'wake' skills/make-ci-green/` returns nothing.

### Task 5: Routing source of truth and docs

**Files:** `AGENTS.md`, `README.md`, `docs/plans/2026-11-04-great-refactor.md`

- 1. `AGENTS.md`: add the canonical permission-order rule, the secrets deny list, the no-tests provisional PASS rule, the degraded-council rule, and the fixer-must-run-tests rule.
- 2. `AGENTS.md`: recalculate the council budget to a number that is arithmetically possible (3 rounds x 3 seats + 3 demotions + 1 escalation = 13, so the cap is 14 including one escalation demotion) or restate what counts. Route compaction off the training family or add it to the privacy gate.
- 3. `README.md`: fix "7 phases" to "7 numbered phases plus 6.5", fix the primary-seat allowance claim to exclude the 440 and 147 tiers, and make the auto-approve claim match Task 3.
- 4. `docs/plans/2026-11-04-great-refactor.md`: replace the file-structure map with the real tree (9 agents, 12 skills including `domain-modeling` and `codebase-design`, no commands, no craft), and mark the superseded validation gates as historical in a Revision 7 note.
- 5. Verify: `rg -n 'commands/|skills/craft' README.md AGENTS.md` returns nothing; the historical plan `docs/plans/2026-11-04-great-refactor.md` keeps those strings by design under its new historical banner.

---

## Final verification

- `bash -n install.sh && bash -n test/install.sh && bash test/install.sh`
- `for f in skills/*/SKILL.md; do rg -q '^name:' "$f" && rg -q '^description:' "$f" || echo "bad $f"; done`
- `for f in agents/*.md; do rg -q '^mode: subagent' "$f" && rg -q '^model:' "$f" || echo "bad $f"; done`
- `! rg -n '\x{2014}' .`
- `git diff --check`
