# Tri provider profile

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go (open-weight long tail, cheap high-allowance quota). Distribution principle, token-output efficiency: spend frontier output tokens only where each token carries the most judgment, and push volume to the cheapest model that is still reliable for it.

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: Codex `gpt-6.1-sol` at `medium` effort (coding and everyday workhorse), with Antigravity `claude-sonnet-5-5` at `medium` as fallback, keeping Antigravity quota free for implementation.
- **Discovery (`scout`)** is read-heavy, write-light: high-allowance OpenCode Go flash models (`mimo-v2.6-flash`, `deepseek-v4.1-flash` at `low`) with Antigravity `gemini-3.8-flash` as last resort. Output is a compressed `path:line` table, so the expensive part is input, which flash models price lowest.
- **Testing & script running (`tester`)** writes red-step failing tests and runs verification/CI scripts with compressed reports: high-volume OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation (`implementer`, `implementer-deep`, `patch`)** produces the bulk of all output tokens: `implementer` runs on Antigravity `gemini-4-argon` (`medium`), falling back to OpenCode Go `gemini-4-argon` (`high`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` is reserved for complex multi-file architecture and hard root-cause bugs on Antigravity `claude-opus-5-5` (`high`), falling back to Codex `gpt-6-astra` (`high`) and `gpt-6.1-sol` (`high`); `patch` shares the cheap `tester` ladder for 1-2 file no-test edits.
- **Per-task review (`task-reviewer`)** runs once per task, often, checking spec compliance and quality on a single task diff: Codex `gpt-6.1-terra` (`high`), falling back to OpenCode Go `glm-5.3-flash` (`high`) and Antigravity `gemini-3.8-flash` (`high`), skipping any rung whose family authored the task.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`)** outputs are short and decide the merge: three independent families (open-weight on Seat A, Anthropic on Seat B, OpenAI on Seat C) at `high` effort (or provider default `-` where the Go catalog exposes a single tier). Every seat's last resort sits on a different provider than its primary, except `reviewer-a` (see outage exception below).
- **Escalation (`reviewer-esc`)** is a fourth family none of the council seats (`reviewer-a`, `reviewer-b`, `reviewer-c`) used this PR (`deepseek-v4-pro`, `qwen3.8-max`, `gemini-4-argon`), so its verdict stays independent; implementation rungs do not block it. `reviewer-esc` also supplies the non-author council vote when every council seat's family is an author family.

## Budget facts and provider load split

From the local Codex catalog (`~/.codex/models_cache.json`):

| Model | Codex description |
| --- | --- |
| `gpt-6-astra` | frontier intelligence for the most demanding work |
| `gpt-6.1-sol` | latest workhorse for coding and everyday work |
| `gpt-6.1-terra` | balanced, for straightforward work (5.6-terra wording) |
| `gpt-6-luna` | fast and affordable, for easier tasks |

Antigravity and Codex limits depend on the plan, with rolling 5-hour windows (check with `/status` in the provider), so the profile ranks those models relatively rather than by fixed request count.

OpenCode Go (`opencode.ai/docs/go`): each model gets a monthly dollar limit, and the 5-hour cap is 20% of it. Estimated requests per 5 hours below are computed from the documented per-request token mix and prices for the $10 Go plan (Go Plus is about 4x):

| Model | est. req/5h | Model | est. req/5h |
| --- | --- | --- | --- |
| deepseek-v4.1-flash (off-peak) | ~43,300 | gpt-6-luna | ~4,200 |
| muse-spark-1.3 (trains) | ~45,300 | claude-haiku-5-5 | ~3,800 |
| mimo-v2.6-flash | ~30,100 | mimo-v2.6-pro | ~3,250 |
| glm-5.3-flash | ~6,300 | minimax-m3 | ~3,200 |
| qwen3.8-flash | ~5,400 | deepseek-v4-pro (off-peak) | ~1,040 |
| gemini-4-argon (50% off to Nov 30) | ~440 | glm-5.3 | ~200 |
| qwen3.8-max | ~160 | kimi-k3.1-pro | ~147 |

Provider load split:

