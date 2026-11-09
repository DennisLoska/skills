# Tri provider profile

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go (open-weight long tail, cheap high-allowance quota). Distribution principle, token-output efficiency: spend frontier output tokens only where each token carries the most judgment, and push volume to the cheapest model that is still reliable for it.

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: Codex `gpt-6.1-sol` at `medium` effort (coding and everyday workhorse), with Antigravity `claude-sonnet-5-5` at `medium` as fallback, keeping Antigravity quota free for implementation.
- **Discovery (`scout`)** is read-heavy, write-light: high-allowance OpenCode Go flash models (`mimo-v2.6-flash`, `deepseek-v4.1-flash` at `low`) with Antigravity `gemini-3.8-flash` as last resort. Output is a compressed `path:line` table, so the expensive part is input, which flash models price lowest.
- **Testing & script running (`tester`)** writes red-step failing tests and runs verification/CI scripts with compressed reports: high-volume OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation (`implementer`, `implementer-deep`, `patch`)** produces the bulk of all output tokens: `implementer` runs on Antigravity `gemini-4-argon` (`high`), falling back to Antigravity `claude-sonnet-5-5` (`medium`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` is reserved for complex multi-file architecture and hard root-cause bugs on Antigravity `claude-opus-5-5` (`high`), falling back to Codex `gpt-6-astra` (`high`) and `gpt-6.1-sol` (`high`); `patch` shares the cheap `tester` ladder for 1-2 file no-test edits.
- **Per-task review (`task-reviewer`)** runs once per task, often, checking spec compliance and quality on a single task diff: Codex `gpt-6.1-terra` (`high`), falling back to OpenCode Go `glm-5.3-flash` (`high`) and Antigravity `gemini-3.8-flash` (`high`), skipping any rung whose family authored the task.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`)** keeps Argon off council review so Argon never reviews its own code: OpenAI frontier lead / tie-breaker on Seat A (`gpt-6-astra` via Codex at `high`, falling back to `gpt-6.1-sol` and `gpt-6-sol`), Anthropic frontier on Seat B (`claude-opus-5-5` at `high`, falling back to `claude-sonnet-5-5` and OpenCode Go `opencode-go/claude-haiku-5-5`), and high-budget Open-weight Pro on Seat C (`opencode-go/deepseek-v4-pro` at ~1,040 req/5h, falling back to `opencode-go/mimo-v2.6-pro` at ~3,250 req/5h and `opencode-go/minimax-m3` at ~3,200 req/5h). Under the author-family PASS rule, while Argon (Google) authors the code, all three council seats (`openai`, `anthropic`, `deepseek`/`xiaomi`/`minimax`) are non-author families.
- **Escalation (`reviewer-esc`)** sits on high-budget open-weight Pro families (`opencode-go/mimo-v2.6-pro`, falling back to `opencode-go/minimax-m3` and `opencode-go/kimi-k3.1-pro` at `high`), keeping escalation independent of the primary council families (`openai`, `anthropic`, `deepseek`).

## Budget facts and provider load split

From the local Codex catalog (`~/.codex/models_cache.json`):

| Model | Codex description |
| --- | --- |
| `gpt-6-astra` | frontier intelligence for the most demanding work |
| `gpt-6.1-sol` | latest workhorse for coding and everyday work |
| `gpt-6.1-terra` | balanced, for straightforward work (5.6-terra wording) |
| `gpt-6-luna` | fast and affordable, for easier tasks |

No Google or OpenAI (`gpt-*`) model is routed through OpenCode Go in `tri`: all Google models come from Antigravity and all `gpt-*` models come from the Codex subscription. Antigravity and Codex limits depend on the plan, with rolling 5-hour windows (check with `/status` in the provider), so the profile ranks those models relatively rather than by fixed request count.

OpenCode Go (`opencode.ai/docs/go`): each model gets a monthly dollar limit, and the 5-hour cap is 20% of it. Estimated requests per 5 hours below are computed from the documented per-request token mix and prices for the $10 Go plan (Go Plus is about 4x):

| Model | est. req/5h | Model | est. req/5h |
| --- | --- | --- | --- |
| deepseek-v4.1-flash (off-peak) | ~43,300 | minimax-m3 | ~3,200 |
| mimo-v2.6-flash | ~30,100 | deepseek-v4-pro (off-peak) | ~1,040 |
| glm-5.3-flash | ~6,300 | glm-5.3 | ~200 |
| qwen3.8-flash | ~5,400 | qwen3.8-max | ~160 |
| claude-haiku-5-5 | ~3,800 | kimi-k3.1-pro | ~147 |
| mimo-v2.6-pro | ~3,250 | - | - |

Provider load split and council budget notes:

