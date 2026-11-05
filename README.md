# skills

A cybernetic SDLC harness for OpenCode V2. One gated controller (`oneshot`), four closed feedback loops, nine model-pinned agent seats on OpenCode Go, and ten flat-named pipeline skills.

## Cybernetic Architecture

```
                        USER  (3 gates only)
                 G1 design OK | G2 plan OK | G3 finish OK
                                   |
                                   v
+-------------------------------------------------------------------------+
|                        ONESHOT = CONTROLLER                             |
|                                                                         |
|  [1 SHAPE]-->[2 PLAN]-->[3 DISPATCH]-->[4 VERIFY]-->[5 LAND + PR]       |
|     |          |             |              |             |             |
|     +--spec    +--plan       |              |             v             |
|                              |              |    [6.5 MAKE-CI-GREEN]    |
|                              |              |             |             |
|                              |              |             v             |
|                              |              +------> [6 COUNCIL] <--+   |
|                              |                         | PASS       |   |
|                              |                         v            |   |
|                              +------------------> [7 LAND]          |   |
+-------------------------------------------------------------------------+

+------------------------- L1  TASK LOOP (per task) ----------------------+
|  [SCOUT] ----path:line----> [IMPLEMENTER / IMPLEMENTER-B]               |
|  (mimo-v2.6-flash)          (deepseek-v4.1-flash#high /                 |
|                              muse-spark-1.3-contributor#medium)         |
|       ^                              |                                  |
|       |                     complex / 3x fail                           |
|       |                              v                                  |
|       +---- [DEBUG] ------> [IMPLEMENTER-DEEP] ----> [TDD + VERIFY]     |
|                             (gemini-4-argon#high)                       |
+-------------------------------------------------------------------------+

+------------------------- L2  BRANCH LOOP (max 3 rounds) ----------------+
|  reviewer-a: muse-spark-1.3-contributor#xhigh (45.3k req/5h)  -+        |
|  reviewer-b: deepseek-v4.1-flash#max          (43.3k req/5h)  -+-> PASS |
|  reviewer-c: glm-5.3-flash#high               ( 6.3k req/5h)  -+    or  |
|                                                                    FAIL |
|  FAIL (rounds 1-2) -> [PATCH] surgical fixer -> re-review               |
|  Rounds exhausted  -> [REVIEWER-ESC] kimi-k3.1-pro#high -> STOP         |
+-------------------------------------------------------------------------+

+------------------------- L3  CI LOOP -----------------------------------+
|  [MAKE-CI-GREEN] watches checks + review bots -> [PATCH] on real bugs   |
|  No blind reruns; flakes require log-line evidence before a single retry|
+-------------------------------------------------------------------------+

+------------------------- L4  META LOOP ---------------------------------+
|  OpenCode token telemetry + session memory record outcomes and burn;    |
|  routing re-tunes happen deliberately between sessions with the user    |
+-------------------------------------------------------------------------+
```

## Usage & Example Prompts

### 1. Full Autonomous Pipeline (`oneshot` - 3 Human Gates)

Trigger the end-to-end controller by prefixing a task with `oneshot`:

```text
oneshot build a rate-limited webhook delivery worker with exponential backoff, dead-letter queue, and SQLite persistence
```

What happens across the 7 phases:

1. **Phase 1 - `shape` (Design & Spec):** creates branch `feat/webhook-delivery-worker`, explores constraints and trade-offs, and writes `docs/specs/YYYY-MM-DD-webhook-delivery-worker-design.md`. **Pauses at Gate 1 for design approval.**
2. **Phase 2 - `plan` (Task Decomposition):** breaks the approved spec into bite-size TDD tasks with exact file paths and verification commands in `docs/plans/YYYY-MM-DD-webhook-delivery-worker.md`. **Pauses at Gate 2 for plan approval.**
3. **Phase 3 - `dispatch` + `tdd` (L1 Task Loop):**
   - Dispatches `scout` (`mimo-v2.6-flash`) for compressed `path:line` discovery without polluting main-session context.
   - Dispatches fresh per-task `implementer` (`deepseek-v4.1-flash#high`) or `implementer-b` (`muse-spark-1.3-contributor#medium`) subagents following strict red-green-refactor TDD.
   - Escalates complex multi-file architecture tasks or 3x task failures (via `debug`) to `implementer-deep` (`gemini-4-argon#high`).
   - Runs two-stage review after every task: Stage 1 spec compliance, then Stage 2 code quality (`glm-5.3-flash#high`).
