# Tri provider profile

Three subscriptions: Antigravity (Google + Anthropic models), Codex (OpenAI models), OpenCode Go Plus ($40/mo, open-weight long tail with a now-large allowance). Distribution principle: spend frontier output tokens where judgment matters most, and push high-volume work to the cheapest reliable model.

- **Driver** emits little (briefs, verdicts, gate decisions) but its mistakes fan out to every child: Codex `gpt-6.1-sol` at `medium` effort, with Antigravity `claude-sonnet-5-5` at `medium` as fallback, keeping Antigravity quota free for implementation.
- **Discovery (`scout`)** is read-heavy, write-light: OpenCode Go flash models (`mimo-v2.6-flash`, `deepseek-v4.1-flash` at `low`) with Antigravity `gemini-3.8-flash` as last resort.
- **Testing & script running (`tester`)** writes red-step failing tests and runs verification/CI scripts: OpenCode Go `deepseek-v4.1-flash` (`high`), falling back to Codex `gpt-6-luna` (`medium`) and Antigravity `gemini-3.8-flash` (`medium`).
- **Implementation (`implementer`, `implementer-deep`, `patch`)** produces the bulk of output tokens: `implementer` runs on Antigravity `gemini-4-argon` (`high`), falling back to Antigravity `claude-sonnet-5-5` (`medium`) and Codex `gpt-6.1-sol` (`medium`); `implementer-deep` handles complex architecture and hard root-cause bugs on Antigravity `claude-opus-5-5` (`high`), falling back to Codex `gpt-6-astra` (`high`) and `gpt-6.1-sol` (`high`); `patch` shares the `tester` ladder for 1-2 file no-test edits.
- **Per-task review (`task-reviewer`)** checks spec compliance and quality on a single task diff: Codex `gpt-6.1-terra` (`high`), falling back to OpenCode Go `glm-5.3` (`high`, now 8x cheaper per allowance than on the Go tier) and Antigravity `gemini-3.8-flash` (`high`), skipping any rung whose family authored the task.
- **Council (`reviewer-a`, `reviewer-b`, `reviewer-c`)** keeps Argon off council review so Argon never reviews its own code: OpenAI frontier on Seat A (`gpt-6-astra` via Codex at `high`, falling back to `gpt-6.1-sol` and `gpt-6-sol`), Anthropic frontier on Seat B (`claude-opus-5-5` at `high`, falling back to `claude-sonnet-5-5` and OpenCode Go `opencode-go/claude-haiku-5-5`), and Open-weight Pro on Seat C (`opencode-go/deepseek-v4-pro` at ~4,200 req/5h, falling back to `opencode-go/mimo-v2.6-pro` at ~13,000 req/5h and `opencode-go/minimax-m3` at ~9,600 req/5h). While Argon (Google) authors the code, all three council seats (`openai`, `anthropic`, `deepseek`/`xiaomi`/`minimax`) are non-author families.
- **Escalation (`reviewer-esc`)** starts on `opencode-go/mimo-v2.6-pro` (~13,000 req/5h, `xiaomi`), falling back to `opencode-go/kimi-k3.1-pro` (`variant=high`, ~588 req/5h, `moonshot`) and `opencode-go/qwen3.8-max` (~640 req/5h, `alibaba`). `mimo-v2.6-pro` costs roughly a tenth of `kimi-k3.1-pro` per token under the same $60 monthly cap, so the tie-breaker stays on the cheap pro model; kimi is the stronger but budget-sensitive rung. `mimo-v2.6-pro` is disjoint from all three council primaries (`openai`, `anthropic`, `deepseek`), and if `reviewer-c` demotes onto `xiaomi`, `reviewer-esc` skips to `kimi-k3.1-pro` (`moonshot`) or `qwen3.8-max` (`alibaba`).

## Budget facts and provider load split

From the local Codex catalog (`~/.codex/models_cache.json`):

| Model | Codex description |
| --- | --- |
| `gpt-6-astra` | frontier intelligence for the most demanding work |
| `gpt-6.1-sol` | latest workhorse for coding and everyday work |
| `gpt-6.1-terra` | balanced, for straightforward work (5.6-terra wording) |
| `gpt-6-luna` | fast and affordable, for easier tasks |

No Google or OpenAI (`gpt-*`) model is routed through OpenCode Go in `tri`: all Google models come from Antigravity and all `gpt-*` models come from Codex. Antigravity and Codex limits use rolling 5-hour windows (check with `/status`).

OpenCode Go (`opencode.ai/docs/go`): each model has a monthly dollar limit with a 20% 5-hour cap and a 50% weekly cap. Estimated requests per 5h on the **Go Plus ($40/mo)** tier this profile is sized for:

| Model | est. req/5h | Model | est. req/5h |
| --- | --- | --- | --- |
| deepseek-v4.1-flash | ~86,700 | minimax-m3 | ~9,600 |
| mimo-v2.6-flash | ~60,200 | deepseek-v4-pro | ~4,200 |
| glm-5.3-flash | ~19,000 | glm-5.3 | ~1,760 |
| qwen3.8-flash | ~16,200 | qwen3.8-max | ~640 |
| claude-haiku-5-5 | ~15,400 | kimi-k3.1-pro | ~588 |
| mimo-v2.6-pro | ~13,000 | kimi-k3 | ~440 |