- **Antigravity:** carries `implementer` primary (`gemini-4-argon` at `high`) and fallback (`claude-sonnet-5-5` at `medium`), `implementer-deep` primary (`claude-opus-5-5` at `high`), and `reviewer-b` primary/fallback (`claude-opus-5-5` / `claude-sonnet-5-5`). Keeping `driver`, `scout`, `tester`, `reviewer-a`, and `reviewer-c` off Antigravity primaries leaves room for Argon and the Anthropic review seat (`antigravity-claude` is soft-capped at 6 dispatches and reserved for `reviewer-b`). Antigravity's Claude limits are low; if you also have a Claude Code (Anthropic) subscription, use [`providers/quad.md`](./quad.md) (`--profile quad`) so Anthropic roles run primarily on `claudeAgent`.
- **Codex:** carries `driver` (`gpt-6.1-sol`), per-task review `task-reviewer` (`gpt-6.1-terra`), council Seat A `reviewer-a` (`gpt-6-astra` -> `gpt-6.1-sol` -> `gpt-6-sol`), `implementer` last-resort (`gpt-6.1-sol`), `implementer-deep` fallback/last-resort (`gpt-6-astra` / `gpt-6.1-sol`), and `gpt-6-luna` fallbacks for `tester`, `patch`, and `compaction`.
- **OpenCode Go:** carries the high-volume cheap roles (`scout`, `tester`, `patch`, `compaction`), council Seat C `reviewer-c` (`deepseek-v4-pro` -> `mimo-v2.6-pro` -> `minimax-m3`), and `reviewer-esc` (`mimo-v2.6-pro` -> `minimax-m3` -> `kimi-k3.1-pro`).
- **Council budget:** the council runs at most 3 rounds × 3 seats + 1 escalation per PR. Seat A (`gpt-6-astra`), Seat B (`claude-opus-5-5`), and Seat C (`deepseek-v4-pro` ~1,040 req/5h -> `mimo-v2.6-pro` ~3,250 req/5h -> `minimax-m3` ~3,200 req/5h) give three non-author families whenever Argon authors the code, and `reviewer-esc` starts on `mimo-v2.6-pro` (~3,250 req/5h) -> `minimax-m3` (~3,200 req/5h) -> `kimi-k3.1-pro`.

| role | rung | provider | model | effort | family | privacy |
| --- | --- | --- | --- | --- | --- | --- |
| driver | primary | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| driver | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
| scout | primary | opencode | opencode-go/mimo-v2.6-flash | - | xiaomi | ok |
| scout | fallback | opencode | opencode-go/deepseek-v4.1-flash | variant=low | deepseek | ok |
| scout | last-resort | antigravity | gemini-3.8-flash | thinking_level=low | google | ok |
| implementer | primary | antigravity | gemini-4-argon | thinking_level=high | google | ok |
| implementer | fallback | antigravity | claude-sonnet-5-5 | thinking_level=medium | anthropic | ok |
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
| reviewer-a | primary | codex | gpt-6-astra | reasoningEffort=high | openai | ok |
| reviewer-a | fallback | codex | gpt-6.1-sol | reasoningEffort=high | openai | ok |
| reviewer-a | last-resort | codex | gpt-6-sol | reasoningEffort=high | openai | ok |
| reviewer-b | primary | antigravity | claude-opus-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | fallback | antigravity | claude-sonnet-5-5 | thinking_level=high | anthropic | ok |
| reviewer-b | last-resort | opencode | opencode-go/claude-haiku-5-5 | variant=high | anthropic | ok |
| reviewer-c | primary | opencode | opencode-go/deepseek-v4-pro | - | deepseek | ok |
| reviewer-c | fallback | opencode | opencode-go/mimo-v2.6-pro | - | xiaomi | ok |
| reviewer-c | last-resort | opencode | opencode-go/minimax-m3 | - | minimax | ok |
| reviewer-esc | primary | opencode | opencode-go/mimo-v2.6-pro | - | xiaomi | ok |
| reviewer-esc | fallback | opencode | opencode-go/minimax-m3 | - | minimax | ok |
| reviewer-esc | last-resort | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
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

1. **OpenCode host:** native seats (for seats with an `opencode` rung), plus `delegate_task` when OpenCode runs inside T3 Code. Under `tri`, `implementer`, `implementer-deep`, and `reviewer-a` have no `opencode` rung on their 3-rung ladder, so they are installed with no `model:` pin and dispatched via `delegate_task`.
2. **Any T3 Code provider session** (for example Codex `gpt-6.1-sol` or Antigravity `claude-sonnet-5-5`): install into all hosts with `./install.sh --target all` (or tell the session to load `<dest>/HARNESS.md`, `<dest>/PROVIDERS.md`, and the skills from `<dest>/skills/`). It dispatches via `delegate_task`, and permissions are self-enforced by the children.

## Privacy

The `ok` marks for Antigravity (`antigravity`) and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`). `muse-spark-*` trains on request data and is excluded from this profile.

Driver and compaction rows are advisory host recommendations; the installer validates them when present, never requires them, and never renders them.

## Catalog

Model ids are verified against the live provider catalogs: `opencode models` lists every `opencode-go/*` model id used in this table, and Codex model ids match `~/.codex/models_cache.json` (checked 2026-11-09; re-check with `orchestrator_capabilities` or `opencode models` after catalog updates).