4. **Phase 4 - `verify` (Evidence Gate):** runs the full test suite, typecheck, linter, and build, confirming every spec checklist item with fresh command output.
5. **Phase 5 - `land` (PR Filing):** pushes the feature branch and opens a problem-led GitHub PR (`## Summary`, `## Changes`, `## Test plan`).
6. **Phase 6.5 - `make-ci-green` (L3 CI Loop):** watches GitHub Actions and review bots, dispatches surgical `patch` fixers on real failures, and requires concrete log-line evidence before retrying a suspected flake.
7. **Phase 6 - `council` (L2 Branch Loop):** dispatches 3 adversarial reviewers from independent model families in parallel (`reviewer-a` on `muse-spark-1.3-contributor#xhigh`, `reviewer-b` on `deepseek-v4.1-flash#max`, `reviewer-c` on `glm-5.3-flash#high`). Any confirmed red finding triggers `patch` fixers and re-review (up to 3 rounds, then `reviewer-esc` on `kimi-k3.1-pro#high`).
8. **Phase 7 - `land` (Gate 3 Finish & Handoff):** presents finish options (merge PR and hand off to default branch, keep PR open, keep branch, or drop).

### 2. Zero-Gate Unattended Mode (`oneshot` Auto-Approve)

Include an explicit bypass phrase (`auto-approve`, `skip all approvals`, `no approval gates`, or `full autonomy no questions`) in the initial prompt to run Phases 1 through 7 non-stop without human pauses:

```text
oneshot auto-approve: fix the race condition in session token refresh when concurrent requests hit an expired JWT
```

The controller records `auto-approve: true` with the quoted trigger phrase in the spec header and executes the entire pipeline through CI verification and council consensus autonomously.

### 3. Confidential Mode (Privacy Gate)

Mark a prompt or diff as confidential to engage the privacy gate automatically:

```text
oneshot [confidential] implement HMAC signature rotation for partner billing webhooks
```

Any rung marked as training on request data in [`AGENTS.md`](./AGENTS.md) (`muse-spark-*`) is automatically skipped across both implementation and council seats, routing exclusively to zero-training rungs (`deepseek-v4.1-flash`, `glm-5.3-flash`, `gemini-4-argon`, `claude-haiku-5-5`, `gpt-6-luna`, `kimi-k3.1-pro`).

### 4. Standalone Skills & Individual Loops

Every pipeline skill and seat agent can also be triggered directly outside a full `oneshot` run:

| Example Prompt | Unit Triggered | What It Does |
| --- | --- | --- |
| `"shape a plugin hook system for custom tool permissions"` | `shape` | Socratic design exploration; writes spec to `docs/specs/` |
| `"write a plan for docs/specs/2026-11-04-plugin-hooks-design.md"` | `plan` | Produces a bite-size TDD task plan in `docs/plans/` |
| `"dispatch docs/plans/2026-11-04-plugin-hooks.md"` | `dispatch` | Runs the L1 per-task subagent loop + two-stage review on an existing plan |
| `"debug why test/webhook-retry.test.ts fails intermittently"` | `debug` | 4-phase root-cause investigation before any fix is proposed |
| `"council review this branch"` | `council` | Runs the 3-family adversarial review loop (`reviewer-a`, `reviewer-b`, `reviewer-c`) + `patch` fixes |
| `"make ci green on this PR"` | `make-ci-green` | Watches PR checks and review bots until green; fixes real bugs via `patch` |
| `"land it"` / `"next feature"` | `land` | Files or merges the PR, checks out default branch, pulls latest, and reports ready |

## Model Tank (OpenCode Go)

All seats use `opencode-go/*` exclusively. Primary seats sit on high-allowance tiers (6,320 to 45,300 req/5h) so everyday work never hits rate limits; scarce frontier capacity (`gemini-4-argon#high`, `kimi-k3.1-pro#high`) is reserved for complex tasks, difficult bugs, and last-resort escalation.