Plus does not scale uniformly from the $10 Go tier, so a blanket "Go Plus ~4x" assumption is wrong per model: the flash workhorses only double (`deepseek-v4.1-flash` 43,330 -> 86,670, `mimo-v2.6-flash` 30,100 -> 60,200), the pro tier quadruples (`kimi-k3.1-pro` 147 -> 588, `deepseek-v4-pro` 1,040 -> 4,200, `mimo-v2.6-pro` 3,250 -> 13,000), and `glm-5.3` gets 8x ($15 -> $120 monthly, 220 -> 1,760). The flash seats never needed more; the pro seats that used to be quota-starved now fit regular use.

Provider load split and council budget notes:

- **Antigravity:** carries `implementer` primary (`gemini-4-argon` at `high`) and fallback (`claude-sonnet-5-5` at `medium`), `implementer-deep` primary (`claude-opus-5-5` at `high`), and `reviewer-b` primary/fallback (`claude-opus-5-5` / `claude-sonnet-5-5`). `antigravity-claude` is soft-capped at 6 dispatches and reserved for `reviewer-b`. With a Claude Code subscription, use [`providers/quad.md`](./quad.md) (`--profile quad`).
- **Codex:** carries `driver` (`gpt-6.1-sol`), `task-reviewer` (`gpt-6.1-terra`), council Seat A `reviewer-a` (`gpt-6-astra` -> `gpt-6.1-sol` -> `gpt-6-sol`), `implementer` last-resort (`gpt-6.1-sol`), `implementer-deep` fallback/last-resort (`gpt-6-astra` / `gpt-6.1-sol`), and `gpt-6-luna` fallbacks for `tester`, `patch`, and `compaction`.
- **OpenCode Go Plus:** carries `scout`, `tester`, `patch`, `compaction`, council Seat C `reviewer-c` (`deepseek-v4-pro` -> `mimo-v2.6-pro` -> `minimax-m3`), the `task-reviewer` fallback (`glm-5.3`, which gained 8x allowance on Plus and now outclasses `glm-5.3-flash` at a workable 1,760 req/5h), and `reviewer-esc` (`mimo-v2.6-pro` -> `kimi-k3.1-pro` -> `qwen3.8-max`).
- **Council budget:** at most 3 rounds × 3 seats + 1 escalation per PR. Seat A (`gpt-6-astra`), Seat B (`claude-opus-5-5`), and Seat C (`deepseek-v4-pro` ~4,200 req/5h -> `mimo-v2.6-pro` ~13,000 req/5h -> `minimax-m3` ~9,600 req/5h) give three non-author families whenever Argon authors the code, and `reviewer-esc` starts on `kimi-k3.1-pro` (~588 req/5h) -> `mimo-v2.6-pro` (~13,000 req/5h) -> `qwen3.8-max` (`alibaba`).

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
| task-reviewer | fallback | opencode | opencode-go/glm-5.3 | variant=high | zhipu | ok |
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
| reviewer-esc | primary | opencode | opencode-go/kimi-k3.1-pro | variant=high | moonshot | ok |
| reviewer-esc | fallback | opencode | opencode-go/mimo-v2.6-pro | - | xiaomi | ok |
| reviewer-esc | last-resort | opencode | opencode-go/qwen3.8-max | - | alibaba | ok |
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
| 4 | * | codex | gpt-6.1-sol | reasoningEffort=medium | openai | ok |
| 5 | * | antigravity | gemini-3.8-flash | thinking_level=medium | google | ok |

## Supported driver setups

The `driver` row is advisory. Two setups are supported:

1. **Standalone host (without T3 Code):** OpenCode, Codex, or Antigravity (Gemini session) runs same-provider rungs natively via Dispatch Adapter Path 1/Path 3, falling back to the matching `*` row in `## Backup ladder` when primary rungs sit on other providers (standalone Claude Code uses `--profile claude` or `quad`; standalone Claude Antigravity sessions use `--profile antigravity`). Under `tri` on OpenCode, `implementer`, `implementer-deep`, and `reviewer-a` have no `opencode` ladder rung and install unpinned.
2. **Any T3 Code provider session:** `./install.sh --target all` populates standalone roots and any T3 Antigravity instances (`skills/_harness/`), dispatching across all connected providers via `delegate_task` with child-enforced permissions.

## Privacy

The `ok` marks for Antigravity (`antigravity`) and Codex (`codex`) assume the account has model-training opt-out enabled. Confirm that account setting before dispatch. OpenCode Go rows use non-training privacy classes (`ok`). `muse-spark-*` trains on request data and is excluded from this profile.

Driver and compaction rows are advisory host recommendations; the installer validates them when present, never requires them, and never renders them.

## Catalog

Model ids are verified against the live provider catalogs: `opencode models` lists every `opencode-go/*` model id used in this table, and Codex model ids match `~/.codex/models_cache.json` (checked 2026-11-09; re-check with `orchestrator_capabilities` or `opencode models` after catalog updates). Allowance figures come from `opencode.ai/docs/go` on the Go Plus ($40/mo) tier; re-read them there when the plan changes, since Plus scales non-uniformly per model (2x-8x over Go).