- **Antigravity:** Argon-heavy (`implementer` primary), plus `implementer-deep` primary (`claude-opus-5-5`) and `reviewer-b` (`claude-sonnet-5-5` / `claude-opus-5-5`). Keeping `driver`, `scout`, and `tester` off Antigravity primaries leaves room for Argon, which writes most of the code.
- **Codex:** carries `driver` (`gpt-6.1-sol`), per-task review `task-reviewer` (`gpt-6.1-terra`), and council Seat C `reviewer-c` (`gpt-6.1-sol` / `gpt-6-sol`), plus `gpt-6-astra` as `implementer-deep`'s fallback.
- **OpenCode Go:** carries the high-volume cheap roles (`scout`, `tester`, `patch`, `compaction`), the open-weight council seat (`reviewer-a`), and `reviewer-esc` primary/fallback.

### Seat A rationale, Kimi allowance, and `reviewer-a` outage exception

Under `tri`, `gemini-4-argon` (Google) is the primary implementer, so a Google council seat would review its own family. Seat A (`reviewer-a`) therefore moves to an open-weight family (`moonshot` -> `xiaomi` -> `minimax`) that never authors code under `tri`, guaranteeing it can always supply the required non-author council vote.

`kimi-k3.1-pro` is the strongest open-weight reviewer, with an allowance of ~147 req/5h (roughly 2-4 review sessions, enough for at most 3 council rounds per PR). When Kimi's 5-hour window runs out, `reviewer-a` demotes to the ~3.2k req/5h Pro models (`mimo-v2.6-pro`, then `minimax-m3`).

Exception to "last resort on a different provider": `reviewer-a` stays entirely on OpenCode Go across all three rungs so it remains an open-weight non-author family. Losing `reviewer-a` during a full OpenCode Go outage still leaves 2 independent reviewer families (`reviewer-b` Anthropic on Antigravity and `reviewer-c` OpenAI on Codex), which the degraded-council rule allows.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | antigravity | gemini-4-argon | thinking_level=medium | google | ok |
| implementer | fallback | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
| implementer | last-resort | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| implementer-deep | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| implementer-deep | fallback | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| implementer-deep | last-resort | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| tester | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| tester | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| tester | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| patch | primary | opencode | opencode-go/deepseek-v4.1-flash | variant=high | deepseek | ok |
| patch | fallback | codex | gpt-6-luna | reasoningEffort=medium | openai | ok |
| patch | last-resort | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |
| task-reviewer | primary | codex | gpt-6.1-terra | reasoningEffort=high | openai | ok |
| task-reviewer | fallback | opencode | opencode-go/glm-5.3-flash | variant=high | zhipu | ok |
| task-reviewer | last-resort | antigravity | gemini-3.8-flash | thinking_level=high | google | ok |
| reviewer-a | primary | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-a | fallback | opencode | opencode-go/mimo-v2.6-pro | - | xiaomi | ok |
| reviewer-a | last-resort | opencode | opencode-go/minimax-m3 | - | minimax | ok |
| reviewer-b | primary | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | fallback | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | last-resort | opencode | opencode-go/claude-haiku-5-5 | variant=high | anthropic | ok |
| reviewer-c | primary | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-c | fallback | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-c | last-resort | opencode | opencode-go/gpt-6-luna | variant=high | openai | ok |
| reviewer-esc | primary | opencode | opencode-go/deepseek-v4-pro | - | deepseek | ok |
| reviewer-esc | fallback | opencode | opencode-go/qwen3.8-max | - | alibaba | ok |
| reviewer-esc | last-resort | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| compaction | primary | opencode | opencode-go/claude-haiku-5-5 | variant=low | anthropic | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **OpenCode host:** native seats, plus `delegate_task` when OpenCode runs inside T3 Code.
2. **Any T3 Code provider session** (for example Codex `gpt-6.1-sol` or Antigravity `claude-sonnet-5-5`): tell the session to load `<dest>/HARNESS.md`, `<dest>/PROVIDERS.md`, and the skills from `<dest>/skills/`. It dispatches only via `delegate_task`, and permissions are self-enforced by the children.

## Privacy

The `ok` marks for Antigravity (`antigravity`) and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`). `muse-spark-*` trains on request data and is excluded from this profile.

Driver and compaction rows are advisory host recommendations; the installer validates them when present, never requires them, and never renders them.

## Catalog

Model ids are verified against the live provider catalogs: `opencode models` lists every `opencode-go/*` model id used in this table, and Codex model ids match `~/.codex/models_cache.json` (checked 2026-11-09; re-check with `orchestrator_capabilities` or `opencode models` after catalog updates).
