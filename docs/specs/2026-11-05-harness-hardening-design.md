# Harness Hardening Design

auto-approve: true
trigger: "Work on a draft PR until it has an approval of 9/10 from all council members using oneshot"

## Problem

Round 1 council on `2da72f7` returned three FAIL verdicts (3, 4, 6 out of 10). Verified defects:

1. Permission order makes the broad `bash|shell` deny swallow the narrow git allows, so `reviewer-a/b/c/esc` and `scout` have no shell at all despite their bodies promising it.
2. No seat denies reads of `.env`, `.env.*`, or shell dotfiles, so the global secrets rule is unenforced.
3. No seat denies commits on `main`/`master`; branch protection is prose only.
4. `install.sh` silently overwrites, has no collision preflight and no `--force`, contradicting the plan's validated contract.
5. `git check-ignore -q X || git add X && git commit` commits even when the path is ignored.
6. `shape` and `plan` hard-wait for approval and `plan` offers inline execution, so oneshot's auto-approve mode cannot run unattended.
7. `gh pr view --json reviews, labels` and `gh pr remove` are invalid commands.
8. Council dispatch budget arithmetic exceeds its own cap.
9. Contract text disagrees on no-tests PASS, degraded council, and fixer routing (`patch` cannot run tests).
10. README, AGENTS.md, and the stale plan file map disagree with the tree.

## Goal

Every one of the three council seats returns at least 9/10 with zero confirmed red findings, and the repo ships a runnable install test proving the installer contract.

## Success criteria

- `test/install.sh` passes: clean install, second run refuses with exit 1 listing collisions, `--force` overwrites, stale destination file is pruned, `OPENCODE_CONFIG` is honored.
- `bash -n install.sh` and `bash -n test/install.sh` pass.
- Frontmatter loop passes for all 9 agents and 10 skills.
- No emdash characters anywhere in the tree.
- No `bash|shell` allow appears after a broader deny in any read-only seat.
- Every `gh ` command in the skills is a real `gh` subcommand.
- `shape` and `plan` both honor `auto-approve: true`.
- Council round 2: three seats, all 9/10 or higher, zero red findings.

## Approaches considered

1. **Patch the symptoms only.** Fix the nine reds, leave the contract contradictions. Cheap, will not reach 9/10 because reviewers re-read the same contradictions.
2. **Rewrite the permission layer as a shared include.** OpenCode agent frontmatter has no include mechanism, so this means a generator script. Adds a build step to a repo that is deliberately plain markdown.
3. **Chosen: fix in place, one owner per file, single source of truth for each contract.** Every contradictory rule gets one canonical sentence in `AGENTS.md` and the skills point at it rather than restating it in different words.

## Decisions

- Permission order is stated once in `AGENTS.md` as last-match-wins, and every seat lists the broad deny first.
- Secrets protection moves from prose to permission rules: explicit `read` deny for `.env*`, `.zshrc`, `.zsh_history`, and `.ssh/*` placed after the broad read allow.
- Main-branch protection stays prose plus a `bash` deny for `git commit` and `git push` when invoked with the default branch. Exact-pattern denies are best effort; the dispatch brief still carries the branch check.
- `install.sh` gains `--force` and `--prune`; collision preflight exits 1 before any copy.
- Auto-approve is a header flag in the spec, read by both `shape` and `plan`, which suppress their approval waits and the inline option.
- No-tests PASS is a provisional PASS, explicitly labelled, and never satisfies the standard green-tests gate.
- `patch` stays shell-free; loops that need tests route fixers to `implementer`.
