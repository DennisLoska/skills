# Role rebalance and profile parameterization (addendum)

Date: 2026-11-09. Branch: `feat/provider-decoupling` (PR #6). Amends `2026-11-09-provider-decoupling-design.md`; everything not mentioned there stays.

## Why

User feedback on the first `tri` profile:

1. Discovery should run on a cheap OpenCode Go model.
2. Opus as driver is too expensive.
3. Codex describes `gpt-6.1-sol` as the coding and everyday workhorse; `gpt-6.1-terra` might suit review better.
4. Gemini 4 Argon should be the only implementer model; drop `implementer-b`.
5. `implementer-deep` should be Opus 5.5.
6. Council seat A should change.
7. Add a dedicated cheap agent for writing tests and running scripts.
8. Models must be easy for harness users to configure, and the README architecture view and docs must be current.

## Budget facts used

From the local Codex catalog (`~/.codex/models_cache.json`):

| Model | Codex description |
| --- | --- |
| `gpt-6-astra` | frontier intelligence for the most demanding work |
| `gpt-6.1-sol` | latest workhorse for coding and everyday work |
| `gpt-6.1-terra` | balanced, for straightforward work (5.6-terra wording) |
| `gpt-6-luna` | fast and affordable, for easier tasks |

Antigravity and Codex limits depend on the plan, with rolling 5-hour windows. Check them with `/status` in the provider. The profile therefore ranks those models relatively, not by number.

OpenCode Go (opencode.ai/docs/go): each model gets a monthly dollar limit, and the 5-hour cap is 20% of it. Below, estimated requests per 5 hours are computed from the documented per-request token mix and prices, for the $10 Go plan. Go Plus is about 4x.

| Model | est. req/5h | Model | est. req/5h |
| --- | --- | --- | --- |
| deepseek-v4.1-flash (off-peak) | ~43,300 | gpt-6-luna | ~4,200 |
| muse-spark-1.3 (trains) | ~45,300 | claude-haiku-5-5 | ~3,800 |
| mimo-v2.6-flash | ~30,100 | mimo-v2.6-pro | ~3,250 |
| glm-5.3-flash | ~6,300 | minimax-m3 | ~3,200 |
| qwen3.8-flash | ~5,400 | deepseek-v4-pro (off-peak) | ~1,040 |
| gemini-4-argon (50% off to Nov 30) | ~440 | glm-5.3 | ~200 |
| qwen3.8-max | ~160 | kimi-k3.1-pro | ~147 |

Conclusions:

- **Antigravity:** under the new plan it mostly carries Argon. Argon writes most of the code, so it is the heaviest single consumer. Keep scout, tester and the driver off Antigravity to leave room for it.
- **Codex:** carries the driver, per-task review and council C.
- **OpenCode Go:** carries the high-volume cheap roles (scout, tester, patch) and the open-weight council seat.
- **Model replacements:**
  - `glm-5.3` (~200/5h) leaves every ladder; `glm-5.3-flash` stays.
  - Terra fits per-task review (spec compliance and quality on one diff), not the council.
  - Astra is too expensive for routine work. It is only `implementer-deep`'s fallback.

## Harness changes

1. **Remove `implementer-b`:** delete the agent file and drop the role from the required roles, skills, AGENTS.md and README.
   - Parallel fan-out dispatches several `implementer` instances.
   - Zero-reachable handoff: `implementer-deep` -> `implementer` and `implementer` -> `implementer-deep`, never revisiting a seat. When all are exhausted, stop and report.
   - Fixer routing reads "implementation seat (`implementer`, or `implementer-deep` for hard clusters)".
2. **New seat `tester`:** a required role with an agent file. Its permissions mirror `implementer`: shell allowed, destructive denies, secret denies, Step 0 branch check. Its contract:
   - **Red step:** for a plan task with behaviour to test, it writes the failing tests from the task brief, runs them, and confirms they fail for the right reason. It never writes production code. It never commits: the tests stay in the working tree for the implementer. It reports the test files, the run command and the failure excerpt.
   - **Script runner:** runs the suite, lint, typecheck, build and project scripts for `verify`, and reads CI logs for `make-ci-green`. It returns a compressed pass/fail report with failing names and first-error excerpts, never full logs.
   - It counts as an author family when its tests are committed.
3. **Implementer contract:** when the brief names tester-written red tests, start from them. Make them pass, refactor, run the suite, and commit tests plus implementation together. Additional tests may be added. Tester tests are never weakened or deleted without a stated reason in the report, and the spec reviewer checks that. Without tester tests (mechanical tasks), the implementer does its own red-green-refactor as before.
4. **Profile parameterization:**
   - `install.sh --profile-file <path>` binds any profile file outside the repo, so users keep their own copy and never edit the clone. The file gets the same validation. `PROVIDERS.md` is a byte copy, and the manifest line 2 is `# profile-file <absolute path>`.
   - `--profile` and `--profile-file` are mutually exclusive (exit 2).
   - On refresh without flags, a recorded `# profile-file` is reused if it still exists. Otherwise exit 2 with `install.sh: profile file not found: <path>`.
   - The README gets a "Configure models" section: copy `providers/tri.md`, edit rows, install with `--profile-file`.
5. **README:** a new architecture visualization (Mermaid) showing harness roles -> profile slots -> provider instances, with role names (no model IDs) in the pipeline diagram. Updated tables, structure, test count and setup.

## New default `tri` table

| role | primary | fallback | last-resort |
| --- | --- | --- | --- |
| driver (advisory) | codex `gpt-6.1-sol` medium | antigravity `claude-sonnet-5-5` medium | - |
| scout | opencode `mimo-v2.6-flash` - | opencode `deepseek-v4.1-flash` low | antigravity `gemini-3.8-flash` low |
| implementer | antigravity `gemini-4-argon` medium | opencode `gemini-4-argon` high | codex `gpt-6.1-sol` medium |
| implementer-deep | antigravity `claude-opus-5-5` high | codex `gpt-6-astra` high | codex `gpt-6.1-sol` high |
| tester | opencode `deepseek-v4.1-flash` high | codex `gpt-6-luna` medium | antigravity `gemini-3.8-flash` medium |
| patch | opencode `deepseek-v4.1-flash` high | codex `gpt-6-luna` medium | antigravity `gemini-3.8-flash` medium |
| task-reviewer | codex `gpt-6.1-terra` high | opencode `glm-5.3-flash` high | antigravity `gemini-3.8-flash` high |
| reviewer-a (open-weight) | opencode `kimi-k3.1-pro` high | opencode `mimo-v2.6-pro` - | opencode `minimax-m3` - |
| reviewer-b (Anthropic) | antigravity `claude-sonnet-5-5` high | antigravity `claude-opus-5-5` high | opencode `claude-haiku-5-5` high |
| reviewer-c (OpenAI) | codex `gpt-6.1-sol` high | codex `gpt-6-sol` high | opencode `gpt-6-luna` high |
| reviewer-esc | opencode `deepseek-v4-pro` - | opencode `qwen3.8-max` - | antigravity `gemini-4-argon` high |
| compaction (advisory) | opencode `claude-haiku-5-5` low | codex `gpt-6-luna` low | - |

Families: kimi=moonshot, mimo=xiaomi, minimax=minimax, qwen=alibaba, deepseek=deepseek, glm=zhipu, gemini=google, claude=anthropic, gpt=openai. All rows `privacy: ok`. Effort `-` is used where the Go catalog does not document variants.

Seat A rationale: Argon (Google) now writes the code, so a Google seat would review its own family. Seat A moves to an open-weight family that never authors under `tri`, so it can always supply the non-author vote. Kimi is the strongest open-weight reviewer, but its allowance is ~147 req/5h, roughly 2-4 review sessions. That is enough for at most 3 rounds per PR. The ladder drops to the ~3k/5h Pro models when it runs out.

Exceptions to "last resort on a different provider": `reviewer-a` (all OpenCode Go). Losing it in an outage leaves 2 families, which the degraded-council rule allows.

## Legacy profile `opencode-go`

The `implementer-b` rows are removed. New `tester` rows: deepseek-v4.1-flash high -> glm-5.3-flash high -> gpt-6-luna medium. Everything else is unchanged.

## Success criteria

- `bash test/install.sh` is green on both Bash versions. New cases:
  - `tester` is required (`incomplete: tester`).
  - No `implementer-b` file is installed or required.
  - `--profile-file` binds, records, reuses and validates.
  - `--profile-file` plus `--profile` exits 2.
  - A missing recorded profile file exits 2.
  - The new `tri` pins: scout `model: opencode-go/mimo-v2.6-flash`, implementer `model: opencode-go/gemini-4-argon#high`, tester `model: opencode-go/deepseek-v4.1-flash#high`, reviewer-a `model: opencode-go/kimi-k3.1-pro#high`, reviewer-esc `model: opencode-go/deepseek-v4-pro`, implementer-deep has no pin and prints the note.
- The harness grep stays empty, and `implementer-b` appears nowhere outside `docs/` history.
