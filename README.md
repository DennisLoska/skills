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

`./install.sh` copies `agents/` and `skills/` into `${OPENCODE_CONFIG:-$HOME/.config/opencode}` and writes [`AGENTS.md`](./AGENTS.md) to `~/.config/opencode/HARNESS.md` so any existing `~/.config/opencode/AGENTS.md` is never overwritten.

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
