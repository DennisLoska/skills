---
title: T3 Code Harness Alignment
date: 2026-11-16
phase: shape
auto-approve: true ("get them merged well using the fixed Oneshot Harness")
status: approved
---

# T3 Code Harness Alignment

Align the Oneshot Harness with T3 Code's actual delegation and PR lifecycle contracts (`delegate_task`, `orchestrator_capabilities`, `task_status`, `task_cancel`, `link_pull_request`, `link_pull_requests`, `watch_pull_request`, `unwatch_pull_request`) and the battle-tested patterns in `t3dotgg/tstack` (`sol-loop`, `babysit-pr`, `full-send`, `full-stop`, `file-pr`, `council`). Make provider/model targeting explicit, preserve durable execution state in `oneshot-state.md`, and replace blocking waits and manual PR polling with T3 Code's async completion and watcher mechanisms.

This change is built on top of `2cacea1` (`council-opus-sol-gemini`) and preserves its council availability, self-review eligibility, and `SKIPPED mode=unavailable` verdict rules.

## Assumptions

- The live Telos diagnosis and `t3dotgg/tstack` comparison establish the failure modes and reference behavior (auto-approved).
- Implementation occurs in `/home/dennis/.t3/worktrees/skills/feat-t3-harness-alignment` on top of `council-opus-sol-gemini` (`2cacea1`).
- `PROVIDERS.md` remains the single source of models, provider instances, options, privacy, and routing ladders.
- T3 Code MCP schemas (`delegate_task.json`, `orchestrator_capabilities.json`, `task_status.json`, `task_cancel.json`, `link_pull_request.json`, `watch_pull_request.json`, `unwatch_pull_request.json`) are authoritative for parameter names.
- Outside T3 Code, existing standalone native dispatch (Paths 2 and 3) and non-T3 CI/PR verification remain supported.

## Approaches

### 1. Add point warnings at the observed failure sites
Add short warnings against `modelSelection`, blocking `wait` calls, state truncation, and PR polling.
- **Trade-offs:** Smallest diff, but leaves incomplete examples and missing `taskId`/`watch_pull_request`/`link_pull_request` contracts across the skills.

### 2. Align the shared contract in `AGENTS.md` and every execution entry point (Recommended - Chosen)
Keep a concise, authoritative T3 Code Path 1 contract in `AGENTS.md` (within its 150-line / 24 KiB cap), align operational instructions across `skills/dispatch/SKILL.md`, `skills/oneshot/SKILL.md`, `skills/council/SKILL.md`, `skills/make-ci-green/SKILL.md`, and `skills/land/SKILL.md`, and add regression tests in `test/t3-harness-alignment.sh`.
- **Trade-offs:** Updates multiple skill files, but eliminates drift between `AGENTS.md` and the phase skills while mechanically verifying the contract in CI/test suites.

### 3. Introduce an executable orchestration wrapper script
Centralize delegation, state mutation, and PR watchers in a shell/node wrapper.
- **Trade-offs:** Adds new runtime/installation surface and cannot wrap MCP tool calls directly inside the model turn. Rejected (YAGNI).

## Design (auto-approved)

### 1. Delegation Contract & Lifecycle (`AGENTS.md`, `skills/dispatch/SKILL.md`, `skills/oneshot/SKILL.md`, `skills/council/SKILL.md`)
- **Exact `delegate_task` envelope:**
  - `role`: `"research"` (`scout`), `"test"` (`tester`), `"implementation"` (`implementer`, `implementer-deep`, `patch`), `"review"` (`reviewer-a`, `reviewer-b`, `reviewer-c`, captain ruling, `task-reviewer`), or `"design"` (`designer`, `planner`, design alternatives).
  - `target`: `{ providerInstanceId: "<provider>", model: "<model>", options: { ... } }` resolved from the active `PROVIDERS.md` rung.
  - `mode`: `"async"` by default (especially for `designer`/`planner` drafts, `implementer*`, and `review` so 3-minute host MCP call deadlines never orphan running children); `"wait"` only when the current turn strictly requires an immediate short result.
  - `isolation`: `"shared"` by default, or `"worktree"` when parallel tasks touch overlapping files.
  - `clientRequestId`: fresh unique ID per dispatch/round.
  - `task`: the child brief (T3 children receive no parent conversation history).
