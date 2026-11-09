# Tri provider profile

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go (open-weight long tail, cheap high-allowance quota). Distribution principle, token-output efficiency: spend frontier output tokens only where each token carries the most judgment, and push volume to the cheapest model that is still reliable for it.

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: Codex `gpt-6.1-sol` at `medium` effort (coding and everyday workhorse), with Antigravity `claude-sonnet-5-5` at `medium` as fallback, keeping Antigravity quota free for implementation.
- **Discovery (`scout`)** is read-heavy, write-light: high-allowance OpenCode Go flash models (`mimo-v2.6-flash`, `deepseek-v4.1-flash` at `low`) with Antigravity `gemini-3.8-flash` as last resort. Output is a compressed `path:line` table, so the expensive part is input, which flash models price lowest.
- **Testing & script running (`tester`)** writes red-step failing tests and runs verification/CI scripts with compressed reports: high-volume OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation (`implementer`, `implementer-deep`, `patch`)** produces the bulk of all output tokens: `implementer` runs on Antigravity `gemini-4-argon` (`medium`), falling back to OpenCode Go `gemini-4-argon` (`high`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` is reserved for complex multi-file architecture and hard root-cause bugs on Antigravity `claude-opus-5-5` (`high`), falling back to Codex `gpt-6-astra` (`high`) and `gpt-6.1-sol` (`high`); `patch` shares the cheap `tester` ladder for 1-2 file no-test edits.
- **Per-task review (`task-reviewer`)** runs once per task, often, checking spec compliance and quality on a single task diff: Codex `gpt-6.1-terra` (`high`), falling back to OpenCode Go `glm-5.3-flash` (`high`) and Antigravity `gemini-3.8-flash` (`high`), skipping any rung whose family authored the task.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`)** gets the strongest model of each frontier family at `high` effort: Google (`gemini-4-argon` on Seat A, falling back to OpenCode Go `opencode-go/gemini-4-argon` and `opencode-go/qwen3.8-max`), Anthropic (`claude-opus-5-5` on Seat B, falling back to `claude-sonnet-5-5` and OpenCode Go `opencode-go/claude-haiku-5-5`), and OpenAI (`gpt-6-astra` on Seat C, Codex's frontier-intelligence model, falling back to `gpt-6.1-sol` and `gpt-6-sol`). Review is short output with the highest stakes, so frontier tokens pay off most here. Under the author-family PASS rule, while Argon (Google) authors the code, the required non-author PASS vote comes from Opus (Anthropic) or Astra (OpenAI).
- **Escalation (`reviewer-esc`)** sits on the best open-weight families unused by the council seats (`opencode-go/kimi-k3.1-pro` at `high`, then `opencode-go/deepseek-v4-pro` and `opencode-go/mimo-v2.6-pro`), so its verdict stays independent of all three frontier council families; `reviewer-esc` also supplies the non-author council vote when every council seat's family is an author family.

## Budget facts and provider load split

From the local Codex catalog (`~/.codex/models_cache.json`):

| Model | Codex description |
| --- | --- |
| `gpt-6-astra` | frontier intelligence for the most demanding work |
| `gpt-6.1-sol` | latest workhorse for coding and everyday work |
| `gpt-6.1-terra` | balanced, for straightforward work (5.6-terra wording) |
| `gpt-6-luna` | fast and affordable, for easier tasks |

No OpenAI model is routed through OpenCode Go in `tri`: all `gpt-*` models come from the Codex subscription. Antigravity and Codex limits depend on the plan, with rolling 5-hour windows (check with `/status` in the provider), so the profile ranks those models relatively rather than by fixed request count.

OpenCode Go (`opencode.ai/docs/go`): each model gets a monthly dollar limit, and the 5-hour cap is 20% of it. Estimated requests per 5 hours below are computed from the documented per-request token mix and prices for the $10 Go plan (Go Plus is about 4x):

| Model | est. req/5h | Model | est. req/5h |
| --- | --- | --- | --- |
| deepseek-v4.1-flash (off-peak) | ~43,300 | minimax-m3 | ~3,200 |
| mimo-v2.6-flash | ~30,100 | deepseek-v4-pro (off-peak) | ~1,040 |
| glm-5.3-flash | ~6,300 | gemini-4-argon (50% off to Nov 30) | ~440 |
| qwen3.8-flash | ~5,400 | glm-5.3 | ~200 |
| claude-haiku-5-5 | ~3,800 | qwen3.8-max | ~160 |
| mimo-v2.6-pro | ~3,250 | kimi-k3.1-pro | ~147 |

Provider load split and council budget notes:

- **Antigravity:** carries `implementer` primary (`gemini-4-argon`), `implementer-deep` primary (`claude-opus-5-5`), `reviewer-a` primary (`gemini-4-argon`), and `reviewer-b` primary/fallback (`claude-opus-5-5` / `claude-sonnet-5-5`). Keeping `driver`, `scout`, and `tester` off Antigravity primaries leaves room for Argon and the frontier review seats. Antigravity's Claude limits are low; if you also have a Claude Code (Anthropic) subscription, use [`providers/quad.md`](./quad.md) (`--profile quad`) so Anthropic roles run primarily on `claudeAgent`.
- **Codex:** carries `driver` (`gpt-6.1-sol`), per-task review `task-reviewer` (`gpt-6.1-terra`), council Seat C `reviewer-c` (`gpt-6-astra` -> `gpt-6.1-sol` -> `gpt-6-sol`), `implementer-deep` fallback/last-resort (`gpt-6-astra` / `gpt-6.1-sol`), and `gpt-6-luna` fallbacks for `tester`, `patch`, and `compaction`.
- **OpenCode Go:** carries the high-volume cheap roles (`scout`, `tester`, `patch`, `compaction`), `reviewer-esc` (`kimi-k3.1-pro` -> `deepseek-v4-pro` -> `mimo-v2.6-pro`), and cross-provider fallbacks (`opencode-go/gemini-4-argon` is a separate ~440 req/5h pool from Antigravity's Argon quota).
- **Council budget:** the council runs at most 3 rounds × 3 seats + 1 escalation per PR. Because review outputs are short and capped at 3 rounds, frontier primaries (`gemini-4-argon`, `claude-opus-5-5`, `gpt-6-astra`) are affordable on the council seats, and `kimi-k3.1-pro`'s ~147 req/5h allowance is plenty for single-dispatch escalation (`reviewer-esc`).

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
| reviewer-a | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| reviewer-a | fallback | opencode | opencode-go/gemini-4-argon | variant=high | google | ok |
| reviewer-a | last-resort | opencode | opencode-go/qwen3.8-max | - | alibaba | ok |
| reviewer-b | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | last-resort | opencode | opencode-go/claude-haiku-5-5 | variant=high | anthropic | ok |
| reviewer-c | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-c | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-c | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-esc | primary | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-esc | fallback | opencode | opencode-go/deepseek-v4-pro | - | deepseek | ok |
| reviewer-esc | last-resort | opencode | opencode-go/mimo-v2.6-pro | - | xiaomi | ok |
| compaction | primary | opencode | opencode-go/claude-haiku-5-5 | variant=low | anthropic | ok |
| compaction | fallback | codex | gpt-6-luna | reasoningEffort=low | openai | ok |

## Quota pools

| pool | provider | models | window | soft-cap | reserve |
| --- | --- | --- | --- | --- | --- |
| antigravity-claude | antigravity | claude-* | 5h | 6 | reviewer-b |
| antigravity-gemini | antigravity | gemini-* | 5h | - | - |
| codex | codex | * | 5h | - | - |

## Backup ladder

| order | roles | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | implementer,implementer-deep,tester,patch | opencode | opencode-go/deepseek-v4-pro | - | deepseek | ok |
| 2 | reviewer-a,reviewer-b,reviewer-c,task-reviewer | opencode | opencode-go/mimo-v2.6-pro | - | xiaomi | ok |
| 3 | * | opencode | opencode-go/minimax-m3 | - | minimax | ok |

## Supported driver setups

The `driver` row stays advisory; the installer validates it when present, never requires it, and never renders it. Two setups are supported:

1. **OpenCode host:** native seats, plus `delegate_task` when OpenCode runs inside T3 Code.
2. **Any T3 Code provider session** (for example Codex `gpt-6.1-sol` or Antigravity `claude-sonnet-5-5`): tell the session to load `<dest>/HARNESS.md`, `<dest>/PROVIDERS.md`, and the skills from `<dest>/skills/`. It dispatches only via `delegate_task`, and permissions are self-enforced by the children.

## Privacy

The `ok` marks for Antigravity (`antigravity`) and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`). `muse-spark-*` trains on request data and is excluded from this profile.

Driver and compaction rows are advisory host recommendations; the installer validates them when present, never requires them, and never renders them.

## Catalog

Model ids are verified against the live provider catalogs: `opencode models` lists every `opencode-go/*` model id used in this table, and Codex model ids match `~/.codex/models_cache.json` (checked 2026-11-09; re-check with `orchestrator_capabilities` or `opencode models` after catalog updates).