| Role | Seat Agent | Pinned Primary (est. req / 5h) | Fallback | Last Resort |
| --- | --- | --- | --- | --- |
| Implementation (default A) | `implementer` | `deepseek-v4.1-flash#high` (43,330) | `muse-spark-1.3-contributor#medium` (45,300) | `gpt-6-luna#medium` (4,230) |
| Implementation (default B) | `implementer-b` | `muse-spark-1.3-contributor#medium` (45,300) | `deepseek-v4.1-flash#high` (43,330) | `gpt-6-luna#medium` (4,230) |
| Complex tasks / hard bugs | `implementer-deep` | `gemini-4-argon#high` (440) | `deepseek-v4.1-flash#max` (43,330) | `muse-spark-1.3-contributor#high` (45,300) |
| Surgical fixes (1-2 files) | `patch` | `deepseek-v4.1-flash#high` (43,330) | `muse-spark-1.3-contributor#medium` (45,300) | `gpt-6-luna#medium` (4,230) |
| Scout / discovery | `scout` | `mimo-v2.6-flash` (30,100) | `deepseek-v4.1-flash#low` (43,330) | `glm-5.3-flash#low` (6,320) |
| Council reviewer A | `reviewer-a` | `muse-spark-1.3-contributor#xhigh` (45,300) | `claude-haiku-5-5#high` (3,850) | `kimi-k3.1-pro#high` (147) |
| Council reviewer B | `reviewer-b` | `deepseek-v4.1-flash#max` (43,330) | `gpt-6-luna#high` (4,230) | `kimi-k3.1-pro#high` (147) |
| Council reviewer C | `reviewer-c` | `glm-5.3-flash#high` (6,320) | `claude-haiku-5-5#high` (3,850) | `gpt-6-luna#high` (4,230) |
| Council escalation | `reviewer-esc` | `kimi-k3.1-pro#high` (147) | `gemini-4-argon#high` (440) | `gpt-6-luna#high` (4,230) |

*Note:* `deepseek-v4.1-flash` exposes `low|high|max` in the Go catalog (`#high` is its middle tier, `#max` its top tier), while `mimo-v2.6-flash` exposes a single default reasoning tier (no `#variant` suffix). Full routing rules and privacy gates live in [`AGENTS.md`](./AGENTS.md).

## Structure

```
agents/      9 model-pinned seats:        implementer, implementer-b,
             implementer-deep,            scout, patch,
             reviewer-a, reviewer-b,      reviewer-c, reviewer-esc
skills/      10 pipeline skills:          oneshot, shape, plan, dispatch, tdd,
                                          debug, verify, council, land,
                                          make-ci-green
AGENTS.md    harness routing instructions (installed as ~/.config/opencode/HARNESS.md)
install.sh   installer for ~/.config/opencode/
```

## Installation (For Agents and Humans)

Requires OpenCode V2 with a connected OpenCode Go provider (`/connect`). Config reloads automatically without a restart.

### 1. Clone and run `./install.sh`

```sh
git clone https://github.com/DennisLoska/skills.git
cd skills
./install.sh
```

`./install.sh` copies `agents/` and `skills/` into `${OPENCODE_CONFIG:-$HOME/.config/opencode}` and writes [`AGENTS.md`](./AGENTS.md) to `<dest>/HARNESS.md` so any existing `AGENTS.md` is never overwritten.

The copy is collision-safe. Before touching anything, the installer checks every target path; if any already exists it prints one `collision: <dest path>` line per conflict plus `refusing to overwrite; rerun with --force`, then exits 1 having copied nothing. Content is not compared, so a second run always needs `--force`, even when nothing changed.

| Flag | Effect |
| --- | --- |
| `--force` | overwrite files that already exist in the destination |
| `--prune` | after copying, remove files under `<dest>/agents` and `<dest>/skills` that no longer exist in this repository, then print `pruned N stale file(s)`. Nothing else under the destination is touched |
| `-h`, `--help` | print usage and exit 0 without copying |

Reinstall after pulling changes:

```sh
./install.sh --force              # refresh the harness files
./install.sh --force --prune      # also drop skills or agents removed upstream
```

Set `OPENCODE_CONFIG` to install anywhere other than `~/.config/opencode`:

```sh
OPENCODE_CONFIG="$HOME/.config/opencode-v2" ./install.sh
```

Run the installer contract tests (they use a throwaway `HOME` and never touch your real config):

```sh
bash test/install.sh
```

### 2. Register `HARNESS.md` in `~/.config/opencode/opencode.json`

OpenCode V2 loads `~/.config/opencode/AGENTS.md` automatically and then concatenates every file listed in `"instructions"`. Add `"~/.config/opencode/HARNESS.md"` to `"instructions"` in `~/.config/opencode/opencode.json`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "~/.config/opencode/HARNESS.md"
  ]
}
```

### 3. Verify installation

```sh
test -f ~/.config/opencode/HARNESS.md &&
  test -f ~/.config/opencode/agents/implementer.md &&
  test -f ~/.config/opencode/agents/implementer-b.md &&
  test -f ~/.config/opencode/agents/implementer-deep.md &&
  test -f ~/.config/opencode/agents/reviewer-a.md &&
  test -f ~/.config/opencode/skills/oneshot/SKILL.md &&
  test -f ~/.config/opencode/skills/council/SKILL.md &&
  echo "installed ok"
```

## License

MIT.