- **Explicit parameter prohibitions:** Never pass invented keys such as `modelSelection`, top-level `provider`, or `cwd` to `delegate_task` (unknown keys are ignored by `delegate_task`, silently causing the child to inherit the parent driver's model).
- **Delegate lifecycle (from `tstack/skills/sol-loop/SKILL.md`):**
  - Save the returned `taskId`. Retain `childThreadId` as storage/reference only; never call `t3_thread_send`, `create_threads`, `t3_thread_launch`, or `t3_thread_interrupt` on a `childThreadId`.
  - Follow the returned `next` instruction and end the turn when waiting for an async delegate's reactive completion wakeup. Never poll `task_status` in a loop before completion wakes the thread.
  - A tool-call timeout or missing reply is not approval and does not stop the child: cancel replaced, timed-out, or aborted runs with `task_cancel` (`taskId`) before starting a replacement.

### 2. Phase 3 Task Review & Shared-Checkout Safety (`skills/dispatch/SKILL.md`, `skills/oneshot/SKILL.md`, `skills/council/SKILL.md`)
- **Sequential two-stage task review:** Stage 1 (`spec-reviewer-prompt.md`) and Stage 2 (`quality-reviewer-prompt.md`) are two separate, sequential `delegate_task` (`role: "review"`) dispatches per task. Never merge Stage 1 and Stage 2 into a single combined review prompt.
- **No concurrent edits during shared-checkout review:** While any review delegate (`task-reviewer` or `council` seat) is actively reviewing in `isolation: "shared"`, the driver and other delegates must not edit scoped files in that checkout.
- **Durable `oneshot-state.md` updates:** Updating `$(git rev-parse --git-dir)/info/oneshot-state.md` must preserve all canonical keys (`dispatch_adapter`, `primary_rungs`, `phase`, `branch`, `pr_url`, `author_models`, `author_families`, `author_commits`, `tests_status`, `council_round`, `council_verdict`, `captain`, `backlog`, `soft_cap_counts`); never overwrite the file with a truncated summary that drops routing or authorship state.

### 3. T3 Code PR Linking, REST Fallback & Watcher Lifecycle (`skills/land/SKILL.md`, `skills/make-ci-green/SKILL.md`, `skills/oneshot/SKILL.md`)
- **PR linking:** In T3 Code, immediately after creating, taking over, or pushing to a PR, call `link_pull_request` (or `link_pull_requests`) with the full PR URL.
- **GraphQL rate-limit fallback (from `tstack/skills/file-pr/SKILL.md` & `babysit-pr/SKILL.md`):** When `gh pr create`, `gh pr view`, or `gh pr checks` fails due to GitHub GraphQL rate limits, fall back to REST (`gh api repos/<owner>/<repo>/pulls` to create/read PRs and `gh api repos/<owner>/<repo>/commits/<sha>/check-runs` for check runs; check for an existing PR before retrying creation).
- **One watcher per PR (`watch_pull_request` / `unwatch_pull_request`):**
  - In T3 Code (`make-ci-green` and `oneshot` Phase 6.5 / `land` merge wait), inspect existing checks and comments first, finish any needed branch update and push, then call `watch_pull_request` and end the turn so T3 Code wakes the thread on check/review/conflict events. Never run a manual 30-second `gh pr checks` sleep/poll loop in T3 Code.
  - **Parent-only rule:** Only the parent thread that owns the PR may call `watch_pull_request`; delegated children (`delegate_task`) never call `watch_pull_request`.
  - **Unwatch before handback:** Before handing back control, stopping, or asking the user a question, call `unwatch_pull_request`.
  - Outside T3 Code, retain the existing CLI check/poll flow.

### 4. Compatibility with Parallel Branch (`council-opus-sol-gemini`) & Regression Testing
- Preserve `AGENTS.md` size/line budget (`<= 150` lines, `<= 24576` bytes).
- Preserve all `council-opus-sol-gemini` (`2cacea1`) semantics: self-review allowed, unavailable council members skipped, and `council_verdict: SKIPPED mode=unavailable` accepted by `land` and `oneshot`.
- Add `test/t3-harness-alignment.sh` to verify the T3 `delegate_task` envelope, `modelSelection` prohibition, `taskId`/`task_cancel` lifecycle, `link_pull_request`/`watch_pull_request`/`unwatch_pull_request` rules, sequential Stage 1 -> Stage 2 review rule, `oneshot-state.md` key preservation, and compatibility with existing test suites.
